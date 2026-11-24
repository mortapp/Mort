param(
  [string]$ProjectRef = 'ckcxakhxqlkhppsxxjhv'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

& npx supabase secrets --help *> $null
if ($LASTEXITCODE -ne 0) {
  throw 'Supabase secrets command is unavailable.'
}

$listing = & npx supabase secrets list --project-ref $ProjectRef 2>&1 | Out-String
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
  throw "Supabase secret-name listing failed with exit code $exitCode."
}

$functions = & npx supabase functions list --project-ref $ProjectRef 2>&1 | Out-String
$functionExitCode = $LASTEXITCODE
if ($functionExitCode -ne 0) {
  throw "Supabase function listing failed with exit code $functionExitCode."
}
$webhookUrl = [Environment]::GetEnvironmentVariable('MORT_STRIPE_TEST_CONNECT_WEBHOOK_URL', 'Process')
$expectedWebhookUrl = "https://$ProjectRef.supabase.co/functions/v1/stripe-webhook"
$hasWebhookFunction = [regex]::IsMatch($functions, '(?m)(^|[^a-zA-Z0-9_-])stripe-webhook([^a-zA-Z0-9_-]|$)')
if (-not $hasWebhookFunction -or $webhookUrl -ne $expectedWebhookUrl) {
  Write-Output 'Task 31 Connect webhook preflight: deployed webhook function or configured Connect URL is missing/mismatched.'
  exit 2
}

$hasTestConnect = [regex]::IsMatch(
  $listing,
  '(?m)(^|[^A-Z0-9_])STRIPE_TEST_CONNECT_WEBHOOK_SECRET([^A-Z0-9_]|$)'
)
$hasLiveConnect = [regex]::IsMatch(
  $listing,
  '(?m)(^|[^A-Z0-9_])STRIPE_LIVE_CONNECT_WEBHOOK_SECRET([^A-Z0-9_]|$)'
)

if ($hasLiveConnect) {
  Write-Output 'Task 31 Connect webhook preflight: blocked by live-name contamination.'
  exit 2
}
if ($hasWebhookFunction -and $webhookUrl -eq $expectedWebhookUrl) {
  Write-Output 'Task 31 Connect webhook preflight: deployed QA webhook URL is configured.'
}
if (-not $hasTestConnect) {
  Write-Output 'Task 31 Connect webhook preflight: required TEST Connect webhook secret name is missing.'
  exit 2
}

Write-Output 'Task 31 Connect webhook preflight: TEST Connect webhook secret name is present. No secret values were printed.'
exit 0
