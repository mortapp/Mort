param([string]$StartAt = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'play-review-secrets-common.ps1')

Set-MortPlayReviewEnvironment
$scripts = @(
  'qa-old-project-smoke.mjs',
  'qa-complete-multi-user-isolation.mjs',
  'audit-remote-storage.mjs',
  'qa-avatar-storage.mjs',
  'qa-verification-storage-lockdown.mjs',
  'qa-flutter-data-isolation.mjs',
  'audit-mission-pilot-remote.mjs',
  'qa-closed-pilot-access.mjs',
  'qa-pilot-job-restrictions.mjs',
  'qa-public-data-boundaries.mjs',
  'qa-marketplace-trust-gating.mjs',
  'qa-job-lifecycle.mjs',
  'qa-job-applications.mjs',
  'qa-saved-jobs.mjs',
  'qa-arrival-handshake.mjs',
  'qa-job-contract-immutability.mjs',
  'qa-contract-change-consent.mjs',
  'qa-payment-obligation.mjs',
  'qa-nonpayment-dispute-isolation.mjs',
  'qa-mutual-reporting.mjs',
  'qa-address-privacy.mjs',
  'qa-location-release-stages.mjs',
  'qa-rate-limits.mjs'
  'qa-ai-cost-prompt-boundary.mjs'
  'qa-signed-media-rate-limits.mjs'
  'qa-payment-operations-queue-boundary.mjs'
)

if ($StartAt) {
  $startIndex = [Array]::IndexOf($scripts, $StartAt)
  if ($startIndex -lt 0) { throw "Unknown regression start script: $StartAt" }
  $scripts = $scripts[$startIndex..($scripts.Count - 1)]
}

$completed = @()
try {
  foreach ($script in $scripts) {
    & node (Join-Path $PSScriptRoot $script)
    if ($LASTEXITCODE -ne 0) { throw "$script failed." }
    $completed += $script
  }
  Write-Output "Final Supabase regression PASS: $($completed.Count) scripts."
} finally {
  foreach ($name in @(
    'PLAY_REVIEW_TEEN_EMAIL', 'PLAY_REVIEW_TEEN_PASSWORD',
    'PLAY_REVIEW_ADULT_EMAIL', 'PLAY_REVIEW_ADULT_PASSWORD',
    'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_DB_PASSWORD',
    'SUPABASE_ACCESS_TOKEN'
  )) {
    [Environment]::SetEnvironmentVariable($name, $null, 'Process')
  }
}
