#requires -Version 7.0
param([string]$Ref = 'HEAD', [string]$Out = '', [string]$ScopeFile = 'docs/releases/v0.1.0-scope.json')
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
  $stage = 'select-scope'
  Require ($ScopeFile -cin @('docs/releases/v0.1.0-scope.json','docs/releases/v0.1.0-rc.2-scope.json')) 'Unsupported release scope path'
  $rc2 = $ScopeFile -ceq 'docs/releases/v0.1.0-rc.2-scope.json'
  $stage = 'resolve-commit'
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
      if ($path -in @('moon.mod','toolchain.json','toolchain-linux.json',$ScopeFile,'docs/evidence/github-ci-39248905440.json','docs/evidence/main-toolchain-acceptance-20261024.json')) {
        $contents[$path] = [Text.UTF8Encoding]::new($false,$true).GetString($bytes)
      }
    }
  } finally { $archive.Dispose() }
  Require ($files.Count -eq $tracked.Count) 'Source archive omitted tracked files'
  $stage = 'scope-and-evidence'
  Require ($contents.ContainsKey($ScopeFile)) 'Commit has no frozen release scope'
  $scope = $contents[$ScopeFile] | ConvertFrom-Json
  Require ($scope.schema -eq 1 -and $scope.version -ceq '0.1.0' -and $scope.status -ceq 'experimental-source-candidate') 'Unsupported release scope'
  Require ($contents['moon.mod'] -match '(?m)^version\s*=\s*"0\.1\.0"\s*$' -and $contents['moon.mod'] -match '(?m)^name\s*=\s*"serikaonoe123/moonffi-lab"\s*$') 'Module identity does not match release scope'
  foreach ($path in $scope.required_notices) { Require ($tracked.ContainsKey($path)) "Required notice missing: $path" }
  $preparationOnlyPaths = @('scripts/prepare-release.ps1','scripts/verify-release-preparation.ps1')
  if ($rc2) {
    $anchor = '2df35d5b26d2d139e83db41916032b8bd8d4e2c7'
    $baselineCommit = 'f464479107ea46369846a41dde090d25b28426d6'
    $evidencePath = 'docs/evidence/main-toolchain-acceptance-20261024.json'
    Require ($scope.release_tag -ceq 'v0.1.0-rc.2' -and $scope.baseline_tested_commit -ceq $baselineCommit -and
      $scope.evidence_anchor_commit -ceq $anchor -and $scope.baseline_evidence -ceq $evidencePath -and $contents.ContainsKey($evidencePath)) 'Unsupported rc.2 baseline'
    [void](Git -Arguments @('merge-base','--is-ancestor',$anchor,$commit))
    $evidenceBlob = (Git -Arguments @('rev-parse',"${anchor}:$evidencePath")).Trim()
    Require ($tracked[$evidencePath] -ceq $evidenceBlob) 'Recorded baseline evidence differs from the reviewed anchor'
    $baseline = $contents[$evidencePath] | ConvertFrom-Json
    Require ($baseline.state -ceq 'passed' -and $baseline.tested_commit -ceq $baselineCommit -and
      $baseline.windows.state -ceq 'passed' -and $baseline.linux.state -ceq 'passed' -and
      $baseline.windows.tested_commit -ceq $baselineCommit -and $baseline.linux.tested_commit -ceq $baselineCommit) 'Cross-platform baseline did not pass'
    Require ($baseline.windows.jobs.Count -eq 7 -and @($baseline.windows.jobs | Where-Object conclusion -ne 'success').Count -eq 0) 'Baseline Windows jobs incomplete'
    Require ((@($scope.required_suites | Sort-Object) -join ',') -ceq 'asan,behavior,benchmark,generation,native-errors,sdk,sqlite' -and
      (@($scope.required_linux_suites | Sort-Object) -join ',') -ceq 'native-errors,ordinary') 'Release suite list changed'
    Require ($baseline.windows.artifacts.Count -eq 7 -and $baseline.linux.artifacts.Count -eq 1) 'Baseline artifact coverage incomplete'
    foreach ($artifact in @($baseline.windows.artifacts) + @($baseline.linux.artifacts)) {
      Require ($artifact.archive_verified -eq $true -and $artifact.bytes -gt 0 -and $artifact.digest -cmatch '^sha256:[a-f0-9]{64}$') 'Unverified baseline artifact'
    }
    foreach ($path in @('toolchain.json','toolchain-linux.json')) {
      $expectedBlob = (Git -Arguments @('rev-parse',"${baselineCommit}:$path")).Trim()
      Require ($tracked[$path] -ceq $expectedBlob) "Toolchain content differs from the accepted baseline: $path"
    }
    $oldScope = (Git -Arguments @('show',"${anchor}:docs/releases/v0.1.0-scope.json")) | ConvertFrom-Json
    Require ((@($scope.required_notices | Sort-Object) -join ',') -ceq (@($oldScope.required_notices | Sort-Object) -join ',')) 'Required source notices changed'
    foreach ($path in $scope.required_notices) {
      $expectedBlob = (Git -Arguments @('rev-parse',"${baselineCommit}:$path")).Trim()
      Require ($tracked[$path] -ceq $expectedBlob) "Required notice content differs: $path"
    }
    Require ((@($scope.pending | Sort-Object) -join ',') -ceq 'candidate-hosted-acceptance,explicit-publication-approval,independent-user-reproduction') 'Candidate pending work must remain explicit'
    $baselineRuns = @($baseline.windows.run_url,$baseline.linux.run_url)
    $preparationOnlyPaths += @('scripts/test_release_rc2.py','.github/workflows/release-candidate.yml')
  } else {
    Require ($scope.baseline_evidence -ceq 'docs/evidence/github-ci-39248905440.json' -and $contents.ContainsKey($scope.baseline_evidence)) 'Unsupported baseline evidence'
    $baseline = $contents[$scope.baseline_evidence] | ConvertFrom-Json
    Require ($baseline.conclusion -eq 'success' -and $baseline.tested_commit -ceq $scope.baseline_tested_commit) 'Baseline did not pass'
    Require ($baseline.jobs.Count -eq 6 -and @($baseline.jobs | Where-Object conclusion -ne 'success').Count -eq 0) 'Baseline jobs incomplete'
    Require ((@($scope.required_suites | Sort-Object) -join ',') -ceq 'asan,behavior,benchmark,generation,sdk,sqlite') 'Release suite list changed'
    $baselineRuns = $baseline.run_url
  }
  [void](Git -Arguments @('merge-base','--is-ancestor',$baseline.tested_commit,$commit))
  $changed = @((Git -Arguments @('diff','--name-only','-z',$baseline.tested_commit,$commit)).Split([char]0,[StringSplitOptions]::RemoveEmptyEntries))
  if ($rc2) {
    $runtimeChanges = @($changed | Where-Object {
      $_ -notin $preparationOnlyPaths -and $_ -match '^(core/|runner/|fixtures/|cmd/|vendor/|examples/|scripts/|\.github/|moon\.mod$|toolchain(-linux)?\.json$|\.gitattributes$|\.gitignore$)'
    })
  } else {
    $runtimeChanges = @($changed | Where-Object {
      $_ -notmatch '\.md$' -and ($_ -match '^(core/|runner/|fixtures/|cmd/|vendor/|examples/|moon\.mod$|toolchain\.json$)' -or
        ($_ -like 'scripts/*' -and $_ -notin @('scripts/prepare-release.ps1','scripts/verify-release-preparation.ps1')))
    })
  }
  Require ($runtimeChanges.Count -eq 0) 'Runtime or validation scripts differ from the declared CI baseline; update evidence before preparing'
  $files.ToArray() | Sort-Object path | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Out 'source-manifest.json') -Encoding utf8
  [IO.File]::WriteAllText((Join-Path $Out 'scope.json'),$contents[$ScopeFile],[Text.UTF8Encoding]::new($false))
  [ordered]@{
    state='prepared-not-published';source_commit=$commit;source_tree=$tree;version=$scope.version
    archive='source.zip';archive_sha256=(Get-FileHash $archivePath).Hash;archive_bytes=(Get-Item $archivePath).Length
    source_files=$files.Count;all_git_blobs_matched=$true;source_manifest_sha256=(Get-FileHash (Join-Path $Out 'source-manifest.json')).Hash
    source_scope_sha256=(@($files | Where-Object path -eq $ScopeFile)[0]).sha256
    preparer_sha256=(Get-FileHash $PSCommandPath).Hash;baseline_tested_commit=$baseline.tested_commit;baseline_run=$baselineRuns
    runtime_diff_from_baseline=$runtimeChanges;other_changed_paths=$changed;baseline_is_candidate_ci=($baseline.tested_commit -eq $commit)
    scope_file=$ScopeFile;release_tag=$(if ($rc2) {$scope.release_tag} else {'v0.1.0-rc.1'})
    preparation_only_changed_paths=@($changed | Where-Object { $_ -in $preparationOnlyPaths })
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
