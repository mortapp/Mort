# Uploads an iOS .ipa to BrowserStack App Automate.
#
# Verified against BrowserStack's documented App Automate upload API
# (https://www.browserstack.com/docs/app-automate/api-reference/appium/apps):
#   POST https://api-cloud.browserstack.com/app-automate/upload
#   multipart/form-data: file=@<ipa>, custom_id=<id>
#
# NOTE: this uploads to App Automate. App Live has a separate product with an
# endpoint this program could not verify from documentation in this session
# (see scripts/browserstack/verify-browserstack-env.ps1) -- confirm the exact
# App Live upload endpoint against a live BrowserStack account before relying
# on it, rather than assuming the same path works.
#
# This does NOT resign the app. Whether BrowserStack accepts an unsigned iOS
# .ipa for a real-device session depends on the account/project configuration
# and is unverified — this script reports BrowserStack's actual response, it
# does not assume success.
#
# Usage:
#   $env:BROWSERSTACK_USERNAME = "..."
#   $env:BROWSERSTACK_ACCESS_KEY = "..."
#   ./scripts/browserstack/upload-ios-app.ps1 -IpaPath build/ios/mort-ios-qa-unsigned.ipa

param(
  [Parameter(Mandatory = $true)][string]$IpaPath,
  [string]$CustomId = "mort-ios-qa"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:BROWSERSTACK_USERNAME) -or
    [string]::IsNullOrWhiteSpace($env:BROWSERSTACK_ACCESS_KEY)) {
  throw "BROWSERSTACK_USERNAME / BROWSERSTACK_ACCESS_KEY are not set. See MORT_EXTERNAL_RELEASE_GATES.md."
}
if (-not (Test-Path -LiteralPath $IpaPath)) {
  throw "IPA not found at: $IpaPath"
}

$pair = "$($env:BROWSERSTACK_USERNAME):$($env:BROWSERSTACK_ACCESS_KEY)"
$basicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $basicAuth" }

Write-Host "Uploading $IpaPath to BrowserStack App Automate..."
try {
  $response = Invoke-RestMethod `
    -Uri "https://api-cloud.browserstack.com/app-automate/upload" `
    -Headers $headers `
    -Method Post `
    -Form @{ file = Get-Item -LiteralPath $IpaPath; custom_id = $CustomId }
} catch {
  $body = $null
  if ($_.Exception.Response) {
    try {
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $body = $reader.ReadToEnd()
    } catch {}
  }
  Write-Host "Upload failed. This may mean BrowserStack rejected the unsigned artifact -- do not assume success." -ForegroundColor Red
  if ($body) { Write-Host "Response body: $body" -ForegroundColor Red }
  Write-Host "IOS_SIGNING=BLOCKED_EXTERNAL (if the rejection reason is signing-related)"
  throw
}

Write-Host "Upload succeeded." -ForegroundColor Green
Write-Host "  app_url:      $($response.app_url)"
Write-Host "  custom_id:    $($response.custom_id)"
Write-Host "  shareable_id: $($response.shareable_id)"
Write-Host "BROWSERSTACK_IOS_APP_URL=$($response.app_url)"

if ($env:GITHUB_OUTPUT) {
  "app_url=$($response.app_url)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
