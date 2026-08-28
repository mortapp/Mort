[CmdletBinding()]
param()

& (Join-Path $PSScriptRoot 'android-release-profile-common.ps1') `
  -ReleaseProfile closed_test `
  -ReleaseStage closed_test `
  -OperationalMode closed_pilot `
  -ArtifactKind Aab `
  -PlayReviewModeEnabled $false `
  -GoogleAuthEnabled $true `
  -PublicMarketplaceEnabled $false `
  -IdentityVerificationEnabled $false `
  -RemotePushEnabled $false `
  -CrashReportingEnabled $false `
  -PublicActivationApproved $false `
  -AdsEnabled $false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
