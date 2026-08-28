[CmdletBinding()]
param(
  [switch]$KeepStaging
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$buildAab = Join-Path $root 'build\play\mort-closed-test.aab'
$buildApk = Join-Path $root 'build\play\mort-play-closed-test-qa.apk'
$releaseAab = Join-Path $root 'mort-play-closed-test.aab'
$releaseApk = Join-Path $root 'mort-play-closed-test-qa.apk'
$sourceZip = Join-Path $root 'mort-play-closed-test-source-clean.zip'
$policyZip = Join-Path $root 'mort-play-policy-and-listing-package.zip'
$webZip = Join-Path $root 'mort-web-legal-support-pages.zip'
$stagingRoot = Join-Path $root 'build\packaging\play-closed-test'
$sourceStage = Join-Path $stagingRoot 'source'
$policyStage = Join-Path $stagingRoot 'policy'
$webStage = Join-Path $stagingRoot 'web'

$excludedDirectories = @(
  '.branches', '.dart_tool', '.expo', '.git', '.gradle', '.idea',
  '.supabase-cli-config', '.swiftpm', '.symlinks', '.temp',
  'backups', 'build', 'coverage', 'DerivedData', 'dist', 'ephemeral',
  'logs', 'node_modules', 'outputs', 'Pods'
)
$forbiddenFileNames = @(
  '.flutter-plugins-dependencies', 'Generated.xcconfig', 'key.properties',
  'local.properties', 'flutter_export_environment.sh'
)
$forbiddenExtensions = @(
  '.aab', '.apk', '.bak', '.db', '.dump', '.jks', '.keystore', '.key',
  '.mobileprovision', '.p12', '.pem', '.pfx', '.sqlite', '.sqlite3', '.zip'
)

function Assert-UnderPath {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Parent
  )

  $resolvedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
  $resolvedParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\')
  if (-not $resolvedPath.StartsWith("$resolvedParent\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to operate outside $resolvedParent`: $resolvedPath"
  }
}

function Reset-StagingDirectory {
  param([Parameter(Mandatory = $true)][string]$Path)

  Assert-UnderPath -Path $Path -Parent (Join-Path $root 'build\packaging')
  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
  New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

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
  if ($File.Name -match '^\.env($|\.)' -and $File.Name -notmatch '^\.env\.(example|sample|template)$') {
    return $false
  }
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

function Copy-DirectoryContents {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
  }
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

function Get-ArtifactResult {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Use
  )

  $item = Get-Item -LiteralPath $Path
  $fileCount = 1
  if ($item.Extension -eq '.zip') {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($item.FullName)
    try {
      $fileCount = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') }).Count
    } finally {
      $archive.Dispose()
    }
  }
  return [pscustomobject]@{
    Path = $item.FullName
    Bytes = $item.Length
    Files = $fileCount
    SHA256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    IntendedUse = $Use
  }
}

foreach ($required in @($buildAab, $buildApk)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Required release artifact is missing: $required"
  }
}

Reset-StagingDirectory -Path $stagingRoot
New-Item -ItemType Directory -Path $sourceStage, $policyStage, $webStage -Force | Out-Null

$sourceFiles = @(Get-IncludedSourceFiles -Directory $root)
foreach ($file in $sourceFiles) {
  $relative = Get-RootRelativePath -FullPath $file.FullName
  $destination = Join-Path $sourceStage $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
}

foreach ($directory in @('play', 'mobile', 'legal', 'operations', 'security', 'ios')) {
  Copy-DirectoryContents -Source (Join-Path $root "docs\$directory") -Destination (Join-Path $policyStage "docs\$directory")
}

Copy-DirectoryContents -Source (Join-Path $root 'web\public') -Destination (Join-Path $webStage 'public')
Copy-Item -LiteralPath (Join-Path $root 'web\netlify.toml') -Destination (Join-Path $webStage 'netlify.toml') -Force

Copy-Item -LiteralPath $buildAab -Destination $releaseAab -Force
Copy-Item -LiteralPath $buildApk -Destination $releaseApk -Force
Compress-DirectoryContents -Source $sourceStage -Destination $sourceZip
Compress-DirectoryContents -Source $policyStage -Destination $policyZip
Compress-DirectoryContents -Source $webStage -Destination $webZip

$results = @(
  Get-ArtifactResult -Path $sourceZip -Use 'Clean source and documentation handoff'
  Get-ArtifactResult -Path $releaseAab -Use 'Google Play closed-test upload candidate'
  Get-ArtifactResult -Path $releaseApk -Use 'Direct QA installation only, not Play distribution'
  Get-ArtifactResult -Path $policyZip -Use 'Play Console policy, listing, safety, and operations package'
  Get-ArtifactResult -Path $webZip -Use 'Netlify-ready public legal and support pages'
)
$results | ConvertTo-Json -Depth 3

if (-not $KeepStaging) {
  Assert-UnderPath -Path $stagingRoot -Parent (Join-Path $root 'build\packaging')
  Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}
