param(
  [string]$RootPath = '',
  [string]$ArchivePath = '',
  [switch]$AllowPlayStoreMedia
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

if ([string]::IsNullOrWhiteSpace($RootPath)) {
  $RootPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
} else {
  $RootPath = (Resolve-Path -LiteralPath $RootPath).Path
}

$excludedSegments = @(
  'node_modules', '.expo', '.supabase-cli-config', '.dart_tool', '.git',
  'build', 'dist', 'logs', 'backups', 'coverage', 'outputs', 'DerivedData',
  'Pods', '.temp', '.symlinks', 'ephemeral'
)
$mediaExtensions = @('.png', '.jpg', '.jpeg', '.heic', '.tif', '.tiff', '.webp', '.pdf')
$identityNamePattern = '(?i)(passport|driver.?licen[cs]e|government.?id|school.?id|student.?id|selfie|liveness|identity.?evidence|identity.?document|address.?evidence|residential.?document)'
$forbiddenExtensions = @('.pem', '.p12', '.pfx', '.key', '.mobileprovision', '.sqlite', '.sqlite3', '.db', '.dump', '.bak')
$allowedMediaPatterns = @(
  '(?i)(^|/)(assets/notification-icon\.png)$',
  '(?i)(^|/)(web/)?favicon\.png$',
  '(?i)(^|/)(web/)?icons/Icon(?:-maskable)?-(192|512)\.png$',
  '(?i)(^|/)Assets\.xcassets/AppIcon\.appiconset/.+\.png$',
  '(?i)(^|/)Assets\.xcassets/LaunchImage\.imageset/.+\.png$',
  '(?i)(^|/)android/app/src/main/res/mipmap-[^/]+/ic_launcher\.png$'
)
if ($AllowPlayStoreMedia) {
  $allowedMediaPatterns += @(
    '(?i)(^|/)app-icon/mort-play-icon-512\.png$',
    '(?i)(^|/)feature-graphic/mort-feature-graphic-1024x500\.png$',
    '(?i)(^|/)phone-large/[0-9]{2}-[a-z0-9-]+-1080x1920\.png$',
    '(?i)(^|/)phone-small/[0-9]{2}-[a-z0-9-]+-720x1280\.png$'
  )
}

function Test-ExcludedPath {
  param([string]$RelativePath)
  $segments = $RelativePath -split '[\\/]'
  foreach ($segment in $segments) {
    if ($excludedSegments -contains $segment) { return $true }
  }
  return $false
}

function Test-AllowedMedia {
  param([string]$RelativePath)
  $normalized = $RelativePath.Replace('\', '/')
  foreach ($pattern in $allowedMediaPatterns) {
    if ($normalized -match $pattern) { return $true }
  }
  return $false
}

function Get-SecretValues {
  $names = @(
    'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD',
    'MORT_UPLOAD_STORE_PASSWORD', 'MORT_UPLOAD_KEY_PASSWORD',
    'PLAY_REVIEW_TEEN_PASSWORD', 'PLAY_REVIEW_TEEN_EMAIL',
    'PLAY_REVIEW_ADULT_PASSWORD', 'PLAY_REVIEW_ADULT_EMAIL',
    'REVENUECAT_V1_SECRET_API_KEY', 'REVENUECAT_WEBHOOK_AUTH_HEADER',
    'REVENUECAT_FLUTTER_IOS_SDK_KEY', 'REVENUECAT_IOS_API_KEY',
    'REVENUECAT_WEBHOOK_SECRET', 'SEND_PUSH_INVOKE_SECRET',
    'IDENTITY_VERIFICATION_WEBHOOK_SECRET', 'OPENAI_API_KEY',
    'ANTHROPIC_API_KEY', 'GEMINI_API_KEY', 'NETLIFY_AUTH_TOKEN', 'VERCEL_TOKEN',
    'MORT_REBUILD_TEST_PASSWORD'
  )
  $values = @()
  foreach ($name in $names) {
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
      $value = [Environment]::GetEnvironmentVariable($name, 'User')
    }
    if (-not [string]::IsNullOrWhiteSpace($value) -and $value.Length -ge 8) {
      $values += [pscustomobject]@{ Name = $name; Value = $value }
    }
  }
  return @($values)
}

function Assert-EntryNameSafe {
  param([string]$Name)
  $normalized = $Name.Replace('\', '/')
  $fileName = [System.IO.Path]::GetFileName($normalized)
  $extension = [System.IO.Path]::GetExtension($fileName).ToLowerInvariant()
  if ($fileName -match '^\.env($|\.)' -and $fileName -notmatch '^\.env\.(example|sample|template)$') {
    throw "Environment file is not allowed: $normalized"
  }
  if ($forbiddenExtensions -contains $extension) {
    throw "Credential/database container is not allowed: $normalized"
  }
  if ($extension -eq '.gz' -and $fileName -match '(?i)\.(sql|dump)\.gz$') {
    throw "Database backup is not allowed: $normalized"
  }
  if ($mediaExtensions -contains $extension) {
    if ($normalized -match $identityNamePattern) {
      throw "Identity-document-like media is not allowed: $normalized"
    }
    if (-not (Test-AllowedMedia -RelativePath $normalized)) {
      throw "Unrecognized media file requires manual privacy review: $normalized"
    }
  }
}

function Assert-LocalPublicExpoEnvironment {
  param([Parameter(Mandatory = $true)][string]$Path)
  $allowed = @(
    'EXPO_PUBLIC_SUPABASE_URL',
    'EXPO_PUBLIC_SUPABASE_ANON_KEY',
    'EXPO_PUBLIC_APP_ENV'
  )
  $found = @{}
  foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) { continue }
    if ($trimmed -notmatch '^([^=]+)=(.*)$') {
      throw 'The local Expo environment file contains a malformed line.'
    }
    $name = $Matches[1].Trim()
    $value = $Matches[2].Trim().Trim('"').Trim("'")
    if ($allowed -notcontains $name) {
      throw "Non-public environment variable is not allowed in .env.local: $name"
    }
    if ($found.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($value)) {
      throw "Duplicate or empty public environment variable in .env.local: $name"
    }
    $found[$name] = $true
  }
  foreach ($name in $allowed) {
    if (-not $found.ContainsKey($name)) {
      throw "Required public environment variable is missing from .env.local: $name"
    }
  }
  & git -C $RootPath check-ignore --quiet -- .env.local
  if ($LASTEXITCODE -ne 0) {
    throw '.env.local must remain ignored by Git.'
  }
}

$secretValues = @(Get-SecretValues)
$filesScanned = 0
$mediaScanned = 0

foreach ($file in Get-ChildItem -LiteralPath $RootPath -Recurse -File -Force) {
  $relative = $file.FullName.Substring($RootPath.Length).TrimStart('\', '/')
  if (Test-ExcludedPath -RelativePath $relative) { continue }
  if ($file.Extension -eq '.zip') { continue }
  if ($relative.Replace('\', '/') -eq '.env.local') {
    Assert-LocalPublicExpoEnvironment -Path $file.FullName
  } else {
    Assert-EntryNameSafe -Name $relative
  }
  $filesScanned += 1
  if ($mediaExtensions -contains $file.Extension.ToLowerInvariant()) {
    $mediaScanned += 1
    continue
  }
  if ($file.Length -gt 10MB) { continue }
  $content = [System.IO.File]::ReadAllText($file.FullName)
  foreach ($secret in $secretValues) {
    if ($content.Contains($secret.Value)) {
      throw "Secret value from $($secret.Name) found in $relative"
    }
  }
  if ($content -match '\b\d{3}-\d{2}-\d{4}\b') {
    throw "SSN-like value found in $relative"
  }
}

if (-not [string]::IsNullOrWhiteSpace($ArchivePath)) {
  $resolvedArchive = (Resolve-Path -LiteralPath $ArchivePath).Path
  $archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedArchive)
  try {
    foreach ($entry in $archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') }) {
      Assert-EntryNameSafe -Name $entry.FullName
      $stream = $entry.Open()
      $memory = New-Object System.IO.MemoryStream
      try {
        $stream.CopyTo($memory)
        if ($entry.Length -le 10MB -and $mediaExtensions -notcontains [System.IO.Path]::GetExtension($entry.Name).ToLowerInvariant()) {
          $content = [System.Text.Encoding]::UTF8.GetString($memory.ToArray())
          foreach ($secret in $secretValues) {
            if ($content.Contains($secret.Value)) {
              throw "Secret value from $($secret.Name) found in archive entry $($entry.FullName)"
            }
          }
          if ($content -match '\b\d{3}-\d{2}-\d{4}\b') {
            throw "SSN-like value found in archive entry $($entry.FullName)"
          }
        }
      } finally {
        $memory.Dispose()
        $stream.Dispose()
      }
    }
  } finally {
    $archive.Dispose()
  }
}

Write-Host "Sensitive-file scan passed. Files scanned: $filesScanned; known app media: $mediaScanned; secret values checked: $($secretValues.Count)."
