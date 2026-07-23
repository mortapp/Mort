param(
  [string]$ForwardTo = 'http://127.0.0.1:54321/functions/v1/stripe-webhook'
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command stripe -ErrorAction SilentlyContinue)) {
  throw 'Stripe CLI is not installed or is not on PATH.'
}
if (-not [Uri]::IsWellFormedUriString($ForwardTo, [UriKind]::Absolute)) {
  throw 'ForwardTo must be an absolute HTTP or HTTPS URL.'
}

Write-Output 'Stripe CLI will display a temporary whsec_ value. Set it only in the active shell or Supabase test secret store; never save it in source.'
& stripe listen --events account.updated,payment_intent.succeeded,payment_intent.payment_failed,transfer.created,transfer.reversed,payout.paid,payout.failed,charge.dispute.created,charge.dispute.closed --forward-to $ForwardTo
exit $LASTEXITCODE
