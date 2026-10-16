param([string]$Out = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Out) { $Out = Join-Path $projectRoot ('results/asan-' + [guid]::NewGuid().ToString('N')) }
$Out = [System.IO.Path]::GetFullPath($Out)
if (Test-Path -LiteralPath $Out) { throw "Output must be new: $Out" }
New-Item -ItemType Directory -Path $Out | Out-Null
$savedLocation = Get-Location
$savedPath = $env:PATH
$savedAsanOptions = $env:ASAN_OPTIONS
$savedAsanDebugging = $env:ASAN_VCASAN_DEBUGGING
$stage = 'setup'

function Invoke-Checked([string]$Exe, [string[]]$ToolArgs, [int]$Expected, [string]$Log) {
  $lines = & $Exe @ToolArgs 2>&1
  $actual = $LASTEXITCODE
  $lines | Set-Content -LiteralPath $Log -Encoding utf8
  if ($actual -ne $Expected) { throw "$Exe exited $actual, expected $Expected. See $Log" }
}
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

try {
  Require ($env:OS -eq 'Windows_NT') 'This ASan profile requires Windows x64 / MSVC'
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
  Require (Test-Path -LiteralPath $vswhere) 'MSVC discovery tool vswhere.exe is unavailable'
  $asanDir = $null
  foreach ($installation in (& $vswhere -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)) {
    foreach ($version in (Get-ChildItem -LiteralPath (Join-Path $installation 'VC/Tools/MSVC') -Directory | Sort-Object Name -Descending)) {
      $candidate = Join-Path $version.FullName 'bin/Hostx64/x64'
      if (Test-Path -LiteralPath (Join-Path $candidate 'clang_rt.asan_dynamic-x86_64.dll')) { $asanDir = $candidate; break }
    }
    if ($asanDir) { break }
  }
  Require ([bool]$asanDir) 'ASan runtime not installed; no memory-detection pass can be reported'
  Require (Test-Path -LiteralPath (Join-Path $projectRoot '.mooncakes/moonbitlang/async/moon.mod')) 'Prepare the pinned dependency with moon update before running this profile'

  # Copy explicit source directories, never build outputs, evidence or Git data.
  $stage = 'prepare-isolated-source'
  $workspace = Join-Path $Out 'workspace'
  New-Item -ItemType Directory -Path $workspace | Out-Null
  foreach ($directory in @('core','runner','fixtures','cmd','vendor')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $directory) -Destination $workspace -Recurse
  }
  Copy-Item -LiteralPath (Join-Path $projectRoot 'moon.mod') -Destination $workspace
  $sourceManifest = @(Get-ChildItem -LiteralPath $workspace -Recurse -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = $_.FullName.Substring($workspace.Length + 1).Replace('\','/'); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
  })
  $sourceManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Out 'source-manifest.json') -Encoding utf8
  Copy-Item -LiteralPath (Join-Path $projectRoot '.mooncakes') -Destination $workspace -Recurse

  # Only the isolated copy changes. Actual detector effectiveness is checked by
  # the canary below, rather than trusting this build marker or linked symbols.
  $markerPath = Join-Path $workspace 'fixtures/buffer/asan_profile.mbt'
  $marker = [System.IO.File]::ReadAllText($markerPath)
  Require ($marker.Contains('  false')) 'Unexpected ASan build marker source'
  [System.IO.File]::WriteAllText($markerPath, $marker.Replace('  false', '  true'))
  $bufferConfig = Join-Path $workspace 'fixtures/buffer/moon.pkg'
  $configuration = [System.IO.File]::ReadAllText($bufferConfig)
  $configuration = $configuration.Replace('"native-stub": ["buffer.c"],', '"native-stub": ["buffer.c"], link: { "native": { "stub-cc-flags": "/fsanitize=address", }, },')
  Require ($configuration.Contains('/fsanitize=address')) 'Could not instrument Buffer translation unit'
  [System.IO.File]::WriteAllText($bufferConfig, $configuration)
  $eigenConfig = Join-Path $workspace 'vendor/eigen-binding/moon.pkg'
  $configuration = [System.IO.File]::ReadAllText($eigenConfig)
  Require ($configuration.Contains('/EHsc /utf-8 /bigobj /O1')) 'Unexpected Eigen snapshot configuration'
  [System.IO.File]::WriteAllText($eigenConfig, $configuration.Replace('/EHsc /utf-8 /bigobj /O1', '/EHsc /utf-8 /bigobj /O1 /fsanitize=address'))
  foreach ($command in @('buffer-lab','eigen-lab')) {
    $commandConfig = Join-Path $workspace "cmd/$command/moon.pkg"
    $configuration = [System.IO.File]::ReadAllText($commandConfig)
    $configuration = $configuration.Replace('options("is-main": true)', 'options("is-main": true, link: { "native": { "cc-link-flags": "/DEBUG", }, })')
    Require ($configuration.Contains('/DEBUG')) 'Could not retain linker debugging information'
    [System.IO.File]::WriteAllText($commandConfig, $configuration)
  }

  $env:PATH = $asanDir + ';' + $savedPath
  $env:ASAN_OPTIONS = 'halt_on_error=1:abort_on_error=1'
  $env:ASAN_VCASAN_DEBUGGING = '0'
  Set-Location -LiteralPath $workspace
  $stage = 'build'
  Invoke-Checked 'moon' @('build','--target','native','--frozen','cmd/buffer-lab','cmd/eigen-lab') 0 (Join-Path $Out 'build.log')
  $buffer = Join-Path $workspace '_build/native/debug/build/cmd/buffer-lab/buffer-lab.exe'
  $eigen = Join-Path $workspace '_build/native/debug/build/cmd/eigen-lab/eigen-lab.exe'

  $stage = 'positive-canary'
  $canaryDir = Join-Path $Out 'canary'
  Invoke-Checked $buffer @('run','--mode','asan-canary','--cases','3','--timeout-ms','10000','--out',$canaryDir) 1 (Join-Path $Out 'canary.log')
  $reports = @(Read-Json (Join-Path $canaryDir 'summary.json'))
  Require ($reports.Count -eq 3 -and @($reports | Where-Object outcome -ne 'MemoryError').Count -eq 0) 'Canary did not produce three real sanitizer reports'
  foreach ($index in 1..3) {
    $diagnostic = Get-Content -LiteralPath (Join-Path $canaryDir "case-$index/stderr.log") -Raw
    Require ($diagnostic.Contains('ERROR: AddressSanitizer: heap-buffer-overflow') -and $diagnostic.Contains('SUMMARY: AddressSanitizer: heap-buffer-overflow')) 'Canary diagnostic missing expected category'
  }
  $stage = 'correct-controls'
  foreach ($kind in @('buffer','eigen')) {
    $exe = if ($kind -eq 'buffer') { $buffer } else { $eigen }
    $destination = Join-Path $Out "$kind-correct"
    Invoke-Checked $exe @('run','--cases','10','--timeout-ms','10000','--out',$destination) 0 (Join-Path $Out "$kind-correct.log")
    $controls = @(Read-Json (Join-Path $destination 'summary.json'))
    Require ($controls.Count -eq 10 -and @($controls | Where-Object outcome -ne 'Pass').Count -eq 0) "$kind control did not pass with ASan runtime active"
  }
  $stage = 'memory-reduction-boundary'
  $shrinkDir = Join-Path $Out 'canary-shrink'
  Invoke-Checked $buffer @('shrink',(Join-Path $canaryDir 'case-1/case.json'),'--timeout-ms','10000','--out',$shrinkDir) 3 (Join-Path $Out 'canary-shrink.log')
  $reduction = Read-Json (Join-Path $shrinkDir 'reduction.json')
  Require (-not $reduction.confirmed -and $reduction.stop_reason -eq 'unsupported_outcome' -and $reduction.baseline.outcome -eq 'MemoryError' -and $reduction.executions -eq 1) 'Memory category was incorrectly used as a root-cause fingerprint'

  $stage = 'complete'
  [ordered]@{
    state = 'passed'; completed_at = [DateTimeOffset]::UtcNow.ToString('o')
    profile = 'windows-msvc-asan-stubs'; toolchain = @(& moon version --all)
    runtime = Join-Path $asanDir 'clang_rt.asan_dynamic-x86_64.dll'
    runtime_sha256 = (Get-FileHash -LiteralPath (Join-Path $asanDir 'clang_rt.asan_dynamic-x86_64.dll')).Hash
    canary_runs = 3; canary_outcome = 'MemoryError'; category = 'heap-buffer-overflow'
    correct_buffer_runs = 10; correct_eigen_runs = 10
    instrumented_translation_units = @('fixtures/buffer/buffer.c','vendor/eigen-binding/eigen_shim.cpp (including instantiated Eigen headers)')
    not_instrumented = @('MoonBit-generated C','MoonBit runtime','async dependency C stubs','other prebuilt/system libraries')
    dependency_source = 'local pinned .mooncakes source cache; no build outputs copied'
    buffer_sha256 = (Get-FileHash -LiteralPath $buffer).Hash
    eigen_sha256 = (Get-FileHash -LiteralPath $eigen).Hash
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Out 'verification.json') -Encoding utf8
  Write-Host "ASan verification passed. Evidence: $Out"
} catch {
  [ordered]@{ state = 'failed'; stage = $stage; error = $_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Out 'failure.json') -Encoding utf8
  throw
} finally {
  $env:PATH = $savedPath
  $env:ASAN_OPTIONS = $savedAsanOptions
  $env:ASAN_VCASAN_DEBUGGING = $savedAsanDebugging
  Set-Location -LiteralPath $savedLocation
}
