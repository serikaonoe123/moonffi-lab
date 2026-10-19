param([string]$Out = '', [string]$UpstreamArchive = '', [string]$OfflineDependencySource = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
$savedLocation = Get-Location
$savedTemp = [Environment]::GetEnvironmentVariable('TEMP', 'Process')
$savedTmp = [Environment]::GetEnvironmentVariable('TMP', 'Process')
$savedFdCheck = [Environment]::GetEnvironmentVariable('MOONBIT_ASYNC_CHECK_FD_LEAK', 'Process')
$stage = 'setup'
if (-not $Out) { $Out = Join-Path $projectRoot ('results/sqlite-' + [guid]::NewGuid().ToString('N')) }
$Out = [IO.Path]::GetFullPath($Out)
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
if ($UpstreamArchive) { $UpstreamArchive = (Resolve-Path -LiteralPath $UpstreamArchive).Path }
if (-not $OfflineDependencySource) { $OfflineDependencySource = Join-Path $projectRoot '.mooncakes' }
$OfflineDependencySource = (Resolve-Path -LiteralPath $OfflineDependencySource).Path
New-Item -ItemType Directory -Path $Out | Out-Null
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Invoke-Checked([string]$Exe, [string[]]$ToolArgs, [int[]]$Expected, [string]$Log) {
  $lines = & $Exe @ToolArgs 2>&1
  $actual = $LASTEXITCODE
  $lines | Set-Content -LiteralPath $Log -Encoding utf8
  Require ($actual -in $Expected) "Expected exit $Expected, got $actual. See $Log"
}
function Check-Upstream([string]$Root, [object[]]$Files) {
  foreach ($entry in $Files) {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $Root $entry.path))
    $header = [Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
    $actual = [Convert]::ToHexString([Security.Cryptography.SHA1]::HashData([byte[]]($header + $bytes))).ToLowerInvariant()
    Require ($actual -ceq $entry.git_blob_sha1) "Upstream Git blob mismatch: $($entry.path)"
  }
}
try {
  $temporaryDirectory = Join-Path $Out 'temp'
  New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
  $env:TEMP = $temporaryDirectory
  $env:TMP = $temporaryDirectory
  $env:MOONBIT_ASYNC_CHECK_FD_LEAK = '1'
  $example = Join-Path $projectRoot 'examples/sqlite-lab'
  $lock = Read-Json (Join-Path $example 'upstream.json')
  $upstreamFiles = @(Read-Json (Join-Path $example 'upstream-files.json'))
  $stage = 'toolchain'
  & (Join-Path $projectRoot 'scripts/assert-toolchain.ps1') -Out (Join-Path $Out 'toolchain.json')
  $stage = 'upstream-archive'
  $archivePath = Join-Path $Out 'upstream-source.zip'
  $archiveMode = 'official-fixed-commit-download'
  if ($UpstreamArchive) {
    $archiveMode = 'explicit-local-source-archive'
    Copy-Item -LiteralPath $UpstreamArchive -Destination $archivePath
  } else { Invoke-WebRequest -Uri $lock.archive_url -OutFile $archivePath -TimeoutSec 55 }
  Require ((Get-Item -LiteralPath $archivePath).Length -eq $lock.archive_bytes) 'Upstream archive size mismatch'
  Require ((Get-FileHash -LiteralPath $archivePath).Hash -eq $lock.archive_sha256) 'Upstream archive SHA-256 mismatch'
  $workspace = Join-Path $Out 'workspace'
  $thirdParty = Join-Path $workspace 'third-party'
  $zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
  try {
    foreach ($entry in $zip.Entries) {
      Require ($entry.FullName.StartsWith($lock.archive_prefix + '/', [StringComparison]::Ordinal)) 'Unexpected upstream archive prefix'
      $destination = [IO.Path]::GetFullPath((Join-Path $thirdParty $entry.FullName))
      Require (-not [IO.Path]::IsPathRooted($entry.FullName) -and $destination.StartsWith($thirdParty + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Unsafe upstream archive path'
    }
  } finally { $zip.Dispose() }
  [IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $thirdParty)
  $binding = Join-Path $thirdParty $lock.archive_prefix
  Check-Upstream $binding $upstreamFiles
  Require ((Get-Content (Join-Path $binding 'internal/ffi/sqlite_version') -Raw).Trim() -eq $lock.sqlite_version) 'SQLite amalgamation version mismatch'
  $stage = 'prepare-public-consumer'
  $engine = Join-Path $workspace 'engine'
  $consumer = Join-Path $workspace 'consumer'
  New-Item -ItemType Directory -Path $engine | Out-Null
  foreach ($name in @('core', 'runner', 'moon.mod')) { Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $engine -Recurse }
  foreach ($name in @('fixtures', 'vendor', 'cmd', '.git', '.mooncakes', '_build')) {
    Require (-not (Test-Path -LiteralPath (Join-Path $engine $name))) 'Engine copy contains private targets or build state'
  }
  Copy-Item -LiteralPath $example -Destination $consumer -Recurse
  $asyncSource = Join-Path $OfflineDependencySource 'moonbitlang/async'
  Require ((Get-Content (Join-Path $asyncSource 'moon.mod') -Raw) -match ('(?m)^version\s*=\s*"' + [regex]::Escape($lock.workspace_async_version) + '"\s*$')) 'Async source version mismatch'
  $asyncDestination = Join-Path $workspace 'async'
  foreach ($file in Get-ChildItem -LiteralPath $asyncSource -Recurse -File -Force) {
    $relative = [IO.Path]::GetRelativePath($asyncSource, $file.FullName)
    if ($relative -match '(^|[\\/])(_build|target|\.git)([\\/]|$)' -or $file.Extension -in @('.exe','.obj','.pdb','.ilk','.lib','.dll','.o','.a','.mi','.core')) { continue }
    $destination = Join-Path $asyncDestination $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
  }
  ('members = ["engine", "consumer", "async", "third-party/' + $lock.archive_prefix + '"]') | Set-Content (Join-Path $workspace 'moon.work') -Encoding utf8
  @(Get-ChildItem -LiteralPath $workspace -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
    [ordered]@{path=[IO.Path]::GetRelativePath($workspace,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
  }) | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Out 'source-manifest.json') -Encoding utf8
  Set-Location -LiteralPath $consumer
  $stage = 'resolve-and-check'
  Invoke-Checked 'moon' @('check','--target','native','--frozen','--deny-warn','sqlite','cmd/main') @(0) (Join-Path $Out 'check.log')
  Invoke-Checked 'moon' @('tree','--json') @(0) (Join-Path $Out 'module-tree.json')
  Invoke-Checked 'moon' @('tree','--package','--json') @(0) (Join-Path $Out 'package-tree.json')
  $tree = Read-Json (Join-Path $Out 'module-tree.json')
  foreach ($entry in @(@{name='serikaonoe123/moonffi-lab';path=$engine},@{name='moonffi-example/sqlite-lab';path=$consumer},@{name=$lock.module;path=$binding},@{name='moonbitlang/async';path=$asyncDestination})) {
    $found = @($tree.modules | Where-Object name -eq $entry.name)
    Require ($found.Count -eq 1 -and $found[0].source.kind -eq 'local' -and $found[0].source.path -eq $entry.path) "Unexpected dependency resolution: $($entry.name)"
  }
  $packages = Read-Json (Join-Path $Out 'package-tree.json')
  $enginePackages = @($packages.nodes | Where-Object module -eq 'serikaonoe123/moonffi-lab')
  Require ((@($enginePackages.rel | Sort-Object) -join ',') -eq 'core,runner') 'Consumer used non-public engine packages'
  $stage = 'upstream-unit-tests'
  # The unchanged persistence test opens _build/sqlite3-persistence-test.db
  # relative to its module directory; Moon's workspace build directory differs.
  New-Item -ItemType Directory -Path (Join-Path $binding '_build') -Force | Out-Null
  Invoke-Checked 'moon' @('test','--target','native','--frozen','--deny-warn','-j','1','--package',$lock.module) @(0) (Join-Path $Out 'upstream-tests.log')
  $upstreamSummary = [regex]::Match((Get-Content (Join-Path $Out 'upstream-tests.log') -Raw),'Total tests: (\d+), passed: (\d+), failed: 0\.')
  Require ($upstreamSummary.Success -and [int]$upstreamSummary.Groups[1].Value -gt 0 -and $upstreamSummary.Groups[1].Value -eq $upstreamSummary.Groups[2].Value) 'Upstream tests incomplete'
  $stage = 'adapter-unit-tests-and-build'
  Invoke-Checked 'moon' @('test','--target','native','--frozen','--deny-warn','-j','1','sqlite') @(0) (Join-Path $Out 'tests.log')
  Require ((Get-Content (Join-Path $Out 'tests.log') -Raw).Contains('Total tests: 8, passed: 8, failed: 0.')) 'Adapter tests incomplete'
  Invoke-Checked 'moon' @('build','--target','native','--frozen','--deny-warn','cmd/main') @(0) (Join-Path $Out 'build.log')
  $executables = @(Get-ChildItem -LiteralPath (Join-Path $workspace '_build/native/debug/build') -Recurse -File -Filter main.exe)
  Require ($executables.Count -eq 1) 'SQLite executable discovery ambiguous'
  $exe = $executables[0].FullName
  $stage = 'native-campaigns'
  $coverage = [System.Collections.Generic.HashSet[string]]::new()
  foreach ($campaign in @(@{label='contract';generator='default';cases=32},@{label='walk';generator='walk';cases=64})) {
    $destination = Join-Path $Out $campaign.label
    Invoke-Checked $exe @('run','--generator',$campaign.generator,'--seed','17','--cases',[string]$campaign.cases,'--steps','64','--timeout-ms','10000','--out',$destination) @(0) (Join-Path $Out "$($campaign.label).log")
    $reports = @(Read-Json (Join-Path $destination 'summary.json'))
    Require ($reports.Count -eq $campaign.cases -and @($reports | Where-Object outcome -ne 'Pass').Count -eq 0) 'SQLite campaign contains an observed failure'
    foreach ($index in 1..$campaign.cases) {
      $input = Read-Json (Join-Path $destination "case-$index/case.json")
      foreach ($step in $input.steps) { [void]$coverage.Add($step.op) }
    }
  }
  Require ($coverage.Count -eq 10) 'Campaign did not exercise every declared operation'
  $stage = 'replay-determinism-and-boundaries'
  foreach ($label in @('contract','walk')) {
    Invoke-Checked $exe @('replay',(Join-Path $Out "$label/case-1/case.json"),'--out',(Join-Path $Out "replay-$label")) @(0) (Join-Path $Out "replay-$label.log")
  }
  foreach ($label in @('a','b')) {
    Invoke-Checked $exe @('generate','--generator','walk','--seed','17','--steps','64','--out',(Join-Path $Out "determinism-$label")) @(0) (Join-Path $Out "determinism-$label.log")
  }
  $walkHash = (Get-FileHash (Join-Path $Out 'walk/case-1/case.json')).Hash
  foreach ($label in @('a','b')) { Require ((Get-FileHash (Join-Path $Out "determinism-$label/case.json")).Hash -eq $walkHash) 'Saved SQLite walk differs between processes'
  }
  $passingInput = Join-Path $Out 'walk/case-1/case.json'
  Invoke-Checked $exe @('shrink',$passingInput,'--budget','100','--out',(Join-Path $Out 'passing-shrink')) @(3) (Join-Path $Out 'passing-shrink.log')
  $passingShrink = Read-Json (Join-Path $Out 'passing-shrink/reduction.json')
  Require (-not $passingShrink.confirmed -and -not $passingShrink.deletion_minimal -and $passingShrink.stop_reason -eq 'unsupported_outcome') 'Passing target was misreported as a reduced failure'
  $invalid = Read-Json (Join-Path $Out 'contract/case-1/case.json')
  $invalid.steps[0].defines = @()
  $invalidPath = Join-Path $Out 'invalid-declarations.json'
  $invalid | ConvertTo-Json -Depth 30 | Set-Content $invalidPath -Encoding utf8
  Invoke-Checked $exe @('replay',$invalidPath,'--out',(Join-Path $Out 'invalid')) @(2) (Join-Path $Out 'invalid.log')
  $invalidReport = Read-Json (Join-Path $Out 'invalid/case-1/report.json')
  Require ($invalidReport.outcome -eq 'InvalidCase' -and $invalidReport.executed -eq 0) 'Invalid declaration reached target execution'
  Invoke-Checked $exe @('run','--mode','mutant','--out',(Join-Path $Out 'unknown-mode')) @(2) (Join-Path $Out 'unknown-mode.log')
  Invoke-Checked $exe @('generate','--generator','unknown','--out',(Join-Path $Out 'unknown-generator')) @(2) (Join-Path $Out 'unknown-generator.log')
  $existing = Join-Path $Out 'replay-walk/case-1/report.json'
  $existingHash = (Get-FileHash $existing).Hash
  Invoke-Checked $exe @('replay',$passingInput,'--out',(Join-Path $Out 'replay-walk')) @(2) (Join-Path $Out 'output-reuse.log')
  Require ((Get-FileHash $existing).Hash -eq $existingHash) 'Existing SQLite evidence was overwritten'
  $stage = 'upstream-source-preservation'
  Check-Upstream $binding $upstreamFiles
  [ordered]@{
    state='passed';completed_at=[DateTimeOffset]::UtcNow.ToString('o');consumer_module='moonffi-example/sqlite-lab'
    upstream_module=$lock.module;upstream_commit=$lock.commit;upstream_archive_mode=$archiveMode
    upstream_archive_bytes=$lock.archive_bytes;upstream_archive_sha256=$lock.archive_sha256;upstream_git_blobs_checked_before_and_after=$upstreamFiles.Count
    upstream_source_modified=$false;upstream_scripts_executed=$false;sqlite_version=$lock.sqlite_version
    upstream_persistence_fixture='Empty module-local _build directory created before unchanged upstream tests'
    declared_upstream_async_version=$lock.declared_async_version;resolved_workspace_async_version=$lock.workspace_async_version
    dependency_mode='explicit-local-source-cache';dependency_source=$OfflineDependencySource
    engine_packages=@($enginePackages.rel | Sort-Object);source_manifest_sha256=(Get-FileHash (Join-Path $Out 'source-manifest.json')).Hash
    upstream_unit_tests=[int]$upstreamSummary.Groups[1].Value;adapter_unit_tests=8;repair_subsets=1024;pure_generated_walks=256;native_unit_walks=32
    contract_cases=32;walk_cases=64;operation_kinds=@($coverage | Sort-Object);saved_replays=2;separate_process_determinism=$true
    passing_shrink_stop_reason=$passingShrink.stop_reason;passing_shrink_claimed_failure=$false;invalid_preflight_rejected=$true;output_reuse_rejected=$true
    executable_sha256=(Get-FileHash $exe).Hash;temporary_directory=$temporaryDirectory;async_fd_leak_check='1'
    unknown_defects_found=0;artificial_target_mutants_used=$false;independent_environment=$false
    scope='Unchanged pinned community binding consumed through public core/runner. Synchronous in-memory SELECT/bind/reset/step/read and explicit lifecycle contracts only; no unknown defect, heap-leak proof, concurrency coverage or SQLite ASan coverage claimed.'
  } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'verification.json') -Encoding utf8
  Write-Host "External SQLite verification passed. Evidence: $Out"
} catch {
  [ordered]@{state='failed';stage=$stage;error=$_.Exception.Message} | ConvertTo-Json | Set-Content (Join-Path $Out 'failure.json') -Encoding utf8
  throw
} finally {
  foreach ($variable in @(@{name='TEMP';value=$savedTemp},@{name='TMP';value=$savedTmp},@{name='MOONBIT_ASYNC_CHECK_FD_LEAK';value=$savedFdCheck})) {
    if ($null -eq $variable.value) {
      [Environment]::SetEnvironmentVariable($variable.name,[NullString]::Value,'Process')
    } else { [Environment]::SetEnvironmentVariable($variable.name,$variable.value,'Process') }
  }
  Set-Location -LiteralPath $savedLocation
}
