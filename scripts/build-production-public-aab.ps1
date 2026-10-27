[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$commonBuilder = Join-Path $PSScriptRoot 'android-release-profile-common.ps1'
if (-not (Test-Path -LiteralPath $commonBuilder -PathType Leaf)) {
  throw 'The shared Android release-profile builder is missing.'
}

$profileValidator = Join-Path $PSScriptRoot 'validate-release-profile.mjs'
if (-not (Test-Path -LiteralPath $profileValidator -PathType Leaf)) {
  throw 'The authoritative Android release-profile validator is missing.'
}
$profileJson = & node $profileValidator --profile production
if ($LASTEXITCODE -ne 0) { throw 'The public production release profile is invalid.' }
$profile = $profileJson | ConvertFrom-Json
if ($profile.name -ne 'production' -or
    $profile.releaseStage -ne 'production_public' -or
    $profile.operationalMode -ne 'production') {
  throw 'The authoritative release profile is not configured for public production.'
}
$publicActivationApproved = [bool]$profile.productionActivationApproved

& $commonBuilder `
  -ReleaseProfile production `
  -ReleaseStage ([string]$profile.releaseStage) `
  -OperationalMode ([string]$profile.operationalMode) `
  -ArtifactKind Aab `
  -PlayReviewModeEnabled ([bool]$profile.reviewerModeEnabled) `
  -GoogleAuthEnabled ([bool]$profile.googleAuthEnabled) `
  -PublicMarketplaceEnabled ([bool]$profile.publicMarketplaceEnabled) `
  -IdentityVerificationEnabled ([bool]$profile.identityVerificationEnabled) `
  -RemotePushEnabled ([bool]$profile.remotePushEnabled) `
  -CrashReportingEnabled ([bool]$profile.crashReportingEnabled) `
  -PublicActivationApproved $publicActivationApproved `
  -AdsEnabled ([bool]$profile.adsEnabled)

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
