$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$names = @(
  "REVENUECAT_V2_SECRET_API_KEY",
  "REVENUECAT_V1_SECRET_API_KEY",
  "REVENUECAT_PROJECT_ID",
  "REVENUECAT_APP_ID",
  "REVENUECAT_FLUTTER_IOS_SDK_KEY",
  "REVENUECAT_WEBHOOK_AUTH_HEADER"
)

foreach ($name in $names) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name, "Process"))) {
    $value = [Environment]::GetEnvironmentVariable($name, "User")
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
  }
}

$missing = @()
if (
  [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable("REVENUECAT_V2_SECRET_API_KEY", "Process")) -and
  [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable("REVENUECAT_V1_SECRET_API_KEY", "Process"))
) {
  $missing += "REVENUECAT_V2_SECRET_API_KEY or REVENUECAT_V1_SECRET_API_KEY"
}
foreach ($required in @("REVENUECAT_PROJECT_ID", "REVENUECAT_FLUTTER_IOS_SDK_KEY")) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($required, "Process"))) {
    $missing += $required
  }
}

if ($missing.Count -gt 0) {
  throw "Missing required RevenueCat env vars: $($missing -join ', ')"
}

Push-Location $repoRoot
try {
  node .\scripts\revenuecat-setup.mjs @args
} finally {
  Pop-Location
}
