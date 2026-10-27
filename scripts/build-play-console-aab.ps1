[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

& (Join-Path $PSScriptRoot 'build-production-public-aab.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
