param([string]$Out = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if (-not $Out) { $Out = Join-Path $projectRoot ('results/benchmark-' + [guid]::NewGuid().ToString('N')) }
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
New-Item -ItemType Directory -Path $Out | Out-Null
$Out = (Resolve-Path -LiteralPath $Out).Path
$buffer = Join-Path $projectRoot '_build/native/debug/build/cmd/buffer-lab/buffer-lab.exe'
if (-not (Test-Path -LiteralPath $buffer)) { throw 'Run moon build --target native first' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Invoke-Case([string[]]$ToolArgs, [int]$Expected, [string]$Log) {
  $lines = & $buffer @ToolArgs 2>&1
  $actual = $LASTEXITCODE
  $lines | Set-Content -LiteralPath $Log -Encoding utf8
  if ($actual -ne $Expected) { throw "Expected exit $Expected, got $actual. See $Log" }
}
function Step([string]$Id, [string]$Operation, [object[]]$Payload, [string[]]$Defines = @(), [string[]]$Uses = @(), [string[]]$Releases = @()) {
  [ordered]@{ id = $Id; op = $Operation; args = $Payload; defines = $Defines; uses = $Uses; releases = $Releases }
}
function Argument-Bytes($Trace) {
  $total = 0
  foreach ($step in $Trace.steps) { $total += [System.Text.Encoding]::UTF8.GetByteCount(($step.args | ConvertTo-Json -Compress -Depth 20)) }
  $total
}

$rows = [System.Collections.Generic.List[object]]::new()
$corpus = [System.Collections.Generic.List[object]]::new()
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
    environment = @{ fixture_mode = 'error'; profile = 'behavior' }; steps = $operations.ToArray()
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

foreach ($entry in $corpus) {
  $label = $entry.label
  $original = Read-Json $entry.path
  $baselineDir = Join-Path $Out "$label-baseline"
  Invoke-Case @('replay',$entry.path,'--out',$baselineDir) 1 (Join-Path $Out "$label-baseline.log")
  $baseline = Read-Json (Join-Path $baselineDir 'case-1/report.json')
  Require ($baseline.outcome -eq 'PropertyFailure') 'Corpus case did not reproduce a property failure'
  foreach ($strategy in @('plain','dependency','state')) {
    $destination = Join-Path $Out "$label-$strategy"
    Invoke-Case @('shrink',$entry.path,'--strategy',$strategy,'--budget','200','--out',$destination) 1 (Join-Path $Out "$label-$strategy.log")
    $reduction = Read-Json (Join-Path $destination 'reduction.json')
    Require ($reduction.confirmed -and $reduction.deletion_minimal -and $reduction.stop_reason -eq 'search_complete') "Unfinished benchmark: $label/$strategy"
    Require ($reduction.baseline.fingerprint -eq $baseline.fingerprint) 'Benchmark changed failure oracle'
    $ledger = @(Get-Content -LiteralPath (Join-Path $destination 'reduction-events.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
    $repairRemovals = @($ledger | ForEach-Object { $_.repair_removals }).Count
    $semanticRemovals = @($ledger | ForEach-Object { $_.repair_removals } | Where-Object reason -eq 'write precondition violated').Count
    if ($strategy -eq 'state' -and $label -eq 'separated-resize-0') {
      Require ($semanticRemovals -gt 0) 'Separated resize case did not exercise semantic state repair'
    }
    $proposals = $reduction.accepted_candidates + $reduction.rejected_candidates + $reduction.invalid_candidates
    $invalidRate = if ($proposals) { [Math]::Round(100.0 * $reduction.invalid_candidates / $proposals,2) } else { 0 }
    $row = [ordered]@{
      case = $label; family = $entry.family; strategy = $strategy
      original_steps = $original.steps.Count; reduced_steps = $reduction.reduced_steps
      original_argument_bytes = Argument-Bytes $original; reduced_argument_bytes = Argument-Bytes $reduction.trace
      proposals = $proposals; invalid_proposals = $reduction.invalid_candidates; invalid_percent = $invalidRate
      worker_executions = $reduction.executions; elapsed_ms = [long]$reduction.elapsed_ms
      repair_removals = $repairRemovals; semantic_write_removals = $semanticRemovals; fingerprint = $baseline.fingerprint
      neighborhood_checked = $reduction.neighborhood_checked; deletion_minimal = $reduction.deletion_minimal
    }
    $rows.Add($row)
    $fixedDir = Join-Path $Out "$label-$strategy-corrected"
    Invoke-Case @('replay',(Join-Path $destination 'reduced.json'),'--mode','correct','--out',$fixedDir) 0 (Join-Path $Out "$label-$strategy-corrected.log")

    # Check every proper raw subset of the final state-strategy result using
    # independent bit-mask enumeration, never the reducer's deletion helper.
    if ($strategy -eq 'state') {
      $trace = Read-Json (Join-Path $destination 'reduced.json')
      $finalSteps = @($trace.steps)
      Require ($finalSteps.Count -le 6) 'Exhaustive subset oracle limited to six steps'
      for ($mask = 0; $mask -lt (1 -shl $finalSteps.Count) - 1; $mask++) {
        $selected = [System.Collections.Generic.List[object]]::new()
        for ($i = 0; $i -lt $finalSteps.Count; $i++) { if (($mask -band (1 -shl $i)) -ne 0) { $selected.Add($finalSteps[$i]) } }
        $trace.steps = $selected.ToArray()
        $subsetPath = Join-Path $Out "$label-subset-$mask.json"
        $trace | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $subsetPath -Encoding utf8
        $subsetDir = Join-Path $Out "$label-subset-$mask"
        $lines = & $buffer replay $subsetPath --out $subsetDir 2>&1
        $subsetExit = $LASTEXITCODE
        $lines | Set-Content -LiteralPath (Join-Path $Out "$label-subset-$mask.log") -Encoding utf8
        $report = Read-Json (Join-Path $subsetDir 'case-1/report.json')
        Require ($subsetExit -in @(0,1,2) -and $report.outcome -in @('Pass','PropertyFailure','InvalidCase')) 'Subset oracle encountered a harness/environment failure'
        Require ($report.fingerprint -ne $baseline.fingerprint) 'A proper subset preserves the failure'
      }
      $row['proper_subsets_checked'] = (1 -shl $finalSteps.Count) - 1
    }
    Write-Host "$label/${strategy}: $($original.steps.Count) -> $($reduction.reduced_steps), $($reduction.executions) executions"
    # Preserve partial aggregate results even if a later case fails.
    $rows.ToArray() | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Out 'measurements.json') -Encoding utf8
  }
}

$summary = [System.Collections.Generic.List[string]]::new()
$summary.Add('# Reduction comparison')
$summary.Add('')
$summary.Add("Pilot on $($corpus.Count) deterministic local fixtures; identical scheduler, oracle, candidate-execution budget (200) and wall budget (60s). All strategies validate before launching workers. Runs are sequential, single measurements; timing is dominated by process/file IO and is not a statistical performance claim.")
$summary.Add('')
$summary.Add('| Case | Strategy | Steps | Argument bytes | Invalid proposals | Worker executions | Elapsed ms |')
$summary.Add('|---|---|---:|---:|---:|---:|---:|')
foreach ($row in $rows) { $summary.Add("| $($row.case) | $($row.strategy) | $($row.original_steps) -> $($row.reduced_steps) | $($row.original_argument_bytes) -> $($row.reduced_argument_bytes) | $($row.invalid_proposals)/$($row.proposals) | $($row.worker_executions) | $($row.elapsed_ms) |") }
$summary.Add('')
$summary.Add('State repair only deletes rejected transitions; it cannot rewrite values or claim the same native root cause. Every final result has three confirmation runs and a complete deletion-neighborhood audit. All proper raw subsets of state results were checked independently. These observations do not establish global minimality across parameter changes or general superiority on external libraries.')
$summary | Set-Content -LiteralPath (Join-Path $Out 'comparison.md') -Encoding utf8
[ordered]@{ state = 'passed'; cases = $corpus.Count; strategies = @('plain','dependency','state'); measurements = $rows.Count; completed_at = [DateTimeOffset]::UtcNow.ToString('o'); toolchain = @(& moon version --all); executable_sha256 = (Get-FileHash -LiteralPath $buffer).Hash } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Out 'verification.json') -Encoding utf8
Write-Host "Comparison passed. Evidence: $Out"
