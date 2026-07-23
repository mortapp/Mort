[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifacts = Join-Path $root 'artifacts'
$stageRoot = Join-Path $root 'build\package-0.9.4'

function Assert-WorkspaceChild {
  param([Parameter(Mandatory = $true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  $prefix = $root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a package path outside the workspace: $full"
  }
}

Assert-WorkspaceChild $artifacts
Assert-WorkspaceChild $stageRoot
if (Test-Path -LiteralPath $stageRoot) {
  Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $artifacts, $stageRoot | Out-Null

$excludedSegments = @(
  '.git', '.dart_tool', '.expo', '.gradle', '.idea', '.supabase-cli-config',
  '.temp', '.vscode', 'artifacts', 'backups', 'build', 'coverage',
  'DerivedData', 'dist', 'ephemeral', 'logs', 'node_modules', 'outputs',
  'Pods', '.symlinks'
)
$forbiddenNames = @(
  '.env', '.env.local', '.env.production', '.flutter-plugins-dependencies',
  'GeneratedPluginRegistrant.java', 'key.properties', 'local.properties'
)
$forbiddenExtensions = @(
  '.aab', '.apk', '.bak', '.db', '.dump', '.jks', '.key', '.keystore',
  '.log', '.mobileprovision', '.p12', '.pem', '.pfx', '.sqlite', '.sqlite3', '.zip'
)

function Test-SourceFileAllowed {
  param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)
  $relative = $File.FullName.Substring($root.Length + 1)
  foreach ($segment in ($relative -split '[\\/]')) {
    if ($excludedSegments -contains $segment) { return $false }
  }
  if ($forbiddenNames -contains $File.Name) { return $false }
  if ($File.Name -match '^\.env\.' -and $File.Name -notmatch '^\.env\.(example|sample|template)$') {
    return $false
  }
  if ($forbiddenExtensions -contains $File.Extension.ToLowerInvariant()) { return $false }
  return $true
}

function Copy-RelativeFile {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$DestinationRoot
  )
  $source = Join-Path $root $RelativePath
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Required package file is missing: $RelativePath"
  }
  $file = Get-Item -LiteralPath $source
  if (-not (Test-SourceFileAllowed $file)) {
    throw "Selected package file violates clean-source rules: $RelativePath"
  }
  $destination = Join-Path $DestinationRoot $RelativePath
  New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force
}

function Copy-RelativeTree {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$DestinationRoot
  )
  $source = Join-Path $root $RelativePath
  if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Required package directory is missing: $RelativePath"
  }
  foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File -Force) {
    if (-not (Test-SourceFileAllowed $file)) { continue }
    Copy-RelativeFile -RelativePath $file.FullName.Substring($root.Length + 1) -DestinationRoot $DestinationRoot
  }
}

function New-SelectedPackage {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string[]]$Files = @(),
    [string[]]$Trees = @()
  )
  $stage = Join-Path $stageRoot $Name
  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  foreach ($file in $Files) { Copy-RelativeFile -RelativePath $file -DestinationRoot $stage }
  foreach ($tree in $Trees) { Copy-RelativeTree -RelativePath $tree -DestinationRoot $stage }
  $zip = Join-Path $artifacts "$Name.zip"
  if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
  [System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stage, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false
  )
  return $zip
}

$sourceStage = Join-Path $stageRoot 'mort-android-0.9.4-final-source-clean'
New-Item -ItemType Directory -Force -Path $sourceStage | Out-Null
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
  if (-not (Test-SourceFileAllowed $file)) { continue }
  Copy-RelativeFile -RelativePath $file.FullName.Substring($root.Length + 1) -DestinationRoot $sourceStage
}
$sourceZip = Join-Path $artifacts 'mort-android-0.9.4-final-source-clean.zip'
if (Test-Path -LiteralPath $sourceZip) { Remove-Item -LiteralPath $sourceZip -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory(
  $sourceStage, $sourceZip, [System.IO.Compression.CompressionLevel]::Optimal, $false
)

$evidenceZip = New-SelectedPackage -Name 'mort-0.9.4-test-evidence' -Files @(
  'docs\MORT_0_9_4_GAP_MATRIX.md',
  'docs\MORT_ANDROID_EMULATOR_EVIDENCE_0_9_4.md',
  'docs\MORT_COMPLETION_SCORE.md',
  'docs\MORT_SECURITY_DELTA_0_9_3_TO_0_9_4.md',
  'docs\MORT_STRIPE_TESTMODE_END_TO_END_0_9_4.md',
  'docs\play-final\MORT_COMMAND_RESULTS_0_9_4.md',
  'docs\release\MORT_ROUTE_ACTION_INVENTORY_0_9_4.csv',
  'docs\release\MORT_ROUTE_ACTION_INVENTORY_0_9_4.json',
  'docs\release\MORT_ROUTE_ACTION_INVENTORY_0_9_4.md'
)

$stripeZip = New-SelectedPackage -Name 'mort-stripe-testmode-evidence-0.9.4' -Files @(
  'docs\MORT_STRIPE_TESTMODE_END_TO_END_0_9_4.md',
  'docs\MORT_PAYMENT_ARCHITECTURE_DECISION.md',
  'docs\MORT_PAYMENT_STATE_MACHINE.md',
  'docs\MORT_PAYMENT_TEST_REPORT.md',
  'scripts\stripe-qa-suites.mjs',
  'scripts\qa-payment-resolution-boundary.mjs',
  'scripts\qa-payment-operations-queue-boundary.mjs'
) -Trees @(
  'flutter_mort\lib\features\payments',
  'supabase\functions\stripe-config',
  'supabase\functions\stripe-create-connected-account',
  'supabase\functions\stripe-create-job-payment-intent',
  'supabase\functions\stripe-create-job-refund',
  'supabase\functions\stripe-create-job-transfer',
  'supabase\functions\stripe-create-onboarding-link',
  'supabase\functions\stripe-get-connected-account-status',
  'supabase\functions\stripe-resolve-job-payment',
  'supabase\functions\stripe-webhook'
)

$playZip = New-SelectedPackage -Name 'mort-play-review-package-0.9.4' -Files @(
  'docs\MORT_ANDROID_EMULATOR_EVIDENCE_0_9_4.md',
  'docs\MORT_COMPLETION_SCORE.md',
  'docs\MORT_RELEASE_READINESS.md',
  'docs\MORT_SECURITY_DELTA_0_9_3_TO_0_9_4.md',
  'scripts\android-lint-release.ps1',
  'scripts\qa-android-apk.ps1',
  'scripts\verify-play-aab.ps1'
) -Trees @('docs\play-final')

$docsZip = New-SelectedPackage -Name 'mort-documentation-0.9.4' -Trees @('docs')

$supportPinZip = New-SelectedPackage -Name 'mort-support-pin-evidence-0.9.4' -Files @(
  'docs\MORT_SUPPORT_SYSTEM.md',
  'docs\MORT_PIN_JOB_VERIFICATION.md',
  'docs\MORT_JOB_STATE_MACHINE.md',
  'docs\MORT_OPERATIONAL_RUNBOOKS_0_9_4.md',
  'scripts\qa-support-cross-user-isolation.mjs',
  'scripts\qa-support-staff-forgery.mjs',
  'scripts\qa-evidence-isolation.mjs',
  'scripts\qa-job-start-funding-gate.mjs',
  'scripts\qa-job-pin-replay-lock.mjs',
  'scripts\qa-abandonment-safety-cooldown.mjs'
)

$apk = Join-Path $artifacts 'mort-android-0.9.4-final-qa.apk'
$aab = Join-Path $artifacts 'mort-android-0.9.4-closed-test.aab'
Copy-Item -LiteralPath (Join-Path $root 'mort-play-production-pilot-final-qa.apk') -Destination $apk -Force
Copy-Item -LiteralPath (Join-Path $root 'mort-play-production-pilot-final.aab') -Destination $aab -Force

$secretNames = @(
  'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD',
  'MORT_UPLOAD_STORE_PASSWORD', 'MORT_UPLOAD_KEY_PASSWORD',
  'REVENUECAT_V1_SECRET_API_KEY', 'REVENUECAT_WEBHOOK_AUTH_HEADER',
  'SEND_PUSH_INVOKE_SECRET', 'OPENAI_API_KEY', 'STRIPE_TEST_SECRET_KEY',
  'STRIPE_LIVE_SECRET_KEY', 'STRIPE_TEST_WEBHOOK_SECRET'
)
$secretValues = @()
foreach ($name in $secretNames) {
  $value = [Environment]::GetEnvironmentVariable($name, 'Process')
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($name, 'User')
  }
  if (-not [string]::IsNullOrWhiteSpace($value) -and $value.Length -ge 8) {
    $secretValues += $value
  }
}

function Get-ArtifactRecord {
  param([Parameter(Mandatory = $true)][string]$Path)
  $file = Get-Item -LiteralPath $Path
  $fileCount = 1
  if ($file.Extension -eq '.zip') {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
    try {
      $entries = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
      $fileCount = $entries.Count
      foreach ($entry in $entries) {
        $normalized = $entry.FullName.Replace('\', '/')
        if ($normalized -match '(^|/)(node_modules|\.dart_tool|\.expo|\.git|\.gradle|artifacts|backups|build|dist|logs)(/|$)' -or
            ($normalized -match '(^|/)\.env($|\.)' -and $normalized -notmatch '(^|/)\.env\.(example|sample|template)$') -or
            [System.IO.Path]::GetExtension($normalized).ToLowerInvariant() -in @('.jks', '.keystore', '.p12', '.pem', '.key', '.log')) {
          throw "Forbidden archive entry: $normalized"
        }
        if ($entry.Length -le 25MB) {
          $stream = $entry.Open()
          $memory = New-Object System.IO.MemoryStream
          try {
            $stream.CopyTo($memory)
            $content = $memory.ToArray()
            foreach ($secret in $secretValues) {
              $needle = [System.Text.Encoding]::UTF8.GetBytes($secret)
              $text = [System.Text.Encoding]::UTF8.GetString($content)
              if ($text.Contains($secret)) { throw "Sensitive environment value found in $normalized" }
            }
          } finally {
            $memory.Dispose()
            $stream.Dispose()
          }
        }
      }
    } finally {
      $archive.Dispose()
    }
  }
  [pscustomobject]@{
    name = $file.Name
    path = $file.FullName
    bytes = $file.Length
    files = $fileCount
    sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    secret_values_checked = $secretValues.Count
  }
}

$records = @(
  $sourceZip, $evidenceZip, $stripeZip, $playZip, $docsZip, $supportPinZip, $apk, $aab
) | ForEach-Object { Get-ArtifactRecord -Path $_ }

$records | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $artifacts 'MORT_0_9_4_ARTIFACT_INVENTORY.json') -Encoding utf8
$records | ForEach-Object { "$($_.sha256)  $($_.name)" } |
  Set-Content -LiteralPath (Join-Path $artifacts 'SHA256SUMS.txt') -Encoding ascii
$markdown = @(
  '# MORT 0.9.4 Artifact Inventory',
  '',
  'Generated from the verified local 0.9.4 tree. No production-readiness claim.',
  '',
  '| Artifact | Bytes | Files | SHA-256 |',
  '|---|---:|---:|---|'
) + @($records | ForEach-Object { "| ``$($_.name)`` | $($_.bytes) | $($_.files) | ``$($_.sha256)`` |" })
$markdown | Set-Content -LiteralPath (Join-Path $artifacts 'MORT_0_9_4_ARTIFACT_INVENTORY.md') -Encoding utf8

Assert-WorkspaceChild $stageRoot
Remove-Item -LiteralPath $stageRoot -Recurse -Force
$records | Format-Table name, bytes, files, sha256 -AutoSize
