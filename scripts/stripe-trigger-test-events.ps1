param(
  [ValidateSet(
    'payment_intent.succeeded',
    'payment_intent.processing',
    'payment_intent.requires_action',
    'payment_intent.payment_failed',
    'payment_intent.canceled',
    'account.updated',
    'refund.created',
    'refund.updated',
    'refund.failed',
    'charge.refunded',
    'transfer.created',
    'transfer.updated',
    'transfer.reversed',
    'charge.dispute.created',
    'charge.dispute.updated',
    'charge.dispute.closed',
    'payout.created',
    'payout.updated',
    'payout.paid',
    'payout.failed',
    'payout.canceled'
  )]
  [string[]]$Event = @(
    'payment_intent.succeeded',
    'payment_intent.payment_failed'
  ),
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$mode = [Environment]::GetEnvironmentVariable('MORT_STRIPE_MODE', 'Process')
if (-not $mode) {
  $mode = [Environment]::GetEnvironmentVariable('MORT_STRIPE_MODE', 'User')
}
if ($mode -and $mode -ne 'sandbox') {
  throw 'MORT_STRIPE_MODE must be sandbox. Live Stripe CLI triggers are refused.'
}

Write-Output 'Stripe CLI trigger fixtures are diagnostic only. They cannot satisfy MORT end-to-end payment evidence because generic fixtures may not contain MORT contract, quote, settlement, or participant metadata.'
foreach ($eventName in $Event) {
  Write-Output "Planned Stripe TEST diagnostic event: $eventName"
}

if (-not $Execute) {
  Write-Output 'No Stripe event was triggered. Re-run with -Execute only inside an approved sandbox QA window.'
  exit 0
}

if (-not (Get-Command stripe -ErrorAction SilentlyContinue)) {
  throw 'Stripe CLI is not installed or is not on PATH.'
}

foreach ($eventName in $Event) {
  Write-Output "Triggering Stripe TEST diagnostic event: $eventName"
  & stripe trigger $eventName
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Output "Triggered $($Event.Count) Stripe TEST diagnostic event(s). These results remain diagnostic-only and do not count as MORT sandbox E2E evidence."
