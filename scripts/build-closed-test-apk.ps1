[CmdletBinding()]
param()

& (Join-Path $PSScriptRoot 'android-release-profile-common.ps1') `
  -ReleaseProfile reviewer_demo `
  -ReleaseStage closed_test `
  -OperationalMode closed_pilot `
  -ArtifactKind Apk `
  -PlayReviewModeEnabled $true `
  -GoogleAuthEnabled $true `
  -PublicMarketplaceEnabled $false `
  -IdentityVerificationEnabled $false `
  -RemotePushEnabled $false `
  -CrashReportingEnabled $false `
  -PublicActivationApproved $false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
