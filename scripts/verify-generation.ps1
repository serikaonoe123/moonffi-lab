param(
  [string]$Out = '',
  [ValidateRange(1,256)][int]$Cases = 64,
  [ValidateRange(8,256)][int]$Steps = 64,
  [UInt64]$Seed = 17
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'executable-common.ps1')
Set-Location -LiteralPath $projectRoot
if (-not $Out) { $Out = Join-Path $projectRoot ('results/generation-' + [guid]::NewGuid().ToString('N')) }
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
New-Item -ItemType Directory -Path $Out | Out-Null
$Out = (Resolve-Path -LiteralPath $Out).Path
$buffer = Find-LabExecutable $projectRoot 'buffer-lab'
$stage = 'setup'
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Invoke-Buffer([string[]]$ToolArgs, [int[]]$Expected, [string]$Log) {
  $lines = & $buffer @ToolArgs 2>&1
  $code = $LASTEXITCODE
  $lines | Set-Content -LiteralPath $Log -Encoding utf8
  Require ($code -in $Expected) "Unexpected exit $code. See $Log"
}
function Measure-Generation([string]$Directory) {
  $operations = [ordered]@{ new=0; share=0; close=0; read=0; write=0; reject_write=0; resize=0 }
  $shapes = [System.Collections.Generic.HashSet[string]]::new()
  $edges = [System.Collections.Generic.HashSet[string]]::new()
  $features = [System.Collections.Generic.HashSet[string]]::new()
  $maximumLive = 0
  for ($caseIndex = 1; $caseIndex -le $Cases; $caseIndex++) {
    $trace = Read-Json (Join-Path $Directory "case-$caseIndex/case.json")
    $handles = @{}
    $everCreated = $false
    $previous = 'start'
    [void]$shapes.Add((@($trace.steps | ForEach-Object op) | ConvertTo-Json -Compress))
    foreach ($step in $trace.steps) {
      $operations[$step.op]++
      [void]$edges.Add("$previous/$($step.op)")
      $previous = $step.op
      $payload = $step.args
      $id = [string]$payload[1]
      switch ($step.op) {
        'new' {
          if ($everCreated -and $handles.Count -eq 0) { [void]$features.Add('restart-after-close') }
          $length = $payload[2].Length / 2
          if ($length -eq 0) { [void]$features.Add('new-empty') }
          if ($length -eq 256) { [void]$features.Add('new-maximum') }
          $handles[$id] = @{ length=$length; resizer=$null; closed_alias=$false }
          $everCreated = $true
        }
        'share' { $handles[[string]$payload[2]] = $handles[$id] }
        'close' { $handles[$id].closed_alias = $true; $handles.Remove($id) }
        'read' { if ($handles[$id].closed_alias) { [void]$features.Add('read-after-alias-close') } }
        'write' {
          if ($null -ne $handles[$id].resizer -and $handles[$id].resizer -ne $id) { [void]$features.Add('write-after-other-alias-resize') }
        }
        'reject_write' {
          if ($payload[2] -lt 0) { [void]$features.Add('reject-negative') }
          if ($payload[2] -eq $handles[$id].length) { [void]$features.Add('reject-at-end') }
        }
        'resize' {
          $before = $handles[$id].length
          $length = $payload[2]
          if ($length -gt $before) { [void]$features.Add('grow') }
          if ($length -lt $before) { [void]$features.Add('shrink') }
          if ($length -eq 0) { [void]$features.Add('resize-empty') }
          if ($before -eq 0 -and $length -gt 0) { [void]$features.Add('regrow-empty') }
          $handles[$id].length = $length
          $handles[$id].resizer = $id
        }
      }
      $maximumLive = [Math]::Max($maximumLive,$handles.Count)
    }
  }
  [ordered]@{ schedules=$shapes.Count; operation_pairs=$edges.Count; operations=$operations; features=@($features | Sort-Object); maximum_live_handles=$maximumLive }
}

try {
  Require (Test-Path -LiteralPath $buffer) 'Run moon build --target native first'
  $stage = 'fixed-examples'
  $exampleRoot = Join-Path $projectRoot 'examples/stateful'
  $exampleEntries = @(Read-Json (Join-Path $exampleRoot 'manifest.json'))
  Require ($exampleEntries.Count -eq 3) 'Expected three fixed exploratory regressions'
  foreach ($entry in $exampleEntries) {
    $casePath = Join-Path $exampleRoot "$($entry.fixture_mode)-case.json"
    $reportPath = Join-Path $exampleRoot "$($entry.fixture_mode)-report.json"
    Require ((Get-FileHash -LiteralPath $casePath).Hash -eq $entry.case_sha256) 'Fixed input hash changed'
    Require ((Get-FileHash -LiteralPath $reportPath).Hash -eq $entry.report_sha256) 'Fixed report hash changed'
    $caseDir = Join-Path $Out "example-$($entry.fixture_mode)-defect"
    Invoke-Buffer @('replay',$casePath,'--out',$caseDir) @(1) (Join-Path $Out "example-$($entry.fixture_mode)-defect.log")
    $observed = Read-Json (Join-Path $caseDir 'case-1/report.json')
    Require ($observed.fingerprint -eq $entry.fingerprint) 'Fixed exploratory regression changed failure'
    Invoke-Buffer @('replay',$casePath,'--mode','correct','--out',(Join-Path $Out "example-$($entry.fixture_mode)-corrected")) @(0) (Join-Path $Out "example-$($entry.fixture_mode)-corrected.log")
  }
  $rows = [System.Collections.Generic.List[object]]::new()
  $coverage = [ordered]@{}
  foreach ($generatorName in @('default','stateful')) {
    foreach ($fixtureMode in @('correct','nul','share','error')) {
      $stage = "$generatorName/$fixtureMode"
      $label = "$generatorName-$fixtureMode"
      $destination = Join-Path $Out $label
      $expected = if ($fixtureMode -eq 'correct') { @(0) } elseif ($generatorName -eq 'default') { @(1) } else { @(0,1) }
      Invoke-Buffer @('run','--generator',$generatorName,'--mode',$fixtureMode,'--seed',"$Seed",'--cases',"$Cases",'--steps',"$Steps",'--out',$destination) $expected (Join-Path $Out "$label.log")
      $reports = @(Read-Json (Join-Path $destination 'summary.json'))
      Require ($reports.Count -eq $Cases) 'Incomplete case summary'
      Require (@($reports | Where-Object outcome -notin @('Pass','PropertyFailure')).Count -eq 0) 'Unexpected worker/harness failure'
      $failures = @($reports | Where-Object outcome -eq 'PropertyFailure').Count
      if ($fixtureMode -eq 'correct') {
        Require ($failures -eq 0) 'Correct binding failed'
        $coverage[$generatorName] = Measure-Generation $destination
        if ($generatorName -eq 'stateful') { Require ($coverage[$generatorName].maximum_live_handles -le 8) 'Stateful live-handle limit exceeded' }
      }
      $row = [ordered]@{ generator=$generatorName; fixture_mode=$fixtureMode; cases=$Cases; property_failures=$failures; passed=$Cases-$failures }
      # Observed discovery is not guaranteed by a fixed trigger suffix. A small
      # campaign may legitimately find no failure in an intentional mutant.
      if ($generatorName -eq 'stateful' -and $failures -gt 0) {
        $firstFailure = 0
        while ($reports[$firstFailure].outcome -ne 'PropertyFailure') { $firstFailure++ }
        $casePath = Join-Path $destination "case-$($firstFailure + 1)/case.json"
        $reductionDir = Join-Path $Out "$label-shrink"
        Invoke-Buffer @('shrink',$casePath,'--budget','200','--out',$reductionDir) @(1) (Join-Path $Out "$label-shrink.log")
        $reduction = Read-Json (Join-Path $reductionDir 'reduction.json')
        Require ($reduction.confirmed -and $reduction.deletion_minimal) 'Exploratory failure was not stably reduced and audited'
        Require ($reduction.baseline.fingerprint -eq $reports[$firstFailure].fingerprint) 'Exploratory failure changed fingerprint'
        Invoke-Buffer @('replay',(Join-Path $reductionDir 'reduced.json'),'--mode','correct','--out',(Join-Path $Out "$label-corrected")) @(0) (Join-Path $Out "$label-corrected.log")
        $row['first_failure_seed'] = ([UInt64]$Seed + [UInt64]$firstFailure).ToString()
        $row['reduced_steps'] = $reduction.reduced_steps
        $row['fingerprint'] = $reduction.baseline.fingerprint
        $row['deletion_minimal'] = $reduction.deletion_minimal
      }
      $rows.Add($row)
      $rows.ToArray() | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $Out 'measurements.json') -Encoding utf8
      Write-Host "$label : $failures/$Cases property failures"
    }
  }
  $stage = 'cli-boundaries'
  foreach ($invalid in @(
    @('generate','--generator','missing'),
    @('replay',(Join-Path $Out 'stateful-correct/case-1/case.json'),'--generator','stateful')
  )) {
    $label = if ($invalid[0] -eq 'generate') { 'unknown-generator' } else { 'replay-generator' }
    $rejectedOutput = Join-Path $Out $label
    Invoke-Buffer ($invalid + @('--out',$rejectedOutput)) @(2) (Join-Path $Out "$label.log")
    Require (-not (Test-Path -LiteralPath $rejectedOutput)) 'Invalid generator option created worker output'
  }
  foreach ($copy in @('a','b')) {
    Invoke-Buffer @('generate','--generator','stateful','--seed',"$Seed",'--steps',"$Steps",'--out',(Join-Path $Out "determinism-$copy")) @(0) (Join-Path $Out "determinism-$copy.log")
  }
  Require ((Get-Content (Join-Path $Out 'determinism-a/case.json') -Raw) -ceq (Get-Content (Join-Path $Out 'determinism-b/case.json') -Raw)) 'Separate generation processes differ for the same seed'
  $stage = 'eigen-generation'
  $eigenOutput = Join-Path $Out 'eigen'
  & (Join-Path $PSScriptRoot 'verify-eigen-generation.ps1') -Out $eigenOutput -Cases $Cases -Steps $Steps -Seed $Seed
  $eigenVerification = Read-Json (Join-Path $eigenOutput 'verification.json')
  Require ($eigenVerification.state -eq 'passed') 'Eigen generation evidence missing'
  [ordered]@{
    state='passed'; completed_at=[DateTimeOffset]::UtcNow.ToString('o'); seed=$Seed.ToString(); cases_per_mode=$Cases; step_budget=$Steps
    fixed_examples_replayed=$exampleEntries.Count; eigen=$eigenVerification
    modes=@('correct','nul','share','error'); generators=@('default','stateful'); measurements=$rows.ToArray(); coverage=$coverage
    toolchain=@(& moon version --all); executable_sha256=(Get-FileHash -LiteralPath $buffer).Hash
    scope='Operation/state-feature observations on labelled local fixtures, not native code coverage or external defect-finding rates. Default has fixed contract triggers; stateful has an eight-live-handle bound and no fixed suffix.'
  } | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $Out 'verification.json') -Encoding utf8
  Write-Host "Generation verification passed. Evidence: $Out"
} catch {
  [ordered]@{ state='failed'; stage=$stage; error=$_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Out 'failure.json') -Encoding utf8
  throw
}
