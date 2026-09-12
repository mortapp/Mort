# Polls a BrowserStack App Automate XCUITest build until it finishes, or
# until -TimeoutMinutes elapses. Verified against BrowserStack's documented
# XCUITest builds API
# (https://www.browserstack.com/docs/app-automate/api-reference/xcuitest/builds):
#   GET https://api-cloud.browserstack.com/app-automate/xcuitest/v2/builds/{buildId}
#
# This program has not yet exercised BrowserStack's Flutter-integration-test
# packaging requirements against a live account (Track 11, blocked on
# credentials) -- confirm the exact test-framework endpoint (XCUITest vs. a
# Flutter-specific one) once BrowserStack access exists, rather than assuming
# XCUITest is the final answer for this project.
#
# Usage:
#   $env:BROWSERSTACK_USERNAME = "..."
#   $env:BROWSERSTACK_ACCESS_KEY = "..."
#   ./scripts/browserstack/poll-browserstack-build.ps1 -BuildId <build_id>

param(
  [Parameter(Mandatory = $true)][string]$BuildId,
  [int]$TimeoutMinutes = 30,
  [int]$PollIntervalSeconds = 20
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:BROWSERSTACK_USERNAME) -or
    [string]::IsNullOrWhiteSpace($env:BROWSERSTACK_ACCESS_KEY)) {
  throw "BROWSERSTACK_USERNAME / BROWSERSTACK_ACCESS_KEY are not set. See MORT_EXTERNAL_RELEASE_GATES.md."
}

$pair = "$($env:BROWSERSTACK_USERNAME):$($env:BROWSERSTACK_ACCESS_KEY)"
$basicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $basicAuth" }
$uri = "https://api-cloud.browserstack.com/app-automate/xcuitest/v2/builds/$BuildId"

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$terminalStatuses = @("passed", "failed", "error", "timed_out")

while ((Get-Date) -lt $deadline) {
  $build = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
  $status = $build.status
  Write-Host "[$(Get-Date -Format 'HH:mm:ss')] build $BuildId status: $status"
  if ($terminalStatuses -contains $status) {
    $build | ConvertTo-Json -Depth 10 | Write-Output
    if ($status -ne "passed") {
      Write-Host "BROWSERSTACK_BUILD_RESULT=$status" -ForegroundColor Yellow
      exit 1
    }
    Write-Host "BROWSERSTACK_BUILD_RESULT=passed" -ForegroundColor Green
    exit 0
  }
  Start-Sleep -Seconds $PollIntervalSeconds
}

throw "Timed out after $TimeoutMinutes minutes waiting for build $BuildId to finish."
