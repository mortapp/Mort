[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
$versionName = [string]$version.versionName
$versionCode = [string]$version.versionCode
$versionLabel = "$versionName+$versionCode"
$releaseDirectory = Join-Path $root "artifacts\release-$versionLabel"
$apk = Join-Path $root "build\play\mort-closed-test-$versionName.apk"
$aab = Join-Path $root "build\play\mort-closed-test-$versionName.aab"
$apkManifest = Join-Path $root "build\play\mort-closed-test-$versionName-apk-build-manifest.json"
$aabManifest = Join-Path $root "build\play\mort-closed-test-$versionName-aab-build-manifest.json"
$sourceZip = Join-Path $releaseDirectory "mort-supreme-closed-test-$versionLabel-source.zip"
$symbolsDirectory = Join-Path $env:USERPROFILE "MortSymbols\android\$versionLabel"
$symbolsZip = Join-Path $releaseDirectory "mort-android-symbols-$versionLabel.zip"
$manifestPath = Join-Path $releaseDirectory 'MORT_RELEASE_ARTIFACT_MANIFEST.json'
$sbomPath = Join-Path $releaseDirectory 'MORT_SBOM.cdx.json'
$copiedFinalReport = Join-Path $releaseDirectory 'MORT_SUPREME_FINAL_READINESS_REPORT.md'
$sourceFinalReport = Join-Path $root "docs\MORT_${versionName}_FINAL_READINESS_REPORT.md"

foreach ($required in @($apk, $aab, $apkManifest, $aabManifest, $symbolsDirectory, $sourceFinalReport)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required release input is missing: $required"
  }
}

New-Item -ItemType Directory -Force -Path $releaseDirectory | Out-Null
foreach ($staleGeneratedFile in @($manifestPath, $copiedFinalReport)) {
  if (Test-Path -LiteralPath $staleGeneratedFile -PathType Leaf) {
    Remove-Item -LiteralPath $staleGeneratedFile -Force
  }
}
Copy-Item -LiteralPath $apk, $aab, $apkManifest, $aabManifest -Destination $releaseDirectory -Force
$releaseReportsDirectory = Join-Path $releaseDirectory 'reports'
New-Item -ItemType Directory -Force -Path $releaseReportsDirectory | Out-Null
Get-ChildItem -LiteralPath (Join-Path $root 'build\play\reports') -File |
  Where-Object { $_.Name -notmatch '^emulator-' } |
  Copy-Item -Destination $releaseReportsDirectory -Force
Copy-Item -LiteralPath (Join-Path $root 'docs\play-final\MORT_CLOSED_TEST_RELEASE_NOTES.txt') -Destination $releaseDirectory -Force
Copy-Item -LiteralPath (Join-Path $root 'docs\device-test\MORT_DEVICE_TESTER_INSTRUCTIONS.md') -Destination $releaseDirectory -Force
Copy-Item -LiteralPath (Join-Path $root 'docs\play-final\MORT_REVIEWER_WALKTHROUGH.md') -Destination $releaseDirectory -Force
Copy-Item -LiteralPath (Join-Path $root 'docs\play-final\MORT_DATA_SAFETY_FINAL_WORKBOOK.md') -Destination $releaseDirectory -Force
Copy-Item -LiteralPath (Join-Path $root 'docs\mobile\MORT_UPLOAD_CERTIFICATE_REPORT.md') -Destination $releaseDirectory -Force
Copy-Item -LiteralPath $sourceFinalReport -Destination $copiedFinalReport -Force

& node (Join-Path $PSScriptRoot 'generate-release-sbom.mjs') --output $sbomPath
if ($LASTEXITCODE -ne 0) { throw 'Dependency inventory generation failed.' }
if (-not (Test-Path -LiteralPath $sbomPath -PathType Leaf)) {
  throw 'Dependency inventory was not written to the current release directory.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
foreach ($zipPath in @($sourceZip, $symbolsZip)) {
  if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
    Remove-Item -LiteralPath $zipPath -Force
  }
}

$excludedDirectoryNames = @(
  '.git', '.dart_tool', '.expo', '.gradle', '.idea', '.vscode',
  'node_modules', 'build', 'dist', 'backups', 'logs', 'coverage',
  'Pods', 'DerivedData', 'artifacts', 'temp_old_zip', 'temp_zip',
  'RorkIOSManualCopy'
)
$excludedFileNames = @(
  '.env', '.env.local', 'key.properties',
  'mort-upload-key.credentials.xml',
  'MORT_SUPREME_FINAL_READINESS_REPORT.md',
  'public-config.js'
)
$excludedExtensions = @(
  '.zip', '.jks', '.keystore', '.p12', '.pfx', '.mobileprovision',
  '.apk', '.aab', '.log', '.tmp'
)

$archive = [IO.Compression.ZipFile]::Open($sourceZip, [IO.Compression.ZipArchiveMode]::Create)
$sourceFileCount = 0
try {
  foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
    if (-not $file.FullName.StartsWith("$root\", [StringComparison]::OrdinalIgnoreCase)) {
      throw "Packaging traversal escaped the repository root: $($file.FullName)"
    }
    $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    if ($relative -match '(?i)^qa/recordings(?:/|$)') { continue }
    $segments = $relative.Split('/')
    if (@($segments | Where-Object { $excludedDirectoryNames -contains $_ }).Count -gt 0) { continue }
    if ($excludedFileNames -contains $file.Name) { continue }
    if ($file.Name -match '^\.env\.' -and $file.Name -ne '.env.example') { continue }
    if ($excludedExtensions -contains $file.Extension.ToLowerInvariant()) { continue }
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $archive,
      $file.FullName,
      $relative,
      [IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
    $sourceFileCount += 1
  }
} finally {
  $archive.Dispose()
}

[IO.Compression.ZipFile]::CreateFromDirectory(
  $symbolsDirectory,
  $symbolsZip,
  [IO.Compression.CompressionLevel]::Optimal,
  $false
)

$forbiddenNamePattern = '(^|/)(\.env($|\.)|key\.properties$)|\.(jks|keystore|p12|pfx|mobileprovision)$'
$jwtPattern = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'
$auditArchive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
$jwtHitPaths = @()
$forbiddenNamePaths = @()
try {
  foreach ($entry in $auditArchive.Entries) {
    if ($entry.FullName -match $forbiddenNamePattern -and
        $entry.Name -notmatch '^\.env\.(example|sample|template)$') {
      $forbiddenNamePaths += $entry.FullName
    }
    if ($entry.Length -gt 5MB -or $entry.FullName -match '\.(png|jpg|jpeg|gif|webp|ico|pdf)$') { continue }
    $reader = [IO.StreamReader]::new($entry.Open())
    try {
      if ($reader.ReadToEnd() -match $jwtPattern) { $jwtHitPaths += $entry.FullName }
    } finally {
      $reader.Dispose()
    }
  }
} finally {
  $auditArchive.Dispose()
}
if ($forbiddenNamePaths.Count -ne 0 -or $jwtHitPaths.Count -ne 0) {
  $forbiddenNamePaths | ForEach-Object { Write-Output "FORBIDDEN_ARCHIVE_NAME=$_" }
  $jwtHitPaths | ForEach-Object { Write-Output "JWT_SHAPED_VALUE_ENTRY=$_" }
  throw "Source ZIP audit failed: forbidden_names=$($forbiddenNamePaths.Count) jwt_values=$($jwtHitPaths.Count)"
}

$artifacts = Get-ChildItem -LiteralPath $releaseDirectory -File | Sort-Object Name | ForEach-Object {
  [ordered]@{
    name = $_.Name
    sizeBytes = $_.Length
    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
  }
}
$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  release = $versionLabel
  profile = 'closed_test'
  publicMarketplace = $false
  sourceZipFileCount = $sourceFileCount
  sourceZipAudit = [ordered]@{
    forbiddenFileNames = 0
    jwtValues = 0
    envFilesIncluded = $false
    secretsIncluded = $false
  }
  artifacts = $artifacts
}
[IO.File]::WriteAllText(
  $manifestPath,
  ($manifest | ConvertTo-Json -Depth 5),
  [Text.UTF8Encoding]::new($false)
)

Write-Output "RELEASE_DIRECTORY=$releaseDirectory"
Write-Output "SOURCE_ZIP=$sourceZip"
Write-Output "SOURCE_ZIP_FILES=$sourceFileCount"
Write-Output "SOURCE_ZIP_BYTES=$((Get-Item -LiteralPath $sourceZip).Length)"
Write-Output "SOURCE_ZIP_SECRET_AUDIT=PASS"
Write-Output "SYMBOLS_ZIP=$symbolsZip"
Write-Output "ARTIFACT_MANIFEST=$manifestPath"
