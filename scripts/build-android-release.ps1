[CmdletBinding()]
param(
  [ValidateSet('production_public')]
  [string]$Profile = 'production_public',
  [switch]$Apk,
  [switch]$Downloads
)

$ErrorActionPreference = 'Stop'
if ($Apk -and $Downloads) {
  throw 'Choose either a local APK build or the verified Downloads package.'
}

$builder = if ($Downloads) {
  'build-production-public-downloads.ps1'
} elseif ($Apk) {
  'build-production-public-apk.ps1'
} else {
  'build-production-public-aab.ps1'
}

& (Join-Path $PSScriptRoot $builder)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
