#requires -Version 7.0
param([string]$Ref = 'HEAD', [string]$Out = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$project = Split-Path -Parent $PSScriptRoot
if (-not $Out) { $Out = Join-Path $project ('results/release-candidate-' + [guid]::NewGuid().ToString('N')) }
$Out = [IO.Path]::GetFullPath($Out)
if (Test-Path -LiteralPath $Out) { throw 'Candidate output must be new' }
New-Item -ItemType Directory -Path $Out | Out-Null
$stage = 'resolve-commit'
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Git([string[]]$Arguments) {
  $start = [Diagnostics.ProcessStartInfo]::new('git')
  $start.WorkingDirectory = $project
  $start.UseShellExecute = $false
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::Start($start)
  try {
    $output = $process.StandardOutput.ReadToEnd()
    $errorText = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    Require ($process.ExitCode -eq 0) "Git command failed: $errorText"
    return $output
  } finally { $process.Dispose() }
}
try {
  $commit = (Git -Arguments @('rev-parse','--verify','--end-of-options',"$Ref^{commit}")).Trim()
  $tree = (Git -Arguments @('rev-parse',"$commit^{tree}")).Trim()
  $tracked = @{}
  foreach ($entry in (Git -Arguments @('ls-tree','-r','-z',$commit)).Split([char]0,[StringSplitOptions]::RemoveEmptyEntries)) {
    Require ($entry -match '^100644 blob ([a-f0-9]{40})\t(.+)$') 'Only ordinary source files are supported'
    $tracked[$Matches[2]] = $Matches[1]
  }
  Require ($tracked.Count -gt 0) 'Empty source commit'
  $stage = 'archive-source'
  $archivePath = Join-Path $Out 'source.zip'
  # Keep committed bytes on Windows too; do not change repository/global config.
  [void](Git -Arguments @('-c','core.autocrlf=false','-c','core.eol=lf','archive','--format=zip',"--output=$archivePath",$commit))
  $files = [Collections.Generic.List[object]]::new()
  $contents = @{}
  $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
  try {
    foreach ($entry in $archive.Entries) {
      $path = $entry.FullName
      Require (-not [IO.Path]::IsPathRooted($path) -and $path -notmatch '(^|/)(\.|\.\.|\.git|\.mooncakes|_build|results)(/|$)' -and $path -notmatch '[\\:]') 'Unexpected source archive path'
      if ($path.EndsWith('/')) { continue }
      Require ($seen.Add($path) -and $tracked.ContainsKey($path)) 'Unexpected or duplicate archive entry'
      Require ([IO.Path]::GetExtension($path) -notin @('.exe','.dll','.obj','.pdb','.ilk','.lib','.o','.a','.so','.zip','.tar','.gz','.mi','.core')) 'Source archive contains a binary or dependency archive'
      $stream = $entry.Open()
      $memory = [IO.MemoryStream]::new()
      try { $stream.CopyTo($memory); $bytes = $memory.ToArray() }
      finally { $stream.Dispose(); $memory.Dispose() }
      $header = [Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
      $blob = [Convert]::ToHexString([Security.Cryptography.SHA1]::HashData([byte[]]($header + $bytes))).ToLowerInvariant()
      Require ($blob -ceq $tracked[$path]) "Source differs from Git blob: $path"
      $files.Add([ordered]@{path=$path;bytes=$bytes.Length;git_blob=$blob;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))})
      if ($path -in @('moon.mod','toolchain.json','docs/releases/v0.1.0-scope.json','docs/evidence/github-ci-39248905440.json')) {
        $contents[$path] = [Text.UTF8Encoding]::new($false,$true).GetString($bytes)
      }
    }
  } finally { $archive.Dispose() }
  Require ($files.Count -eq $tracked.Count) 'Source archive omitted tracked files'
  $stage = 'scope-and-evidence'
  Require ($contents.ContainsKey('docs/releases/v0.1.0-scope.json')) 'Commit has no frozen release scope'
  $scope = $contents['docs/releases/v0.1.0-scope.json'] | ConvertFrom-Json
  Require ($scope.schema -eq 1 -and $scope.version -ceq '0.1.0' -and $scope.status -ceq 'experimental-source-candidate') 'Unsupported release scope'
  Require ($contents['moon.mod'] -match '(?m)^version\s*=\s*"0\.1\.0"\s*$' -and $contents['moon.mod'] -match '(?m)^name\s*=\s*"serikaonoe123/moonffi-lab"\s*$') 'Module identity does not match release scope'
  foreach ($path in $scope.required_notices) { Require ($tracked.ContainsKey($path)) "Required notice missing: $path" }
  Require ($scope.baseline_evidence -ceq 'docs/evidence/github-ci-39248905440.json' -and $contents.ContainsKey($scope.baseline_evidence)) 'Unsupported baseline evidence'
  $baseline = $contents[$scope.baseline_evidence] | ConvertFrom-Json
  Require ($baseline.conclusion -eq 'success' -and $baseline.tested_commit -ceq $scope.baseline_tested_commit) 'Baseline did not pass'
  Require ($baseline.jobs.Count -eq 6 -and @($baseline.jobs | Where-Object conclusion -ne 'success').Count -eq 0) 'Baseline jobs incomplete'
  Require ((@($scope.required_suites | Sort-Object) -join ',') -ceq 'asan,behavior,benchmark,generation,sdk,sqlite') 'Release suite list changed'
  [void](Git -Arguments @('merge-base','--is-ancestor',$baseline.tested_commit,$commit))
  $changed = @((Git -Arguments @('diff','--name-only','-z',$baseline.tested_commit,$commit)).Split([char]0,[StringSplitOptions]::RemoveEmptyEntries))
  $runtimeChanges = @($changed | Where-Object {
    $_ -notmatch '\.md$' -and ($_ -match '^(core/|runner/|fixtures/|cmd/|vendor/|examples/|moon\.mod$|toolchain\.json$)' -or
      ($_ -like 'scripts/*' -and $_ -notin @('scripts/prepare-release.ps1','scripts/verify-release-preparation.ps1')))
  })
  Require ($runtimeChanges.Count -eq 0) 'Runtime or validation scripts differ from the declared CI baseline; update evidence before preparing'
  $files.ToArray() | Sort-Object path | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Out 'source-manifest.json') -Encoding utf8
  [IO.File]::WriteAllText((Join-Path $Out 'scope.json'),$contents['docs/releases/v0.1.0-scope.json'],[Text.UTF8Encoding]::new($false))
  [ordered]@{
    state='prepared-not-published';source_commit=$commit;source_tree=$tree;version=$scope.version
    archive='source.zip';archive_sha256=(Get-FileHash $archivePath).Hash;archive_bytes=(Get-Item $archivePath).Length
    source_files=$files.Count;all_git_blobs_matched=$true;source_manifest_sha256=(Get-FileHash (Join-Path $Out 'source-manifest.json')).Hash
    source_scope_sha256=(@($files | Where-Object path -eq 'docs/releases/v0.1.0-scope.json')[0]).sha256
    preparer_sha256=(Get-FileHash $PSCommandPath).Hash;baseline_tested_commit=$baseline.tested_commit;baseline_run=$baseline.run_url
    runtime_diff_from_baseline=$runtimeChanges;other_changed_paths=$changed;baseline_is_candidate_ci=($baseline.tested_commit -eq $commit)
    required_notices=$scope.required_notices;toolchain=($contents['toolchain.json'] | ConvertFrom-Json).components
    archive_includes='Tracked project sources and existing third-party source notices only. No toolchain, async cache, downloaded SQLite archive or build outputs.'
    pending=$scope.pending;publish_ready=$false;registry_published=$false;release_published=$false
    scope='Local source preparation only; no builds, tests, downloads, tags, registry publication, GitHub release or upstream communication performed.'
  } | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $Out 'candidate.json') -Encoding utf8
  Write-Host "Source candidate prepared locally. Not published. Evidence: $Out"
  $global:LASTEXITCODE = 0
} catch {
  [ordered]@{state='failed';stage=$stage;error=$_.Exception.Message} | ConvertTo-Json | Set-Content (Join-Path $Out 'failure.json') -Encoding utf8
  throw
}
