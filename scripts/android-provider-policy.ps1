function Assert-MortAndroidProviderPolicy {
  param([string]$ManifestText = '', [byte[]]$DexBytes)

  if ($ManifestText -match '(?i)(com\.google\.firebase\.|io\.flutter\.plugins\.firebase\.)') {
    throw 'AAB manifest contains a forbidden Firebase SDK or Flutter plugin.'
  }
  if ($null -eq $DexBytes) { return }
  if ($DexBytes.Length -lt 112 -or
      [Text.Encoding]::ASCII.GetString($DexBytes, 0, 4) -cne "dex`n") {
    throw 'AAB contains an unsupported or malformed DEX header.'
  }

  # Inspect defined classes, not arbitrary strings/references. Sentry can
  # reference optional integrations without shipping their SDK implementations.
  $stringIdsOffset = [BitConverter]::ToUInt32($DexBytes, 60)
  $typeIdsOffset = [BitConverter]::ToUInt32($DexBytes, 68)
  $classCount = [BitConverter]::ToUInt32($DexBytes, 96)
  $classDefsOffset = [BitConverter]::ToUInt32($DexBytes, 100)
  for ($i = 0; $i -lt $classCount; $i++) {
    $typeIndex = [BitConverter]::ToUInt32($DexBytes, $classDefsOffset + 32 * $i)
    $stringIndex = [BitConverter]::ToUInt32($DexBytes, $typeIdsOffset + 4 * $typeIndex)
    $cursor = [BitConverter]::ToUInt32($DexBytes, $stringIdsOffset + 4 * $stringIndex)
    # Skip the ULEB128 UTF-16 length preceding each DEX string.
    $lengthBytes = 0
    do {
      if ($cursor -ge $DexBytes.Length -or $lengthBytes -ge 5) {
        throw 'AAB contains a malformed DEX string.'
      }
      $lengthByte = $DexBytes[$cursor++]
      $lengthBytes++
    } while (($lengthByte -band 128) -ne 0)
    $start = $cursor
    while ($cursor -lt $DexBytes.Length -and $DexBytes[$cursor] -ne 0) { $cursor++ }
    if ($cursor -ge $DexBytes.Length) { throw 'AAB contains an unterminated DEX string.' }
    $descriptor = [Text.Encoding]::UTF8.GetString($DexBytes, $start, $cursor - $start)
    if ($descriptor -cmatch '^L(com/google/firebase/|io/flutter/plugins/firebase/)') {
      throw 'AAB defines a forbidden Firebase SDK or Flutter plugin class.'
    }
  }
}
