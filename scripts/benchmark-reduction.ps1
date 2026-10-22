param(
  [string]$Out = '',
  [ValidateRange(1,9)][int]$Repetitions = 3,
  [UInt64[]]$ExplorationSeeds = @(17,18,19,20),
  [ValidateRange(6,10000)][int]$Budget = 200,
  [ValidateRange(100,600000)][int]$WallMs = 60000
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'executable-common.ps1')
Set-Location -LiteralPath $projectRoot
if (-not $Out) { $Out = Join-Path $projectRoot ('results/benchmark-' + [guid]::NewGuid().ToString('N')) }
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
New-Item -ItemType Directory -Path $Out | Out-Null
$Out = (Resolve-Path -LiteralPath $Out).Path
$buffer = Find-LabExecutable $projectRoot 'buffer-lab'
if (-not (Test-Path -LiteralPath $buffer)) { throw 'Run moon build --target native first' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Invoke-Case([string[]]$ToolArgs, [int[]]$Expected, [string]$Log) {
  $lines = & $buffer @ToolArgs 2>&1
  $actual = $LASTEXITCODE
  $lines | Set-Content -LiteralPath $Log -Encoding utf8
  if ($actual -notin $Expected) { throw "Expected exit $Expected, got $actual. See $Log" }
}
function Step([string]$Id, [string]$Operation, [object[]]$Payload, [string[]]$Defines = @(), [string[]]$Uses = @(), [string[]]$Releases = @()) {
  [ordered]@{ id = $Id; op = $Operation; args = $Payload; defines = $Defines; uses = $Uses; releases = $Releases }
}
function Argument-Bytes($Trace) {
  $total = 0
  foreach ($step in $Trace.steps) { $total += [System.Text.Encoding]::UTF8.GetByteCount(($step.args | ConvertTo-Json -Compress -Depth 20)) }
  $total
}

function Numeric-Summary([double[]]$Values) {
  Require ($Values.Count -gt 0) 'Cannot summarize empty measurements'
  [double[]]$orderedValues = @($Values | Sort-Object)
  $middle = [int][Math]::Floor($orderedValues.Count / 2)
  $median = if ($orderedValues.Count % 2) { $orderedValues[$middle] } else { ($orderedValues[$middle-1] + $orderedValues[$middle]) / 2 }
  [ordered]@{ median=$median; minimum=$orderedValues[0]; maximum=$orderedValues[-1] }
}

Require ((Numeric-Summary @(9,1,3)).median -eq 3) 'Odd median self-check failed'
Require ((Numeric-Summary @(4,1,3,2)).median -eq 2.5) 'Even median self-check failed'
Require (@($ExplorationSeeds | Select-Object -Unique).Count -eq $ExplorationSeeds.Count) 'Exploration seeds must be unique'
$strategies = @('plain','dependency','state')
$stage = 'prepare-corpus'
$protocol = [ordered]@{
  schema=2; study='reduction-study-2'; repetitions=$Repetitions; strategies=$strategies
  execution_budget=$Budget; wall_budget_ms=$WallMs; exhaustive_subset_limit=6
  exploration_seeds=@($ExplorationSeeds | ForEach-Object { $_.ToString() }); exploration_modes=@('nul','share','error'); exploration_steps=64
  default_seeds=@('1','17','20261016'); synthetic_noise_counts=@(0,2,6)
  screening='Freeze every input and screen it before any timed reduction; retain passing inputs in screening.json'
  order='For repetition r and zero-based case c, rotate plain/dependency/state by (r-1+c) modulo 3'
  validation='Corrected replays and bounded subset enumeration occur after all timed reductions; reuse identical subset oracles by concrete trace hash and fingerprint'
  timing='Record controller elapsed_ms and CLI invocation_ms, including output capture; no warm-up samples discarded'
  installer_or_engine_changes=$false; executable_sha256=(Get-FileHash -LiteralPath $buffer).Hash
  script_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash; toolchain=@(& moon version --all)
  host_environment=[ordered]@{ os=[System.Runtime.InteropServices.RuntimeInformation]::OSDescription; powershell=$PSVersionTable.PSVersion.ToString(); image_version=$env:ImageVersion }
}
$protocol | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $Out 'protocol.json') -Encoding utf8

$rows = [System.Collections.Generic.List[object]]::new()
$corpus = [System.Collections.Generic.List[object]]::new()
try {
foreach ($seed in @(1,17,20261016)) {
  $inputDir = Join-Path $Out "generated-$seed"
  Invoke-Case @('generate','--mode','error','--seed',"$seed",'--out',$inputDir) 0 (Join-Path $Out "generate-$seed.log")
  $corpus.Add([ordered]@{ label = "generated-error-$seed"; path = Join-Path $inputDir 'case.json'; family = 'original-generator' })
}

foreach ($noiseCount in @(0,2,6)) {
  $operations = [System.Collections.Generic.List[object]]::new()
  for ($i = 0; $i -lt $noiseCount; $i++) {
    $a = "noise-$i"; $b = "noise-$i-copy"
    $operations.Add((Step "noise-$i-new" 'new' @('New',$a,'4142') @($a)))
    $operations.Add((Step "noise-$i-share" 'share' @('Share',$a,$b) @($b) @($a)))
    $operations.Add((Step "noise-$i-close" 'close' @('Close',$a) @() @() @($a)))
    $operations.Add((Step "noise-$i-read" 'read' @('Read',$b) @() @($b)))
    $operations.Add((Step "noise-$i-drop" 'close' @('Close',$b) @() @() @($b)))
  }
  $operations.Add((Step 'create' 'new' @('New','a','4142434445464748') @('a')))
  $operations.Add((Step 'alias' 'share' @('Share','a','b') @('b') @('a')))
  $operations.Add((Step 'expand' 'resize' @('Resize','b',16) @() @('b')))
  $operations.Add((Step 'write-after-expand' 'write' @('Write','a',15,9) @() @('a')))
  $operations.Add((Step 'rejected-write' 'reject_write' @('RejectWrite','b',99) @() @('b')))
  $operations.Add((Step 'observe' 'read' @('Read','b') @() @('b')))
  $trace = [ordered]@{
    schema = 1; adapter = 'buffer'; adapter_version = '1'; generator_version = 'resize-benchmark-1'; seed = "$noiseCount"
    environment = [ordered]@{ fixture_mode = 'error'; profile = 'behavior' }; steps = $operations.ToArray()
  }
  $inputPath = Join-Path $Out "resize-$noiseCount.json"
  $trace | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $inputPath -Encoding utf8
  $corpus.Add([ordered]@{ label = "resize-alias-$noiseCount"; path = $inputPath; family = 'synthetic-resize-alias' })
  # Separate the state transition from its dependent write so the initial block
  # schedule does not always delete them together. This is a labelled synthetic
  # counterexample family, not an estimate of real-library defect frequency.
  $separated = [System.Collections.Generic.List[object]]::new()
  foreach ($step in $operations) {
    $separated.Add($step)
    if ($step.id -eq 'expand') {
      $separated.Add((Step 'read-after-expand-1' 'read' @('Read','b') @() @('b')))
      $separated.Add((Step 'read-after-expand-2' 'read' @('Read','b') @() @('b')))
    }
  }
  $trace.steps = $separated.ToArray()
  $inputPath = Join-Path $Out "separated-resize-$noiseCount.json"
  $trace | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $inputPath -Encoding utf8
  $corpus.Add([ordered]@{ label = "separated-resize-$noiseCount"; path = $inputPath; family = 'synthetic-separated-resize' })
}

foreach ($seed in $ExplorationSeeds) {
  foreach ($fixtureMode in @('nul','share','error')) {
    $label = "stateful-$fixtureMode-$seed"
    $inputDir = Join-Path $Out "$label-input"
    Invoke-Case @('generate','--generator','stateful','--mode',$fixtureMode,'--seed',"$seed",'--steps','64','--out',$inputDir) @(0) (Join-Path $Out "$label-input.log")
    $corpus.Add([ordered]@{ label=$label; path=Join-Path $inputDir 'case.json'; family='stateful-exploration' })
  }
}

# Freeze and screen every planned input before timing. Passing generated cases
# remain in the manifest rather than being replaced with a convenient failure.
$screening = [System.Collections.Generic.List[object]]::new()
$selectedCorpus = [System.Collections.Generic.List[object]]::new()
foreach ($entry in $corpus) {
  $stage = "screen/$($entry.label)"
  $trace = Read-Json $entry.path
  Require ($trace.environment.profile -eq 'behavior') 'Comparison requires a behavior-profile executable'
  $baselineDir = Join-Path $Out "$($entry.label)-baseline"
  Invoke-Case @('replay',$entry.path,'--out',$baselineDir) @(0,1) (Join-Path $Out "$($entry.label)-baseline.log")
  $baseline = Read-Json (Join-Path $baselineDir 'case-1/report.json')
  Require ($baseline.outcome -in @('Pass','PropertyFailure')) 'Corpus encountered a harness/environment failure'
  $entry['input_sha256'] = (Get-FileHash -LiteralPath $entry.path).Hash
  $entry['fingerprint'] = $baseline.fingerprint
  $screening.Add([ordered]@{
    case=$entry.label; family=$entry.family; seed=$trace.seed; fixture_mode=$trace.environment.fixture_mode
    path=[System.IO.Path]::GetRelativePath($Out,$entry.path).Replace('\','/'); sha256=$entry.input_sha256
    outcome=$baseline.outcome; fingerprint=$baseline.fingerprint; included=($baseline.outcome -eq 'PropertyFailure')
  })
  if ($baseline.outcome -eq 'PropertyFailure') { $selectedCorpus.Add($entry) }
  $screening.ToArray() | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $Out 'screening.json') -Encoding utf8
}
Require ($selectedCorpus.Count -gt 0) 'No reproducible property failures in corpus'

for ($repetition = 1; $repetition -le $Repetitions; $repetition++) {
  for ($caseIndex = 0; $caseIndex -lt $selectedCorpus.Count; $caseIndex++) {
    $entry = $selectedCorpus[$caseIndex]
    $original = Read-Json $entry.path
    $offset = ($repetition - 1 + $caseIndex) % $strategies.Count
    for ($position = 0; $position -lt $strategies.Count; $position++) {
      $strategy = $strategies[($offset + $position) % $strategies.Count]
      $label = "$($entry.label)-repeat-$repetition-$strategy"
      $stage = "measure/$label"
      $destination = Join-Path $Out $label
      $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
      Invoke-Case @('shrink',$entry.path,'--strategy',$strategy,'--budget',"$Budget",'--wall-ms',"$WallMs",'--out',$destination) @(1,3) (Join-Path $Out "$label.log")
      $stopwatch.Stop()
      $reduction = Read-Json (Join-Path $destination 'reduction.json')
      Require ($reduction.baseline.fingerprint -eq $entry.fingerprint) 'Benchmark changed failure oracle'
      Require ($reduction.executions -le $Budget) 'Reduction exceeded execution budget'
      $ledger = @(Get-Content -LiteralPath (Join-Path $destination 'reduction-events.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
      Require (@($ledger | Where-Object { $null -ne $_.report }).Count -eq $reduction.executions) 'Incomplete execution ledger'
      $repairRemovals = @($ledger | ForEach-Object { $_.repair_removals }).Count
      $semanticRemovals = @($ledger | ForEach-Object { $_.repair_removals } | Where-Object reason -eq 'write precondition violated').Count
      if ($strategy -eq 'state' -and $entry.label -eq 'separated-resize-0' -and $reduction.deletion_minimal) {
        Require ($semanticRemovals -gt 0) 'Separated resize case did not exercise semantic state repair'
      }
      $proposals = $reduction.accepted_candidates + $reduction.rejected_candidates + $reduction.invalid_candidates
      $row = [ordered]@{
        case=$entry.label; family=$entry.family; strategy=$strategy; repetition=$repetition; order_position=$position+1
        directory=$label; input_sha256=$entry.input_sha256; reduced_sha256=(Get-FileHash (Join-Path $destination 'reduced.json')).Hash
        original_steps=$original.steps.Count; reduced_steps=$reduction.reduced_steps
        original_argument_bytes=Argument-Bytes $original; reduced_argument_bytes=Argument-Bytes $reduction.trace
        proposals=$proposals; invalid_proposals=$reduction.invalid_candidates
        worker_executions=$reduction.executions; elapsed_ms=[long]$reduction.elapsed_ms; invocation_ms=$stopwatch.ElapsedMilliseconds
        repair_removals=$repairRemovals; semantic_write_removals=$semanticRemovals; fingerprint=$entry.fingerprint
        confirmed=$reduction.confirmed; stop_reason=$reduction.stop_reason; deletion_minimal=$reduction.deletion_minimal
        inconclusive_neighbors=$reduction.inconclusive_neighbors; corrected_replay=$false
        subset_oracle_status='pending'; proper_subsets_checked=0; proper_subsets_total=0; subset_oracle_source=$null
      }
      $rows.Add($row)
      $rows.ToArray() | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Out 'measurements.json') -Encoding utf8
      Write-Host "$label : $($original.steps.Count) -> $($reduction.reduced_steps), $($reduction.executions) workers, $($reduction.stop_reason)"
    }
  }
}

# Keep validation work outside every timed measurement. Identical concrete state
# results reuse their checked subset oracle; large results are reported as such.
$oracleCache = @{}
foreach ($row in $rows) {
  $stage = "validate/$($row.directory)"
  $reducedPath = Join-Path $Out "$($row.directory)/reduced.json"
  Invoke-Case @('replay',$reducedPath,'--mode','correct','--out',(Join-Path $Out "$($row.directory)-corrected")) @(0) (Join-Path $Out "$($row.directory)-corrected.log")
  $row.corrected_replay = $true
  $row.subset_oracle_status = 'not-state-strategy'
  if ($row.strategy -eq 'state') {
    $row.subset_oracle_status = 'unconfirmed-or-incomplete'
    if ($row.confirmed -and $row.deletion_minimal) {
      $trace = Read-Json $reducedPath
      $finalSteps = @($trace.steps)
      $row.subset_oracle_status = 'above-six-step-limit'
      if ($finalSteps.Count -le 6) {
        $oracleKey = "$($row.reduced_sha256):$($row.fingerprint)"
        $row.proper_subsets_total = (1 -shl $finalSteps.Count) - 1
        if ($oracleCache.ContainsKey($oracleKey)) {
          $row.subset_oracle_status = 'reused'
          $row.subset_oracle_source = $oracleCache[$oracleKey]
        } else {
          for ($mask = 0; $mask -lt $row.proper_subsets_total; $mask++) {
            $kept = [System.Collections.Generic.List[object]]::new()
            for ($i = 0; $i -lt $finalSteps.Count; $i++) { if (($mask -band (1 -shl $i)) -ne 0) { $kept.Add($finalSteps[$i]) } }
            $trace.steps = $kept.ToArray()
            $subsetPath = Join-Path $Out "$($row.directory)-subset-$mask.json"
            $trace | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $subsetPath -Encoding utf8
            $subsetDir = Join-Path $Out "$($row.directory)-subset-$mask"
            Invoke-Case @('replay',$subsetPath,'--out',$subsetDir) @(0,1,2) (Join-Path $Out "$($row.directory)-subset-$mask.log")
            $report = Read-Json (Join-Path $subsetDir 'case-1/report.json')
            Require ($report.outcome -in @('Pass','PropertyFailure','InvalidCase')) 'Subset encountered an environment/protocol failure'
            Require ($report.fingerprint -ne $row.fingerprint) 'A proper subset preserves the failure'
            $row.proper_subsets_checked++
          }
          $row.subset_oracle_status = 'checked'
          $row.subset_oracle_source = $row.directory
          $oracleCache[$oracleKey] = $row.directory
        }
      }
    }
  }
  $rows.ToArray() | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Out 'measurements.json') -Encoding utf8
}
foreach ($entry in $corpus) { Require ((Get-FileHash -LiteralPath $entry.path).Hash -eq $entry.input_sha256) 'Frozen corpus input changed' }

$aggregate = [System.Collections.Generic.List[object]]::new()
foreach ($entry in $selectedCorpus) {
  foreach ($strategy in $strategies) {
    $samples = @($rows | Where-Object { $_.case -eq $entry.label -and $_.strategy -eq $strategy })
    Require ($samples.Count -eq $Repetitions) 'Missing repeated measurement'
    $signatures = @($samples | ForEach-Object { "$($_.reduced_sha256)/$($_.worker_executions)/$($_.proposals)/$($_.invalid_proposals)/$($_.stop_reason)/$($_.confirmed)/$($_.deletion_minimal)" } | Select-Object -Unique)
    $aggregate.Add([ordered]@{
      case=$entry.label; family=$entry.family; strategy=$strategy; repetitions=$samples.Count
      reduced_steps=Numeric-Summary $samples.reduced_steps; reduced_argument_bytes=Numeric-Summary $samples.reduced_argument_bytes
      worker_executions=Numeric-Summary $samples.worker_executions; invalid_proposals=Numeric-Summary $samples.invalid_proposals
      elapsed_ms=Numeric-Summary $samples.elapsed_ms; invocation_ms=Numeric-Summary $samples.invocation_ms
      complete_searches=@($samples | Where-Object { $_.confirmed -and $_.deletion_minimal -and $_.stop_reason -eq 'search_complete' }).Count
      structurally_repeatable=($signatures.Count -eq 1)
    })
  }
}
$aggregate.ToArray() | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Out 'aggregate.json') -Encoding utf8
$summary = [System.Collections.Generic.List[string]]::new()
$summary.Add('# Repeated reduction comparison')
$summary.Add('')
$summary.Add("Screened $($corpus.Count) fixed inputs, included $($selectedCorpus.Count) observed property failures; $Repetitions repetitions with rotating strategy order (balanced when repetitions are a multiple of three). Execution budget $Budget, wall budget $WallMs ms. Passing inputs and incomplete searches remain explicit. This is a local labelled-fixture study, not a statistical claim about external libraries.")
$summary.Add('')
$summary.Add('| Case | Strategy | Steps median | Workers median | Invalid median | Controller ms median (min-max) | Complete |')
$summary.Add('|---|---|---:|---:|---:|---:|---:|')
foreach ($item in $aggregate) { $summary.Add("| $($item.case) | $($item.strategy) | $($item.reduced_steps.median) | $($item.worker_executions.median) | $($item.invalid_proposals.median) | $($item.elapsed_ms.median) ($($item.elapsed_ms.minimum)-$($item.elapsed_ms.maximum)) | $($item.complete_searches)/$Repetitions |") }
$summary.Add('')
$summary.Add('Structural repeatability includes concrete reduced input, candidate counts, workers and stopping status. Timings include process/file IO and uncontrolled host load. Exhaustive raw-subset checks apply only to confirmed state results of at most six steps, once per identical result/fingerprint; larger and incomplete results are marked. No parameter/global minimality or same-native-root-cause claim.')
$summary | Set-Content -LiteralPath (Join-Path $Out 'comparison.md') -Encoding utf8
[ordered]@{
  schema=2; state='passed'; screened_cases=$corpus.Count; cases=$selectedCorpus.Count; passing_inputs=$corpus.Count-$selectedCorpus.Count
  strategies=$strategies; repetitions=$Repetitions; measurements=$rows.Count
  complete_searches=@($rows | Where-Object { $_.confirmed -and $_.deletion_minimal -and $_.stop_reason -eq 'search_complete' }).Count
  repeatable_case_strategies=@($aggregate | Where-Object structurally_repeatable -eq $true).Count
  case_strategy_groups=$aggregate.Count; actual_proper_subsets_checked=($rows.proper_subsets_checked | Measure-Object -Sum).Sum
  large_state_results=@($rows | Where-Object subset_oracle_status -eq 'above-six-step-limit').Count
  completed_at=[DateTimeOffset]::UtcNow.ToString('o'); executable_sha256=$protocol.executable_sha256
  protocol_sha256=(Get-FileHash -LiteralPath (Join-Path $Out 'protocol.json')).Hash
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Out 'verification.json') -Encoding utf8
Write-Host "Repeated comparison passed. Evidence: $Out"
} catch {
  [ordered]@{ state='failed'; stage=$stage; error=$_.Exception.Message; completed_measurements=$rows.Count } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Out 'failure.json') -Encoding utf8
  throw
}
