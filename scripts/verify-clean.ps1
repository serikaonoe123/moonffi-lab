param(
  [string]$Out = '',
  [string]$Ref = 'HEAD',
  [ValidateSet('behavior','asan','benchmark','generation','sdk','sqlite','native-errors')][string[]]$Suite = @('behavior'),
  [string]$OfflineDependencySource = '',
  [switch]$WorkspaceTemp
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
$savedLocation = Get-Location
$stage = 'setup'
if (-not $Out) { $Out = Join-Path $projectRoot ('results/clean-' + [guid]::NewGuid().ToString('N')) }
$Out = [System.IO.Path]::GetFullPath($Out)
if ($WorkspaceTemp -and -not $Out.StartsWith($projectRoot + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'WorkspaceTemp requires an output directory inside this project.'
}
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
if ($OfflineDependencySource) { $OfflineDependencySource = (Resolve-Path -LiteralPath $OfflineDependencySource).Path }
New-Item -ItemType Directory -Path $Out | Out-Null
$savedTemp = [Environment]::GetEnvironmentVariable('TEMP', 'Process')
$savedTmp = [Environment]::GetEnvironmentVariable('TMP', 'Process')
$savedMoonHome = [Environment]::GetEnvironmentVariable('MOON_HOME', 'Process')
$savedPath = $env:PATH
$temporaryDirectory = $null

function Invoke-Logged([string]$Exe, [string[]]$ToolArgs, [string]$Log) {
  $lines = & $Exe @ToolArgs 2>&1
  $code = $LASTEXITCODE
  $lines | Set-Content -LiteralPath $Log -Encoding utf8
  if ($code -ne 0) { throw "$Exe exited $code. See $Log" }
}
try {
  if ($WorkspaceTemp) {
    $temporaryDirectory = Join-Path $Out 'temp'
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
    $env:TEMP = $temporaryDirectory
    $env:TMP = $temporaryDirectory
  }
  Set-Location -LiteralPath $projectRoot
  $stage = 'export-commit'
  $sourceCommit = & git rev-parse --verify "$Ref^{commit}"
  if ($LASTEXITCODE -ne 0) { throw "Not a commit: $Ref" }
  $sourceCommit = $sourceCommit.Trim()
  $archivePath = Join-Path $Out 'source.tar'
  Invoke-Logged 'git' @('archive','--format=tar',"--output=$archivePath",$sourceCommit) (Join-Path $Out 'archive.log')
  $workspace = Join-Path $Out 'workspace'
  New-Item -ItemType Directory -Path $workspace | Out-Null
  Invoke-Logged 'tar' @('-xf',$archivePath,'-C',$workspace) (Join-Path $Out 'extract.log')
  foreach ($forbidden in @('.git','.mooncakes','_build','results')) {
    if (Test-Path -LiteralPath (Join-Path $workspace $forbidden)) { throw "Archive contains local state: $forbidden" }
  }
  $sourceManifest = @(Get-ChildItem -LiteralPath $workspace -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = $_.FullName.Substring($workspace.Length + 1).Replace('\','/'); sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash }
  })
  $sourceManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Out 'source-manifest.json') -Encoding utf8
  $stage = 'toolchain'
  & (Join-Path $workspace 'scripts/assert-toolchain.ps1') -Out (Join-Path $Out 'toolchain.json')
  $verifiedToolchain = (Get-Content -LiteralPath (Join-Path $Out 'toolchain.json') -Raw | ConvertFrom-Json).toolchain_root
  $env:MOON_HOME = $verifiedToolchain
  $env:PATH = (Join-Path $verifiedToolchain 'bin') + ';' + $savedPath
  $expected = Get-Content -LiteralPath (Join-Path $workspace 'toolchain.json') -Raw | ConvertFrom-Json
  $dependencyMode = 'registry'
  Set-Location -LiteralPath $workspace
  $stage = 'dependencies'
  if ($OfflineDependencySource) {
    $dependencyMode = 'explicit-local-workspace-source'
    $asyncSource = Join-Path $OfflineDependencySource 'moonbitlang/async'
    $asyncConfig = Get-Content -LiteralPath (Join-Path $asyncSource 'moon.mod') -Raw
    if ($asyncConfig -notmatch ('(?m)^version\s*=\s*"' + [regex]::Escape($expected.async_version) + '"\s*$')) { throw 'Offline async source version mismatch' }
    $asyncDestination = Join-Path $workspace '.mooncakes/moonbitlang/async'
    foreach ($file in (Get-ChildItem -LiteralPath $asyncSource -Recurse -File -Force)) {
      $relative = $file.FullName.Substring($asyncSource.Length + 1)
      if ($file.Name -eq 'pkg.generated.mbti' -or $relative -match '(^|[\\/])(_build|target|\.git)([\\/]|$)' -or $file.Extension -in @('.exe','.obj','.pdb','.ilk','.lib','.dll','.o','.a','.mi','.core')) { continue }
      $destination = Join-Path $asyncDestination $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
      Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    'members = [".", ".mooncakes/moonbitlang/async"]' | Set-Content -LiteralPath (Join-Path $workspace 'moon.work') -Encoding utf8
  } else {
    Invoke-Logged 'moon' @('update') (Join-Path $Out 'dependency-update.log')
  }
  # Frozen mode must only be used after dependency sources are available.
  $checkArgs = @('check','--target','native','--deny-warn')
  if ($OfflineDependencySource) { $checkArgs += '--frozen' }
  Invoke-Logged 'moon' $checkArgs (Join-Path $Out 'dependency-check.log')
  Invoke-Logged 'moon' @('tree','--json') (Join-Path $Out 'module-tree.json')
  $resolvedAsync = Get-Content -LiteralPath (Join-Path $workspace '.mooncakes/moonbitlang/async/moon.mod') -Raw
  if ($resolvedAsync -notmatch ('(?m)^version\s*=\s*"' + [regex]::Escape($expected.async_version) + '"\s*$')) { throw 'Resolved async version mismatch' }
  $dependencyManifest = @(Get-ChildItem -LiteralPath (Join-Path $workspace '.mooncakes') -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
    if ($_.Name -ne 'pkg.generated.mbti' -and $_.FullName -notmatch '[\\/]_build[\\/]') {
      [ordered]@{ path = $_.FullName.Substring($workspace.Length + 1).Replace('\','/'); sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash }
    }
  })
  $dependencyManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Out 'dependency-manifest.json') -Encoding utf8
  foreach ($selectedSuite in $Suite) {
    $stage = $selectedSuite
    $suiteOutput = Join-Path $Out $selectedSuite
    switch ($selectedSuite) {
      'behavior' { & (Join-Path $workspace 'scripts/verify.ps1') -Out $suiteOutput }
      'asan' { & (Join-Path $workspace 'scripts/verify-asan.ps1') -Out $suiteOutput }
      'native-errors' { & (Join-Path $workspace 'scripts/verify-native-errors.ps1') -Out $suiteOutput }
      'benchmark' {
        Invoke-Logged 'moon' @('build','--target','native','--frozen') (Join-Path $Out 'benchmark-build.log')
        & (Join-Path $workspace 'scripts/benchmark-reduction.ps1') -Out $suiteOutput
      }
      'generation' {
        Invoke-Logged 'moon' @('build','--target','native','--frozen') (Join-Path $Out 'generation-build.log')
        & (Join-Path $workspace 'scripts/verify-generation.ps1') -Out $suiteOutput
      }
      'sdk' {
        if ($OfflineDependencySource) {
          & (Join-Path $workspace 'scripts/verify-sdk.ps1') -Out $suiteOutput -OfflineDependencySource (Join-Path $workspace '.mooncakes')
        } else { & (Join-Path $workspace 'scripts/verify-sdk.ps1') -Out $suiteOutput }
      }
      'sqlite' {
        & (Join-Path $workspace 'scripts/verify-sqlite.ps1') -Out $suiteOutput -OfflineDependencySource (Join-Path $workspace '.mooncakes')
      }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $suiteOutput 'verification.json'))) { throw "Suite produced no success evidence: $selectedSuite" }
    $suiteResult = Get-Content -LiteralPath (Join-Path $suiteOutput 'verification.json') -Raw | ConvertFrom-Json
    if ($suiteResult.state -ne 'passed') { throw "Suite did not pass: $selectedSuite" }
  }
  foreach ($entry in @($sourceManifest) + @($dependencyManifest)) {
    if ($entry.sha256 -cne (Get-FileHash -LiteralPath (Join-Path $workspace $entry.path)).Hash) { throw "Source input changed: $($entry.path)" }
  }
  [ordered]@{
    state = 'passed'; completed_at = [DateTimeOffset]::UtcNow.ToString('o')
    source_commit = $sourceCommit; archive_sha256 = (Get-FileHash -LiteralPath $archivePath).Hash
    driver_sha256 = (Get-FileHash -LiteralPath $PSCommandPath).Hash
    source_files = $sourceManifest.Count; suites = $Suite; dependency_mode = $dependencyMode
    dependency_source = $OfflineDependencySource; fresh_project_build = $true
    temporary_directory = $temporaryDirectory
    host_environment = [ordered]@{
      os = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
      architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
      powershell = $PSVersionTable.PSVersion.ToString()
      github_actions = $env:GITHUB_ACTIONS; runner_os = $env:RUNNER_OS; runner_arch = $env:RUNNER_ARCH
      image_os = $env:ImageOS; image_version = $env:ImageVersion
    }
    independent_environment = $false
    scope = 'Exported committed source; no project build outputs copied. Host toolchain/core and registry cache are shared; hosted-runner provenance must be inspected separately.'
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Out 'verification.json') -Encoding utf8
  Write-Host "Clean source verification passed. Evidence: $Out"
} catch {
  [ordered]@{ state = 'failed'; stage = $stage; error = $_.Exception.Message; temporary_directory = $temporaryDirectory } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Out 'failure.json') -Encoding utf8
  throw
} finally {
  [Environment]::SetEnvironmentVariable('MOON_HOME', $savedMoonHome, 'Process')
  $env:PATH = $savedPath
  if ($WorkspaceTemp) {
    foreach ($variable in @(@{name='TEMP';value=$savedTemp},@{name='TMP';value=$savedTmp})) {
      if ($null -eq $variable.value) {
        [Environment]::SetEnvironmentVariable($variable.name, [NullString]::Value, 'Process')
      } else { [Environment]::SetEnvironmentVariable($variable.name, $variable.value, 'Process') }
    }
  }
  Set-Location -LiteralPath $savedLocation
}
