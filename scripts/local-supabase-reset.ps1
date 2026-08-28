$ErrorActionPreference = "Stop"

Set-Location -LiteralPath (Resolve-Path "$PSScriptRoot\..")
. "$PSScriptRoot\resolve-supabase-cli.ps1"

Write-Host "LOCAL ONLY: this resets the Docker Supabase database for this repo." -ForegroundColor Yellow
Write-Host "It must never be used as a remote/live reset workflow." -ForegroundColor Yellow

if ($env:MORT_LOCAL_SUPABASE_CONFIRM -ne "LOCAL_ONLY") {
  throw "Refusing to run. Set MORT_LOCAL_SUPABASE_CONFIRM=LOCAL_ONLY to confirm this is the local Docker Supabase stack."
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is not installed or not on PATH."
}

try {
  docker info | Out-Null
} catch {
  throw "Docker daemon is not running. Start Docker Desktop before resetting local Supabase."
}

$statusResult = Invoke-SupabaseCli -Arguments @("status")
$statusResult.Output
if ($statusResult.ExitCode -ne 0 -or ($statusResult.Output -join "`n") -match "failed to connect|docker API|error during connect") {
  throw "Local Supabase is not reachable. Start Docker Desktop and run local-supabase-start.ps1 before reset."
}

$resetResult = Invoke-SupabaseCli -Arguments @("db", "reset")
$resetResult.Output
if ($resetResult.ExitCode -ne 0 -or ($resetResult.Output -join "`n") -match "failed to connect|docker API|error during connect") {
  throw "Local Supabase reset failed."
}
Write-Host "Local Supabase reset complete. Re-copy local URL/keys into .env.local if they changed."
