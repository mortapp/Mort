$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'play-review-secrets-common.ps1')
. (Join-Path $PSScriptRoot 'android-signing-common.ps1')

Set-MortPlayReviewEnvironment
$env:SUPABASE_ACCESS_TOKEN = [Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN', 'User')
$signing = Get-MortUploadSigning
Set-MortUploadSigningEnvironment $signing

$scripts = @(
  'qa-play-release-mode.mjs',
  'qa-production-feature-flags.mjs',
  'qa-under-13-block.mjs',
  'validate-play-review-tenant.mjs',
  'qa-play-review-account-isolation.mjs',
  'qa-play-review-partner-actions.mjs',
  'qa-ugc-report-block.mjs',
  'qa-child-safety-standards.mjs',
  'qa-account-deletion-in-app.mjs',
  'qa-account-deletion-web.mjs',
  'qa-account-deletion-enumeration.mjs',
  'qa-account-deletion.mjs',
  'qa-data-safety-inventory.mjs',
  'qa-android-permission-minimization.mjs',
  'qa-release-network-security.mjs',
  'qa-release-deep-links.mjs',
  'qa-debug-feature-removal.mjs',
  'qa-closed-test-marketplace-lock.mjs'
)

try {
  foreach ($script in $scripts) {
    & node (Join-Path $PSScriptRoot $script)
    if ($LASTEXITCODE -ne 0) { throw "$script failed." }
  }
  if (Test-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'build\play\mort-closed-test.aab')) {
    foreach ($script in @('qa-aab-secret-scan.mjs', 'qa-aab-signing.mjs')) {
      & node (Join-Path $PSScriptRoot $script)
      if ($LASTEXITCODE -ne 0) { throw "$script failed." }
    }
  }
} finally {
  foreach ($name in @(
    'PLAY_REVIEW_TEEN_EMAIL','PLAY_REVIEW_TEEN_PASSWORD',
    'PLAY_REVIEW_ADULT_EMAIL','PLAY_REVIEW_ADULT_PASSWORD',
    'SUPABASE_SERVICE_ROLE_KEY','SUPABASE_DB_PASSWORD',
    'SUPABASE_ACCESS_TOKEN','MORT_UPLOAD_STORE_PASSWORD','MORT_UPLOAD_KEY_PASSWORD'
  )) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
}
