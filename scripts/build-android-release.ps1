[CmdletBinding()]
param(
  [ValidateSet('production_public')]
  [string]$Profile = 'production_public',
  [switch]$Apk
)

if ($Apk) {
  throw 'Public production distribution is AAB-only.'
}

& (Join-Path $PSScriptRoot 'build-production-public-aab.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
