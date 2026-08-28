$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$swiftRoot = (Resolve-Path (Join-Path $root 'swift_mort')).Path
$webRoot = (Resolve-Path (Join-Path $root 'flutter_mort\build\web')).Path
$masterZip = Join-Path $root 'mort-mission-pilot-independence-master-clean.zip'
$webZip = Join-Path $root 'mort-web-mission-pilot-independence.zip'
$swiftZip = Join-Path $root 'mort-swiftui-mission-pilot-independence-clean.zip'
$sourceStage = Join-Path $root '.delivery-stage-mission-pilot-source'
$swiftStage = Join-Path $root '.delivery-stage-mission-pilot-swift'
$sensitiveScan = Join-Path $PSScriptRoot 'sensitive-file-scan.ps1'

$excludedSegments = @(
  'node_modules', '.expo', '.supabase-cli-config', '.dart_tool', '.git',
  '.idea', '.vscode', 'build', 'dist', 'logs', 'backups', 'coverage',
  'outputs', 'DerivedData', 'Pods', 'ephemeral', '.symlinks', '.temp',
  'secrets', '.delivery-stage-mission-pilot-source',
  '.delivery-stage-mission-pilot-swift'
)

function Assert-WorkspacePath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  $prefix = $root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a path outside the workspace: $full"
  }
}

function Test-CleanSourceFile {
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
  if ($File.Extension -in @(
    '.zip', '.log', '.pem', '.p12', '.pfx', '.key', '.mobileprovision',
    '.sqlite', '.sqlite3', '.db', '.dump', '.bak'
  )) { return $false }
  return $true
}

function Copy-CleanTree {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )
  foreach ($file in Get-ChildItem -LiteralPath $Source -Recurse -File -Force) {
    if (-not (Test-CleanSourceFile -File $file -BasePath $Source)) { continue }
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
  try { return [BitConverter]::ToString($sha.ComputeHash($Stream)).Replace('-', '') }
  finally { $sha.Dispose() }
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
        throw "Archive entry has no staged source: $($entry.FullName)"
      }
      $entryStream = $entry.Open()
      $sourceStream = [System.IO.File]::OpenRead($source)
      try {
        if ((Get-StreamHash $entryStream) -ne (Get-StreamHash $sourceStream)) {
          throw "Archive/source byte mismatch: $($entry.FullName)"
        }
      } finally {
        $sourceStream.Dispose()
        $entryStream.Dispose()
      }
    }
  } finally { $archive.Dispose() }
}

function Get-ArchiveResult {
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
      $_ -match '\.(zip|log|pem|p12|pfx|key|mobileprovision|sqlite|sqlite3|db|dump|bak)$'
    })
    if ($forbidden.Count -gt 0) { throw "Forbidden $Kind archive entries: $($forbidden -join ', ')" }

    $required = switch ($Kind) {
      'master' { @(
        'docs/MORT_MISSION_AND_SOCIAL_IMPACT.md',
        'docs/MORT_CLOSED_PILOT_OPERATING_MODEL.md',
        'docs/MORT_SENSITIVE_DOCUMENT_VAULT.md',
        'docs/MORT_MISSION_PILOT_IMPLEMENTATION_RESULTS.md',
        'supabase/migrations/20260719012241_mission_closed_pilot_independence.sql',
        'supabase/migrations/20260719031115_mission_pilot_lint_fixes.sql',
        'supabase/functions/document-vault-access/index.ts',
        'scripts/qa-closed-pilot-access.mjs',
        'scripts/audit-mission-pilot-remote.mjs',
        'swift_mort/MORT/Features/Mission/MissionPilotViews.swift',
        'flutter_mort/lib/features/mission/mission_pilot_screens.dart'
      ) }
      'web' { @('index.html', 'manifest.json', 'flutter_bootstrap.js', 'main.dart.js') }
      'swift' { @(
        'MORT.xcodeproj/project.pbxproj',
        'MORT/App/MORTApp.swift',
        'MORT/Models/MissionPilot.swift',
        'MORT/Repositories/MissionPilotRepository.swift',
        'MORT/Features/Mission/MissionPilotViews.swift',
        'MORTTests/MissionPilotContractTests.swift'
      ) }
    }
    foreach ($item in $required) {
      if ($names -notcontains $item) { throw "$Kind archive is missing $item" }
    }
    if ($Kind -eq 'web' -and ($names | Where-Object { $_ -match '(^|/)(lib|test|supabase|scripts|docs)(/|$)' })) {
      throw 'Web archive contains source directories.'
    }
    if ($Kind -eq 'swift' -and ($names | Where-Object { $_ -match '(^|/)(flutter_mort|node_modules|supabase)(/|$)' })) {
      throw 'Swift archive contains a non-Swift project tree.'
    }
    $count = $entries.Count
  } finally { $archive.Dispose() }

  Assert-ArchiveMatchesTree -ArchivePath $Path -TreeRoot $SourceTree
  [pscustomobject]@{
    Kind = $Kind
    Path = $Path
    Bytes = (Get-Item -LiteralPath $Path).Length
    Files = $count
    Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    ForbiddenEntryAudit = 'PASS'
    SecretValueAudit = 'PASS'
    SensitiveIdentityAudit = 'PASS'
    ByteComparison = 'PASS'
  }
}

foreach ($path in @($masterZip, $webZip, $swiftZip, $sourceStage, $swiftStage)) {
  Assert-WorkspacePath -Path $path
}

foreach ($path in @($sourceStage, $swiftStage)) {
  if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  New-Item -ItemType Directory -Path $path | Out-Null
}

try {
  Copy-CleanTree -Source $root -Destination $sourceStage
  Copy-CleanTree -Source $swiftRoot -Destination $swiftStage

  & powershell -ExecutionPolicy Bypass -File $sensitiveScan -RootPath $sourceStage
  if ($LASTEXITCODE -ne 0) { throw 'Source-stage sensitive-file scan failed.' }
  & powershell -ExecutionPolicy Bypass -File $sensitiveScan -RootPath $swiftStage
  if ($LASTEXITCODE -ne 0) { throw 'Swift-stage sensitive-file scan failed.' }

  foreach ($zip in @($masterZip, $webZip, $swiftZip)) {
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
  }
  [System.IO.Compression.ZipFile]::CreateFromDirectory($sourceStage, $masterZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
  [System.IO.Compression.ZipFile]::CreateFromDirectory($webRoot, $webZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
  [System.IO.Compression.ZipFile]::CreateFromDirectory($swiftStage, $swiftZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)

  & powershell -ExecutionPolicy Bypass -File $sensitiveScan -RootPath $sourceStage -ArchivePath $masterZip
  if ($LASTEXITCODE -ne 0) { throw 'Master archive sensitive-file scan failed.' }
  & powershell -ExecutionPolicy Bypass -File $sensitiveScan -RootPath $webRoot -ArchivePath $webZip
  if ($LASTEXITCODE -ne 0) { throw 'Web archive sensitive-file scan failed.' }
  & powershell -ExecutionPolicy Bypass -File $sensitiveScan -RootPath $swiftStage -ArchivePath $swiftZip
  if ($LASTEXITCODE -ne 0) { throw 'Swift archive sensitive-file scan failed.' }

  @(
    Get-ArchiveResult -Path $masterZip -Kind master -SourceTree $sourceStage
    Get-ArchiveResult -Path $webZip -Kind web -SourceTree $webRoot
    Get-ArchiveResult -Path $swiftZip -Kind swift -SourceTree $swiftStage
  ) | Format-List
} finally {
  foreach ($path in @($sourceStage, $swiftStage)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  }
}
