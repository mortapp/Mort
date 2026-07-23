param(
  [string]$ProjectRef = $env:MORT_SUPABASE_PROJECT_REF,
  [string]$ConfirmProjectRef = $env:MORT_CONFIRM_PROJECT_REF,
  [switch]$SkipLink
)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath (Resolve-Path "$PSScriptRoot\..")
. "$PSScriptRoot\resolve-supabase-cli.ps1"

Write-Host "FRESH/STAGING PROJECT ONLY. This runs supabase db push; it never runs db reset or wipes data." -ForegroundColor Yellow

if ($env:MORT_CONFIRM_FRESH_SUPABASE -ne "YES_FRESH_PROJECT") {
  throw "Refusing to run. Set MORT_CONFIRM_FRESH_SUPABASE=YES_FRESH_PROJECT only for a fresh/staging Supabase project."
}

if ([string]::IsNullOrWhiteSpace($ProjectRef)) {
  throw "Set MORT_SUPABASE_PROJECT_REF to the fresh/staging Supabase project ref."
}

$currentLinkedRefPath = Join-Path (Get-Location) "supabase\.temp\project-ref"
if (Test-Path -LiteralPath $currentLinkedRefPath) {
  $currentLinkedRef = (Get-Content -LiteralPath $currentLinkedRefPath -Raw).Trim()
  Write-Host "Currently linked project ref: $currentLinkedRef"
} else {
  Write-Host "No local Supabase linked project ref file found."
}

if ([string]::IsNullOrWhiteSpace($ConfirmProjectRef)) {
  $ConfirmProjectRef = Read-Host "Type the fresh/staging project ref to confirm"
}

if ($ConfirmProjectRef -ne $ProjectRef) {
  throw "Project ref confirmation did not match. No Supabase command was run."
}

if (-not $SkipLink) {
  $linkResult = Invoke-SupabaseCli -Arguments @("link", "--project-ref", $ProjectRef)
  $linkResult.Output
  if ($linkResult.ExitCode -ne 0) {
    throw "supabase link failed."
  }
}

Write-Host "Applying migrations with supabase db push to confirmed fresh/staging project: $ProjectRef" -ForegroundColor Cyan
$pushResult = Invoke-SupabaseCli -Arguments @("db", "push")
$pushResult.Output
if ($pushResult.ExitCode -ne 0) {
  throw "supabase db push failed."
}
Write-Host "Fresh/staging Supabase migration push complete. Now deploy Edge Functions and set secrets manually."
