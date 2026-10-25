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
  $expectedCliVersion = "2.122.0"
  $versionResult = Invoke-SupabaseCli -Arguments @("--version")
  $cliVersion = $versionResult.Output -join " "
  if ($versionResult.ExitCode -ne 0 -or $cliVersion -notmatch [regex]::Escape($expectedCliVersion)) {
    throw "The minimal regression image mirror is pinned to Supabase CLI $expectedCliVersion; installed CLI reported '$cliVersion'."
  }

  $imageMirrors = @(
    @{ Source = "ghcr.io/supabase/postgres:17.11.0.006"; Target = "public.ecr.aws/supabase/postgres:17.11.0.006" },
    @{ Source = "ghcr.io/supabase/gotrue:v2.197.0"; Target = "public.ecr.aws/supabase/gotrue:v2.197.0" },
    @{ Source = "ghcr.io/supabase/realtime:v2.147.1"; Target = "public.ecr.aws/supabase/realtime:v2.147.1" },
    @{ Source = "ghcr.io/supabase/storage-api:v1.84.19"; Target = "public.ecr.aws/supabase/storage-api:v1.84.19" },
    @{ Source = "ghcr.io/supabase/postgrest:v16.5"; Target = "public.ecr.aws/supabase/postgrest:v16.5" },
    @{ Source = "ghcr.io/supabase/kong:2.8.1"; Target = "public.ecr.aws/supabase/kong:2.8.1" },
    @{ Source = "ghcr.io/supabase/edge-runtime:v1.77.8"; Target = "public.ecr.aws/supabase/edge-runtime:v1.77.8" }
  )
  foreach ($image in $imageMirrors) {
    Write-Host "Preloading official Supabase image mirror: $($image.Source)" -ForegroundColor Cyan
    & docker pull $image.Source
    if ($LASTEXITCODE -ne 0) { throw "Failed to pull the Supabase image mirror $($image.Source)." }
    & docker tag $image.Source $image.Target
    if ($LASTEXITCODE -ne 0) { throw "Failed to prepare the Supabase CLI image tag for $($image.Source)." }
  }

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
