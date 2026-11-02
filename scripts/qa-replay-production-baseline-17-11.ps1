param(
  [string]$Container = 'mort-pg1711-baseline6-mort20261102'
)

$ErrorActionPreference = 'Stop'
& node (Join-Path $PSScriptRoot 'qa-replay-production-baseline-17-11.mjs') --container $Container
if ($LASTEXITCODE -ne 0) {
  throw "Fresh PostgreSQL 17.11 baseline replay failed with exit code $LASTEXITCODE."
}
