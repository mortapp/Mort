[CmdletBinding()]
param()

$crashProvider = Join-Path $PSScriptRoot '..\flutter_mort\lib\core\observability\production_crash_provider.dart'
$pushProvider = Join-Path $PSScriptRoot '..\flutter_mort\lib\features\notifications\remote_push_service.dart'
if (-not (Test-Path -LiteralPath $crashProvider) -or -not (Test-Path -LiteralPath $pushProvider)) {
  throw 'BLOCKED-EXTERNAL: production pilot requires real crash and remote-push provider implementations.'
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
  -RemotePushEnabled $true `
  -CrashReportingEnabled $true `
  -PublicActivationApproved $false `
  -AdsEnabled $true
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
