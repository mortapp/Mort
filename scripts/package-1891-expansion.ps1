$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$masterZip = Join-Path $root 'mort-1891-feature-expansion-master-clean.zip'
$webZip = Join-Path $root 'mort-web-1891-feature-expansion.zip'
$swiftZip = Join-Path $root 'mort-swiftui-1891-feature-expansion-clean.zip'

$excludedDirectoryNames = @(
  '.git', '.expo', '.dart_tool', '.temp', '.supabase-cli-config',
  'node_modules', 'build', 'dist', 'logs', 'backups', 'outputs',
  'coverage', 'DerivedData', 'Pods', 'ephemeral', '.plugin_symlinks'
)
$excludedExtensions = @('.zip', '.log', '.dump', '.bak', '.tmp', '.p8', '.p12', '.mobileprovision')

function Get-RelativeArchivePath {
  param([Parameter(Mandatory = $true)][string]$BasePath, [Parameter(Mandatory = $true)][string]$FullPath)
  $baseUri = [Uri]($BasePath.TrimEnd('\') + '\')
  $fileUri = [Uri]$FullPath
  return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fileUri).ToString()).Replace('\', '/')
}

function Test-AllowedSourceFile {
  param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)
  $relative = Get-RelativeArchivePath -BasePath $root -FullPath $File.FullName
  $segments = $relative.Split('/')
  foreach ($segment in $segments) {
    if ($excludedDirectoryNames -contains $segment) { return $false }
  }
  if ($File.Name -match '^\.env($|\.)') { return $false }
  if ($File.Name -eq '.flutter-plugins-dependencies') { return $false }
  if ($excludedExtensions -contains $File.Extension) { return $false }
  return $true
}

function New-FileMap {
  param([Parameter(Mandatory = $true)][System.IO.FileInfo[]]$Files, [Parameter(Mandatory = $true)][string]$BasePath)
  $map = @{}
  foreach ($file in ($Files | Sort-Object FullName)) {
    $entryPath = Get-RelativeArchivePath -BasePath $BasePath -FullPath $file.FullName
    if ($map.ContainsKey($entryPath)) { throw "Duplicate archive path: $entryPath" }
    $map[$entryPath] = $file.FullName
  }
  return $map
}

function New-CleanZip {
  param(
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][hashtable]$FileMap
  )
  $stream = [System.IO.File]::Open($Destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
  try {
    $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
    try {
      foreach ($entryPath in ($FileMap.Keys | Sort-Object)) {
        $sourcePath = $FileMap[$entryPath]
        $entry = $archive.CreateEntry($entryPath, [System.IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = (Get-Item -LiteralPath $sourcePath).LastWriteTime
        $input = [System.IO.File]::OpenRead($sourcePath)
        $output = $entry.Open()
        try { $input.CopyTo($output) } finally { $output.Dispose(); $input.Dispose() }
      }
    } finally {
      $archive.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}

function Test-ByteSequence {
  param([byte[]]$Haystack, [byte[]]$Needle)
  if ($Needle.Length -eq 0 -or $Needle.Length -gt $Haystack.Length) { return $false }
  for ($index = 0; $index -le $Haystack.Length - $Needle.Length; $index++) {
    if ($Haystack[$index] -ne $Needle[0]) { continue }
    $match = $true
    for ($offset = 1; $offset -lt $Needle.Length; $offset++) {
      if ($Haystack[$index + $offset] -ne $Needle[$offset]) { $match = $false; break }
    }
    if ($match) { return $true }
  }
  return $false
}

function Get-CurrentSecretValues {
  $names = @(
    'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD',
    'REVENUECAT_V1_SECRET_API_KEY', 'REVENUECAT_V2_SECRET_API_KEY',
    'REVENUECAT_WEBHOOK_AUTH_HEADER', 'SEND_PUSH_INVOKE_SECRET',
    'OPENAI_API_KEY', 'AI_PROVIDER_API_KEY', 'NETLIFY_AUTH_TOKEN',
    'VERCEL_TOKEN', 'APPLE_PRIVATE_KEY', 'APP_STORE_CONNECT_API_KEY'
  )
  $values = @()
  foreach ($name in $names) {
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
      $value = [Environment]::GetEnvironmentVariable($name, 'User')
    }
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      $values += [pscustomobject]@{ Name = $name; Bytes = [System.Text.Encoding]::UTF8.GetBytes($value) }
    }
  }
  return $values
}

function Get-BytesHash {
  param([byte[]]$Bytes)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') } finally { $sha.Dispose() }
}

function Test-CleanZip {
  param(
    [Parameter(Mandatory = $true)][string]$ArchivePath,
    [Parameter(Mandatory = $true)][hashtable]$FileMap,
    [string[]]$RequiredExact = @(),
    [string[]]$RequiredPrefixes = @()
  )
  $secretValues = Get-CurrentSecretValues
  $forbiddenEntries = @()
  $patternHits = @()
  $exactSecretHits = @()
  $byteMismatches = @()
  $entryNames = @()
  $pattern = '(?i)(-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|(?:^|[^A-Za-z0-9])sbp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|(?:^|[^A-Za-z0-9])sk-(?:proj-)?[A-Za-z0-9_-]{20,})'

  $stream = [System.IO.File]::OpenRead($ArchivePath)
  try {
    $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Read, $true)
    try {
      foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $name = $entry.FullName.Replace('\', '/')
        $entryNames += $name
        $segments = $name.Split('/')
        if (($segments | Where-Object { $excludedDirectoryNames -contains $_ }).Count -gt 0 -or
            $entry.Name -match '^\.env($|\.)' -or
            $excludedExtensions -contains [System.IO.Path]::GetExtension($entry.Name)) {
          $forbiddenEntries += $name
        }

        $entryStream = $entry.Open()
        $memory = [System.IO.MemoryStream]::new()
        try { $entryStream.CopyTo($memory); $bytes = $memory.ToArray() } finally { $memory.Dispose(); $entryStream.Dispose() }

        foreach ($secret in $secretValues) {
          if (Test-ByteSequence -Haystack $bytes -Needle $secret.Bytes) { $exactSecretHits += ($name + ':' + $secret.Name) }
        }

        if ($entry.Length -le 30000000) {
          $text = [System.Text.Encoding]::UTF8.GetString($bytes)
          if ($text -match $pattern) { $patternHits += $name }
        }

        if (-not $FileMap.ContainsKey($name)) {
          $byteMismatches += ($name + ':missing source map')
        } else {
          $sourceBytes = [System.IO.File]::ReadAllBytes($FileMap[$name])
          if ((Get-BytesHash $sourceBytes) -ne (Get-BytesHash $bytes)) { $byteMismatches += $name }
        }
      }
    } finally {
      $archive.Dispose()
    }
  } finally {
    $stream.Dispose()
  }

  foreach ($required in $RequiredExact) {
    if ($entryNames -notcontains $required) { throw "Archive $ArchivePath is missing required entry $required" }
  }
  foreach ($prefix in $RequiredPrefixes) {
    if (-not ($entryNames | Where-Object { $_.StartsWith($prefix) } | Select-Object -First 1)) {
      throw "Archive $ArchivePath is missing required prefix $prefix"
    }
  }
  if ($forbiddenEntries.Count -gt 0) { throw "Forbidden archive entries: $($forbiddenEntries -join ', ')" }
  if ($patternHits.Count -gt 0) { throw "Secret-pattern audit failed in: $($patternHits -join ', ')" }
  if ($exactSecretHits.Count -gt 0) { throw "Exact current-secret audit failed in: $($exactSecretHits -join ', ')" }
  if ($byteMismatches.Count -gt 0) { throw "Workspace/archive byte comparison failed: $($byteMismatches -join ', ')" }

  $item = Get-Item -LiteralPath $ArchivePath
  return [pscustomobject]@{
    Path = $item.FullName
    SizeBytes = $item.Length
    FileCount = $entryNames.Count
    Sha256 = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
    ForbiddenEntryHits = 0
    SecretPatternHits = 0
    ExactCurrentSecretHits = 0
    ByteCompared = $entryNames.Count
    ByteMismatches = 0
  }
}

$webRoot = Join-Path $root 'flutter_mort\build\web'
if (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html'))) { throw 'Flutter web build is missing.' }
$webFiles = @(Get-ChildItem -LiteralPath $webRoot -Recurse -File -Force)
$webMap = New-FileMap -Files $webFiles -BasePath $webRoot
New-CleanZip -Destination $webZip -FileMap $webMap
$webResult = Test-CleanZip -ArchivePath $webZip -FileMap $webMap `
  -RequiredExact @('index.html', 'manifest.json', 'flutter_bootstrap.js', 'main.dart.js') `
  -RequiredPrefixes @('assets/', 'icons/')

$swiftFiles = @(Get-ChildItem -LiteralPath (Join-Path $root 'swift_mort') -Recurse -File -Force | Where-Object { Test-AllowedSourceFile $_ })
$swiftDocs = @(Get-ChildItem -LiteralPath (Join-Path $root 'docs') -File | Where-Object { $_.Name -match '^(SWIFT_|IPHONE_)' })
$swiftMap = New-FileMap -Files @($swiftFiles + $swiftDocs) -BasePath $root
New-CleanZip -Destination $swiftZip -FileMap $swiftMap
$swiftResult = Test-CleanZip -ArchivePath $swiftZip -FileMap $swiftMap `
  -RequiredExact @('swift_mort/MORT.xcodeproj/project.pbxproj') `
  -RequiredPrefixes @('swift_mort/MORT/', 'swift_mort/MORTTests/', 'swift_mort/Scripts/', 'docs/SWIFT_')

$masterFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object { Test-AllowedSourceFile $_ })
$masterMap = New-FileMap -Files $masterFiles -BasePath $root
New-CleanZip -Destination $masterZip -FileMap $masterMap
$masterResult = Test-CleanZip -ArchivePath $masterZip -FileMap $masterMap `
  -RequiredExact @(
    'package.json', 'pnpm-lock.yaml',
    'docs/MORT_1891_FEATURE_REGISTRY.json',
    'docs/MORT_1891_FEATURE_REGISTRY.csv',
    'docs/MORT_1891_FEATURE_REGISTRY.md',
    'scripts/validate-1891-feature-registry.mjs',
    'scripts/audit-feature-implementation.mjs',
    'supabase/migrations/20260717082454_feature_expansion_unread_proof_review.sql',
    'supabase/migrations/20260717092233_feature_expansion_proof_review_fk_index.sql'
  ) `
  -RequiredPrefixes @('app/', 'flutter_mort/lib/', 'swift_mort/MORT/', 'supabase/functions/', 'docs/')

@($masterResult, $webResult, $swiftResult) | ConvertTo-Json -Depth 4
