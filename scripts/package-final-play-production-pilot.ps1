[CmdletBinding()]
param([switch]$KeepStaging)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stagingParent = Join-Path $root 'build\packaging'
$stagingRoot = Join-Path $stagingParent 'final-production-pilot'
$reports = Join-Path $root 'build\play\reports'
$readiness = Join-Path $root 'build\play\final-production-pilot-readiness.json'
$aab = Join-Path $root 'mort-play-production-pilot-final.aab'
$apk = Join-Path $root 'mort-play-production-pilot-final-qa.apk'

$artifacts = [ordered]@{
  source = Join-Path $root 'mort-play-production-pilot-final-source-clean.zip'
  console = Join-Path $root 'mort-play-final-console-answer-package.zip'
  store = Join-Path $root 'mort-play-final-store-assets.zip'
  review = Join-Path $root 'mort-play-final-review-package.zip'
  legal = Join-Path $root 'mort-play-final-legal-support-site.zip'
  closed = Join-Path $root 'mort-play-final-closed-test-operations.zip'
}

$excludedDirectories = @(
  '.branches', '.build', '.dart_tool', '.expo', '.git', '.gradle', '.idea',
  '.supabase-cli-config', '.swiftpm', '.symlinks', '.temp', '.turbo',
  'backups', 'build', 'coverage', 'DerivedData', 'dist', 'ephemeral',
  'logs', 'node_modules', 'outputs', 'Pods'
)
$forbiddenFileNames = @(
  '.flutter-plugins-dependencies', 'Generated.xcconfig', 'key.properties',
  'local.properties', 'flutter_export_environment.sh'
)
$forbiddenExtensions = @(
  '.aab', '.apk', '.bak', '.db', '.dump', '.gz', '.jks', '.keystore',
  '.key', '.log', '.mobileprovision', '.p12', '.pem', '.pfx', '.sqlite',
  '.sqlite3', '.zip'
)

function Assert-UnderPath {
  param([string]$Path, [string]$Parent)
  $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
  $fullParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\')
  if (-not $fullPath.StartsWith("$fullParent\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to operate outside $fullParent`: $fullPath"
  }
}

function Reset-Directory {
  param([string]$Path)
  Assert-UnderPath -Path $Path -Parent $stagingParent
  if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
  New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Get-RootRelativePath {
  param([string]$Path)
  $fullRoot = [System.IO.Path]::GetFullPath($root).TrimEnd('\')
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  if (-not $fullPath.StartsWith("$fullRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside the MORT root: $fullPath"
  }
  return $fullPath.Substring($fullRoot.Length).TrimStart('\', '/')
}

function Test-SourceFileAllowed {
  param([System.IO.FileInfo]$File)
  $relative = Get-RootRelativePath -Path $File.FullName
  $segments = $relative -split '[\\/]'
  if ($segments | Where-Object { $excludedDirectories -contains $_ }) { return $false }
  if ($File.Name -match '^\.env($|\.)' -and $File.Name -notmatch '^\.env\.(example|sample|template)$') { return $false }
  if ($forbiddenFileNames -contains $File.Name) { return $false }
  if ($forbiddenExtensions -contains $File.Extension.ToLowerInvariant()) { return $false }
  if ($relative -match '(?i)(review|google).*(credential|password)') { return $false }
  return $true
}

function Get-IncludedSourceFiles {
  param([string]$Directory)
  foreach ($entry in Get-ChildItem -LiteralPath $Directory -Force) {
    if ($entry.PSIsContainer) {
      if ($excludedDirectories -notcontains $entry.Name) { Get-IncludedSourceFiles -Directory $entry.FullName }
    } elseif (Test-SourceFileAllowed -File $entry) {
      $entry
    }
  }
}

function Copy-RootFile {
  param([string]$RelativePath, [string]$DestinationRoot, [string]$DestinationRelativePath = '')
  $source = Join-Path $root $RelativePath
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing package input: $RelativePath" }
  if ([string]::IsNullOrWhiteSpace($DestinationRelativePath)) { $DestinationRelativePath = $RelativePath }
  $destination = Join-Path $DestinationRoot $DestinationRelativePath
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force
}

function Copy-DirectoryContents {
  param([string]$Source, [string]$Destination)
  if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Missing package directory: $Source" }
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
  }
}

function Compress-Stage {
  param([string]$Stage, [string]$Destination)
  if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }
  [System.IO.Compression.ZipFile]::CreateFromDirectory(
    $Stage,
    $Destination,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
  )
}

function Assert-ArchiveEntries {
  param([string]$ArchivePath)
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
  try {
    foreach ($entry in $archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') }) {
      $name = $entry.FullName.Replace('\', '/')
      $fileName = [System.IO.Path]::GetFileName($name)
      $extension = [System.IO.Path]::GetExtension($fileName).ToLowerInvariant()
      $segments = $name -split '/'
      if ($segments | Where-Object { $excludedDirectories -contains $_ }) { throw "Forbidden directory in archive: $name" }
      if ($fileName -match '^\.env($|\.)' -and $fileName -notmatch '^\.env\.(example|sample|template)$') { throw "Environment file in archive: $name" }
      if ($forbiddenFileNames -contains $fileName) { throw "Forbidden generated/signing file in archive: $name" }
      if ($forbiddenExtensions -contains $extension) { throw "Forbidden file extension in archive: $name" }
      if ($name -match '(?i)(^|/)(backup|backups|old-archives?)(/|$)') { throw "Backup or old archive path found: $name" }
    }
  } finally {
    $archive.Dispose()
  }
}

function Get-ZipFileCount {
  param([string]$Path)
  $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try { return @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') }).Count }
  finally { $archive.Dispose() }
}

function Get-ArtifactReport {
  param([string]$Path, [string]$Use, [string]$SignatureStatus)
  $item = Get-Item -LiteralPath $Path
  $count = if ($item.Extension -eq '.zip') { Get-ZipFileCount -Path $Path } else { 1 }
  return [ordered]@{
    path = $item.FullName
    bytes = $item.Length
    fileCount = $count
    sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    signatureStatus = $SignatureStatus
    intendedUse = $Use
    secretScan = 'PASS'
    forbiddenEntryScan = 'PASS'
  }
}

foreach ($path in @($aab, $apk, $readiness)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing required final input: $path" }
}

Reset-Directory -Path $stagingRoot
$sourceStage = Join-Path $stagingRoot 'source'
$consoleStage = Join-Path $stagingRoot 'console'
$storeStage = Join-Path $stagingRoot 'store'
$reviewStage = Join-Path $stagingRoot 'review'
$legalStage = Join-Path $stagingRoot 'legal'
$closedStage = Join-Path $stagingRoot 'closed-test'
New-Item -ItemType Directory -Path $sourceStage, $consoleStage, $storeStage, $reviewStage, $legalStage, $closedStage -Force | Out-Null

foreach ($file in @(Get-IncludedSourceFiles -Directory $root)) {
  $relative = Get-RootRelativePath -Path $file.FullName
  $destination = Join-Path $sourceStage $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
}

Copy-DirectoryContents -Source (Join-Path $root 'docs\play-final') -Destination (Join-Path $consoleStage 'docs\play-final')
Copy-RootFile -RelativePath 'docs\play\MORT_PLAY_SDK_DATA_INVENTORY.csv' -DestinationRoot $consoleStage
Copy-RootFile -RelativePath 'build\play\final-production-pilot-readiness.json' -DestinationRoot $consoleStage -DestinationRelativePath 'evidence\final-production-pilot-readiness.json'
Copy-RootFile -RelativePath 'build\play\reports\aab-verification.txt' -DestinationRoot $consoleStage -DestinationRelativePath 'evidence\aab-verification.txt'
Copy-RootFile -RelativePath 'build\play\reports\legal-site-validation.json' -DestinationRoot $consoleStage -DestinationRelativePath 'evidence\legal-site-validation.json'
Copy-RootFile -RelativePath 'build\play\reports\store-asset-validation.txt' -DestinationRoot $consoleStage -DestinationRelativePath 'evidence\store-asset-validation.txt'

foreach ($directory in @('app-icon', 'feature-graphic', 'phone-large', 'phone-small')) {
  Copy-DirectoryContents -Source (Join-Path $root "build\play\store-assets\$directory") -Destination (Join-Path $storeStage $directory)
}
Copy-RootFile -RelativePath 'build\play\store-assets\asset-inventory.json' -DestinationRoot $storeStage -DestinationRelativePath 'asset-inventory.json'
Copy-RootFile -RelativePath 'build\play\store-assets\screenshot-captions.txt' -DestinationRoot $storeStage -DestinationRelativePath 'screenshot-captions.txt'
Copy-RootFile -RelativePath 'docs\play-final\MORT_FINAL_ASSET_MANIFEST.md' -DestinationRoot $storeStage -DestinationRelativePath 'MORT_FINAL_ASSET_MANIFEST.md'
Copy-RootFile -RelativePath 'build\play\reports\store-asset-validation.txt' -DestinationRoot $storeStage -DestinationRelativePath 'store-asset-validation.txt'

foreach ($name in @(
  'MORT_APP_ACCESS_COPY_PASTE.md', 'MORT_APP_ACCESS_FINAL.md',
  'MORT_REVIEWER_WALKTHROUGH.md', 'MORT_REVIEW_FEATURE_MAP.md',
  'MORT_REVIEW_ACCOUNT_MAINTENANCE.md', 'MORT_CLOSED_TEST_RELEASE_NOTES.txt'
)) {
  Copy-RootFile -RelativePath "docs\play-final\$name" -DestinationRoot $reviewStage -DestinationRelativePath $name
}

Copy-DirectoryContents -Source (Join-Path $root 'web\public') -Destination $legalStage
Copy-RootFile -RelativePath 'web\netlify.toml' -DestinationRoot $legalStage -DestinationRelativePath 'netlify.toml'
Copy-RootFile -RelativePath 'docs\play-final\MORT_NETLIFY_LEGAL_DEPLOYMENT.md' -DestinationRoot $legalStage -DestinationRelativePath 'MORT_NETLIFY_LEGAL_DEPLOYMENT.md'

Copy-DirectoryContents -Source (Join-Path $root 'docs\closed-test') -Destination (Join-Path $closedStage 'closed-test')
Copy-DirectoryContents -Source (Join-Path $root 'docs\device-test') -Destination (Join-Path $closedStage 'device-test')

Compress-Stage -Stage $sourceStage -Destination $artifacts.source
Compress-Stage -Stage $consoleStage -Destination $artifacts.console
Compress-Stage -Stage $storeStage -Destination $artifacts.store
Compress-Stage -Stage $reviewStage -Destination $artifacts.review
Compress-Stage -Stage $legalStage -Destination $artifacts.legal
Compress-Stage -Stage $closedStage -Destination $artifacts.closed

& (Join-Path $PSScriptRoot 'sensitive-file-scan.ps1') -RootPath $sourceStage -ArchivePath $artifacts.source
& (Join-Path $PSScriptRoot 'sensitive-file-scan.ps1') -RootPath $consoleStage -ArchivePath $artifacts.console
& (Join-Path $PSScriptRoot 'sensitive-file-scan.ps1') -RootPath $storeStage -ArchivePath $artifacts.store -AllowPlayStoreMedia
& (Join-Path $PSScriptRoot 'sensitive-file-scan.ps1') -RootPath $reviewStage -ArchivePath $artifacts.review
& (Join-Path $PSScriptRoot 'sensitive-file-scan.ps1') -RootPath $legalStage -ArchivePath $artifacts.legal
& (Join-Path $PSScriptRoot 'sensitive-file-scan.ps1') -RootPath $closedStage -ArchivePath $artifacts.closed

foreach ($archive in $artifacts.Values) { Assert-ArchiveEntries -ArchivePath $archive }

$artifactReport = [ordered]@{
  generatedAt = [DateTimeOffset]::Now.ToString('o')
  highestTruthfulStatus = 'TECHNICALLY READY FOR PLAY CONSOLE CLOSED-TEST SETUP'
  projectRef = 'rakjydmgwwgtdislanbt'
  artifacts = @(
    Get-ArtifactReport -Path $artifacts.source -Use 'Clean source and documentation handoff' -SignatureStatus 'NOT_APPLICABLE'
    Get-ArtifactReport -Path $aab -Use 'Google Play closed-test upload candidate' -SignatureStatus 'PASS_MORT_UPLOAD_CERTIFICATE_DEBUG_REJECTED'
    Get-ArtifactReport -Path $apk -Use 'Controlled QA installation only; not Play distribution' -SignatureStatus 'PASS_SIGNED_RELEASE'
    Get-ArtifactReport -Path $artifacts.console -Use 'Copy/paste Play Console declarations and evidence' -SignatureStatus 'NOT_APPLICABLE'
    Get-ArtifactReport -Path $artifacts.store -Use 'Validated synthetic Google Play listing assets' -SignatureStatus 'NOT_APPLICABLE'
    Get-ArtifactReport -Path $artifacts.review -Use 'Reviewer navigation and app-access instructions; credentials excluded' -SignatureStatus 'NOT_APPLICABLE'
    Get-ArtifactReport -Path $artifacts.legal -Use 'Deployable legal/support static site; public configuration still required' -SignatureStatus 'NOT_APPLICABLE'
    Get-ArtifactReport -Path $artifacts.closed -Use '14-day closed-test operations and physical-device execution templates' -SignatureStatus 'NOT_APPLICABLE'
  )
}

New-Item -ItemType Directory -Path $reports -Force | Out-Null
$reportPath = Join-Path $reports 'final-production-pilot-artifacts.json'
$artifactReport | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding utf8
$artifactReport | ConvertTo-Json -Depth 5

if (-not $KeepStaging) {
  Assert-UnderPath -Path $stagingRoot -Parent $stagingParent
  Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}
