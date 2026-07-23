$ErrorActionPreference = "Stop"

Set-Location -LiteralPath (Resolve-Path "$PSScriptRoot\..")

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is not installed or not on PATH."
}

try {
  docker info | Out-Null
} catch {
  throw "Docker daemon is not running. Start Docker Desktop before applying local Storage setup."
}

$dbContainer = "supabase_db_mort-mobile"
$storageSql = Join-Path (Get-Location) "supabase\storage_setup.sql"

if (-not (Test-Path -LiteralPath $storageSql)) {
  throw "Missing supabase\storage_setup.sql."
}

$container = docker ps --filter "name=^/$dbContainer$" --format "{{.Names}}"
if ($container -ne $dbContainer) {
  throw "Local Supabase Postgres container $dbContainer is not running."
}

Get-Content -LiteralPath $storageSql -Raw |
  docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1

Write-Host "Applied local Storage setup from $storageSql"
