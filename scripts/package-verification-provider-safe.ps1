$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$masterZip = Join-Path $root 'mort-verification-provider-safe-foundation-clean.zip'
$webZip = Join-Path $root 'mort-web-verification-disabled-safe.zip'
$swiftZip = Join-Path $root 'mort-swiftui-verification-provider-safe-clean.zip'
$webRoot = (Resolve-Path (Join-Path $root 'flutter_mort\build\web')).Path
$swiftRoot = (Resolve-Path (Join-Path $root 'swift_mort')).Path
$sourceStage = Join-Path $root '.delivery-stage-verification-provider-source'
$swiftStage = Join-Path $root '.delivery-stage-verification-provider-swift'
$sensitiveScan = Join-Path $PSScriptRoot 'sensitive-file-scan.ps1'

function Assert-ChildPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  $prefix = $root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a path outside the workspace: $full"
  }
}

foreach ($path in @($masterZip, $webZip, $swiftZip, $sourceStage, $swiftStage)) {
  Assert-ChildPath -Path $path
}

$excludedSegments = @(
  'node_modules', '.expo', '.supabase-cli-config', '.dart_tool', '.git',
  '.idea', '.vscode', 'build', 'dist', 'logs', 'backups', 'coverage',
  'outputs', 'DerivedData', 'Pods', 'ephemeral', '.symlinks', '.temp',
  '.delivery-stage-verification-provider-source',
  '.delivery-stage-verification-provider-swift'
)

function Test-AllowedSourceFile {
  param(
    [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
    [Parameter(Mandatory = $true)][string]$BasePath
  )
  $relative = $File.FullName.Substring($BasePath.Length + 1)
  $segments = $relative -split '[\\/]'
  foreach ($segment in $segments) {
    if ($excludedSegments -contains $segment) { return $false }
  }
  if ($File.Name -match '^\.env($|\.)') { return $false }
  if ($File.Name -in @('.DS_Store', 'Thumbs.db', 'Secrets.xcconfig')) { return $false }
  if ($File.Extension -in @('.zip', '.log', '.pem', '.p12', '.pfx', '.key', '.mobileprovision', '.dump', '.bak')) { return $false }
  return $true
}

function Copy-CleanTree {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )
  foreach ($file in Get-ChildItem -LiteralPath $Source -Recurse -File -Force) {
    if (-not (Test-AllowedSourceFile -File $file -BasePath $Source)) { continue }
    $relative = $file.FullName.Substring($Source.Length + 1)
    $target = Join-Path $Destination $relative
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $file.FullName -Destination $target
  }
}

function Get-ZipResult {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet('master', 'web', 'swift')][string]$Kind
  )
  $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $entries = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
    $names = @($entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    $forbidden = @($names | Where-Object {
      $_ -match '(^|/)(node_modules|\.expo|\.supabase-cli-config|\.dart_tool|\.git|build|dist|logs|backups|coverage|outputs|DerivedData|Pods)(/|$)' -or
      $_ -match '(^|/)\.env($|\.)' -or
      $_ -match '\.(zip|log|pem|p12|pfx|key|mobileprovision|dump|bak)$'
    })
    if ($forbidden.Count -gt 0) {
      throw "Forbidden $Kind archive entries: $($forbidden -join ', ')"
    }

    if ($Kind -eq 'master') {
      foreach ($required in @(
        'docs/MORT_84_SECURITY_WARNING_RECONCILIATION.md',
        'docs/MORT_VERIFICATION_PROVIDER_SAFE_FOUNDATION_RESULTS.md',
        'docs/IDENTITY_VERIFICATION_PROVIDER_ARCHITECTURE.md',
        'supabase/migrations/20260718051719_identity_verification_provider_safe_foundation.sql',
        'supabase/functions/identity-verification-webhook/index.ts',
        'scripts/qa-verification-production-fail-closed.mjs'
      )) {
        if ($names -notcontains $required) { throw "Master archive is missing $required." }
      }
    }
    if ($Kind -eq 'web') {
      foreach ($required in @('index.html', 'manifest.json', 'flutter_bootstrap.js', 'main.dart.js')) {
        if ($names -notcontains $required) { throw "Web archive is missing root entry $required." }
      }
      if ($names | Where-Object { $_ -match '(^|/)(lib|test|supabase|scripts|docs)(/|$)' }) {
        throw 'Web archive contains source directories.'
      }
    }
    if ($Kind -eq 'swift') {
      foreach ($required in @(
        'MORT.xcodeproj/project.pbxproj',
        'MORT/App/MORTApp.swift',
        'MORT/Services/IdentityVerificationProvider.swift',
        'MORT/Features/Verification/VerificationView.swift'
      )) {
        if ($names -notcontains $required) { throw "Swift archive is missing $required." }
      }
      if ($names | Where-Object { $_ -match '(^|/)(flutter_mort|node_modules|supabase)(/|$)' }) {
        throw 'Swift archive contains a non-Swift project tree.'
      }
    }

    return [pscustomobject]@{
      Kind = $Kind
      Path = $Path
      Bytes = (Get-Item -LiteralPath $Path).Length
      Files = $entries.Count
      Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
      Audit = 'PASS'
    }
  } finally {
    $archive.Dispose()
  }
}

foreach ($path in @($sourceStage, $swiftStage)) {
  if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  New-Item -ItemType Directory -Path $path | Out-Null
}

try {
  Copy-CleanTree -Source $root -Destination $sourceStage
  Copy-CleanTree -Source $swiftRoot -Destination $swiftStage

  & powershell -ExecutionPolicy Bypass -File $sensitiveScan -RootPath $sourceStage
  & powershell -ExecutionPolicy Bypass -File $sensitiveScan -RootPath $swiftStage

  foreach ($zip in @($masterZip, $webZip, $swiftZip)) {
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
  }

  [System.IO.Compression.ZipFile]::CreateFromDirectory($sourceStage, $masterZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
  [System.IO.Compression.ZipFile]::CreateFromDirectory($webRoot, $webZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
  [System.IO.Compression.ZipFile]::CreateFromDirectory($swiftStage, $swiftZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)

  & powershell -ExecutionPolicy Bypass -File $sensitiveScan -RootPath $sourceStage -ArchivePath $masterZip
  & powershell -ExecutionPolicy Bypass -File $sensitiveScan -RootPath $webRoot -ArchivePath $webZip
  & powershell -ExecutionPolicy Bypass -File $sensitiveScan -RootPath $swiftStage -ArchivePath $swiftZip

  Get-ZipResult -Path $masterZip -Kind 'master'
  Get-ZipResult -Path $webZip -Kind 'web'
  Get-ZipResult -Path $swiftZip -Kind 'swift'
} finally {
  foreach ($path in @($sourceStage, $swiftStage)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  }
}
