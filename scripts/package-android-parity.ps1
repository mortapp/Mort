param(
  [switch]$KeepStaging
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceZip = Join-Path $root 'mort-flutter-ios-android-parity-clean.zip'
$androidZip = Join-Path $root 'mort-android-release-candidate-clean.zip'
$unsignedApk = Join-Path $root 'flutter_mort\build\app\outputs\flutter-apk\app-release.apk'
$qaApk = Join-Path $root 'backups\android-emulator-evidence\app-release-qa-signed-startup-fixed.apk'
$stagingRoot = Join-Path $root 'backups\package-staging\android-parity'
$sourceStage = Join-Path $stagingRoot 'source'
$androidStage = Join-Path $stagingRoot 'android-artifacts'

$excludedDirectories = @(
  '.git', '.dart_tool', '.expo', '.gradle', '.idea', '.supabase-cli-config',
  '.swiftpm', '.temp', '.symlinks',
  'backups', 'build', 'coverage', 'DerivedData', 'dist', 'ephemeral', 'logs',
  'node_modules', 'outputs', 'Pods'
)
$forbiddenFileNames = @(
  'Generated.xcconfig', 'flutter_export_environment.sh', 'local.properties'
)
$forbiddenExtensions = @(
  '.bak', '.db', '.dump', '.jks', '.keystore', '.key', '.mobileprovision',
  '.p12', '.pem', '.pfx', '.sqlite', '.sqlite3', '.zip'
)

function Get-RootRelativePath {
  param([Parameter(Mandatory = $true)][string]$FullPath)

  $resolvedRoot = [System.IO.Path]::GetFullPath($root).TrimEnd('\')
  $resolvedPath = [System.IO.Path]::GetFullPath($FullPath)
  if (-not $resolvedPath.StartsWith("$resolvedRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside the MORT root: $resolvedPath"
  }
  return $resolvedPath.Substring($resolvedRoot.Length).TrimStart('\', '/')
}

function Test-SourceFileAllowed {
  param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)

  $relative = Get-RootRelativePath -FullPath $File.FullName
  $segments = $relative -split '[\\/]'
  if ($segments | Where-Object { $excludedDirectories -contains $_ }) { return $false }
  if ($File.Name -match '^\.env($|\.)' -and $File.Name -notmatch '^\.env\.(example|sample|template)$') { return $false }
  if ($forbiddenFileNames -contains $File.Name) { return $false }
  if ($forbiddenExtensions -contains $File.Extension.ToLowerInvariant()) { return $false }
  return $true
}

function Get-IncludedSourceFiles {
  param([Parameter(Mandatory = $true)][string]$Directory)

  foreach ($entry in Get-ChildItem -LiteralPath $Directory -Force) {
    if ($entry.PSIsContainer) {
      if ($excludedDirectories -notcontains $entry.Name) {
        Get-IncludedSourceFiles -Directory $entry.FullName
      }
      continue
    }
    if (Test-SourceFileAllowed -File $entry) { $entry }
  }
}

function Reset-Directory {
  param([Parameter(Mandatory = $true)][string]$Path)

  $resolvedRoot = [System.IO.Path]::GetFullPath($root).TrimEnd('\')
  $resolvedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
  if (-not $resolvedPath.StartsWith("$resolvedRoot\backups\package-staging\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to reset staging path outside the approved package-staging directory: $resolvedPath"
  }
  if (Test-Path -LiteralPath $resolvedPath) {
    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
  }
  New-Item -ItemType Directory -Path $resolvedPath -Force | Out-Null
}

function Compress-DirectoryContents {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  if (Test-Path -LiteralPath $Destination) {
    Remove-Item -LiteralPath $Destination -Force
  }
  [System.IO.Compression.ZipFile]::CreateFromDirectory(
    $Source,
    $Destination,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
  )
}

if (-not (Test-Path -LiteralPath $unsignedApk)) { throw "Unsigned release APK missing: $unsignedApk" }
if (-not (Test-Path -LiteralPath $qaApk)) { throw "QA-signed optimized APK missing: $qaApk" }

Reset-Directory -Path $stagingRoot
New-Item -ItemType Directory -Path $sourceStage, $androidStage -Force | Out-Null

$sourceFiles = @(Get-IncludedSourceFiles -Directory $root)
foreach ($file in $sourceFiles) {
  $relative = Get-RootRelativePath -FullPath $file.FullName
  $destination = Join-Path $sourceStage $relative
  $destinationDirectory = Split-Path -Parent $destination
  New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
}

$artifactDocs = @(
  'docs\mobile\MORT_ANDROID_ARTIFACT_README.md',
  'docs\mobile\MORT_ANDROID_BUILD_CONFIG_STATUS.md',
  'docs\mobile\MORT_ANDROID_CATCHUP_REPORT.md',
  'docs\mobile\MORT_ANDROID_CHANGED_FILES.md',
  'docs\mobile\MORT_IOS_ANDROID_PARITY_MATRIX.md',
  'docs\mobile\MORT_PERMISSION_MATRIX.md',
  'docs\mobile\MORT_PLATFORM_CAPABILITY_MATRIX.json'
)
foreach ($relative in $artifactDocs) {
  $source = Join-Path $root $relative
  $destination = Join-Path $androidStage ([System.IO.Path]::GetFileName($relative))
  Copy-Item -LiteralPath $source -Destination $destination -Force
}
Copy-Item -LiteralPath $unsignedApk -Destination (Join-Path $androidStage 'app-release-unsigned.apk') -Force
Copy-Item -LiteralPath $qaApk -Destination (Join-Path $androidStage 'app-release-qa-debug-signed.apk') -Force

$checksumLines = @(
  Get-ChildItem -LiteralPath $androidStage -File |
    Sort-Object Name |
    ForEach-Object {
      $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
      "$hash  $($_.Name)"
    }
)
[System.IO.File]::WriteAllLines((Join-Path $androidStage 'SHA256SUMS.txt'), $checksumLines)

Compress-DirectoryContents -Source $sourceStage -Destination $sourceZip
Compress-DirectoryContents -Source $androidStage -Destination $androidZip

$sourceArchive = [System.IO.Compression.ZipFile]::OpenRead($sourceZip)
$androidArchive = [System.IO.Compression.ZipFile]::OpenRead($androidZip)
try {
  $sourceCount = @($sourceArchive.Entries | Where-Object { -not $_.FullName.EndsWith('/') }).Count
  $androidCount = @($androidArchive.Entries | Where-Object { -not $_.FullName.EndsWith('/') }).Count
} finally {
  $sourceArchive.Dispose()
  $androidArchive.Dispose()
}

$result = [pscustomobject]@{
  SourceZip = $sourceZip
  SourceFiles = $sourceCount
  SourceBytes = (Get-Item -LiteralPath $sourceZip).Length
  SourceSha256 = (Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash
  AndroidZip = $androidZip
  AndroidFiles = $androidCount
  AndroidBytes = (Get-Item -LiteralPath $androidZip).Length
  AndroidSha256 = (Get-FileHash -LiteralPath $androidZip -Algorithm SHA256).Hash
  SourceStaging = $sourceStage
  AndroidStaging = $androidStage
}
$result | ConvertTo-Json

if (-not $KeepStaging) {
  $resolvedStaging = [System.IO.Path]::GetFullPath($stagingRoot)
  if ($resolvedStaging.StartsWith("$([System.IO.Path]::GetFullPath($root).TrimEnd('\'))\backups\package-staging\", [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
  }
}
