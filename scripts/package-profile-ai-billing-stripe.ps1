param(
  [string]$Root = (Split-Path $PSScriptRoot -Parent),
  [switch]$SourceOnly,
  [switch]$ReplaceOwnSourceArtifacts
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Root = (Resolve-Path -LiteralPath $Root).Path
$blockedSegments = @(
  '.git', '.expo', '.dart_tool', '.gradle', '.idea', '.temp', '.supabase-cli-config',
  'node_modules', 'build', 'dist', 'logs', 'backups', 'coverage', 'Pods',
  'DerivedData', '.symlinks', 'ephemeral', 'outputs'
)
$blockedExtensions = @(
  '.zip', '.aab', '.apk', '.jks', '.keystore', '.pem', '.p12', '.pfx', '.key',
  '.mobileprovision', '.sqlite', '.sqlite3', '.db', '.dump', '.bak'
)

function Get-RelativePath([string]$Path) {
  $full = [IO.Path]::GetFullPath($Path)
  $rootPrefix = $Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Artifact input is outside the MORT root: $full"
  }
  $full.Substring($rootPrefix.Length).Replace('\', '/')
}

function Test-CleanSourceFile([IO.FileInfo]$File) {
  $relative = Get-RelativePath $File.FullName
  $segments = $relative -split '/'
  if (@($segments | Where-Object { $blockedSegments -contains $_ }).Count -gt 0) { return $false }
  if ($blockedExtensions -contains $File.Extension.ToLowerInvariant()) { return $false }
  if ($File.Name -match '^\.env($|\.)' -and $File.Name -notmatch '^\.env\.(example|sample|template)$') { return $false }
  if ($File.Name -in @('local.properties', 'key.properties')) { return $false }
  if ($File.Name -match '(?i)(service.?account|credentials).*\.json$') { return $false }
  if ($File.Name -match '(?i)(passport|driver.?licen[cs]e|government.?id|school.?id|student.?id|selfie|liveness|identity.?evidence|identity.?document|face.?capture|residential.?document)' -and
      $File.Extension -match '(?i)^\.(png|jpg|jpeg|webp|heic|tif|tiff|pdf)$') { return $false }
  return $true
}

function Resolve-RequiredFiles([string[]]$Paths) {
  $resolved = @()
  foreach ($path in $Paths) {
    $full = Join-Path $Root $path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Required artifact input is missing: $path" }
    $resolved += Get-Item -LiteralPath $full
  }
  return @($resolved)
}

function Resolve-TreeFiles([string[]]$Paths) {
  $resolved = @()
  foreach ($path in $Paths) {
    $full = Join-Path $Root $path
    if (-not (Test-Path -LiteralPath $full)) { throw "Required artifact input is missing: $path" }
    if (Test-Path -LiteralPath $full -PathType Leaf) {
      $resolved += Get-Item -LiteralPath $full
    } else {
      $resolved += Get-ChildItem -LiteralPath $full -Recurse -File | Where-Object { Test-CleanSourceFile $_ }
    }
  }
  return @($resolved)
}

function New-MortZip([string]$Name, [IO.FileInfo[]]$Files) {
  $destination = Join-Path $Root $Name
  $exists = Test-Path -LiteralPath $destination
  $replaceAllowed = $ReplaceOwnSourceArtifacts -and $Name -in @(
    'mort-android-profile-ai-billing-final-source-clean.zip',
    'mort-stripe-connect-marketplace-source-clean.zip'
  )
  if ($exists -and -not $replaceAllowed) { throw "Refusing to overwrite existing artifact: $destination" }
  $fileMode = if ($replaceAllowed) { [IO.FileMode]::Create } else { [IO.FileMode]::CreateNew }
  $stream = [IO.File]::Open($destination, $fileMode)
  $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
  try {
    foreach ($file in $Files | Sort-Object FullName -Unique) {
      if (-not (Test-CleanSourceFile $file)) { throw "Forbidden file reached archive input: $(Get-RelativePath $file.FullName)" }
      $entryName = Get-RelativePath $file.FullName
      [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive,
        $file.FullName,
        $entryName,
        [IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }
  } finally {
    $archive.Dispose()
    $stream.Dispose()
  }
  $item = Get-Item -LiteralPath $destination
  $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
  [pscustomobject]@{ Name = $Name; Path = $destination; Bytes = $item.Length; Files = $Files.Count; Sha256 = $hash }
}

function Copy-NewArtifact([string]$Source, [string]$Name) {
  $sourcePath = Join-Path $Root $Source
  $destination = Join-Path $Root $Name
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Build artifact is missing: $Source" }
  if (Test-Path -LiteralPath $destination) { throw "Refusing to overwrite existing artifact: $destination" }
  Copy-Item -LiteralPath $sourcePath -Destination $destination
  $item = Get-Item -LiteralPath $destination
  $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
  [pscustomobject]@{ Name = $Name; Path = $destination; Bytes = $item.Length; Files = 1; Sha256 = $hash }
}

$sourceFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Where-Object { Test-CleanSourceFile $_ })

if ($SourceOnly) {
  if (-not $ReplaceOwnSourceArtifacts) { throw 'SourceOnly refresh requires ReplaceOwnSourceArtifacts.' }
  @(
    New-MortZip 'mort-android-profile-ai-billing-final-source-clean.zip' $sourceFiles
    New-MortZip 'mort-stripe-connect-marketplace-source-clean.zip' $sourceFiles
  ) | ConvertTo-Json -Depth 3
  return
}

$billingFiles = Resolve-TreeFiles @(
  'docs/play-final/MORT_OWNER_CONSOLE_SETUP.md',
  'docs/play-final/MORT_FOUNDER_MANAGER_PERMISSIONS.md',
  'docs/play-final/MORT_BILLING_PRODUCT_SETUP.md',
  'docs/play-final/MORT_LICENSE_TESTER_SETUP.md',
  'supabase/migrations/20260722043000_google_play_billing_foundation.sql',
  'supabase/functions/_shared/google_play.ts',
  'supabase/functions/google-play-verify-purchase',
  'supabase/functions/google-play-rtdn',
  'flutter_mort/lib/features/monetization/data/google_play_billing.dart',
  'flutter_mort/lib/features/monetization/screens/google_play_billing_screens.dart',
  'flutter_mort/test/google_play_billing_contract_test.dart',
  'scripts/qa-billing-entitlement-forgery.mjs',
  'scripts/qa-billing-token-replay.mjs',
  'scripts/qa-billing-review-entitlement.mjs',
  'scripts/qa-billing-free-core.mjs',
  'scripts/qa-paywall-disclosures.mjs'
)

$reviewFiles = Resolve-TreeFiles @('docs/play-final', 'docs/android', 'docs/closed-test', 'docs/device-test')

$aiFiles = Resolve-TreeFiles @(
  'docs/play-final/MORT_AI_PROVIDER_SETUP.md',
  'docs/play-final/MORT_PROFILE_AI_BILLING_RELEASE_RESULTS.md',
  'supabase/migrations/20260722042500_mort_guide_foundation.sql',
  'supabase/functions/ai-support',
  'supabase/functions/ai-safety',
  'flutter_mort/lib/data/repositories/mort_guide_repository.dart',
  'flutter_mort/lib/features/guide/mort_guide_screens.dart',
  'flutter_mort/test/mort_guide_contract_test.dart',
  'scripts/ai-billing-qa-suites.mjs',
  'scripts/qa-ai-mode-gating.mjs',
  'scripts/qa-ai-private-data-boundary.mjs',
  'scripts/qa-ai-input-output-moderation.mjs',
  'scripts/qa-ai-cost-limits.mjs',
  'scripts/qa-ai-minor-consent-gate.mjs',
  'scripts/qa-ai-no-high-stakes-decisions.mjs'
)

$profileFiles = Resolve-TreeFiles @(
  'docs/defects',
  'supabase/migrations/20260722031037_canonical_profile_write_path.sql',
  'flutter_mort/lib/data/models/profile.dart',
  'flutter_mort/lib/data/repositories/profile_repository.dart',
  'flutter_mort/test/profile_persistence_contract_test.dart',
  'scripts/profile-qa-suites.mjs',
  'scripts/qa-profile-update-persistence.mjs',
  'scripts/qa-profile-update-forgery.mjs',
  'scripts/qa-profile-protected-fields.mjs',
  'scripts/qa-profile-cross-user-isolation.mjs',
  'scripts/qa-profile-avatar-storage.mjs',
  'scripts/qa-profile-duplicate-row.mjs',
  'scripts/qa-profile-public-private-projection.mjs'
)

$stripeDashboardFiles = Resolve-TreeFiles @(
  'docs/payments/MORT_STRIPE_SANDBOX_SETUP.md',
  'docs/payments/MORT_STRIPE_LIVE_SETUP.md',
  'docs/payments/MORT_STRIPE_SUPABASE_SECRETS.md',
  'docs/payments/MORT_STRIPE_MANUAL_DASHBOARD_STEPS.md',
  'docs/payments/MORT_STRIPE_CLI_TESTING.md',
  'scripts/stripe-check-config.ps1',
  'scripts/stripe-listen-test.ps1',
  'scripts/stripe-trigger-test-events.ps1'
)

$stripeEvidenceFiles = Resolve-TreeFiles @(
  'docs/payments/MORT_STRIPE_IMPLEMENTATION_RESULTS.md',
  'supabase/migrations/20260722032907_stripe_connect_sandbox_foundation.sql',
  'supabase/migrations/20260722034445_stripe_webhook_completion_rpc.sql',
  'supabase/functions/_shared/stripe.ts',
  'supabase/functions/stripe-config',
  'supabase/functions/stripe-create-connected-account',
  'supabase/functions/stripe-create-job-payment-intent',
  'supabase/functions/stripe-create-job-refund',
  'supabase/functions/stripe-create-job-transfer',
  'supabase/functions/stripe-create-onboarding-link',
  'supabase/functions/stripe-get-connected-account-status',
  'supabase/functions/stripe-webhook',
  'flutter_mort/lib/data/repositories/stripe_marketplace_repository.dart',
  'flutter_mort/lib/features/payments/stripe_marketplace_screens.dart',
  'flutter_mort/lib/features/payments/stripe_payment_sheet_service.dart',
  'flutter_mort/test/stripe_marketplace_contract_test.dart',
  'scripts/stripe-qa-suites.mjs'
)
$stripeEvidenceFiles += Get-ChildItem -LiteralPath (Join-Path $Root 'scripts') -Filter 'qa-stripe-*.mjs' -File

$results = @()
$results += New-MortZip 'mort-android-profile-ai-billing-final-source-clean.zip' $sourceFiles
$results += Copy-NewArtifact 'flutter_mort/build/app/outputs/bundle/release/app-release.aab' 'mort-android-profile-ai-billing-final.aab'
$results += Copy-NewArtifact 'flutter_mort/build/app/outputs/flutter-apk/app-release.apk' 'mort-android-profile-ai-billing-final-qa.apk'
$results += New-MortZip 'mort-play-billing-products-setup.zip' $billingFiles
$results += New-MortZip 'mort-play-review-and-console-package.zip' $reviewFiles
$results += New-MortZip 'mort-ai-guide-setup-and-safety-package.zip' $aiFiles
$results += New-MortZip 'mort-profile-defect-evidence-package.zip' $profileFiles
$results += New-MortZip 'mort-stripe-connect-marketplace-source-clean.zip' $sourceFiles
$results += Copy-NewArtifact 'flutter_mort/build/app/outputs/flutter-apk/app-release.apk' 'mort-stripe-connect-marketplace-qa.apk'
$results += Copy-NewArtifact 'flutter_mort/build/app/outputs/bundle/release/app-release.aab' 'mort-stripe-connect-marketplace-closed-test.aab'
$results += New-MortZip 'mort-stripe-connect-dashboard-setup.zip' $stripeDashboardFiles
$results += New-MortZip 'mort-stripe-connect-test-evidence.zip' $stripeEvidenceFiles
$results += New-MortZip 'mort-stripe-payment-operations-docs.zip' @(Get-ChildItem -LiteralPath (Join-Path $Root 'docs\payments') -File)

$results | ConvertTo-Json -Depth 3
