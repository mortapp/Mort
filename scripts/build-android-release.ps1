[CmdletBinding()]
param(
  [ValidateSet('production_public')]
  [string]$Profile = 'production_public',
  [switch]$Apk
)

$builder = if ($Apk) {
  'build-production-public-apk.ps1'
} else {
  'build-production-public-aab.ps1'
}

& (Join-Path $PSScriptRoot $builder)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
