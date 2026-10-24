#requires -Version 7.0
param([string]$Destination = '', [string]$Out = '', [string]$ArchiveDirectory = '', [string]$LockFile = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $LockFile) { $LockFile = Join-Path $projectRoot 'toolchain.json' }
if (-not $Out) { $Out = Join-Path $projectRoot ('results/bootstrap-' + [guid]::NewGuid().ToString('N')) }
$Out = [IO.Path]::GetFullPath($Out)
if (-not $Destination) { $Destination = Join-Path $Out 'toolchain' }
$Destination = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
if (Test-Path -LiteralPath $Destination) { throw "Toolchain destination must be new: $Destination" }
if ($Out -eq $Destination -or $Out.StartsWith($Destination.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Evidence output must not be inside the installation destination' }
New-Item -ItemType Directory -Path $Out | Out-Null
. (Join-Path $PSScriptRoot 'toolchain-common.ps1')
$savedMoonHome = $env:MOON_HOME
$savedPath = $env:PATH
$savedLocation = Get-Location
$stage = 'lock'
$accepted = [Collections.Generic.List[object]]::new()
try {
  if ($env:OS -ne 'Windows_NT' -or [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString() -ne 'X64') { throw 'This lock requires Windows x64 and PowerShell 7' }
  $LockFile = (Resolve-Path -LiteralPath $LockFile).Path
  $lock = Get-Content -LiteralPath $LockFile -Raw | ConvertFrom-Json
  Assert-ToolchainIdentityLock $lock
  if ($lock.bootstrap.schema -ne 1 -or $lock.bootstrap.platform -ne 'windows-x86_64' -or $lock.bootstrap.archives.Count -ne 2) { throw 'Unsupported bootstrap lock' }
  $kinds = @{}
  foreach ($entry in $lock.bootstrap.archives) {
    if ($entry.kind -notin @('toolchain','core') -or $kinds.ContainsKey($entry.kind) -or
      $entry.file -ne [IO.Path]::GetFileName($entry.file) -or $entry.file -notmatch '^[A-Za-z0-9_.-]+\.zip$' -or
      $entry.sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or $entry.bytes -le 0 -or ([Uri]$entry.url).Scheme -ne 'https') { throw 'Malformed bootstrap archive entry' }
    $kinds[$entry.kind] = $true
  }
  $mode = if ($ArchiveDirectory) {'explicit-local-archives'} else {'official-downloads'}
  if ($ArchiveDirectory) { $archiveRoot = (Resolve-Path -LiteralPath $ArchiveDirectory).Path }
  else { $archiveRoot = Join-Path $Out 'downloads'; New-Item -ItemType Directory -Path $archiveRoot | Out-Null }
  # All archives pass before any extraction or downloaded executable runs.
  foreach ($entry in $lock.bootstrap.archives) {
    $path = Join-Path $archiveRoot $entry.file
    if ($ArchiveDirectory) {
      $stage = 'verify-archives'
      if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing locked archive: $($entry.file)" }
    } else {
      $stage = "download/$($entry.kind)"
      Invoke-WebRequest -Uri $entry.url -OutFile $path
    }
    $stage = 'verify-archives'
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($hash -ne $entry.sha256 -or (Get-Item -LiteralPath $path).Length -ne $entry.bytes) { throw "Locked archive content mismatch: $($entry.file)" }
    $accepted.Add([ordered]@{kind=$entry.kind;file=$entry.file;url=$entry.url;path=$path;bytes=$entry.bytes;sha256=$hash})
  }
  $accepted.ToArray() | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Out 'archives.json') -Encoding utf8
  $stage = 'archive-layout'
  foreach ($archive in $accepted) {
    $target = if ($archive.kind -eq 'core') {Join-Path $Destination 'lib'} else {$Destination}
    Assert-ToolchainZipLayout $archive.path $target
  }
  $stage = 'extract'
  New-Item -ItemType Directory -Path $Destination | Out-Null
  foreach ($archive in $accepted) {
    $target = if ($archive.kind -eq 'core') {Join-Path $Destination 'lib'} else {$Destination}
    Expand-Archive -LiteralPath $archive.path -DestinationPath $target
  }
  $stage = 'verify-extracted-toolchain'
  & (Join-Path $PSScriptRoot 'assert-toolchain.ps1') -ToolchainRoot $Destination -LockFile $LockFile -Out (Join-Path $Out 'before-bundle.json')
  $bin = Join-Path $Destination 'bin'
  $moon = Join-Path $bin 'moon.exe'
  Copy-Item -LiteralPath $moon -Destination (Join-Path $bin 'moonx.exe')
  $env:MOON_HOME = $Destination
  $env:PATH = $bin + ';' + $savedPath
  Set-Location -LiteralPath (Join-Path $Destination 'lib/core')
  $stage = 'bundle-core'
  & $moon bundle --warn-list -a --all *> (Join-Path $Out 'bundle-all.log')
  if ($LASTEXITCODE -ne 0) { throw 'Core bundling failed; see bundle-all.log' }
  & $moon bundle --warn-list -a --target wasm-gc --quiet *> (Join-Path $Out 'bundle-wasm-gc.log')
  if ($LASTEXITCODE -ne 0) { throw 'Core wasm-gc bundling failed; see bundle-wasm-gc.log' }
  $stage = 'verify-bundled-toolchain'
  & (Join-Path $PSScriptRoot 'assert-toolchain.ps1') -ToolchainRoot $Destination -LockFile $LockFile -Out (Join-Path $Out 'toolchain.json')
  [ordered]@{
    state='passed';completed_at=[DateTimeOffset]::UtcNow.ToString('o');destination=$Destination
    source_mode=$mode;lock_sha256=(Get-FileHash -LiteralPath $LockFile).Hash;archives=$accepted.ToArray()
    upstream_installer_executed=$false;bundled_core=$true;environment_restored=$true
    scope='Archive bytes, three tool binaries and core source are pinned. Official versioned URLs may become unavailable; retained local archives support offline installation. No global PATH or existing installation is changed.'
  } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'verification.json') -Encoding utf8
  Write-Host "Locked toolchain installed: $Destination"
  Write-Host "Evidence: $Out"
} catch {
  [ordered]@{state='failed';stage=$stage;error=$_.Exception.Message;accepted_archives=$accepted.ToArray()} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Out 'failure.json') -Encoding utf8
  throw
} finally { $env:MOON_HOME=$savedMoonHome; $env:PATH=$savedPath; Set-Location -LiteralPath $savedLocation }
