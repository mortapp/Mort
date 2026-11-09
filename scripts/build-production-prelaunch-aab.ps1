[CmdletBinding()]
param()

& (Join-Path $PSScriptRoot 'android-release-profile-common.ps1') `
  -ReleaseProfile production_prelaunch `
  -ReleaseStage production_public `
  -OperationalMode production_prelaunch `
  -ArtifactKind Aab `
  -PlayReviewModeEnabled $false `
  -GoogleAuthEnabled $false `
  -PublicMarketplaceEnabled $false `
  -IdentityVerificationEnabled $false `
  -RemotePushEnabled $false `
  -CrashReportingEnabled $false `
  -PublicActivationApproved $false `
  -AdsEnabled $false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
