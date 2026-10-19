#requires -Version 7.0
param([string]$Out = '', [string]$ToolchainRoot = '', [string]$LockFile = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $LockFile) { $LockFile = Join-Path $projectRoot 'toolchain.json' }
if ($Out -and (Test-Path -LiteralPath $Out)) { throw "Toolchain report already exists: $Out" }
. (Join-Path $PSScriptRoot 'toolchain-common.ps1')
$savedMoonHome = $env:MOON_HOME
$savedPath = $env:PATH
$stage = 'lock'
try {
  $expected = Get-Content -LiteralPath $LockFile -Raw | ConvertFrom-Json
  Assert-ToolchainIdentityLock $expected
  if (-not $ToolchainRoot) {
    $activeMoon = (Get-Command moon -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $ToolchainRoot = Split-Path -Parent (Split-Path -Parent $activeMoon)
  }
  $ToolchainRoot = (Resolve-Path -LiteralPath $ToolchainRoot).Path
  $bin = Join-Path $ToolchainRoot 'bin'
  $mismatches = [Collections.Generic.List[string]]::new()
  $binaries = [Collections.Generic.List[object]]::new()
  $actual = @()
  $core = $null
  $stage = 'binary-hashes'
  foreach ($entry in $expected.components.PSObject.Properties) {
    $path = Join-Path $bin "$($entry.Name).exe"
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $wanted = $expected.binary_sha256.($entry.Name)
    if ($wanted -notmatch '^[0-9A-Fa-f]{64}$' -or $hash -ne $wanted) { $mismatches.Add("$($entry.Name): binary SHA256 mismatch") }
    $binaries.Add([ordered]@{name=$entry.Name;path=$path;sha256=$hash;expected_sha256=$wanted})
  }
  # Never execute a binary that failed its content check.
  if ($mismatches.Count -eq 0) {
    $env:MOON_HOME = $ToolchainRoot
    $env:PATH = $bin + ';' + $savedPath
    $stage = 'versions'
    $versionText = & (Join-Path $bin 'moon.exe') version --all --json
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect MoonBit toolchain' }
    $actual = ($versionText | ConvertFrom-Json).items
    foreach ($entry in $expected.components.PSObject.Properties) {
      $observed = @($actual | Where-Object name -eq $entry.Name)
      if ($observed.Count -ne 1 -or $observed[0].version -ne $entry.Value) {
        $mismatches.Add("$($entry.Name): expected '$($entry.Value)', got '$($observed.version -join ', ')'")
      }
    }
    $stage = 'core-source'
    $corePath = Join-Path $ToolchainRoot 'lib/core'
    $coreModule = Get-Content -LiteralPath (Join-Path $corePath 'moon.mod') -Raw
    if ($coreModule -notmatch ('(?m)^version\s*=\s*"' + [regex]::Escape($expected.core_version) + '"\s*$')) { $mismatches.Add('core: module version mismatch') }
    $core = Get-CoreSourceIdentity $corePath
    if ($core.files -ne $expected.core_source_identity.files -or $core.sha256 -ne $expected.core_source_identity.sha256) { $mismatches.Add('core: source tree SHA256 mismatch') }
  }
  $report = [ordered]@{
    state=$(if ($mismatches.Count) {'failed'} else {'passed'});stage=$stage
    lock_sha256=(Get-FileHash -LiteralPath $LockFile).Hash;toolchain_root=$ToolchainRoot
    expected=$expected.components;actual=$actual;binaries=$binaries.ToArray()
    core=$core;expected_core=$expected.core_source_identity;mismatches=$mismatches.ToArray()
    scope='Windows x64 binaries and core source are content-pinned. Generated core bundles, MSVC, Windows SDK, registry state and host environment are not covered by this identity.'
  }
  if ($Out) { $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Out -Encoding utf8 }
  if ($mismatches.Count) { throw ($mismatches -join "`n") }
  Write-Host 'MoonBit versions, binaries and core source match toolchain.json'
} catch {
  if ($Out -and -not (Test-Path -LiteralPath $Out)) {
    [ordered]@{state='failed';stage=$stage;error=$_.Exception.Message} | ConvertTo-Json | Set-Content -LiteralPath $Out -Encoding utf8
  }
  throw
} finally { $env:MOON_HOME=$savedMoonHome; $env:PATH=$savedPath }
