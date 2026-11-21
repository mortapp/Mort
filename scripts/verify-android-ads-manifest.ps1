[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ManifestPath,
  [Parameter(Mandatory)][ValidateSet('Disabled','Enabled')][string]$ExpectedAds
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'android-ads-manifest-common.ps1')

Assert-MortAndroidAdsManifest -ManifestText (Get-Content -Raw -LiteralPath $ManifestPath) -ExpectedAds $ExpectedAds
Write-Output "Packaged MORT Android manifest: ads $ExpectedAds policy passed."
