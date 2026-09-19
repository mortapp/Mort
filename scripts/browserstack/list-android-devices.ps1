# Lists BrowserStack's currently available real Android devices so the QA
# workflow can choose from live inventory rather than relying on stale names.

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:BROWSERSTACK_USERNAME) -or
    [string]::IsNullOrWhiteSpace($env:BROWSERSTACK_ACCESS_KEY)) {
  throw "BROWSERSTACK_USERNAME / BROWSERSTACK_ACCESS_KEY are not set."
}

$pair = "$($env:BROWSERSTACK_USERNAME):$($env:BROWSERSTACK_ACCESS_KEY)"
$basicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $basicAuth" }

$devices = Invoke-RestMethod -Uri "https://api-cloud.browserstack.com/app-automate/devices.json" -Headers $headers -Method Get
$androidDevices = $devices |
  Where-Object { $_.os -eq "android" } |
  Sort-Object -Property os_version -Descending

if (-not $androidDevices) {
  throw "BrowserStack returned no real Android devices for this account."
}

Write-Host "Available real Android devices on this BrowserStack account:" -ForegroundColor Green
foreach ($d in $androidDevices) {
  Write-Host "  device=`"$($d.device)`" os_version=`"$($d.os_version)`" tier=$($d.device_tier)"
}

$androidDevices | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "browserstack-android-devices.json" -Encoding utf8
Write-Host "Saved full list to browserstack-android-devices.json" -ForegroundColor Green
