param(
  [string]$ForwardTo = 'http://127.0.0.1:54321/functions/v1/stripe-webhook',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$mode = [Environment]::GetEnvironmentVariable('MORT_STRIPE_MODE', 'Process')
if (-not $mode) { $mode = [Environment]::GetEnvironmentVariable('MORT_STRIPE_MODE', 'User') }
if ($mode -and $mode -ne 'sandbox') {
  throw 'MORT_STRIPE_MODE must be sandbox for this helper.'
}

if (-not $Execute) {
  Write-Output 'Stripe listener was not started. Re-run with -Execute only for sandbox diagnostics.'
  exit 0
}

if (-not (Get-Command stripe -ErrorAction SilentlyContinue)) {
  throw 'Stripe CLI is not installed or is not on PATH.'
}
if (-not [Uri]::IsWellFormedUriString($ForwardTo, [UriKind]::Absolute)) {
  throw 'ForwardTo must be an absolute HTTP or HTTPS URL.'
}

Write-Output 'Stripe CLI will display a temporary whsec_ value. Set it only in the active shell or Supabase test secret store; never save it in source.'
& stripe listen --events account.updated,payment_intent.succeeded,payment_intent.processing,payment_intent.requires_action,payment_intent.payment_failed,payment_intent.canceled,transfer.created,transfer.updated,transfer.reversed,payout.created,payout.updated,payout.paid,payout.failed,payout.canceled,charge.dispute.created,charge.dispute.updated,charge.dispute.closed,refund.created,refund.updated,refund.failed,charge.refunded --forward-to $ForwardTo
exit $LASTEXITCODE
