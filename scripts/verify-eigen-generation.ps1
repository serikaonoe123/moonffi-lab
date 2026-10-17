param(
  [string]$Out = '',
  [ValidateRange(1,256)][int]$Cases = 64,
  [ValidateRange(8,256)][int]$Steps = 64,
  [UInt64]$Seed = 17
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if (-not $Out) { $Out = Join-Path $projectRoot ('results/eigen-generation-' + [guid]::NewGuid().ToString('N')) }
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
New-Item -ItemType Directory -Path $Out | Out-Null
$Out = (Resolve-Path -LiteralPath $Out).Path
$eigen = Join-Path $projectRoot '_build/native/debug/build/cmd/eigen-lab/eigen-lab.exe'
$stage = 'setup'
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Invoke-Eigen([string[]]$ToolArgs, [int]$Expected, [string]$Log) {
  $lines = & $eigen @ToolArgs 2>&1
  $code = $LASTEXITCODE
  $lines | Set-Content -LiteralPath $Log -Encoding utf8
  Require ($code -eq $Expected) "Unexpected exit $code. See $Log"
}
function Measure-EigenGeneration([string]$Directory, [string]$Version) {
  $schedules = @{}; $pairs = @{}; $features = @{}; $shapes = @{}; $operations = @{}
  $maximumLive = 0
  $inputs = [System.Collections.Generic.List[object]]::new()
  foreach ($index in 1..$Cases) {
    $casePath = Join-Path $Directory "case-$index/case.json"
    $trace = Read-Json $casePath
    Require ($trace.generator_version -eq $Version -and $trace.adapter -eq 'eigen') 'Wrong Eigen generator metadata'
    Require ($trace.seed -eq ([UInt64]$Seed + [UInt64]($index - 1)).ToString()) 'Campaign seed mismatch'
    Require ($trace.environment.fixture_mode -eq 'correct' -and $trace.environment.profile -eq 'behavior') 'Unexpected Eigen environment'
    Require ($trace.steps.Count -eq $Steps) 'Generator did not honor the step count'
    $inputs.Add([ordered]@{ case=$index; seed=$trace.seed; sha256=(Get-FileHash -LiteralPath $casePath).Hash
      binding_revision=$trace.environment.binding_revision; eigen_revision=$trace.environment.eigen_revision })
    $schedules[($trace.steps.op -join '>')] = $true
    $live = @{}; $defined = @{}; $parents = @{}; $operands = @{}; $previous = 'start'
    foreach ($step in $trace.steps) {
      $operations[$step.op] = 1 + [int]$operations[$step.op]
      $pairs["$previous>$($step.op)"] = $true; $previous = $step.op
      $a = $step.args
      switch ($a[0]) {
        'New' {
          $id=[string]$a[1]; $rows=[int]$a[2]; $cols=[int]$a[3]
          Require (-not $defined.ContainsKey($id)) 'Matrix ID reused'
          if ($live.Count -eq 0 -and $defined.Count -gt 0) { $features['restart-after-drop']=$true }
          $live[$id]=@{ rows=$rows; cols=$cols }; $defined[$id]=$true
          $shapes["$rows`x$cols"]=$true
          if ($rows -eq 1 -or $cols -eq 1) { $features['new-minimum-dimension']=$true }
          if ($rows -eq 4 -or $cols -eq 4) { $features['new-maximum-dimension']=$true }
          if (-100 -in $a[4]) { $features['minimum-value']=$true }
          if (100 -in $a[4]) { $features['maximum-value']=$true }
        }
        'Transpose' {
          $source=[string]$a[1]; $id=[string]$a[2]
          Require ($live.ContainsKey($source) -and -not $defined.ContainsKey($id)) 'Invalid transpose lifetime'
          $shape=$live[$source]; $live[$id]=@{rows=$shape.cols;cols=$shape.rows}; $defined[$id]=$true
          $shapes["$($shape.cols)x$($shape.rows)"]=$true
          $parents[$id]=$source
          if ($shape.rows -ne $shape.cols) { $features['rectangular-transpose']=$true }
          if ($parents.ContainsKey($source)) { $features['transpose-chain']=$true }
        }
        'Set' {
          $id=[string]$a[1]
          Require ($live.ContainsKey($id)) 'Set after drop'
          $shape=$live[$id]
          Require ($a[2] -ge 0 -and $a[2] -lt $shape.rows -and $a[3] -ge 0 -and $a[3] -lt $shape.cols) 'Set index outside shape'
          if ($a[2] -eq $shape.rows-1 -and $a[3] -eq $shape.cols-1) { $features['set-last-index']=$true }
          if ($parents.ContainsKey($id)) {
            $features['set-transpose']=$true
            if ($live.ContainsKey($parents[$id])) { $features['set-transpose-with-source-live']=$true }
          }
          foreach ($child in $parents.Keys) {
            if ($parents[$child] -eq $id -and $live.ContainsKey($child)) { $features['set-source-with-transpose-live']=$true }
          }
          if ($operands.ContainsKey($id)) { $features['set-arithmetic-result']=$true }
          foreach ($child in $operands.Keys) {
            if ($id -in $operands[$child] -and $live.ContainsKey($child)) { $features['set-operand-with-result-live']=$true }
          }
        }
        'Check' {
          $id=[string]$a[1]; Require ($live.ContainsKey($id)) 'Check after drop'
          if ($parents.ContainsKey($id) -and -not $live.ContainsKey($parents[$id])) { $features['check-after-source-drop']=$true }
          if ($operands.ContainsKey($id)) {
            foreach ($inputId in $operands[$id]) {
              if (-not $live.ContainsKey($inputId)) { $features['check-result-after-operand-drop']=$true }
            }
          }
        }
        { $_ -in @('Add','Mul') } {
          $leftId=[string]$a[1]; $rightId=[string]$a[2]; $id=[string]$a[3]
          Require ($live.ContainsKey($leftId) -and $live.ContainsKey($rightId) -and -not $defined.ContainsKey($id)) 'Invalid arithmetic lifetime'
          $left=$live[$leftId]; $right=$live[$rightId]; $multiply=$a[0] -eq 'Mul'
          if ($multiply) {
            Require ($left.cols -eq $right.rows) 'Incompatible multiplication'
            $live[$id]=@{rows=$left.rows;cols=$right.cols}
            if ($left.rows -ne $left.cols -or $right.rows -ne $right.cols) { $features['rectangular-mul']=$true }
          } else {
            Require ($left.rows -eq $right.rows -and $left.cols -eq $right.cols) 'Incompatible addition'
            $live[$id]=@{rows=$left.rows;cols=$left.cols}
          }
          if ($leftId -eq $rightId) { $features[('self-' + $step.op)]=$true }
          if ($operands.ContainsKey($leftId) -or $operands.ContainsKey($rightId)) { $features['arithmetic-chain']=$true }
          $shapes["$($live[$id].rows)x$($live[$id].cols)"]=$true
          $operands[$id]=@($leftId,$rightId); $defined[$id]=$true
        }
        'RejectAdd' {
          $left=$live[[string]$a[1]]; $right=$live[[string]$a[2]]
          Require ($null -ne $left -and $null -ne $right) 'RejectAdd after drop'
          Require ($left.rows -ne $right.rows -or $left.cols -ne $right.cols) 'Compatible RejectAdd'
          if ($left.rows -eq $right.rows) { $features['reject-same-rows']=$true }
          if ($left.cols -eq $right.cols) { $features['reject-same-cols']=$true }
          if ($left.rows -ne $right.rows -and $left.cols -ne $right.cols) { $features['reject-both-dimensions']=$true }
        }
        'Drop' {
          $id=[string]$a[1]; Require ($live.ContainsKey($id)) 'Drop unavailable matrix'; $live.Remove($id)
        }
        default { throw 'Unknown Eigen operation' }
      }
      $maximumLive=[Math]::Max($maximumLive,$live.Count)
    }
  }
  [ordered]@{ schedules=$schedules.Count; operation_pairs=$pairs.Count; operations=$operations
    shapes=@($shapes.Keys | Sort-Object); features=@($features.Keys | Sort-Object); maximum_live_handles=$maximumLive
    inputs=$inputs.ToArray() }
}
try {
  Require (Test-Path -LiteralPath $eigen) 'Build the native Eigen runner first'
  Require ($Seed -le [UInt64]::MaxValue - [UInt64]($Cases-1)) 'Seed range overflows UInt64'
  $measurements=[System.Collections.Generic.List[object]]::new()
  $legacyBaseline=Read-Json (Join-Path $projectRoot 'docs/evidence/generation-eigen-20261017.json')
  $legacyHashChecks=0
  foreach ($generatorName in @('default','stateful','arithmetic')) {
    $stage="run/$generatorName"
    $destination=Join-Path $Out $generatorName
    Invoke-Eigen @('run','--generator',$generatorName,'--seed',"$Seed",'--cases',"$Cases",'--steps',"$Steps",'--out',$destination) 0 (Join-Path $Out "$generatorName.log")
    $reports=@(Read-Json (Join-Path $destination 'summary.json'))
    Require ($reports.Count -eq $Cases -and @($reports | Where-Object outcome -ne 'Pass').Count -eq 0) 'Eigen campaign did not entirely pass'
    $version=switch ($generatorName) { 'default' {'eigen-1'}; 'stateful' {'eigen-stateful-1'}; 'arithmetic' {'eigen-arithmetic-1'} }
    $coverage=Measure-EigenGeneration $destination $version
    if ($generatorName -ne 'default') { Require ($coverage.maximum_live_handles -le 8) 'Eigen random walk live-handle bound exceeded' }
    if ($generatorName -ne 'arithmetic' -and $Steps -eq 64) {
      $old=@($legacyBaseline.eigen_generation.measurements | Where-Object generator -eq $generatorName)[0]
      foreach ($inputCase in $coverage.inputs) {
        $previousInput=@($old.coverage.inputs | Where-Object seed -eq $inputCase.seed)
        if ($previousInput.Count -eq 1) {
          Require ($inputCase.sha256 -eq $previousInput[0].sha256) "Legacy generator bytes changed: $generatorName seed $($inputCase.seed)"
          $legacyHashChecks++
        }
      }
    }
    $measurements.Add([ordered]@{generator=$generatorName;version=$version;cases=$Cases;passed=$reports.Count;coverage=$coverage})
    $measurements.ToArray() | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $Out 'measurements.json') -Encoding utf8
    Write-Host "Eigen $generatorName : $($reports.Count)/$Cases passed"
  }
  $stage='determinism-and-replay'
  foreach ($generatorName in @('stateful','arithmetic')) {
    foreach ($copy in @('a','b')) {
      Invoke-Eigen @('generate','--generator',$generatorName,'--seed',"$Seed",'--steps',"$Steps",'--out',(Join-Path $Out "$generatorName-determinism-$copy")) 0 (Join-Path $Out "$generatorName-determinism-$copy.log")
    }
    Require ((Get-FileHash (Join-Path $Out "$generatorName-determinism-a/case.json")).Hash -eq (Get-FileHash (Join-Path $Out "$generatorName-determinism-b/case.json")).Hash) 'Separate generation processes differ'
    Invoke-Eigen @('replay',(Join-Path $Out "$generatorName-determinism-a/case.json"),'--out',(Join-Path $Out "$generatorName-replay")) 0 (Join-Path $Out "$generatorName-replay.log")
  }
  $stage='fixed-example'
  foreach ($exampleName in @('eigen-stateful','eigen-arithmetic')) {
    $exampleDirectory=Join-Path $projectRoot "examples/$exampleName"
    $example=Read-Json (Join-Path $exampleDirectory 'manifest.json')
    $examplePath=Join-Path $exampleDirectory 'case.json'
    Require ($example.expected_outcome -eq 'Pass' -and $example.case -eq 'case.json') 'Unexpected Eigen example manifest'
    Require ((Get-FileHash -LiteralPath $examplePath).Hash -eq $example.sha256) 'Eigen example hash mismatch'
    Invoke-Eigen @('replay',$examplePath,'--out',(Join-Path $Out $exampleName)) 0 (Join-Path $Out "$exampleName.log")
  }
  $stage='cli-boundaries'
  foreach ($invalid in @(
    @('generate','--generator','missing'),
    @('generate','--generator','stateful','--mode','error'),
    @('generate','--generator','arithmetic','--mode','error'),
    @('replay',(Join-Path $Out 'stateful-determinism-a/case.json'),'--generator','stateful')
  )) {
    $label=if ($invalid[0] -eq 'replay') {'replay-generator'} elseif ($invalid -contains '--mode') {"unsupported-mode-$($invalid[2])"} else {'unknown-generator'}
    $destination=Join-Path $Out $label
    Invoke-Eigen ($invalid + @('--out',$destination)) 2 (Join-Path $Out "$label.log")
    Require (-not (Test-Path -LiteralPath $destination)) 'Invalid Eigen generation created worker output'
  }
  [ordered]@{ state='passed';completed_at=[DateTimeOffset]::UtcNow.ToString('o');seed=$Seed.ToString();cases_per_generator=$Cases;steps=$Steps
    measurements=$measurements.ToArray();separate_process_determinism=$true;saved_input_replay='Pass';fixed_example_replay='Pass'
    fixed_examples=@('eigen-stateful','eigen-arithmetic');legacy_input_hashes_checked=$legacyHashChecks
    legacy_hash_scope='Overlap with recorded seed 17-80 at 64 steps only; other seeds or lengths are not hash-checked.'
    toolchain=@(& moon version --all);executable_sha256=(Get-FileHash -LiteralPath $eigen).Hash
    scope='Real vendored Eigen binding, correct mode only. Operation and state-feature observations, not native code coverage, defect-finding rates or exhaustive numerical stability. Teardown drops references; exact finalizer time and native allocation balance are not verified.'
  } | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $Out 'verification.json') -Encoding utf8
  Write-Host "Eigen generation verification passed. Evidence: $Out"
} catch {
  [ordered]@{state='failed';stage=$stage;error=$_.Exception.Message} | ConvertTo-Json | Set-Content (Join-Path $Out 'failure.json') -Encoding utf8
  throw
}
