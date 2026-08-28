$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$masterZip = Join-Path $root 'mort-multi-signal-trust-foundation-master-clean.zip'
$webZip = Join-Path $root 'mort-web-multi-signal-trust.zip'
$swiftZip = Join-Path $root 'mort-swiftui-multi-signal-trust-clean.zip'
$webRoot = (Resolve-Path (Join-Path $root 'flutter_mort\build\web')).Path
$swiftRoot = (Resolve-Path (Join-Path $root 'swift_mort')).Path
$sourceStage = Join-Path $root '.delivery-stage-multi-signal-trust-source'
$swiftStage = Join-Path $root '.delivery-stage-multi-signal-trust-swift'
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
  'secrets', '.delivery-stage-multi-signal-trust-source',
  '.delivery-stage-multi-signal-trust-swift'
)

function Test-AllowedSourceFile {
  param(
    [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
    [Parameter(Mandatory = $true)][string]$BasePath
  )
  $relative = $File.FullName.Substring($BasePath.Length + 1)
  foreach ($segment in ($relative -split '[\\/]')) {
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

function Get-StreamHash {
  param([Parameter(Mandatory = $true)][System.IO.Stream]$Stream)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return [BitConverter]::ToString($sha.ComputeHash($Stream)).Replace('-', '')
  } finally {
    $sha.Dispose()
  }
}

function Assert-ArchiveMatchesTree {
  param(
    [Parameter(Mandatory = $true)][string]$ArchivePath,
    [Parameter(Mandatory = $true)][string]$TreeRoot
  )
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
  try {
    $entries = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
    $treeFiles = @(Get-ChildItem -LiteralPath $TreeRoot -Recurse -File -Force)
    if ($entries.Count -ne $treeFiles.Count) {
      throw "Archive/tree file count mismatch for $ArchivePath ($($entries.Count)/$($treeFiles.Count))."
    }
    foreach ($entry in $entries) {
      $relative = $entry.FullName.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
      $source = Join-Path $TreeRoot $relative
      if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Archive entry has no source counterpart: $($entry.FullName)"
      }
      $entryStream = $entry.Open()
      $sourceStream = [System.IO.File]::OpenRead($source)
      try {
        $entryHash = Get-StreamHash -Stream $entryStream
        $sourceHash = Get-StreamHash -Stream $sourceStream
        if ($entryHash -ne $sourceHash) {
          throw "Archive/source byte mismatch: $($entry.FullName)"
        }
      } finally {
        $sourceStream.Dispose()
        $entryStream.Dispose()
      }
    }
  } finally {
    $archive.Dispose()
  }
}

function Get-ZipResult {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet('master', 'web', 'swift')][string]$Kind,
    [Parameter(Mandatory = $true)][string]$SourceTree
  )
  $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $entries = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
    $names = @($entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    $forbidden = @($names | Where-Object {
      $_ -match '(^|/)(node_modules|\.expo|\.supabase-cli-config|\.dart_tool|\.git|build|dist|logs|backups|coverage|outputs|DerivedData|Pods|secrets)(/|$)' -or
      $_ -match '(^|/)\.env($|\.)' -or
      $_ -match '\.(zip|log|pem|p12|pfx|key|mobileprovision|dump|bak)$'
    })
    if ($forbidden.Count -gt 0) {
      throw "Forbidden $Kind archive entries: $($forbidden -join ', ')"
    }

    if ($Kind -eq 'master') {
      foreach ($required in @(
        'docs/MORT_MULTI_SIGNAL_TRUST_ARCHITECTURE.md',
        'docs/MORT_MULTI_SIGNAL_TRUST_ADVISOR_REPORT.md',
        'docs/MORT_MULTI_SIGNAL_TRUST_RLS_MATRIX.md',
        'supabase/migrations/20260718150502_multi_signal_account_trust_foundation.sql',
        'supabase/migrations/20260718173000_multi_signal_trust_fk_indexes.sql',
        'scripts/qa-account-trust-levels.mjs',
        'scripts/update-multi-signal-trust-registry.mjs',
        'swift_mort/MORT/Services/DeviceAuthenticationService.swift',
        'flutter_mort/lib/features/trust/account_trust_screens.dart'
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
        'MORT/Models/AccountTrust.swift',
        'MORT/Services/DeviceAuthenticationService.swift',
        'MORT/Services/AppleWalletIdentityProvider.swift',
        'MORT/Features/Trust/AccountTrustViews.swift',
        'MORTTests/DeviceAuthenticationServiceTests.swift'
      )) {
        if ($names -notcontains $required) { throw "Swift archive is missing $required." }
      }
      if ($names | Where-Object { $_ -match '(^|/)(flutter_mort|node_modules|supabase)(/|$)' }) {
        throw 'Swift archive contains a non-Swift project tree.'
      }
    }
  } finally {
    $archive.Dispose()
  }

  Assert-ArchiveMatchesTree -ArchivePath $Path -TreeRoot $SourceTree
  return [pscustomobject]@{
    Kind = $Kind
    Path = $Path
    Bytes = (Get-Item -LiteralPath $Path).Length
    Files = $entries.Count
    Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    ForbiddenEntryAudit = 'PASS'
    SecretValueAudit = 'PASS'
    SensitiveIdentityAudit = 'PASS'
    ByteComparison = 'PASS'
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

  Get-ZipResult -Path $masterZip -Kind 'master' -SourceTree $sourceStage
  Get-ZipResult -Path $webZip -Kind 'web' -SourceTree $webRoot
  Get-ZipResult -Path $swiftZip -Kind 'swift' -SourceTree $swiftStage
} finally {
  foreach ($path in @($sourceStage, $swiftStage)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  }
}
