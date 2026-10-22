# Workspace members place outputs under module-qualified directories.
function Find-LabExecutable([string]$Root, [string]$Name) {
  $found = @(Get-ChildItem -LiteralPath (Join-Path $Root '_build/native/debug/build') -Recurse -File |
    Where-Object { $_.Name -eq $Name -or $_.Name -eq "$Name.exe" })
  if ($found.Count -ne 1) { throw "Executable discovery ambiguous: $Name ($($found.Count) matches)" }
  return $found[0].FullName
}
