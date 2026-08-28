param(
  [string]$ProjectRef = 'rakjydmgwwgtdislanbt'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$required = @(
  'SUPABASE_ACCESS_TOKEN',
  'STRIPE_TEST_SECRET_KEY',
  'STRIPE_TEST_PUBLISHABLE_KEY',
  'STRIPE_TEST_WEBHOOK_SECRET',
  'MORT_STRIPE_OPERATIONS_SECRET'
)

$missing = @()
foreach ($name in $required) {
  $value = [Environment]::GetEnvironmentVariable($name, 'Process')
  if (-not $value) { $value = [Environment]::GetEnvironmentVariable($name, 'User') }
  if (-not $value) { $missing += $name }
}

$mode = [Environment]::GetEnvironmentVariable('MORT_STRIPE_MODE', 'Process')
if (-not $mode) { $mode = [Environment]::GetEnvironmentVariable('MORT_STRIPE_MODE', 'User') }
if ($mode -and $mode -ne 'sandbox') {
  throw 'MORT_STRIPE_MODE must be sandbox for this test helper.'
}

$linkedRefFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'supabase\.temp\project-ref'
if (Test-Path $linkedRefFile) {
  $linkedRef = (Get-Content -Raw $linkedRefFile).Trim()
  if ($linkedRef -ne $ProjectRef) { throw "Linked Supabase ref mismatch: $linkedRef" }
}

if ($missing.Count -gt 0) {
  Write-Output "Stripe sandbox configuration is incomplete. Missing names: $($missing -join ', ')"
  exit 2
}

Write-Output "Stripe sandbox configuration names are present for Supabase project $ProjectRef. No values were printed."
