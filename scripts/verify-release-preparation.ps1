#requires -Version 7.0
param([string]$Out = '', [string]$Ref = 'HEAD', [string]$RejectRuntimeRef = '')
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
if (-not $Out) { $Out = Join-Path $project ('results/release-checks-' + [guid]::NewGuid().ToString('N')) }
$Out = [IO.Path]::GetFullPath($Out)
if (Test-Path -LiteralPath $Out) { throw 'Release controls output must be new' }
New-Item -ItemType Directory -Path $Out | Out-Null
$driver = Join-Path $PSScriptRoot 'prepare-release.ps1'
$checks = [Collections.Generic.List[object]]::new()
function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Rejected([string]$Name,[hashtable]$Arguments,[string]$Stage) {
  $caught = $false
  try { & $driver @Arguments *> (Join-Path $Out "$Name.log") }
  catch { $caught=$true; $_.Exception.Message | Add-Content (Join-Path $Out "$Name.log") }
  Require $caught "Control accepted: $Name"
  if ($Stage) {
    $failure = Get-Content (Join-Path $Arguments.Out 'failure.json') -Raw | ConvertFrom-Json
    Require ($failure.stage -ceq $Stage -and -not (Test-Path (Join-Path $Arguments.Out 'candidate.json'))) 'Wrong rejection stage'
  }
  $checks.Add([ordered]@{name=$Name;expected_failure=$true;stage=$Stage})
}
try {
  foreach ($label in @('a','b')) {
    & $driver -Ref $Ref -Out (Join-Path $Out $label) *> (Join-Path $Out "$label.log")
    Require ($LASTEXITCODE -eq 0) 'Successful preparation leaked failure exit status'
  }
  $first = Get-Content (Join-Path $Out 'a/candidate.json') -Raw | ConvertFrom-Json
  $second = Get-Content (Join-Path $Out 'b/candidate.json') -Raw | ConvertFrom-Json
  Require ($first.state -eq 'prepared-not-published' -and $first.all_git_blobs_matched -and $first.source_files -gt 0 -and -not $first.publish_ready -and -not $first.release_published) 'Incorrect candidate claims'
  Require ($first.source_commit -eq $second.source_commit -and $first.archive_sha256 -ceq $second.archive_sha256 -and $first.source_manifest_sha256 -ceq $second.source_manifest_sha256) 'Same commit did not produce identical source artifacts'
  $checks.Add([ordered]@{name='two-complete-source-archives';matched_git_blobs=$first.source_files;deterministic_zip=$true;deterministic_manifest=$true})
  $hash = (Get-FileHash (Join-Path $Out 'a/source.zip')).Hash
  Rejected 'existing-output' @{Out=(Join-Path $Out 'a')} ''
  Require ((Get-FileHash (Join-Path $Out 'a/source.zip')).Hash -ceq $hash) 'Existing source archive changed'
  Rejected 'missing-commit' @{Out=(Join-Path $Out 'missing');Ref='missing-release-controls-ref'} 'resolve-commit'
  Rejected 'missing-frozen-scope' @{Out=(Join-Path $Out 'old');Ref=$first.baseline_tested_commit} 'scope-and-evidence'
  if ($RejectRuntimeRef) {
    Rejected 'runtime-drift' @{Out=(Join-Path $Out 'runtime-drift');Ref=$RejectRuntimeRef} 'scope-and-evidence'
    $drift = Get-Content (Join-Path $Out 'runtime-drift/failure.json') -Raw | ConvertFrom-Json
    Require ($drift.error -like 'Runtime or validation scripts differ*') 'Runtime drift was rejected for the wrong reason'
  }
  [ordered]@{state='passed';source_commit=$first.source_commit;checks=$checks.ToArray();preparer_sha256=(Get-FileHash $driver).Hash;source_files_checked=$first.source_files;archive_sha256=$first.archive_sha256;published=$false} |
    ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'verification.json') -Encoding utf8
  Write-Host "Release preparation controls passed. Evidence: $Out"
  $global:LASTEXITCODE = 0
} catch {
  [ordered]@{state='failed';error=$_.Exception.Message} | ConvertTo-Json | Set-Content (Join-Path $Out 'failure.json') -Encoding utf8
  throw
}
