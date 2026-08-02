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
$reviewedMediaHashes = @{
  'flutter_mort/assets/branding/mort_arrow_adaptive_foreground.png' = 'BCAE9EDFD57B676D97EA0A41500937F67704A87370F03D20A1755EBB551A34D5'
  'flutter_mort/assets/branding/mort_arrow_adaptive_monochrome.png' = '78C72C2B49698ED36351E51324D8EFF89276F7D65873CE9931615B7C78C93D24'
  'artifacts/native-qa/mort-api36-launch.png' = '35A9DFC922AD29D82E79CEB58A7F6CD5FECEDDD0D99A086CA5345B9664C34466'
  'artifacts/native-qa/mort-api36-launch-0.9.10.png' = 'E24AE97D7C3503526AC94FBB4A73B99FF630ACE4750217CA8E41217BE9A07702'
  'artifacts/native-qa/mort-api36-launch-0.9.11.png' = '25A8A730BCAC2C59F319E61F823FF92153786A3E5DD3D634B77DB1071A4180AC'
  'artifacts/release-0.9.12+102/reports/emulator-final-release-launch.png' = '00FD249CEB63C8F2CB8C03C65E5F31F1E2905F090E6B584BBCF7C4138B6FD73E'
  'artifacts/release-0.9.12+102/reports/emulator-release-launch.png' = 'ACB000B71ACC3AFE9474311E3665E7D76F0F8F2BD70664F2A0B30295F3D6FDC4'
  'artifacts/release-0.9.13+103/reports/emulator-final-release-launch.png' = 'B0846DA5CFA4CC6755BE384064651A85ED099F4E05F6509AEAC25DC5D9BCB9C0'
  'artifacts/release-0.9.13+103/reports/emulator-auth-screen.png' = '180C510D42FDEAB0BC335D6DC06B5CAE03F5FD59B3B848A850C39C0F60EFF698'
  'artifacts/release-0.9.13+103/reports/emulator-google-oauth-host.png' = 'EFE3AEC964C1391585D926D3A0004D3776EA6935D75B30C75FAD9FB7EB9D6E7C'
}
$allowedMediaPatterns = @(
  '(?i)(^|/)flutter_mort/assets/branding/mort_arrow_rose_gold\.png$',
  '(?i)(^|/)(assets/notification-icon\.png)$',
  '(?i)(^|/)(web/)?favicon\.png$',
  '(?i)(^|/)(web/)?icons/Icon(?:-maskable)?-(192|512)\.png$',
  '(?i)(^|/)Assets\.xcassets/AppIcon\.appiconset/.+\.png$',
  '(?i)(^|/)Assets\.xcassets/LaunchImage\.imageset/.+\.png$',
  '(?i)(^|/)android/app/src/main/res/drawable-[^/]+/ic_launcher_(foreground|monochrome)\.png$',
  '(?i)(^|/)android/app/src/main/res/mipmap-[^/]+/ic_launcher\.png$'
)
if ($AllowPlayStoreMedia) {
  $allowedMediaPatterns += @(
    '(?i)(^|/)app-icon/mort-play-icon-512\.png$',
    '(?i)(^|/)feature-graphic/mort-feature-graphic-1024x500\.png$',
    '(?i)(^|/)phone-large/[0-9]{2}-[a-z0-9-]+-1080x1920\.png$',
    '(?i)(^|/)phone-small/[0-9]{2}-[a-z0-9-]+-720x1280\.png$',
    '(?i)(^|/)signed-apk-emulator/[a-z0-9-]+\.png$'
  )
}

function Test-ExcludedPath {
  param([string]$RelativePath)
  $normalized = $RelativePath.Replace('\', '/')
  if ($normalized -match '(?i)^qa/recordings(?:/|$)') { return $true }
  $segments = $RelativePath -split '[\\/]'
  foreach ($segment in $segments) {
    if ($excludedSegments -contains $segment) { return $true }
  }
  return $false
}

function Get-IncludedSourceFiles {
  $pending = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
  $pending.Push((Get-Item -LiteralPath $RootPath))

  while ($pending.Count -gt 0) {
    $directory = $pending.Pop()
    foreach ($entry in Get-ChildItem -LiteralPath $directory.FullName -Force) {
      $relative = $entry.FullName.Substring($RootPath.Length).TrimStart('\', '/')
      if (Test-ExcludedPath -RelativePath $relative) { continue }

      if ($entry.PSIsContainer) {
        if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
          $pending.Push($entry)
        }
        continue
      }

      Write-Output $entry
    }
  }
}

function Test-AllowedMedia {
  param([string]$RelativePath)
  $normalized = $RelativePath.Replace('\', '/')
  if ($reviewedMediaHashes.ContainsKey($normalized)) {
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $RootPath $RelativePath)).Hash
    return $actualHash -eq $reviewedMediaHashes[$normalized]
  }
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
    'REVENUECAT_V1_SECRET_API_KEY', 'REVENUECAT_V2_SECRET_API_KEY',
    'REVENUECAT_WEBHOOK_AUTH_HEADER',
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

foreach ($file in Get-IncludedSourceFiles) {
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
