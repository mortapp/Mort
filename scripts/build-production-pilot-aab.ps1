[CmdletBinding()]
param()

$crashProvider = Join-Path $PSScriptRoot '..\flutter_mort\lib\core\observability\sentry_crash_provider.dart'
if (-not (Test-Path -LiteralPath $crashProvider)) {
  throw 'BLOCKED-CONFIG: production pilot requires the app crash provider implementation.'
}

& (Join-Path $PSScriptRoot 'android-release-profile-common.ps1') `
  -ReleaseProfile production_candidate `
  -ReleaseStage production_pilot `
  -OperationalMode restricted_production_pilot `
  -ArtifactKind Aab `
  -PlayReviewModeEnabled $false `
  -GoogleAuthEnabled $false `
  -PublicMarketplaceEnabled $false `
  -IdentityVerificationEnabled $false `
  -RemotePushEnabled $false `
  -CrashReportingEnabled $true `
  -PublicActivationApproved $false `
  -AdsEnabled $true
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
