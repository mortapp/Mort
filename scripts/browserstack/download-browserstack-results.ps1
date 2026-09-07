# Downloads the JSON build report for a finished BrowserStack App Automate
# XCUITest build to a local file, for archiving alongside other MORT release
# evidence. Does not download video/device logs (those are linked from the
# JSON report's per-session URLs, which require the same Basic Auth) -- pull
# those separately if a specific failing session needs deeper inspection.
#
# Usage:
#   $env:BROWSERSTACK_USERNAME = "..."
#   $env:BROWSERSTACK_ACCESS_KEY = "..."
#   ./scripts/browserstack/download-browserstack-results.ps1 -BuildId <build_id> -OutFile evidence/ios-qa/build-<id>.json

param(
  [Parameter(Mandatory = $true)][string]$BuildId,
  [Parameter(Mandatory = $true)][string]$OutFile
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

$build = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

$outDir = Split-Path -Parent $OutFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$build | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutFile -Encoding utf8

Write-Host "Saved build report to $OutFile" -ForegroundColor Green
