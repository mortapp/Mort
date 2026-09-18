param(
  [string]$ProjectRef = 'rakjydmgwwgtdislanbt'
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
if (-not $hasTestConnect) {
  Write-Output 'Task 31 Connect webhook preflight: required TEST Connect webhook secret name is missing.'
  exit 2
}

Write-Output 'Task 31 Connect webhook preflight: TEST Connect webhook secret name is present. No secret values were printed.'
exit 0
