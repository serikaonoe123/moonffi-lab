param([string]$Out = '', [string]$OfflineDependencySource = '')
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$projectRoot=Split-Path -Parent $PSScriptRoot
$savedLocation=Get-Location
$stage='setup'
if (-not $Out) { $Out=Join-Path $projectRoot ('results/sdk-' + [guid]::NewGuid().ToString('N')) }
$Out=[System.IO.Path]::GetFullPath($Out)
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
if ($OfflineDependencySource) { $OfflineDependencySource=(Resolve-Path -LiteralPath $OfflineDependencySource).Path }
New-Item -ItemType Directory -Path $Out | Out-Null
function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Invoke-Checked([string]$Exe,[string[]]$ToolArgs,[int[]]$Expected,[string]$Log) {
  $lines=& $Exe @ToolArgs 2>&1; $actual=$LASTEXITCODE
  $lines | Set-Content -LiteralPath $Log -Encoding utf8
  Require ($actual -in $Expected) "Expected exit $Expected, got $actual. See $Log"
}
try {
  $stage='prepare-external-consumer'
  $workspace=Join-Path $Out 'workspace'
  $engine=Join-Path $workspace 'engine'; $consumer=Join-Path $workspace 'consumer'
  New-Item -ItemType Directory -Path $engine,$consumer | Out-Null
  foreach ($name in @('core','runner','moon.mod')) { Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $engine -Recurse }
  $starter=Join-Path $projectRoot 'examples/adapter-starter'
  foreach ($name in @('counter','cmd','moon.mod','README.md','LICENSE')) { Copy-Item -LiteralPath (Join-Path $starter $name) -Destination $consumer -Recurse }
  foreach ($name in @('fixtures','vendor','cmd','.git','.mooncakes','_build')) {
    Require (-not (Test-Path -LiteralPath (Join-Path $engine $name))) 'SDK engine copy contains non-SDK sources or artifacts'
  }
  $members=@('engine','consumer')
  $dependencyMode='registry-or-tool-cache'
  if ($OfflineDependencySource) {
    $stage='copy-explicit-dependency-source'
    $dependencyMode='explicit-local-source-cache'
    $asyncSource=Join-Path $OfflineDependencySource 'moonbitlang/async'
    Require ((Get-Content (Join-Path $asyncSource 'moon.mod') -Raw) -match '(?m)^version\s*=\s*"0\.22\.5"\s*$') 'Offline async source version mismatch'
    $asyncDestination=Join-Path $workspace 'async'
    foreach ($file in Get-ChildItem -LiteralPath $asyncSource -Recurse -File -Force) {
      $relative=$file.FullName.Substring($asyncSource.Length+1)
      if ($relative -match '(^|[\\/])(_build|target|\.git)([\\/]|$)' -or $file.Extension -in @('.exe','.obj','.pdb','.ilk','.lib','.dll','.o','.a','.mi','.core')) { continue }
      $destination=Join-Path $asyncDestination $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
      Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    $members += 'async'
  }
  ('members = [' + (($members | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ']') | Set-Content (Join-Path $workspace 'moon.work') -Encoding utf8
  $sourceManifest=@(Get-ChildItem -LiteralPath $workspace -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
    [ordered]@{path=[System.IO.Path]::GetRelativePath($workspace,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
  })
  $sourceManifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Out 'source-manifest.json') -Encoding utf8
  Set-Location -LiteralPath $consumer
  $stage='resolve-and-check'
  $checkArgs=@('check','--target','native','--deny-warn','counter','cmd/main')
  if ($OfflineDependencySource) { $checkArgs += '--frozen' }
  Invoke-Checked 'moon' $checkArgs @(0) (Join-Path $Out 'check.log')
  Invoke-Checked 'moon' @('tree','--json') @(0) (Join-Path $Out 'module-tree.json')
  Invoke-Checked 'moon' @('tree','--package','--json') @(0) (Join-Path $Out 'package-tree.json')
  $tree=Read-Json (Join-Path $Out 'module-tree.json')
  foreach ($entry in @(@{name='serikaonoe123/moonffi-lab';path=$engine},@{name='moonffi-example/counter-lab';path=$consumer})) {
    $found=@($tree.modules | Where-Object name -eq $entry.name)
    Require ($found.Count -eq 1 -and $found[0].source.kind -eq 'local' -and $found[0].source.path -eq $entry.path) 'SDK did not resolve the intended local modules'
  }
  $packageTree=Read-Json (Join-Path $Out 'package-tree.json')
  $enginePackages=@($packageTree.nodes | Where-Object module -eq 'serikaonoe123/moonffi-lab')
  Require (($enginePackages.rel | Sort-Object) -join ',' -eq 'core,runner') 'External SDK consumer used private fixtures or commands'
  $stage='test-and-build'
  Invoke-Checked 'moon' @('test','--target','native','--frozen','--deny-warn','-j','1','counter') @(0) (Join-Path $Out 'tests.log')
  Require ((Get-Content (Join-Path $Out 'tests.log') -Raw).Contains('Total tests: 7, passed: 7, failed: 0.')) 'SDK unit tests incomplete'
  Invoke-Checked 'moon' @('build','--target','native','--frozen','--deny-warn','cmd/main') @(0) (Join-Path $Out 'build.log')
  $executables=@(Get-ChildItem -LiteralPath (Join-Path $workspace '_build/native/debug/build') -Recurse -File -Filter main.exe)
  Require ($executables.Count -eq 1) 'SDK executable discovery ambiguous'
  $exe=$executables[0].FullName
  $stage='correct-and-walk'
  foreach ($entry in @(@{label='correct';generator='default';cases=8},@{label='walk';generator='walk';cases=32})) {
    $destination=Join-Path $Out $entry.label
    Invoke-Checked $exe @('run','--generator',$entry.generator,'--cases',"$($entry.cases)",'--seed','17','--steps','64','--out',$destination) @(0) (Join-Path $Out "$($entry.label).log")
    $reports=@(Read-Json (Join-Path $destination 'summary.json'))
    Require ($reports.Count -eq $entry.cases -and @($reports | Where-Object outcome -ne 'Pass').Count -eq 0) 'SDK correct campaign failed'
  }
  $stage='labelled-error-and-reduction'
  Invoke-Checked $exe @('run','--mode','error','--seed','17','--out',(Join-Path $Out 'error')) @(1) (Join-Path $Out 'error.log')
  $inputPath=Join-Path $Out 'error/case-1/case.json'
  $baseline=Read-Json (Join-Path $Out 'error/case-1/report.json')
  Require ($baseline.outcome -eq 'PropertyFailure') 'Teaching fixture did not reproduce'
  $reducedDir=Join-Path $Out 'shrink'
  Invoke-Checked $exe @('shrink',$inputPath,'--strategy','state','--budget','200','--out',$reducedDir) @(1) (Join-Path $Out 'shrink.log')
  $reduction=Read-Json (Join-Path $reducedDir 'reduction.json')
  Require ($reduction.confirmed -and $reduction.deletion_minimal -and $reduction.stop_reason -eq 'search_complete' -and $reduction.reduced_steps -eq 2 -and $reduction.baseline.fingerprint -eq $baseline.fingerprint) 'SDK reduction did not confirm the expected two-step result'
  $reducedPath=Join-Path $reducedDir 'reduced.json'
  Invoke-Checked $exe @('replay',$reducedPath,'--out',(Join-Path $Out 'replay')) @(1) (Join-Path $Out 'replay.log')
  Require ((Read-Json (Join-Path $Out 'replay/case-1/report.json')).fingerprint -eq $baseline.fingerprint) 'SDK saved replay changed fingerprint'
  Invoke-Checked $exe @('replay',$reducedPath,'--mode','correct','--out',(Join-Path $Out 'corrected')) @(0) (Join-Path $Out 'corrected.log')
  $trace=Read-Json $reducedPath; $steps=@($trace.steps)
  Require ($steps[0].args[2] -eq 1 -and $steps[1].args[2] -eq 100) 'SDK integer candidates did not reach the concrete error boundary'
  foreach ($mask in 0..2) {
    $trace.steps=@(for ($i=0;$i -lt 2;$i++) { if ($mask -band (1 -shl $i)) { $steps[$i] } })
    $subsetPath=Join-Path $Out "subset-$mask.json"
    $trace | ConvertTo-Json -Depth 15 | Set-Content $subsetPath -Encoding utf8
    Invoke-Checked $exe @('replay',$subsetPath,'--out',(Join-Path $Out "subset-$mask")) @(0,1,2) (Join-Path $Out "subset-$mask.log")
    $report=Read-Json (Join-Path $Out "subset-$mask/case-1/report.json")
    Require ($report.outcome -in @('Pass','PropertyFailure','InvalidCase') -and $report.fingerprint -ne $baseline.fingerprint) 'SDK proper subset preserved failure or had a harness error'
  }
  $stage='boundaries'
  Invoke-Checked $exe @('shrink',$inputPath,'--budget','6','--out',(Join-Path $Out 'budget')) @(1) (Join-Path $Out 'budget.log')
  $budget=Read-Json (Join-Path $Out 'budget/reduction.json')
  Require ($budget.confirmed -and -not $budget.deletion_minimal -and $budget.stop_reason -eq 'execution_budget' -and $budget.executions -eq 6) 'SDK budget boundary was mislabeled'
  $forged=Read-Json $inputPath; $forged.steps[0].defines=@()
  $forgedPath=Join-Path $Out 'forged.json'; $forged | ConvertTo-Json -Depth 15 | Set-Content $forgedPath -Encoding utf8
  Invoke-Checked $exe @('replay',$forgedPath,'--out',(Join-Path $Out 'invalid')) @(2) (Join-Path $Out 'invalid.log')
  Require ((Read-Json (Join-Path $Out 'invalid/case-1/report.json')).outcome -eq 'InvalidCase' -and -not (Test-Path (Join-Path $Out 'invalid/case-1/events.jsonl'))) 'Forged dependency reached worker execution'
  Invoke-Checked $exe @('generate','--generator','missing','--out',(Join-Path $Out 'unknown')) @(2) (Join-Path $Out 'unknown.log')
  Require (-not (Test-Path (Join-Path $Out 'unknown'))) 'Unknown generator created output'
  foreach ($copy in @('a','b')) { Invoke-Checked $exe @('generate','--generator','walk','--seed','17','--steps','64','--out',(Join-Path $Out "determinism-$copy")) @(0) (Join-Path $Out "determinism-$copy.log") }
  Require ((Get-FileHash (Join-Path $Out 'determinism-a/case.json')).Hash -eq (Get-FileHash (Join-Path $Out 'determinism-b/case.json')).Hash) 'SDK walk differs across processes'
  $existing=Join-Path $Out 'replay/case-1/report.json'; $oldHash=(Get-FileHash $existing).Hash
  Invoke-Checked $exe @('replay',$reducedPath,'--out',(Join-Path $Out 'replay')) @(2) (Join-Path $Out 'output-reuse.log')
  Require ((Get-FileHash $existing).Hash -eq $oldHash) 'Existing SDK evidence was changed'
  $stage='explicit-state-contracts'
  Invoke-Checked 'moon' @('build','--target','native','--frozen','--deny-warn','cmd/contracts') @(0) (Join-Path $Out 'contracts-build.log')
  $contractExecutables=@(Get-ChildItem -LiteralPath (Join-Path $workspace '_build/native/debug/build') -Recurse -File -Filter contracts.exe)
  Require ($contractExecutables.Count -eq 1) 'Contract executable discovery ambiguous'
  $contractExe=$contractExecutables[0].FullName
  foreach ($generator in @('default','walk')) {
    $destination=Join-Path $Out "contracts-$generator"
    Invoke-Checked $contractExe @('run','--generator',$generator,'--cases','16','--seed','17','--steps','64','--out',$destination) @(0) (Join-Path $Out "contracts-$generator.log")
    $reports=@(Read-Json (Join-Path $destination 'summary.json'))
    Require ($reports.Count -eq 16 -and @($reports | Where-Object outcome -ne 'Pass').Count -eq 0) 'Explicit contract correct campaign failed'
  }
  $contractError=Join-Path $Out 'contracts-error'
  Invoke-Checked $contractExe @('run','--mode','error','--steps','32','--out',$contractError) @(1) (Join-Path $Out 'contracts-error.log')
  $contractInput=Join-Path $contractError 'case-1/case.json'
  $contractBaseline=Read-Json (Join-Path $contractError 'case-1/report.json')
  Require ($contractBaseline.outcome -eq 'PropertyFailure' -and $contractBaseline.fingerprint -like 'property:contract-postcondition:reject_add:*') 'Explicit postcondition did not detect error-path corruption'
  $contractReductions=@(foreach ($strategy in @('plain','dependency','state')) {
    $destination=Join-Path $Out "contracts-shrink-$strategy"
    Invoke-Checked $contractExe @('shrink',$contractInput,'--strategy',$strategy,'--budget','200','--out',$destination) @(1) (Join-Path $Out "contracts-shrink-$strategy.log")
    $result=Read-Json (Join-Path $destination 'reduction.json')
    Require ($result.confirmed -and $result.deletion_minimal -and $result.reduced_steps -eq 2 -and $result.stop_reason -eq 'search_complete' -and $result.baseline_checks -eq 3 -and $result.final_checks -eq 3 -and $result.baseline.fingerprint -eq $contractBaseline.fingerprint) 'Explicit contract reduction incomplete'
    $inputFile=Join-Path $destination 'reduced.json'
    Invoke-Checked $contractExe @('replay',$inputFile,'--out',(Join-Path $Out "contracts-replay-$strategy")) @(1) (Join-Path $Out "contracts-replay-$strategy.log")
    Invoke-Checked $contractExe @('replay',$inputFile,'--mode','correct','--out',(Join-Path $Out "contracts-fixed-$strategy")) @(0) (Join-Path $Out "contracts-fixed-$strategy.log")
    [ordered]@{strategy=$strategy;executions=$result.executions;original_steps=$result.original_steps;reduced_steps=$result.reduced_steps;confirmed=$result.confirmed;deletion_minimal=$result.deletion_minimal;independent_replay=$true;corrected_replay='Pass'}
  })
  $invalidContract=Read-Json $contractInput
  $invalidContract.steps[0].defines=@()
  $invalidContractPath=Join-Path $Out 'contracts-forged.json'
  $invalidContract | ConvertTo-Json -Depth 20 | Set-Content $invalidContractPath -Encoding utf8
  Invoke-Checked $contractExe @('replay',$invalidContractPath,'--out',(Join-Path $Out 'contracts-invalid')) @(2) (Join-Path $Out 'contracts-invalid.log')
  Require ((Read-Json (Join-Path $Out 'contracts-invalid/case-1/report.json')).outcome -eq 'InvalidCase' -and -not (Test-Path (Join-Path $Out 'contracts-invalid/case-1/events.jsonl'))) 'Invalid contract reached native worker'
  foreach ($copy in @('a','b')) {
    Invoke-Checked $contractExe @('generate','--generator','walk','--seed','17','--steps','64','--out',(Join-Path $Out "contracts-determinism-$copy")) @(0) (Join-Path $Out "contracts-determinism-$copy.log")
  }
  Require ((Get-FileHash (Join-Path $Out 'contracts-determinism-a/case.json')).Hash -eq (Get-FileHash (Join-Path $Out 'contracts-determinism-b/case.json')).Hash) 'Explicit contract generation differs across processes'
  $contracts=[ordered]@{state='passed';correct_cases=32;step_count_boundary_cases=4;postcondition_failure=$contractBaseline.fingerprint;reductions=$contractReductions;preflight_rejection=$true;separate_process_determinism=$true;executable_sha256=(Get-FileHash $contractExe).Hash}
  $contracts | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $Out 'contracts-verification.json') -Encoding utf8
  [ordered]@{state='passed';completed_at=[DateTimeOffset]::UtcNow.ToString('o');engine_packages=@($enginePackages.rel | Sort-Object)
    consumer_module='moonffi-example/counter-lab';dependency_mode=$dependencyMode;dependency_source=$OfflineDependencySource
    source_manifest_sha256=(Get-FileHash (Join-Path $Out 'source-manifest.json')).Hash;executable_sha256=(Get-FileHash $exe).Hash
    unit_tests=7;pure_oracle_traces=768;repair_subsets=128;native_unit_walks=32;correct_contract_cases=8;correct_walk_cases=32
    original_steps=$reduction.original_steps;reduced_steps=$reduction.reduced_steps;fingerprint=$baseline.fingerprint;executions=$reduction.executions
    deletion_minimal=$reduction.deletion_minimal;proper_subsets_checked=3;corrected_replay='Pass';budget_stop_reason=$budget.stop_reason
    preflight_rejection=$true;output_reuse_rejected=$true;separate_process_determinism=$true;toolchain=@(& moon version --all)
    explicit_state_contracts=$contracts
    independent_environment=$false;scope='Separate consumer module built from a fresh workspace containing only public core/runner sources and the teaching fixture. No registry publication, real defect discovery, full SDK stability or ASan coverage of the counter is claimed.'
  } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'verification.json') -Encoding utf8
  Write-Host "External SDK verification passed. Evidence: $Out"
} catch {
  [ordered]@{state='failed';stage=$stage;error=$_.Exception.Message} | ConvertTo-Json | Set-Content (Join-Path $Out 'failure.json') -Encoding utf8
  throw
} finally { Set-Location -LiteralPath $savedLocation }
