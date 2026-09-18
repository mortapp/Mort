param([string]$StartAt = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'play-review-secrets-common.ps1')
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Set-MortPlayReviewEnvironment
$scripts = @(
  'qa-old-project-smoke.mjs',
  'qa-resumable-onboarding.mjs',
  'qa-orphaned-onboarding-progress.mjs',
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
  'qa-marketplace-state-machine.mjs',
  'qa-job-applications.mjs',
  'qa-saved-jobs.mjs',
  'qa-messaging-safety-state-machine.mjs',
  'qa-arrival-handshake.mjs',
  'qa-job-pin-concurrency.mjs',
  'qa-safety-action-rate-limits.mjs',
  'qa-guardian-optional.mjs',
  'qa-job-contract-immutability.mjs',
  'qa-contract-change-consent.mjs',
  'qa-payment-obligation.mjs',
  'qa-nonpayment-dispute-isolation.mjs',
  'qa-payment-dispute-appeal.mjs',
  'qa-support-evidence-lifecycle.mjs',
  'qa-mutual-reporting.mjs',
  'qa-address-privacy.mjs',
  'qa-location-release-stages.mjs',
  'qa-rate-limits.mjs',
  'qa-edge-rate-limits.mjs',
  'qa-ai-cost-prompt-boundary.mjs',
  'qa-ai-safety-edge.mjs',
  'qa-support-chatbot.mjs',
  'qa-support-human-operations.mjs',
  'qa-remote-push-foundation.mjs',
  'qa-privacy-observability.mjs',
  'qa-identity-provider-neutral.mjs',
  'qa-financial-operations-completion.mjs',
  'qa-google-auth-controls.mjs',
  'qa-play-reviewer-isolation.mjs',
  'qa-revenuecat-atomic.mjs',
  'qa-signed-media-rate-limits.mjs',
  'qa-payment-operations-queue-boundary.mjs',
  'qa-stripe-mode-isolation.mjs',
  'qa-stripe-secret-boundary.mjs',
  'qa-stripe-connected-account-isolation.mjs',
  'qa-stripe-minor-guardian-status.mjs',
  'qa-stripe-onboarding-link-security.mjs',
  'qa-stripe-payment-amount-forgery.mjs',
  'qa-stripe-payment-idempotency.mjs',
  'qa-stripe-payment-sheet-contract.mjs',
  'qa-stripe-webhook-signature.mjs',
  'qa-stripe-webhook-replay.mjs',
  'qa-stripe-webhook-idempotency.mjs',
  'qa-stripe-job-funding.mjs',
  'qa-stripe-transfer-eligibility.mjs',
  'qa-stripe-transfer-duplication.mjs',
  'qa-stripe-refund.mjs',
  'qa-stripe-transfer-reversal.mjs',
  'qa-stripe-dispute-hold.mjs',
  'qa-stripe-payout-status.mjs',
  'qa-stripe-cashapp-boundary.mjs',
  'qa-stripe-public-profile-privacy.mjs',
  'qa-stripe-google-play-billing-boundary.mjs',
  'qa-stripe-saved-payment-consent.mjs',
  'qa-stripe-resolution-role-separation.mjs',
  'qa-stripe-resolution-idempotency.mjs',
  'qa-stripe-refund-webhook-reconciliation.mjs',
  'qa-stripe-policy-versioning.mjs',
  'qa-stripe-funding-quote.mjs',
  'qa-stripe-settlement-policy.mjs'
)

if ($StartAt) {
  $startIndex = [Array]::IndexOf($scripts, $StartAt)
  if ($startIndex -lt 0) { throw "Unknown regression start script: $StartAt" }
  $scripts = $scripts[$startIndex..($scripts.Count - 1)]
}

$completed = @()
try {
  foreach ($script in $scripts) {
    Write-Output "Running Supabase regression: $script"
    & node (Join-Path $PSScriptRoot 'run-node-qa-with-transport-retry.mjs') (Join-Path $PSScriptRoot $script)
    if ($LASTEXITCODE -ne 0) { throw "$script failed." }
    $completed += $script
  }
  $stopwatch.Stop()
  Write-Output "Final Supabase regression PASS: $($completed.Count) scripts in $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1)) seconds."
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
