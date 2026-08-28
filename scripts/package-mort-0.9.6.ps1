[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifacts = Join-Path $root 'artifacts'
$stageParent = Join-Path $root 'build'
$stageRoot = Join-Path $stageParent 'package-0.9.6'

function Assert-WorkspaceChild {
  param([Parameter(Mandatory)][string]$Path)
  $full = [IO.Path]::GetFullPath($Path)
  $prefix = $root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
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
  '.log', '.mobileprovision', '.p12', '.pem', '.pfx', '.sqlite', '.sqlite3',
  '.zip'
)

function Test-SourceFileAllowed {
  param([Parameter(Mandatory)][IO.FileInfo]$File)
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
    [Parameter(Mandatory)][string]$RelativePath,
    [Parameter(Mandatory)][string]$DestinationRoot
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
    [Parameter(Mandatory)][string]$RelativePath,
    [Parameter(Mandatory)][string]$DestinationRoot
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
    [Parameter(Mandatory)][string]$Name,
    [string[]]$Files = @(),
    [string[]]$Trees = @()
  )
  $stage = Join-Path $stageRoot $Name
  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  foreach ($file in $Files) { Copy-RelativeFile -RelativePath $file -DestinationRoot $stage }
  foreach ($tree in $Trees) { Copy-RelativeTree -RelativePath $tree -DestinationRoot $stage }
  $zip = Join-Path $artifacts "$Name.zip"
  if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
  [IO.Compression.ZipFile]::CreateFromDirectory(
    $stage, $zip, [IO.Compression.CompressionLevel]::Optimal, $false
  )
  & (Join-Path $PSScriptRoot 'sensitive-file-scan.ps1') -RootPath $stage -ArchivePath $zip
  return $zip
}

$sourceStage = Join-Path $stageRoot 'mort-android-0.9.6-final-source-clean'
New-Item -ItemType Directory -Force -Path $sourceStage | Out-Null
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
  if (-not (Test-SourceFileAllowed $file)) { continue }
  Copy-RelativeFile -RelativePath $file.FullName.Substring($root.Length + 1) -DestinationRoot $sourceStage
}
$sourceZip = Join-Path $artifacts 'mort-android-0.9.6-final-source-clean.zip'
if (Test-Path -LiteralPath $sourceZip) { Remove-Item -LiteralPath $sourceZip -Force }
[IO.Compression.ZipFile]::CreateFromDirectory(
  $sourceStage, $sourceZip, [IO.Compression.CompressionLevel]::Optimal, $false
)
& (Join-Path $PSScriptRoot 'sensitive-file-scan.ps1') -RootPath $sourceStage -ArchivePath $sourceZip

$googleZip = New-SelectedPackage -Name 'mort-google-auth-evidence-0.9.6' -Files @(
  'docs\MORT_GOOGLE_AUTH_ARCHITECTURE.md',
  'docs\MORT_GOOGLE_AUTH_EXTERNAL_SETUP.md',
  'docs\MORT_GOOGLE_EXTERNAL_ACTION_CHECKLIST_0_9_5.md',
  'flutter_mort\android\app\src\main\AndroidManifest.xml',
  'flutter_mort\ios\Runner\Info.plist',
  'flutter_mort\lib\core\auth\oauth_flow.dart',
  'flutter_mort\lib\features\auth\google_auth_screens.dart',
  'flutter_mort\test\google_auth_contract_test.dart',
  'flutter_mort\test\oauth_flow_test.dart',
  'scripts\qa-google-auth-controls.mjs',
  'supabase\migrations\20260723051250_mort_0_9_5_google_identity_controls.sql'
)

$stripeZip = New-SelectedPackage -Name 'mort-stripe-testmode-evidence-0.9.6' -Files @(
  'docs\MORT_STRIPE_100_TESTMODE_REPORT_0_9_5.md',
  'docs\MORT_PAYMENT_ARCHITECTURE_DECISION.md',
  'docs\MORT_PAYMENT_STATE_MACHINE.md',
  'docs\MORT_PAYMENT_TEST_REPORT.md',
  'scripts\stripe-qa-suites.mjs',
  'scripts\qa-edge-rate-limits.mjs',
  'supabase\migrations\20260723055721_mort_0_9_5_atomic_edge_rate_limits.sql'
) -Trees @(
  'docs\payments',
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

$securityZip = New-SelectedPackage -Name 'mort-security-evidence-0.9.6' -Files @(
  'docs\MORT_SECURITY_100_CODE_CONTROLLED_0_9_5.md',
  'docs\SECURITY_AND_SAFETY.md',
  'scripts\qa-aab-secret-scan.mjs',
  'scripts\qa-aab-signing.mjs',
  'scripts\qa-ai-safety-edge.mjs',
  'scripts\qa-revenuecat-atomic.mjs',
  'scripts\secret-scan-git-history.mjs',
  'scripts\sensitive-file-scan.ps1',
  'supabase\migrations\20260723060321_mort_0_9_5_ai_safety_grants.sql',
  'supabase\migrations\20260723061421_mort_0_9_5_atomic_revenuecat_fulfillment.sql'
) -Trees @('docs\security', 'supabase\functions\ai-safety', 'supabase\functions\revenuecat-webhook')

$supportZip = New-SelectedPackage -Name 'mort-support-admin-jobs-pin-evidence-0.9.6' -Files @(
  'docs\MORT_SUPPORT_SYSTEM.md',
  'docs\MORT_PIN_JOB_VERIFICATION.md',
  'docs\MORT_JOB_STATE_MACHINE.md',
  'scripts\qa-support-cross-user-isolation.mjs',
  'scripts\qa-support-staff-forgery.mjs',
  'scripts\qa-job-pin-replay-lock.mjs',
  'scripts\qa-job-start-funding-gate.mjs'
) -Trees @(
  'flutter_mort\lib\features\admin',
  'flutter_mort\lib\features\jobs',
  'flutter_mort\lib\features\support'
)

$reviewerZip = New-SelectedPackage -Name 'mort-play-reviewer-evidence-0.9.6' -Files @(
  'docs\MORT_PLAY_REVIEWER_SECURITY_ARCHITECTURE_0_9_6.md',
  'docs\MORT_ANDROID_EMULATOR_EVIDENCE_0_9_6.md',
  'docs\play-final\MORT_COMMAND_RESULTS_0_9_6.md',
  'docs\play-final\MORT_PLAY_REVIEWER_ACCESS_0_9_6.md',
  'docs\play-final\MORT_REVIEWER_WALKTHROUGH.md',
  'flutter_mort\lib\core\reviewer\reviewer_session.dart',
  'flutter_mort\lib\features\reviewer\reviewer_screens.dart',
  'flutter_mort\test\play_reviewer_mode_test.dart',
  'scripts\qa-play-reviewer-isolation.mjs',
  'supabase\migrations\20260726024327_reserve_play_reviewer_identifier.sql'
)

$reviewerStage = Join-Path $stageRoot 'mort-play-reviewer-evidence-0.9.6'
$emulatorEvidence = Join-Path $root 'build\emulator-0.9.6'
if (-not (Test-Path -LiteralPath $emulatorEvidence -PathType Container)) {
  throw 'Signed APK emulator evidence is missing from build\emulator-0.9.6.'
}
Copy-Item -LiteralPath $emulatorEvidence -Destination (Join-Path $reviewerStage 'signed-apk-emulator') -Recurse -Force
Remove-Item -LiteralPath $reviewerZip -Force
[IO.Compression.ZipFile]::CreateFromDirectory(
  $reviewerStage, $reviewerZip, [IO.Compression.CompressionLevel]::Optimal, $false
)
& (Join-Path $PSScriptRoot 'sensitive-file-scan.ps1') `
  -RootPath $reviewerStage -ArchivePath $reviewerZip -AllowPlayStoreMedia

$playZip = New-SelectedPackage -Name 'mort-play-review-package-0.9.6' -Files @(
  'docs\MORT_0_9_6_FINAL_REPORT.md',
  'docs\MORT_ANDROID_EMULATOR_EVIDENCE_0_9_6.md',
  'docs\play-final\MORT_COMMAND_RESULTS_0_9_6.md',
  'docs\play-final\MORT_FINAL_CHANGED_FILES_0_9_6.md',
  'docs\play-final\MORT_PLAY_REVIEWER_ACCESS_0_9_6.md',
  'scripts\android-lint-release.ps1',
  'scripts\qa-android-apk.ps1',
  'scripts\verify-play-aab.ps1'
) -Trees @('docs\play-final')

$docsZip = New-SelectedPackage -Name 'mort-documentation-0.9.6' -Trees @('docs')

$apk = Join-Path $artifacts 'mort-android-0.9.6-final-qa.apk'
$aab = Join-Path $artifacts 'mort-android-0.9.6-closed-test.aab'
Copy-Item -LiteralPath (Join-Path $root 'build\play\mort-play-closed-test-qa.apk') -Destination $apk -Force
Copy-Item -LiteralPath (Join-Path $root 'build\play\mort-closed-test.aab') -Destination $aab -Force

$secretNames = @(
  'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD',
  'MORT_UPLOAD_STORE_PASSWORD', 'MORT_UPLOAD_KEY_PASSWORD',
  'REVENUECAT_V1_SECRET_API_KEY', 'REVENUECAT_V2_SECRET_API_KEY',
  'REVENUECAT_WEBHOOK_AUTH_HEADER', 'SEND_PUSH_INVOKE_SECRET', 'OPENAI_API_KEY',
  'STRIPE_TEST_SECRET_KEY', 'STRIPE_LIVE_SECRET_KEY', 'STRIPE_TEST_WEBHOOK_SECRET'
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
  param([Parameter(Mandatory)][string]$Path)
  $file = Get-Item -LiteralPath $Path
  $fileCount = 1
  if ($file.Extension -eq '.zip') {
    $archive = [IO.Compression.ZipFile]::OpenRead($file.FullName)
    try {
      $entries = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
      $fileCount = $entries.Count
      foreach ($entry in $entries) {
        $normalized = $entry.FullName.Replace('\', '/')
        if ($normalized -match '(^|/)(node_modules|\.dart_tool|\.expo|\.git|\.gradle|artifacts|backups|build|dist|logs)(/|$)' -or
            ($normalized -match '(^|/)\.env($|\.)' -and $normalized -notmatch '(^|/)\.env\.(example|sample|template)$') -or
            [IO.Path]::GetExtension($normalized).ToLowerInvariant() -in @('.jks', '.keystore', '.p12', '.pem', '.key', '.log')) {
          throw "Forbidden archive entry: $normalized"
        }
        if ($entry.Length -le 25MB) {
          $stream = $entry.Open()
          $memory = [IO.MemoryStream]::new()
          try {
            $stream.CopyTo($memory)
            $content = [Text.Encoding]::UTF8.GetString($memory.ToArray())
            foreach ($secret in $secretValues) {
              if ($content.Contains($secret)) { throw "Sensitive environment value found in $normalized" }
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
  $sourceZip, $apk, $aab, $reviewerZip, $playZip, $googleZip, $stripeZip,
  $securityZip, $supportZip, $docsZip
) | ForEach-Object { Get-ArtifactRecord -Path $_ }

$inventoryJson = Join-Path $artifacts 'MORT_0_9_6_ARTIFACT_INVENTORY.json'
$inventoryMarkdown = Join-Path $artifacts 'MORT_0_9_6_ARTIFACT_INVENTORY.md'
$checksums = Join-Path $artifacts 'SHA256SUMS.txt'
$records | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $inventoryJson -Encoding utf8
$records | ForEach-Object { "$($_.sha256)  $($_.name)" } |
  Set-Content -LiteralPath $checksums -Encoding ascii
$markdown = @(
  '# MORT 0.9.6 Artifact Inventory',
  '',
  'Generated from the verified 0.9.6 closed-test tree. This is not a production-readiness claim.',
  '',
  '| Artifact | Bytes | Files | SHA-256 |',
  '|---|---:|---:|---|'
) + @($records | ForEach-Object { "| ``$($_.name)`` | $($_.bytes) | $($_.files) | ``$($_.sha256)`` |" })
$markdown | Set-Content -LiteralPath $inventoryMarkdown -Encoding utf8

Assert-WorkspaceChild $stageRoot
Remove-Item -LiteralPath $stageRoot -Recurse -Force
$records | Format-Table name, bytes, files, sha256 -AutoSize
