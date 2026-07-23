$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$masterZip = Join-Path $root 'mort-legal-liveness-payment-trust-master-clean.zip'
$webZip = Join-Path $root 'mort-web-legal-liveness-payment-trust.zip'
$swiftZip = Join-Path $root 'mort-swiftui-legal-liveness-payment-trust-clean.zip'
$webRoot = (Resolve-Path (Join-Path $root 'flutter_mort\build\web')).Path
$swiftRoot = (Resolve-Path (Join-Path $root 'swift_mort')).Path
$sourceStage = Join-Path $root '.delivery-stage-legal-trust-source'
$swiftStage = Join-Path $root '.delivery-stage-legal-trust-swift'
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
  '.idea', '.vscode', '.swiftpm', '.netlify', '.vercel', 'build', 'dist',
  'logs', 'backups', 'coverage', 'outputs', 'DerivedData', 'Pods',
  'ephemeral', '.symlinks', '.temp', 'secrets'
)
$excludedNames = @(
  '.DS_Store', 'Thumbs.db', 'Secrets.xcconfig', '.flutter-plugins',
  '.flutter-plugins-dependencies'
)
$forbiddenExtensions = @(
  '.zip', '.7z', '.tar', '.gz', '.log', '.pem', '.p12', '.pfx', '.key',
  '.mobileprovision', '.dump', '.bak', '.sqlite', '.sqlite3', '.db'
)
$sensitiveMediaExtensions = @(
  '.jpg', '.jpeg', '.png', '.heic', '.tif', '.tiff', '.webp', '.pdf',
  '.mov', '.mp4', '.m4v', '.avi', '.webm', '.npy', '.face', '.embedding'
)
$sensitiveNamePattern = '(?i)(passport|driver.?licen[cs]e|government.?id|school.?id|student.?id|selfie|face.?video|liveness.?capture|biometric.?template|identity.?evidence|identity.?document|residential.?address|court.?document|group.?chat.?export|payment.?dispute.?evidence|incident.?evidence)'
$allowedAppMediaPattern = '(?i)(favicon\.png$|icons/Icon(?:-maskable)?-(192|512)\.png$|Assets\.xcassets/(AppIcon\.appiconset|LaunchImage\.imageset)/.+\.png$|android/app/src/main/res/mipmap-[^/]+/ic_launcher\.png$|assets/notification-icon\.png$)'

function Test-ExcludedRelativePath {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  foreach ($segment in ($RelativePath -split '[\\/]')) {
    if ($excludedSegments -contains $segment -or $segment -like '.delivery-stage-*') { return $true }
  }
  return $false
}

function Test-AllowedSourceFile {
  param(
    [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
    [Parameter(Mandatory = $true)][string]$BasePath
  )
  $relative = $File.FullName.Substring($BasePath.Length + 1)
  if (Test-ExcludedRelativePath -RelativePath $relative) { return $false }
  if ($File.Name -match '^\.env($|\.)') { return $false }
  if ($excludedNames -contains $File.Name) { return $false }
  if ($forbiddenExtensions -contains $File.Extension.ToLowerInvariant()) { return $false }
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
        throw "Archive entry has no source counterpart: $($entry.FullName)"
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

function Get-EnvironmentValue {
  param([Parameter(Mandatory = $true)][string]$Name)
  $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, 'User')
  }
  return $value
}

function Assert-ArchiveContent {
  param(
    [Parameter(Mandatory = $true)][System.IO.Compression.ZipArchive]$Archive,
    [Parameter(Mandatory = $true)][string]$Kind
  )
  $allowedAnonKey = Get-EnvironmentValue -Name 'EXPO_PUBLIC_SUPABASE_ANON_KEY'
  $jwtPattern = 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
  $privateKeyPattern = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
  $tokenPattern = '(?:sbp_|sk_live_|sk_test_)[A-Za-z0-9_-]{20,}'

  foreach ($entry in $Archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') }) {
    $normalized = $entry.FullName.Replace('\', '/')
    $extension = [System.IO.Path]::GetExtension($entry.Name).ToLowerInvariant()
    if ($sensitiveMediaExtensions -contains $extension -and
        $normalized -match $sensitiveNamePattern -and
        $normalized -notmatch $allowedAppMediaPattern) {
      throw "Sensitive identity, biometric, incident, or legal-evidence media found in $Kind archive: $normalized"
    }
    if ($entry.Length -gt 10MB -or $sensitiveMediaExtensions -contains $extension) { continue }
    $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8, $true)
    try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
    if ($content -match $privateKeyPattern) { throw "Private key material found in $Kind archive entry: $normalized" }
    if ($content -match $tokenPattern) { throw "Secret-token pattern found in $Kind archive entry: $normalized" }
    foreach ($match in [regex]::Matches($content, $jwtPattern)) {
      if ([string]::IsNullOrWhiteSpace($allowedAnonKey) -or $match.Value -ne $allowedAnonKey) {
        throw "Non-public JWT found in $Kind archive entry: $normalized"
      }
    }
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
      $_ -match '\.(zip|7z|tar|gz|log|pem|p12|pfx|key|mobileprovision|dump|bak|sqlite|sqlite3|db)$'
    })
    if ($forbidden.Count -gt 0) { throw "Forbidden $Kind archive entries: $($forbidden -join ', ')" }

    if ($Kind -eq 'master') {
      foreach ($required in @(
        'docs/legal-research/MORT_LEGAL_CORPUS_INDEX.json',
        'docs/legal/MORT_TERMS_OF_SERVICE_DRAFT.md',
        'docs/MORT_LEGAL_LIVENESS_PAYMENT_TRUST_IMPLEMENTATION_RESULTS.md',
        'docs/runbooks/MORT_NONPAYMENT_RUNBOOK.md',
        'docs/operations/MORT_REVIEWER_ACCESS_READINESS.md',
        'supabase/migrations/20260719050000_legal_contract_payment_foundation.sql',
        'supabase/migrations/20260719070500_poster_payment_restriction_fk_indexes.sql',
        'scripts/qa-legal-clickwrap.mjs',
        'scripts/update-legal-trust-feature-registry.mjs',
        'swift_mort/MORT/Services/AppLockService.swift',
        'flutter_mort/lib/features/legal/legal_screens.dart'
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
        'MORT/Services/AppLockService.swift',
        'MORT/Features/Settings/LegalCenterView.swift',
        'MORT/Features/Jobs/ContractPaymentViews.swift',
        'MORT/Features/Trust/FirstPartyTrustViews.swift',
        'MORTTests/DeviceAuthenticationServiceTests.swift'
      )) {
        if ($names -notcontains $required) { throw "Swift archive is missing $required." }
      }
      if ($names | Where-Object { $_ -match '(^|/)(flutter_mort|node_modules|supabase)(/|$)' }) {
        throw 'Swift archive contains a non-Swift project tree.'
      }
    }
    Assert-ArchiveContent -Archive $archive -Kind $Kind
  } finally { $archive.Dispose() }

  Assert-ArchiveMatchesTree -ArchivePath $Path -TreeRoot $SourceTree
  return [pscustomobject]@{
    Kind = $Kind
    Path = $Path
    Bytes = (Get-Item -LiteralPath $Path).Length
    Files = $entries.Count
    Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    ForbiddenEntryAudit = 'PASS'
    SecretPatternAudit = 'PASS'
    ExactSecretValueAudit = 'PASS'
    SensitiveIdentityAudit = 'PASS'
    BiometricFileAudit = 'PASS'
    ArchiveWorkspaceComparison = 'PASS'
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
