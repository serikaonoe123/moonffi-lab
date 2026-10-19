param([Parameter(Mandatory)][string]$UpstreamArchive, [string]$Out = '', [string]$OfflineDependencySource = '')
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$originalLocation = Get-Location
$names = @('TEMP','TMP','MOONBIT_ASYNC_CHECK_FD_LEAK')
$original = @{}
foreach ($name in $names) { $original[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
if (-not $Out) { $Out = Join-Path $project ('results/script-controls-' + [guid]::NewGuid().ToString('N')) }
$Out = [IO.Path]::GetFullPath($Out)
if (Test-Path -LiteralPath $Out) { throw 'Controls output must be new' }
$UpstreamArchive = (Resolve-Path -LiteralPath $UpstreamArchive).Path
if (-not $OfflineDependencySource) { $OfflineDependencySource = Join-Path $project '.mooncakes' }
$OfflineDependencySource = (Resolve-Path -LiteralPath $OfflineDependencySource).Path
$lock = Get-Content (Join-Path $project 'examples/sqlite-lab/upstream.json') -Raw | ConvertFrom-Json
if ((Get-FileHash $UpstreamArchive).Hash -ne $lock.archive_sha256) { throw 'Control source archive is not pinned' }
New-Item -ItemType Directory -Path $Out | Out-Null
$checks = [Collections.Generic.List[object]]::new()
function Set-ProcessValue([string]$Name, $Value) {
  if ($null -eq $Value) { [Environment]::SetEnvironmentVariable($Name,[NullString]::Value,'Process') }
  else { [Environment]::SetEnvironmentVariable($Name,$Value,'Process') }
}
function Reject([string]$Name, [string]$Driver, [hashtable]$Arguments, [string]$Stage) {
  $before = @{}
  foreach ($key in $names) { $before[$key] = [Environment]::GetEnvironmentVariable($key,'Process') }
  $location = (Get-Location).Path
  $caught = $false
  $log = Join-Path $Out "$Name.log"
  try { & (Join-Path $project "scripts/$Driver") @Arguments *> $log }
  catch { $caught = $true; $_.Exception.Message | Add-Content $log }
  if (-not $caught) { throw "Control accepted: $Name" }
  foreach ($key in $names) {
    if ([Environment]::GetEnvironmentVariable($key,'Process') -cne $before[$key]) { throw "Caller variable changed: $Name / $key" }
  }
  if ((Get-Location).Path -ne $location) { throw "Caller location changed: $Name" }
  if ($Stage) {
    $failure = Get-Content (Join-Path $Arguments.Out 'failure.json') -Raw | ConvertFrom-Json
    if ($failure.stage -ne $Stage -or (Test-Path (Join-Path $Arguments.Out 'workspace'))) { throw "Unexpected rejection stage: $Name" }
  }
  $checks.Add([ordered]@{name=$Name;expected_failure=$true;environment_restored=$true;location_restored=$true;stage=$Stage})
}
try {
  [IO.File]::WriteAllBytes((Join-Path $Out 'wrong-size.zip'),[byte[]]@(0))
  $bytes = [IO.File]::ReadAllBytes($UpstreamArchive)
  $bytes[128] = $bytes[128] -bxor 1
  [IO.File]::WriteAllBytes((Join-Path $Out 'wrong-hash.zip'),$bytes)
  foreach ($state in @('present','absent','empty')) {
    foreach ($name in $names) {
      switch ($state) {
        present { Set-ProcessValue $name ("control-$name") }
        absent { Set-ProcessValue $name $null }
        empty { Set-ProcessValue $name '' }
      }
      $value = [Environment]::GetEnvironmentVariable($name,'Process')
      if (($state -eq 'absent' -and $null -ne $value) -or ($state -eq 'empty' -and ($null -eq $value -or $value -cne ''))) { throw 'Control environment setup failed' }
    }
    Reject "clean-$state" 'verify-clean.ps1' @{Out=(Join-Path $Out "clean-$state");Ref='missing-script-controls-ref';WorkspaceTemp=$true} 'export-commit'
    Reject "sqlite-$state" 'verify-sqlite.ps1' @{Out=(Join-Path $Out "sqlite-$state");UpstreamArchive=(Join-Path $Out 'wrong-size.zip');OfflineDependencySource=$OfflineDependencySource} 'upstream-archive'
  }
  foreach ($name in $names) { Set-ProcessValue $name $original[$name] }
  Reject 'sqlite-wrong-hash' 'verify-sqlite.ps1' @{Out=(Join-Path $Out 'sqlite-wrong-hash');UpstreamArchive=(Join-Path $Out 'wrong-hash.zip');OfflineDependencySource=$OfflineDependencySource} 'upstream-archive'
  $existing = Join-Path $Out 'existing'
  New-Item -ItemType Directory -Path $existing | Out-Null
  'preserve evidence' | Set-Content (Join-Path $existing 'marker.txt')
  $markerHash = (Get-FileHash (Join-Path $existing 'marker.txt')).Hash
  Reject 'sqlite-existing-output' 'verify-sqlite.ps1' @{Out=$existing;UpstreamArchive=$UpstreamArchive;OfflineDependencySource=$OfflineDependencySource} ''
  Reject 'clean-existing-output' 'verify-clean.ps1' @{Out=$existing;WorkspaceTemp=$true} ''
  if ((Get-FileHash (Join-Path $existing 'marker.txt')).Hash -ne $markerHash -or @(Get-ChildItem $existing -Force).Count -ne 1) { throw 'Existing evidence changed' }
  if ((Get-FileHash $UpstreamArchive).Hash -ne $lock.archive_sha256) { throw 'Original archive changed' }
  [ordered]@{state='passed';checks=$checks.ToArray();original_archive_preserved=$true;environment_states=@('present','absent','empty');source_not_extracted_on_archive_rejection=$true;existing_evidence_preserved=$true;drivers=@('verify-clean.ps1','verify-sqlite.ps1') | ForEach-Object {@{path="scripts/$_";sha256=(Get-FileHash (Join-Path $project "scripts/$_")).Hash}}} |
    ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'verification.json')
  Write-Host "Script rejection and environment controls passed: $($checks.Count)."
  # Expected native failures are evidence, not this successful script's status.
  $global:LASTEXITCODE = 0
} finally {
  foreach ($name in $names) { Set-ProcessValue $name $original[$name] }
  Set-Location -LiteralPath $originalLocation
}
