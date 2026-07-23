param(
  [ValidateSet('payment_intent.succeeded', 'payment_intent.payment_failed', 'account.updated', 'payout.paid', 'payout.failed')]
  [string[]]$Event = @('payment_intent.succeeded', 'payment_intent.payment_failed')
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command stripe -ErrorAction SilentlyContinue)) {
  throw 'Stripe CLI is not installed or is not on PATH.'
}

foreach ($eventName in $Event) {
  Write-Output "Triggering Stripe test event: $eventName"
  & stripe trigger $eventName
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Output "Triggered $($Event.Count) Stripe test event(s). Verify signed webhook processing and database reconciliation separately."
