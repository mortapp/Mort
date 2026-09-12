# Lists BrowserStack's currently available real iOS devices, so a device
# matrix can be chosen from what's actually live rather than a hardcoded,
# possibly-outdated guess.
#
# Usage:
#   $env:BROWSERSTACK_USERNAME = "..."
#   $env:BROWSERSTACK_ACCESS_KEY = "..."
#   ./scripts/browserstack/list-ios-devices.ps1

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:BROWSERSTACK_USERNAME) -or
    [string]::IsNullOrWhiteSpace($env:BROWSERSTACK_ACCESS_KEY)) {
  throw "BROWSERSTACK_USERNAME / BROWSERSTACK_ACCESS_KEY are not set."
}

$pair = "$($env:BROWSERSTACK_USERNAME):$($env:BROWSERSTACK_ACCESS_KEY)"
$basicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $basicAuth" }

$devices = Invoke-RestMethod -Uri "https://api-cloud.browserstack.com/app-automate/devices.json" -Headers $headers -Method Get
$iosDevices = $devices | Where-Object { $_.os -eq "ios" } | Sort-Object -Property os_version -Descending

Write-Host "Available real iOS devices on this BrowserStack account:" -ForegroundColor Green
foreach ($d in $iosDevices) {
  Write-Host "  device=`"$($d.device)`" os_version=`"$($d.os_version)`" tier=$($d.device_tier)"
}

$iosDevices | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "browserstack-ios-devices.json" -Encoding utf8
Write-Host "Saved full list to browserstack-ios-devices.json" -ForegroundColor Green
