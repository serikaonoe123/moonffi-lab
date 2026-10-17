function Assert-ToolchainIdentityLock($Lock) {
  $names = @($Lock.components.PSObject.Properties.Name | Sort-Object)
  if (($names -join ',') -ne 'moon,moonc,moonrun') { throw 'Toolchain lock must name moon, moonc and moonrun exactly once' }
  foreach ($name in $names) {
    if ([string]::IsNullOrWhiteSpace($Lock.components.$name) -or $Lock.binary_sha256.$name -notmatch '^[0-9A-Fa-f]{64}$') { throw "Missing version or binary SHA256 pin: $name" }
  }
  if ([string]::IsNullOrWhiteSpace($Lock.core_version) -or $Lock.core_source_identity.files -le 0 -or $Lock.core_source_identity.sha256 -notmatch '^[0-9A-Fa-f]{64}$') { throw 'Missing core version or source identity pin' }
}

function Get-CoreSourceIdentity([string]$Directory) {
  $root = (Resolve-Path -LiteralPath $Directory).Path.TrimEnd('\','/')
  $files = @{}
  foreach ($file in (Get-ChildItem -LiteralPath $root -Recurse -File -Force)) {
    $relative = $file.FullName.Substring($root.Length + 1).Replace('\','/')
    # Bundling creates _build; dependency caches are not standard-library source.
    if ($relative -match '^(_build|\.mooncakes)/') { continue }
    $files[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  }
  $paths = [string[]]@($files.Keys)
  [Array]::Sort($paths, [StringComparer]::Ordinal)
  $text = [Text.StringBuilder]::new()
  foreach ($path in $paths) { [void]$text.Append($path).Append("`t").Append($files[$path]).Append("`n") }
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try { $digest = [BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($text.ToString()))).Replace('-','') }
  finally { $algorithm.Dispose() }
  [ordered]@{ files=$paths.Count; sha256=$digest; algorithm='ordinal paths, path TAB uppercase file SHA256 LF, UTF-8; exclude root _build/.mooncakes' }
}

function Assert-ToolchainZipLayout([string]$Archive, [string]$Destination) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $root = [IO.Path]::GetFullPath($Destination).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
  $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
  try {
    foreach ($entry in $zip.Entries) {
      $name = $entry.FullName.Replace('\','/')
      if ([string]::IsNullOrWhiteSpace($name) -or $name.StartsWith('/') -or $name.Contains(':') -or '..' -in ($name -split '/')) {
        throw "Unsafe archive path: $name"
      }
      $target = [IO.Path]::GetFullPath((Join-Path $Destination $name))
      if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not $seen.Add($target.TrimEnd('\','/'))) {
        throw "Archive path escapes destination or is duplicated: $name"
      }
      if ((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw "Archive symbolic link is unsupported: $name" }
    }
  } finally { $zip.Dispose() }
}
