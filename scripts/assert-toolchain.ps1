param([string]$Out = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
$expected = Get-Content -LiteralPath (Join-Path $projectRoot 'toolchain.json') -Raw | ConvertFrom-Json
$versionText = & moon version --all --json
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect MoonBit toolchain' }
$actual = ($versionText | ConvertFrom-Json).items
$mismatches = [System.Collections.Generic.List[string]]::new()
$binaries = [System.Collections.Generic.List[object]]::new()
foreach ($entry in $expected.components.PSObject.Properties) {
  $observed = @($actual | Where-Object name -eq $entry.Name)
  if ($observed.Count -ne 1 -or $observed[0].version -ne $entry.Value) {
    $mismatches.Add("$($entry.Name): expected '$($entry.Value)', got '$($observed.version -join ', ')'")
  }
  $binaryPath = (Get-Command $entry.Name -CommandType Application -ErrorAction Stop).Source
  $binaries.Add([ordered]@{ name = $entry.Name; path = $binaryPath; sha256 = (Get-FileHash -LiteralPath $binaryPath).Hash })
}
$report = [ordered]@{
  state = $(if ($mismatches.Count) { 'failed' } else { 'passed' })
  expected = $expected.components; actual = $actual; binaries = $binaries.ToArray()
  mismatches = $mismatches.ToArray()
}
if ($Out) {
  if (Test-Path -LiteralPath $Out) { throw "Toolchain report already exists: $Out" }
  $report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $Out -Encoding utf8
}
if ($mismatches.Count) { throw ($mismatches -join "`n") }
Write-Host 'MoonBit toolchain matches toolchain.json'
