param([string]$Out = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$project = Split-Path -Parent $PSScriptRoot
if (-not $Out) { $Out = Join-Path $project ('results/native-errors-' + [guid]::NewGuid().ToString('N')) }
$Out = [IO.Path]::GetFullPath($Out)
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
New-Item -ItemType Directory -Path $Out | Out-Null
$savedLocation = Get-Location
$saved = @{}
foreach ($name in @('PATH','MOON_HOME','TEMP','TMP','ASAN_OPTIONS','ASAN_VCASAN_DEBUGGING')) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$stage = 'setup'
function Require([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message } }
function Run([string]$Exe, [string[]]$Arguments, [string]$Log) {
  & $Exe @Arguments *> $Log
  if ($LASTEXITCODE -ne 0) { throw "$Exe exited $LASTEXITCODE; see $Log" }
}
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Prepare([string]$Workspace) {
  New-Item -ItemType Directory -Path "$Workspace/cmd", "$Workspace/fixtures" | Out-Null
  Copy-Item -LiteralPath (Join-Path $project 'moon.mod') -Destination $Workspace
  foreach ($name in @('core','runner','cmd/native-errors','fixtures/native-errors')) {
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $project $name) -Recurse -File -Force)) {
      $relative = $file.FullName.Substring($project.Length + 1)
      # Generated package interfaces and compiler outputs are not source inputs.
      if ($file.Name -eq 'pkg.generated.mbti' -or $relative -match '(^|[\\/])(_build|target|\.git|\.mooncakes)([\\/]|$)' -or $file.Extension -in @('.exe','.obj','.pdb','.ilk','.lib','.dll','.o','.a','.mi','.core')) { continue }
      $destination = Join-Path $Workspace $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
      Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
  }
  foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $project '.mooncakes/moonbitlang/async') -File -Recurse -Force)) {
    $dependencyRoot = Join-Path $project '.mooncakes/moonbitlang/async'
    $relative = $file.FullName.Substring($dependencyRoot.Length + 1)
    if ($file.Name -eq 'pkg.generated.mbti' -or $relative -match '(^|[\\/])(_build|target|\.git)([\\/]|$)' -or $file.Extension -in @('.exe','.obj','.pdb','.ilk','.lib','.dll','.o','.a','.mi','.core')) { continue }
    $destination = Join-Path "$Workspace/.mooncakes/moonbitlang/async" $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
  }
}
try {
  Require ($env:OS -eq 'Windows_NT') 'This profile requires Windows x64/MSVC; use verify-linux.py on Linux.'
  Set-Location -LiteralPath $project
  & (Join-Path $PSScriptRoot 'assert-toolchain.ps1') -Out (Join-Path $Out 'toolchain.json')
  $verifiedToolchain = (Read-Json (Join-Path $Out 'toolchain.json')).toolchain_root
  $env:MOON_HOME = $verifiedToolchain
  $config = Read-Json (Join-Path $project 'toolchain.json')
  $dependency = Get-Content -LiteralPath (Join-Path $project '.mooncakes/moonbitlang/async/moon.mod') -Raw
  Require ($dependency -match ('(?m)^version\s*=\s*"' + [regex]::Escape($config.async_version) + '"\s*$')) 'Pinned async sources required'
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
  $runtimeDirectory = $null
  foreach ($installation in (& $vswhere -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)) {
    foreach ($version in (Get-ChildItem -LiteralPath (Join-Path $installation 'VC/Tools/MSVC') -Directory | Sort-Object Name -Descending)) {
      $candidate = Join-Path $version.FullName 'bin/Hostx64/x64'
      if (Test-Path -LiteralPath (Join-Path $candidate 'clang_rt.asan_dynamic-x86_64.dll')) { $runtimeDirectory = $candidate; break }
    }
    if ($runtimeDirectory) { break }
  }
  Require ([bool]$runtimeDirectory) 'MSVC ASan runtime unavailable'
  New-Item -ItemType Directory -Path (Join-Path $Out 'temp') | Out-Null
  $env:TEMP = Join-Path $Out 'temp'; $env:TMP = $env:TEMP
  $env:PATH = (Join-Path $verifiedToolchain 'bin') + ';' + $runtimeDirectory + ';' + $saved['PATH']
  $env:ASAN_OPTIONS = 'halt_on_error=1:abort_on_error=1'
  $env:ASAN_VCASAN_DEBUGGING = '0'
  $profiles = @()
  foreach ($mode in @('crash','asan')) {
    $stage = "prepare/$mode"
    $profile = Join-Path $Out $mode
    $workspace = Join-Path $profile 'workspace'
    Prepare $workspace
    # Explicit workspace membership resolves async source without a registry index.
    'members = [".", ".mooncakes/moonbitlang/async"]' | Set-Content -LiteralPath (Join-Path $workspace 'moon.work') -Encoding utf8
    $dependencyManifest = @(Get-ChildItem -LiteralPath (Join-Path $workspace '.mooncakes') -Recurse -File | Sort-Object FullName | ForEach-Object {
      [ordered]@{path=$_.FullName.Substring($workspace.Length + 1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
    })
    $dependencyManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $profile 'dependency-manifest.json') -Encoding utf8
    if ($mode -eq 'asan') {
      $path = Join-Path $workspace 'fixtures/native-errors/moon.pkg'
      $text = [IO.File]::ReadAllText($path).Replace('options("native-stub": ["faults.c"])', 'options("native-stub": ["faults.c"], link: { "native": { "stub-cc-flags": "/fsanitize=address", }, })')
      Require ($text.Contains('/fsanitize=address')) 'Cannot instrument owned fault fixture'
      [IO.File]::WriteAllText($path, $text)
      $path = Join-Path $workspace 'cmd/native-errors/moon.pkg'
      $text = [IO.File]::ReadAllText($path).Replace('options("is-main": true)', 'options("is-main": true, link: { "native": { "cc-link-flags": "/DEBUG", }, })')
      Require ($text.Contains('/DEBUG')) 'Cannot retain diagnostic symbols'
      [IO.File]::WriteAllText($path, $text)
    }
    $manifest = @(Get-ChildItem -LiteralPath $workspace -Recurse -File -Force | Where-Object { $_.Name -ne 'pkg.generated.mbti' -and $_.FullName -notlike "$workspace/.mooncakes/*" -and $_.FullName -notlike "$workspace\.mooncakes\*" } | Sort-Object FullName | ForEach-Object {
      [ordered]@{path=$_.FullName.Substring($workspace.Length + 1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
    })
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $profile 'source-manifest.json') -Encoding utf8
    Set-Location -LiteralPath $workspace
    $stage = "build/$mode"
    Run 'moon' @('tree','--json') (Join-Path $profile 'module-tree.json')
    $resolved = @((Read-Json (Join-Path $profile 'module-tree.json')).modules | Where-Object name -eq 'moonbitlang/async')
    Require ($resolved.Count -eq 1 -and $resolved[0].source.kind -eq 'local' -and $resolved[0].source.path -eq (Join-Path $workspace '.mooncakes/moonbitlang/async')) 'async must resolve to the copied local source'
    if ($mode -eq 'crash') {
      Run 'moon' @('check','--target','native','--deny-warn','--frozen') (Join-Path $profile 'check.log')
      Run 'moon' @('test','--target','native','--deny-warn','--frozen','-j','1','--package','serikaonoe123/moonffi-lab') (Join-Path $profile 'tests.log')
      Require ((Get-Content -LiteralPath (Join-Path $profile 'tests.log') -Raw).Contains('Total tests: 49, passed: 49, failed: 0.')) 'Focused native unit tests incomplete'
    }
    Run 'moon' @('build','--target','native','--deny-warn','--frozen','cmd/native-errors') (Join-Path $profile 'build.log')
    $executables = @(Get-ChildItem -LiteralPath (Join-Path $workspace '_build/native/debug/build') -Recurse -File -Filter native-errors.exe)
    Require ($executables.Count -eq 1) 'Native executable discovery ambiguous'
    $exe = $executables[0].FullName
    $before = (Get-FileHash -LiteralPath $exe).Hash
    $stage = "execute/$mode"
    Run $exe @('--self-check',$mode,(Join-Path $profile 'checks')) (Join-Path $profile 'checks.log')
    $checks = Read-Json (Join-Path $profile 'checks/verification.json')
    Require ($checks.state -eq 'passed' -and $checks.mode -eq $mode -and @($checks.checks | Where-Object strategy).Count -eq 3) 'Missing native checks'
    Require ($before -ceq (Get-FileHash -LiteralPath $exe).Hash) 'Executable changed during validation'
    foreach ($entry in $manifest) { Require ($entry.sha256 -ceq (Get-FileHash -LiteralPath (Join-Path $workspace $entry.path)).Hash) "Tested source changed during validation: $($entry.path)" }
    foreach ($entry in $dependencyManifest) { Require ($entry.sha256 -ceq (Get-FileHash -LiteralPath (Join-Path $workspace $entry.path)).Hash) "Dependency source changed: $($entry.path)" }
    $profiles += [ordered]@{mode=$mode;executable_sha256=$before;checks=$checks;instrumented=$(if ($mode -eq 'asan') {@('fixtures/native-errors/faults.c')} else {@()})}
    Set-Location -LiteralPath $project
  }
  $runtime = Join-Path $runtimeDirectory 'clang_rt.asan_dynamic-x86_64.dll'
  [ordered]@{state='passed';profiles=$profiles;runtime_sha256=(Get-FileHash -LiteralPath $runtime).Hash;driver_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash;scope='Owned intentional C faults only; source cache reused without build outputs. ASan instruments faults.c, not MoonBit C/runtime/dependencies. Signatures identify observed sites within an unchanged executable, not root cause or global minimum.'} | ConvertTo-Json -Depth 22 | Set-Content -LiteralPath (Join-Path $Out 'verification.json') -Encoding utf8
  Write-Host "Native crash and ASan reduction checks passed: $Out"
} catch {
  [ordered]@{state='failed';stage=$stage;error=$_.Exception.Message} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Out 'failure.json') -Encoding utf8
  throw
} finally {
  foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
  Set-Location -LiteralPath $savedLocation
}
