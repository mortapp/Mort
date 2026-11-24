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
$mode = [Environment]::GetEnvironmentVariable('MORT_STRIPE_MODE', 'Process')
$configuredProject = [Environment]::GetEnvironmentVariable('MORT_SUPABASE_PROJECT_REF', 'Process')

$requiredTestNames = @(
  'STRIPE_TEST_SECRET_KEY',
  'STRIPE_TEST_PUBLISHABLE_KEY',
  'STRIPE_TEST_WEBHOOK_SECRET',
  'STRIPE_TEST_CONNECT_WEBHOOK_SECRET'
)
$forbiddenLiveNames = @(
  'STRIPE_LIVE_SECRET_KEY',
  'STRIPE_LIVE_PUBLISHABLE_KEY',
  'STRIPE_LIVE_WEBHOOK_SECRET',
  'STRIPE_LIVE_CONNECT_WEBHOOK_SECRET'
)
$missingTestNames = @($requiredTestNames | Where-Object {
  -not [regex]::IsMatch($listing, "(?m)(^|[^A-Z0-9_])$([regex]::Escape($_))([^A-Z0-9_]|$)")
})
$presentLiveNames = @($forbiddenLiveNames | Where-Object {
  [regex]::IsMatch($listing, "(?m)(^|[^A-Z0-9_])$([regex]::Escape($_))([^A-Z0-9_]|$)")
})

if ($mode -ne 'sandbox' -or ($configuredProject -and $configuredProject -ne $ProjectRef)) {
  Write-Output 'Task 31 Connect webhook preflight: sandbox mode or project reference mismatch.'
  exit 2
}
if (-not $hasWebhookFunction -or $webhookUrl -ne $expectedWebhookUrl) {
  Write-Output 'Task 31 Connect webhook preflight: deployed webhook function or configured Connect URL is missing/mismatched.'
  exit 2
}
if ($presentLiveNames.Count -gt 0) {
  Write-Output 'Task 31 Connect webhook preflight: blocked by live-secret-name contamination.'
  exit 2
}
if ($missingTestNames.Count -gt 0) {
  Write-Output 'Task 31 Connect webhook preflight: one or more required TEST secret names are missing.'
  exit 2
}

Write-Output 'Task 31 Connect webhook preflight: QA project, sandbox mode, webhook function/URL, and all TEST secret names are present. No secret values were printed.'
exit 0
