# Uploads an Android .apk to BrowserStack App Automate.
# Same endpoint as the iOS uploader (BrowserStack's App Automate upload API
# accepts both .ipa and .apk via the same `file` form field):
#   POST https://api-cloud.browserstack.com/app-automate/upload
#
# Usage:
#   $env:BROWSERSTACK_USERNAME = "..."
#   $env:BROWSERSTACK_ACCESS_KEY = "..."
#   ./scripts/browserstack/upload-android-app.ps1 -ApkPath build/app/outputs/flutter-apk/app-release.apk

param(
  [Parameter(Mandatory = $true)][string]$ApkPath,
  [string]$CustomId = "mort-android-qa"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:BROWSERSTACK_USERNAME) -or
    [string]::IsNullOrWhiteSpace($env:BROWSERSTACK_ACCESS_KEY)) {
  throw "BROWSERSTACK_USERNAME / BROWSERSTACK_ACCESS_KEY are not set. See MORT_EXTERNAL_RELEASE_GATES.md."
}
if (-not (Test-Path -LiteralPath $ApkPath)) {
  throw "APK not found at: $ApkPath"
}

$pair = "$($env:BROWSERSTACK_USERNAME):$($env:BROWSERSTACK_ACCESS_KEY)"
$basicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $basicAuth" }

Write-Host "Uploading $ApkPath to BrowserStack App Automate..."
$response = Invoke-RestMethod `
  -Uri "https://api-cloud.browserstack.com/app-automate/upload" `
  -Headers $headers `
  -Method Post `
  -Form @{ file = Get-Item -LiteralPath $ApkPath; custom_id = $CustomId }

Write-Host "Upload succeeded." -ForegroundColor Green
Write-Host "  app_url:      $($response.app_url)"
Write-Host "  custom_id:    $($response.custom_id)"
Write-Host "  shareable_id: $($response.shareable_id)"
Write-Host "BROWSERSTACK_ANDROID_APP_URL=$($response.app_url)"
