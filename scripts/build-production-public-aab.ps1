[CmdletBinding()]
param()

& (Join-Path $PSScriptRoot 'android-release-profile-common.ps1') `
  -ReleaseProfile production `
  -ReleaseStage production_public `
  -OperationalMode production `
  -ArtifactKind Aab `
  -PlayReviewModeEnabled $false `
  -GoogleAuthEnabled $true `
  -PublicMarketplaceEnabled $true `
  -IdentityVerificationEnabled $true `
  -RemotePushEnabled $false `
  -CrashReportingEnabled $true `
  -PublicActivationApproved $true `
  -AdsEnabled $true
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
