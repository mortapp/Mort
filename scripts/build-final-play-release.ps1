[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
$artifact = Join-Path $root (
  "build\play\mort-production-public-$($version.versionName)-$($version.versionCode).aab"
)

& (Join-Path $PSScriptRoot 'build-production-public-aab.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Public production AAB build failed.' }
if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
  throw 'Public production AAB was not created at the expected path.'
}

& (Join-Path $PSScriptRoot 'verify-play-aab.ps1') `
  -BundlePath $artifact `
  -ReleaseStage production_public `
  -PlayReviewModeEnabled:$false
if ($LASTEXITCODE -ne 0) { throw 'Public production AAB verification failed.' }

Write-Output "Created verified public production AAB: $artifact"
