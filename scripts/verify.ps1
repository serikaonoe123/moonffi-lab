param([string]$Out = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if (-not $Out) { $Out = Join-Path $projectRoot ('results/verify-' + [guid]::NewGuid().ToString('N')) }
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
New-Item -ItemType Directory -Path $Out | Out-Null
$Out = (Resolve-Path -LiteralPath $Out).Path

function Check([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}
function Invoke-Tool([string]$Exe, [string[]]$ToolArgs, [int]$Expected, [string]$Log) {
  $lines = & $Exe @ToolArgs 2>&1
  $actual = $LASTEXITCODE
  $lines | Set-Content -LiteralPath $Log -Encoding utf8
  if ($actual -ne $Expected) { throw "$Exe $($ToolArgs -join ' ') exited $actual, expected $Expected. See $Log" }
}
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }

# Check imported bytes before compiling. No sibling repository is consulted.
$snapshot = Join-Path $projectRoot 'vendor/eigen-binding'
foreach ($entry in (Read-Json (Join-Path $snapshot 'manifest.json'))) {
  $hash = (Get-FileHash -LiteralPath (Join-Path $snapshot $entry.path) -Algorithm SHA256).Hash
  Check ($hash -eq $entry.sha256) "Snapshot hash mismatch: $($entry.path)"
}
Invoke-Tool 'moon' @('check','--target','native','--deny-warn') 0 (Join-Path $Out 'check.log')
Invoke-Tool 'moon' @('test','--target','native','--deny-warn','-j','1') 0 (Join-Path $Out 'tests.log')
Invoke-Tool 'moon' @('build','--target','native') 0 (Join-Path $Out 'build.log')
$buffer = Join-Path $projectRoot '_build/native/debug/build/cmd/buffer-lab/buffer-lab.exe'
$eigen = Join-Path $projectRoot '_build/native/debug/build/cmd/eigen-lab/eigen-lab.exe'
$oracle = Join-Path $projectRoot '_build/native/debug/build/cmd/reducer-probe/reducer-probe.exe'
$facts = [System.Collections.Generic.List[object]]::new()
foreach ($kind in @('buffer','eigen')) {
  $exe = if ($kind -eq 'buffer') { $buffer } else { $eigen }
  $destination = Join-Path $Out "$kind-correct"
  Invoke-Tool $exe @('run','--seed','20261016','--cases','10','--out',$destination) 0 (Join-Path $Out "$kind-correct.log")
  $reports = @(Read-Json (Join-Path $destination 'summary.json'))
  Check ($reports.Count -eq 10 -and @($reports | Where-Object outcome -ne 'Pass').Count -eq 0) "$kind did not pass ten isolated scenarios"
  $facts.Add([ordered]@{ adapter = $kind; cases = 10; outcome = 'Pass' })
}

foreach ($mode in @('nul','share','error')) {
  $originalDir = Join-Path $Out "mutant-$mode"
  Invoke-Tool $buffer @('run','--mode',$mode,'--out',$originalDir) 1 (Join-Path $Out "$mode.log")
  $original = Read-Json (Join-Path $originalDir 'case-1/report.json')
  Check ($original.outcome -eq 'PropertyFailure') "Wrong classification for $mode"
  $reductionDir = Join-Path $Out "reduce-$mode"
  Invoke-Tool $buffer @('shrink',(Join-Path $originalDir 'case-1/case.json'),'--budget','100','--out',$reductionDir) 1 (Join-Path $Out "reduce-$mode.log")
  $reduction = Read-Json (Join-Path $reductionDir 'reduction.json')
  Check ($reduction.confirmed -and $reduction.reduced_steps -lt $reduction.original_steps -and $reduction.executions -le 100) "Reduction not confirmed/smaller/bounded for $mode"
  Check ($reduction.baseline_checks -eq 3 -and $reduction.final_checks -eq 3 -and $reduction.stop_reason -eq 'search_complete') "Incomplete search/stability checks for $mode"
  $reducedPath = Join-Path $reductionDir 'reduced.json'
  $replayDir = Join-Path $Out "replay-$mode"
  Invoke-Tool $buffer @('replay',$reducedPath,'--out',$replayDir) 1 (Join-Path $Out "replay-$mode.log")
  $replayed = Read-Json (Join-Path $replayDir 'case-1/report.json')
  Check ($replayed.fingerprint -eq $original.fingerprint) "Changed fingerprint for $mode"
  $fixedDir = Join-Path $Out "fixed-$mode"
  Invoke-Tool $buffer @('replay',$reducedPath,'--mode','correct','--out',$fixedDir) 0 (Join-Path $Out "fixed-$mode.log")

  # Independent enumeration of all proper subsets: it never calls delete_block.
  # Invalid subsets must be rejected; valid subsets must lose this fingerprint.
  $trace = Read-Json $reducedPath
  $allSteps = @($trace.steps)
  Check ($allSteps.Count -le 6) 'Subset oracle bounded to six steps'
  $subsetCount = (1 -shl $allSteps.Count) - 1
  for ($mask = 0; $mask -lt $subsetCount; $mask++) {
    $trace.steps = @($allSteps | Where-Object { $position = [array]::IndexOf($allSteps, $_); ($mask -band (1 -shl $position)) -ne 0 })
    $subsetPath = Join-Path $Out "subset-$mode-$mask.json"
    $trace | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $subsetPath -Encoding utf8
    $subsetDir = Join-Path $Out "subset-$mode-$mask"
    $lines = & $buffer replay $subsetPath --out $subsetDir 2>&1
    $subsetExit = $LASTEXITCODE
    $lines | Set-Content -LiteralPath (Join-Path $Out "subset-$mode-$mask.log") -Encoding utf8
    $report = Read-Json (Join-Path $subsetDir 'case-1/report.json')
    Check ($subsetExit -in @(0,1,2)) "Unexpected subset exit $subsetExit"
    Check ($report.outcome -in @('Pass','PropertyFailure','InvalidCase')) 'Subset had a harness/environment failure'
    Check ($report.fingerprint -ne $original.fingerprint) "Proper subset preserves failure: $mode/$mask"
  }
  $facts.Add([ordered]@{ mode = $mode; original_steps = $reduction.original_steps; reduced_steps = $reduction.reduced_steps; executions = $reduction.executions; confirmed = $reduction.confirmed; fingerprint = $original.fingerprint; proper_subsets_checked = $subsetCount; corrected_replay = 'Pass' })
}

foreach ($probe in @(@('crash',1,'Crash'), @('hang',3,'Timeout'))) {
  $destination = Join-Path $Out $probe[0]
  Invoke-Tool $buffer @('run','--mode',$probe[0],'--timeout-ms','500','--out',$destination) ([int]$probe[1]) (Join-Path $Out ($probe[0] + '.log'))
  $report = Read-Json (Join-Path $destination 'case-1/report.json')
  Check ($report.outcome -eq $probe[2]) 'Wrong controller probe classification'
  $facts.Add([ordered]@{ probe = $probe[0]; outcome = $report.outcome; raw_exit_code = $report.raw_exit_code })
}

# Synthetic subprocess oracle isolates reducer logic from the real FFI fixtures.
foreach ($scenario in @(
  @('stable',100,1,'search_complete',$true),
  @('stable',6,1,'execution_budget',$true),
  @('flaky-baseline',100,3,'unstable_baseline',$false),
  @('changing-fingerprint',100,3,'unstable_baseline',$false),
  @('flaky-final',100,3,'unstable_final',$false),
  @('pass',100,3,'unsupported_outcome',$false)
)) {
  $mode = [string]$scenario[0]
  $budget = [int]$scenario[1]
  $label = "oracle-$mode-$budget"
  $sourceDir = Join-Path $Out "$label-input"
  Invoke-Tool $oracle @('generate','--mode',$mode,'--out',$sourceDir) 0 (Join-Path $Out "$label-input.log")
  $destination = Join-Path $Out $label
  Invoke-Tool $oracle @('shrink',(Join-Path $sourceDir 'case.json'),'--budget',"$budget",'--out',$destination) ([int]$scenario[2]) (Join-Path $Out "$label.log")
  $reduction = Read-Json (Join-Path $destination 'reduction.json')
  Check ($reduction.stop_reason -eq $scenario[3] -and $reduction.confirmed -eq $scenario[4]) "Wrong reducer status for $label"
  Check ($reduction.executions -le $budget) "Execution budget exceeded for $label"
  $ledger = @(Get-Content -LiteralPath (Join-Path $destination 'reduction-events.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
  $executed = @($ledger | Where-Object { $null -ne $_.report })
  Check ($executed.Count -eq $reduction.executions) "Missing execution diagnostics for $label"
  if ($mode -eq 'stable' -and $budget -eq 100) {
    Check ($reduction.reduced_steps -eq 2) 'Synthetic oracle must retain arm + fail'
    Check ($reduction.invalid_candidates -ge 3) 'Invalid parameter candidates were not diagnosed'
    Check (@($ledger | Where-Object { $_.message -like '*changed operation*' }).Count -ge 2) 'Missing structural candidate rejection'
  }
  if ($budget -eq 6) {
    Check ($reduction.executions -eq 6 -and $reduction.reduced_steps -eq $reduction.original_steps) 'Six-run budget must reserve baseline/final checks without claiming reduction'
  }
  $facts.Add([ordered]@{ probe = $label; stop_reason = $reduction.stop_reason; confirmed = $reduction.confirmed; executions = $reduction.executions })
}

# A hanging baseline gets only the remaining shrink wall budget, rather than
# the full default three-second case timeout. Allow process/file-IO overhead.
$wallDestination = Join-Path $Out 'wall-budget'
Invoke-Tool $buffer @('shrink',(Join-Path $Out 'hang/case-1/case.json'),'--wall-ms','100','--out',$wallDestination) 3 (Join-Path $Out 'wall-budget.log')
$wallResult = Read-Json (Join-Path $wallDestination 'reduction.json')
Check (-not $wallResult.confirmed -and $wallResult.stop_reason -eq 'wall_budget' -and $wallResult.baseline.outcome -eq 'Timeout') 'Hanging baseline was not constrained by wall budget'
Check ([long]$wallResult.elapsed_ms -lt 1500) 'Wall timeout overran by more than process/IO allowance'
$facts.Add([ordered]@{ probe = 'wall-budget'; stop_reason = $wallResult.stop_reason; elapsed_ms = $wallResult.elapsed_ms })

# Reusing an output directory must fail without altering old evidence.
$oldReport = Join-Path $Out 'buffer-correct/case-1/report.json'
$oldHash = (Get-FileHash -LiteralPath $oldReport).Hash
Invoke-Tool $buffer @('run','--out',(Join-Path $Out 'buffer-correct')) 2 (Join-Path $Out 'stale-output.log')
Check ((Get-FileHash -LiteralPath $oldReport).Hash -eq $oldHash) 'Old evidence changed'

$verification = [ordered]@{
  completed_at = [DateTimeOffset]::UtcNow.ToString('o')
  platform = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
  toolchain = @(& moon version --all)
  async_version = '0.22.5'
  build = 'native/debug; Windows/MSVC; behavior only'
  executable_sha256 = @{ buffer = (Get-FileHash -LiteralPath $buffer).Hash; eigen = (Get-FileHash -LiteralPath $eigen).Hash }
  facts = $facts.ToArray()
}
$verification | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $Out 'verification.json') -Encoding utf8
Write-Host "Verification passed. Evidence: $Out"
