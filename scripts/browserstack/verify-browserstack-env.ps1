# Verifies BrowserStack credentials are present and valid without ever
# printing the access key. Reads BROWSERSTACK_USERNAME / BROWSERSTACK_ACCESS_KEY
# from the environment only -- never pass them as script arguments (arguments
# can end up in shell history / CI logs).
#
# Usage:
#   $env:BROWSERSTACK_USERNAME = "..."
#   $env:BROWSERSTACK_ACCESS_KEY = "..."
#   ./scripts/browserstack/verify-browserstack-env.ps1

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:BROWSERSTACK_USERNAME) -or
    [string]::IsNullOrWhiteSpace($env:BROWSERSTACK_ACCESS_KEY)) {
  Write-Host "BROWSERSTACK_USERNAME / BROWSERSTACK_ACCESS_KEY are not both set." -ForegroundColor Yellow
  Write-Host "BROWSERSTACK_ACCOUNT=NOT_CONFIGURED"
  exit 1
}

$pair = "$($env:BROWSERSTACK_USERNAME):$($env:BROWSERSTACK_ACCESS_KEY)"
$basicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $basicAuth" }

try {
  $plan = Invoke-RestMethod -Uri "https://api-cloud.browserstack.com/app-automate/plan.json" -Headers $headers -Method Get
} catch {
  Write-Host "BrowserStack authentication failed. Do not print the access key; check it was set correctly." -ForegroundColor Red
  Write-Host "BROWSERSTACK_ACCOUNT=AUTH_FAILED"
  throw
}

Write-Host "BrowserStack App Automate plan check succeeded." -ForegroundColor Green
Write-Host "  parallel_sessions_max_allowed: $($plan.parallel_sessions_max_allowed)"
Write-Host "  parallel_sessions_running:     $($plan.parallel_sessions_running)"
Write-Host "  queued_sessions:               $($plan.queued_sessions)"
Write-Host "BROWSERSTACK_ACCOUNT=CONNECTED"
Write-Host "APP_AUTOMATE_ACCESS=CONFIRMED"
Write-Host "APP_LIVE_ACCESS=NOT_VERIFIED_BY_THIS_SCRIPT (App Live has no equivalent documented plan-check endpoint used here; verify by attempting an actual App Live session)"
