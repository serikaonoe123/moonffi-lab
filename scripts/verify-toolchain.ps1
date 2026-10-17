#requires -Version 7.0
param([Parameter(Mandatory)][string]$ArchiveDirectory, [Parameter(Mandatory)][string]$ToolchainRoot, [string]$Out = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$ArchiveDirectory = (Resolve-Path -LiteralPath $ArchiveDirectory).Path
$ToolchainRoot = (Resolve-Path -LiteralPath $ToolchainRoot).Path
if (-not $Out) { $Out = Join-Path $projectRoot ('results/toolchain-checks-' + [guid]::NewGuid().ToString('N')) }
$Out = [IO.Path]::GetFullPath($Out)
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
New-Item -ItemType Directory -Path $Out | Out-Null
$savedMoonHome = $env:MOON_HOME
$savedPath = $env:PATH
$install = Join-Path $PSScriptRoot 'install-toolchain.ps1'
$assert = Join-Path $PSScriptRoot 'assert-toolchain.ps1'
$lockPath = Join-Path $projectRoot 'toolchain.json'
$checks = [Collections.Generic.List[object]]::new()
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Expect-Rejection([string]$Name, [scriptblock]$Action) {
  $message = $null
  try { & $Action } catch { $message = $_.Exception.Message }
  Require ([bool]$message) "Expected rejection: $Name"
  $checks.Add([ordered]@{name=$Name;outcome='rejected';message=$message})
}
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Write-Lock([string]$Path, $Lock) { $Lock | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8 }
function Copy-ToolBinaries([string]$Target) {
  New-Item -ItemType Directory -Path (Join-Path $Target 'bin') | Out-Null
  foreach ($name in @('moon','moonc','moonrun')) { Copy-Item -LiteralPath (Join-Path $ToolchainRoot "bin/$name.exe") -Destination (Join-Path $Target "bin/$name.exe") }
}
try {
  & $assert -ToolchainRoot $ToolchainRoot -Out (Join-Path $Out 'positive.json')
  $checks.Add([ordered]@{name='valid-isolated-toolchain';outcome='passed'})
  $originalMoonHash = (Get-FileHash -LiteralPath (Join-Path $ToolchainRoot 'bin/moon.exe')).Hash

  $badArchives = Join-Path $Out 'corrupt-archives'
  New-Item -ItemType Directory -Path $badArchives | Out-Null
  foreach ($file in @('moonbit-windows-x86_64.zip','core-latest.zip')) { Copy-Item -LiteralPath (Join-Path $ArchiveDirectory $file) -Destination $badArchives }
  $corrupt = Join-Path $badArchives 'core-latest.zip'
  $stream = [IO.File]::Open($corrupt, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite)
  try { $value=$stream.ReadByte(); $stream.Position=0; $stream.WriteByte($value -bxor 1) } finally { $stream.Dispose() }
  $rejectedDestination = Join-Path $Out 'corrupt-install'
  $rejectedOutput = Join-Path $Out 'corrupt-output'
  Expect-Rejection 'corrupt-second-archive-before-extraction' { & $install -ArchiveDirectory $badArchives -Destination $rejectedDestination -Out $rejectedOutput }
  Require ((Read-Json (Join-Path $rejectedOutput 'failure.json')).stage -eq 'verify-archives' -and -not (Test-Path -LiteralPath $rejectedDestination)) 'Corrupt archive reached extraction'

  $missingArchives = Join-Path $Out 'missing-archives'
  New-Item -ItemType Directory -Path $missingArchives | Out-Null
  $rejectedDestination = Join-Path $Out 'missing-install'
  $rejectedOutput = Join-Path $Out 'missing-output'
  Expect-Rejection 'missing-offline-archive-no-network-fallback' { & $install -ArchiveDirectory $missingArchives -Destination $rejectedDestination -Out $rejectedOutput }
  Require ((Read-Json (Join-Path $rejectedOutput 'failure.json')).stage -eq 'verify-archives' -and -not (Test-Path -LiteralPath $rejectedDestination) -and -not (Test-Path (Join-Path $rejectedOutput 'downloads'))) 'Missing offline archive was not rejected before work'

  $unsafeArchives = Join-Path $Out 'unsafe-archives'
  New-Item -ItemType Directory -Path $unsafeArchives | Out-Null
  Copy-Item -LiteralPath (Join-Path $ArchiveDirectory 'core-latest.zip') -Destination $unsafeArchives
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zipPath = Join-Path $unsafeArchives 'moonbit-windows-x86_64.zip'
  $zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
  try {
    $writer = [IO.StreamWriter]::new($zip.CreateEntry('../escape.txt').Open())
    try { $writer.Write('labelled traversal control') } finally { $writer.Dispose() }
  } finally { $zip.Dispose() }
  $badLock = Read-Json $lockPath
  $badLock.bootstrap.archives[0].sha256 = (Get-FileHash -LiteralPath $zipPath).Hash
  $badLock.bootstrap.archives[0].bytes = (Get-Item -LiteralPath $zipPath).Length
  $badLockPath = Join-Path $Out 'unsafe-lock.json'; Write-Lock $badLockPath $badLock
  $rejectedDestination = Join-Path $Out 'unsafe-install'
  $rejectedOutput = Join-Path $Out 'unsafe-output'
  Expect-Rejection 'archive-path-traversal-before-extraction' { & $install -ArchiveDirectory $unsafeArchives -Destination $rejectedDestination -Out $rejectedOutput -LockFile $badLockPath }
  Require ((Read-Json (Join-Path $rejectedOutput 'failure.json')).stage -eq 'archive-layout' -and -not (Test-Path -LiteralPath $rejectedDestination) -and -not (Test-Path (Join-Path $Out 'escape.txt'))) 'Unsafe archive reached extraction'

  $badLock = Read-Json $lockPath
  $badLock.bootstrap.archives[0].url = 'http://example.invalid/toolchain.zip'
  $badLockPath = Join-Path $Out 'http-lock.json'; Write-Lock $badLockPath $badLock
  $rejectedDestination = Join-Path $Out 'http-install'
  $rejectedOutput = Join-Path $Out 'http-output'
  Expect-Rejection 'non-https-lock-before-download' { & $install -Destination $rejectedDestination -Out $rejectedOutput -LockFile $badLockPath }
  Require ((Read-Json (Join-Path $rejectedOutput 'failure.json')).stage -eq 'lock' -and -not (Test-Path -LiteralPath $rejectedDestination)) 'Malformed URL reached download or extraction'

  $badLock = Read-Json $lockPath
  $badLock.binary_sha256.PSObject.Properties.Remove('moon')
  $badLockPath = Join-Path $Out 'missing-pin-lock.json'; Write-Lock $badLockPath $badLock
  $rejectedDestination = Join-Path $Out 'missing-pin-install'
  $rejectedOutput = Join-Path $Out 'missing-pin-output'
  Expect-Rejection 'missing-binary-pin-before-any-installation' { & $install -ArchiveDirectory $ArchiveDirectory -Destination $rejectedDestination -Out $rejectedOutput -LockFile $badLockPath }
  Require ((Read-Json (Join-Path $rejectedOutput 'failure.json')).stage -eq 'lock' -and -not (Test-Path -LiteralPath $rejectedDestination)) 'Incomplete content lock reached installation'

  $badLock = Read-Json $lockPath
  $badLock.components.moon = 'deliberate-version-drift'
  $badLockPath = Join-Path $Out 'version-lock.json'; Write-Lock $badLockPath $badLock
  Expect-Rejection 'version-drift' { & $assert -ToolchainRoot $ToolchainRoot -LockFile $badLockPath -Out (Join-Path $Out 'version-drift.json') }
  Require (((Read-Json (Join-Path $Out 'version-drift.json')).mismatches -join ' ').Contains('deliberate-version-drift')) 'Version drift diagnostic missing'

  $binaryDrift = Join-Path $Out 'binary-drift'
  Copy-ToolBinaries $binaryDrift
  $stream = [IO.File]::Open((Join-Path $binaryDrift 'bin/moon.exe'), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite)
  try { $value=$stream.ReadByte(); $stream.Position=0; $stream.WriteByte($value -bxor 1) } finally { $stream.Dispose() }
  Expect-Rejection 'binary-drift-before-execution' { & $assert -ToolchainRoot $binaryDrift -Out (Join-Path $Out 'binary-drift.json') }
  $driftReport = Read-Json (Join-Path $Out 'binary-drift.json')
  Require ($driftReport.stage -eq 'binary-hashes' -and $driftReport.actual.Count -eq 0 -and ($driftReport.mismatches -join ' ').Contains('binary SHA256 mismatch')) 'Unverified binary reached version execution'

  $coreDrift = Join-Path $Out 'core-drift'
  Copy-ToolBinaries $coreDrift
  Expand-Archive -LiteralPath (Join-Path $ArchiveDirectory 'core-latest.zip') -DestinationPath (Join-Path $coreDrift 'lib')
  [IO.File]::AppendAllText((Join-Path $coreDrift 'lib/core/README.md'), "`nLabelled source identity control.`n")
  Expect-Rejection 'core-source-drift-with-unchanged-version' { & $assert -ToolchainRoot $coreDrift -Out (Join-Path $Out 'core-drift.json') }
  $driftReport = Read-Json (Join-Path $Out 'core-drift.json')
  Require ($driftReport.core.files -eq 1201 -and ($driftReport.mismatches -join ' ').Contains('source tree SHA256 mismatch')) 'Core source mutation was not detected'

  $rejectedOutput = Join-Path $Out 'reused-destination-output'
  Expect-Rejection 'existing-installation-preserved' { & $install -ArchiveDirectory $ArchiveDirectory -Destination $ToolchainRoot -Out $rejectedOutput }
  Require (-not (Test-Path -LiteralPath $rejectedOutput) -and (Get-FileHash (Join-Path $ToolchainRoot 'bin/moon.exe')).Hash -eq $originalMoonHash) 'Existing installation changed'
  $rejectedDestination = Join-Path $Out 'reused-output-install'
  $positiveHash = (Get-FileHash (Join-Path $Out 'positive.json')).Hash
  Expect-Rejection 'existing-evidence-preserved' { & $install -ArchiveDirectory $ArchiveDirectory -Destination $rejectedDestination -Out $Out }
  Require (-not (Test-Path -LiteralPath $rejectedDestination) -and (Get-FileHash (Join-Path $Out 'positive.json')).Hash -eq $positiveHash) 'Existing evidence changed'
  Require ($env:MOON_HOME -eq $savedMoonHome -and $env:PATH -eq $savedPath) 'Process environment was not restored'
  [ordered]@{state='passed';completed_at=[DateTimeOffset]::UtcNow.ToString('o');checks=$checks.ToArray();environment_restored=$true;original_installation_preserved=$true} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'verification.json') -Encoding utf8
  Write-Host "Toolchain rejection checks passed ($($checks.Count)). Evidence: $Out"
} catch {
  [ordered]@{state='failed';error=$_.Exception.Message;completed_checks=$checks.ToArray()} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Out 'failure.json') -Encoding utf8
  throw
} finally { $env:MOON_HOME=$savedMoonHome; $env:PATH=$savedPath }
