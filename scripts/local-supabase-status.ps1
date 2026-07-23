$ErrorActionPreference = "Stop"

Set-Location -LiteralPath (Resolve-Path "$PSScriptRoot\..")
. "$PSScriptRoot\resolve-supabase-cli.ps1"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is not installed or not on PATH."
}

try {
  docker info | Out-Null
} catch {
  throw "Docker daemon is not running. Start Docker Desktop to inspect local Supabase."
}

$result = Invoke-SupabaseCli -Arguments @("status")
$result.Output
if ($result.ExitCode -ne 0 -or ($result.Output -join "`n") -match "failed to connect|docker API|error during connect") {
  throw "Local Supabase is not reachable. Start Docker Desktop, then rerun this script."
}
