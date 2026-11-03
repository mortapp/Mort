[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$commonBuilder = Join-Path $PSScriptRoot 'android-release-profile-common.ps1'
if (-not (Test-Path -LiteralPath $commonBuilder -PathType Leaf)) {
  throw 'The shared Android release-profile builder is missing.'
}

& $commonBuilder `
  -ReleaseProfile production `
  -ReleaseStage production_public `
  -OperationalMode production `
  -ArtifactKind Aab `
  -PlayReviewModeEnabled:$false `
  -GoogleAuthEnabled:$false `
  -PublicMarketplaceEnabled:$true `
  -IdentityVerificationEnabled:$true `
  -RemotePushEnabled:$true `
  -CrashReportingEnabled:$true `
  -PublicActivationApproved:$true `
  -AdsEnabled:$true

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
