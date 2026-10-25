param([switch]$Minimal)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath (Resolve-Path "$PSScriptRoot\..")
. "$PSScriptRoot\resolve-supabase-cli.ps1"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is not installed or not on PATH. Supabase local development requires Docker."
}

try {
  docker info | Out-Null
} catch {
  throw "Docker is installed but the daemon is not running. Start Docker Desktop, then rerun this script."
}

Write-Host "Starting local Supabase only. This does not touch the linked remote project." -ForegroundColor Cyan
$startArguments = @("start")
if ($Minimal) {
  $excludedServices = @("studio", "postgres-meta", "logflare", "vector", "supavisor", "imgproxy")
  Write-Host "Using the core QA service set; excluding: $($excludedServices -join ', ')" -ForegroundColor Cyan
  $startArguments += @("--exclude", ($excludedServices -join ","))
}
$result = Invoke-SupabaseCli -Arguments $startArguments
$result.Output
if ($result.ExitCode -ne 0 -or ($result.Output -join "`n") -match "failed to connect|docker API|error during connect") {
  throw "supabase start failed. Start Docker Desktop, then rerun this script."
}
Write-Host "Copy the local API URL and anon key from the output into .env.local for local QA."
