[CmdletBinding()]
param(
  [ValidateSet('','development','automated_test','reviewer_demo','closed_test','production_candidate','production')]
  [string]$ReleaseProfile = '',
  [Parameter(Mandatory)][ValidateSet('closed_test','production_pilot','production_public')][string]$ReleaseStage,
  [Parameter(Mandatory)][string]$OperationalMode,
  [Parameter(Mandatory)][ValidateSet('Aab','Apk')][string]$ArtifactKind,
  [Parameter(Mandatory)][bool]$PlayReviewModeEnabled,
  [Parameter(Mandatory)][bool]$GoogleAuthEnabled,
  [Parameter(Mandatory)][bool]$PublicMarketplaceEnabled,
  [Parameter(Mandatory)][bool]$IdentityVerificationEnabled,
  [Parameter(Mandatory)][bool]$RemotePushEnabled,
  [Parameter(Mandatory)][bool]$CrashReportingEnabled,
  [Parameter(Mandatory)][bool]$PublicActivationApproved,
  [Parameter(Mandatory)][bool]$AdsEnabled
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'android-signing-common.ps1')

$root = Split-Path $PSScriptRoot -Parent
$flutterRoot = Join-Path $root 'flutter_mort'
$outputDirectory = Join-Path $root 'build\play'
$expectedUrl = 'https://rakjydmgwwgtdislanbt.supabase.co'
$expectedProjectRef = 'rakjydmgwwgtdislanbt'
$expectedAuthRedirectUrl = 'com.mortapp.mobile://app/auth-callback'
$expectedCertificateSha256 = Get-MortUploadCertificateSha256
$defineFile = $null

if ([string]::IsNullOrWhiteSpace($ReleaseProfile)) {
  $ReleaseProfile = switch ($ReleaseStage) {
    'closed_test' { if ($PlayReviewModeEnabled) { 'reviewer_demo' } else { 'closed_test' } }
    'production_pilot' { 'production_candidate' }
    'production_public' { 'production' }
  }
}
$profileJson = & node (Join-Path $PSScriptRoot 'validate-release-profile.mjs') --profile $ReleaseProfile
if ($LASTEXITCODE -ne 0) { throw 'Release profile matrix validation failed.' }
$profile = $profileJson | ConvertFrom-Json

foreach ($comparison in @(
  @('release stage', $ReleaseStage, [string]$profile.releaseStage),
  @('operational mode', $OperationalMode, [string]$profile.operationalMode),
  @('reviewer mode', $PlayReviewModeEnabled, [bool]$profile.reviewerModeEnabled),
  @('Google Auth', $GoogleAuthEnabled, [bool]$profile.googleAuthEnabled),
  @('public marketplace', $PublicMarketplaceEnabled, [bool]$profile.publicMarketplaceEnabled),
  @('identity verification', $IdentityVerificationEnabled, [bool]$profile.identityVerificationEnabled),
  @('remote push', $RemotePushEnabled, [bool]$profile.remotePushEnabled),
  @('crash reporting', $CrashReportingEnabled, [bool]$profile.crashReportingEnabled),
  @('production activation', $PublicActivationApproved, [bool]$profile.productionActivationApproved),
  @('ads', $AdsEnabled, [bool]$profile.adsEnabled)
)) {
  if ($comparison[1] -ne $comparison[2]) {
    throw "Build argument disagrees with authoritative $ReleaseProfile profile: $($comparison[0])."
  }
}

$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
if ([int]$version.versionCode -lt 98) { throw 'Android release versionCode must be at least 98.' }

$signing = Get-MortUploadSigning
if (-not (Test-Path -LiteralPath $signing.StorePath -PathType Leaf)) {
  throw 'The protected MORT upload keystore does not exist.'
}
Set-MortUploadSigningEnvironment $signing

$keytool = (Get-Command keytool -ErrorAction Stop).Source
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$certificateOutput = & $keytool -list -v -keystore $signing.StorePath `
  -storepass $signing.StorePassword -alias $signing.Alias 2>&1
$certificateExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousPreference
if ($certificateExitCode -ne 0) { throw 'The upload certificate could not be inspected.' }
$certificateSha256 = (($certificateOutput | Select-String '^\s*SHA256:' | Select-Object -First 1).Line -replace '^\s*SHA256:\s*','').Trim()
if ((ConvertTo-MortCertificateDigest $certificateSha256) -ne (ConvertTo-MortCertificateDigest $expectedCertificateSha256)) {
  throw 'The configured upload certificate does not match MORT release identity.'
}

$supabaseUrl = Get-MortPublicConfigValue -PrimaryName 'SUPABASE_URL' -ExpoName 'EXPO_PUBLIC_SUPABASE_URL' -Root $root
$supabaseAnonKey = Get-MortPublicConfigValue -PrimaryName 'SUPABASE_ANON_KEY' -ExpoName 'EXPO_PUBLIC_SUPABASE_ANON_KEY' -Root $root
if ($supabaseUrl -ne $expectedUrl) { throw 'Release build targets the wrong Supabase project.' }
if ([string]::IsNullOrWhiteSpace($supabaseAnonKey)) { throw 'The public Supabase key is missing.' }
$env:SUPABASE_URL = $supabaseUrl
$env:SUPABASE_ANON_KEY = $supabaseAnonKey
& node (Join-Path $PSScriptRoot 'validate-release-profile-server.mjs') $ReleaseProfile
if ($LASTEXITCODE -ne 0) { throw 'Server-authoritative release gate rejected this build.' }

$envLocalPath = Join-Path $root '.env.local'
if (Test-Path -LiteralPath $envLocalPath) {
  $envLocal = Get-Content -Raw -LiteralPath $envLocalPath
  if ($envLocal -match '(?m)^\s*(SUPABASE_SERVICE_ROLE_KEY|SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD)\s*=') {
    throw '.env.local contains a privileged Supabase secret.'
  }
}

if ($ReleaseStage -ne 'closed_test' -and $PlayReviewModeEnabled) {
  throw 'Reviewer mode is forbidden outside the closed-test profile.'
}
if ($ReleaseStage -eq 'closed_test' -and $PublicMarketplaceEnabled) {
  throw 'Closed test cannot enable the public marketplace.'
}
if ($GoogleAuthEnabled -and $ReleaseStage -ne 'closed_test') {
  throw 'Google Auth activation is approved only for the closed-test profile.'
}
if ($ReleaseStage -like 'production_*' -and (-not $RemotePushEnabled -or -not $CrashReportingEnabled)) {
  throw 'Production profiles require real remote-push and crash providers.'
}
if ($ReleaseStage -eq 'production_public' -and (-not $IdentityVerificationEnabled -or -not $PublicActivationApproved)) {
  throw 'Public production requires approved identity verification and public activation evidence.'
}

$versionLabel = '{0}+{1}' -f $version.versionName, $version.versionCode
$symbolsDirectory = Join-Path $env:USERPROFILE (Join-Path 'MortSymbols\android' $versionLabel)
New-Item -ItemType Directory -Force -Path $outputDirectory, $symbolsDirectory | Out-Null

$defineFile = Join-Path ([IO.Path]::GetTempPath()) ("mort-release-defines-$([guid]::NewGuid().ToString('N')).json")
$defines = [ordered]@{
  SUPABASE_URL = $supabaseUrl
  SUPABASE_ANON_KEY = $supabaseAnonKey
  MORT_SUPABASE_PROJECT_REF = $expectedProjectRef
  MORT_AUTH_REDIRECT_URL = $expectedAuthRedirectUrl
  MORT_RELEASE_STAGE = $ReleaseStage
  MORT_RELEASE_PROFILE = $ReleaseProfile
  MORT_OPERATIONAL_MODE = $OperationalMode
  MORT_PUBLIC_MARKETPLACE_ENABLED = $PublicMarketplaceEnabled.ToString().ToLowerInvariant()
  MORT_IDENTITY_VERIFICATION_ENABLED = $IdentityVerificationEnabled.ToString().ToLowerInvariant()
  MORT_MARKETPLACE_PAYMENTS_ENABLED = 'false'
  MORT_REMOTE_PUSH_ENABLED = $RemotePushEnabled.ToString().ToLowerInvariant()
  MORT_CRASH_REPORTING_ENABLED = $CrashReportingEnabled.ToString().ToLowerInvariant()
  MORT_PAYMENT_PROVIDER_MODE = [string]$profile.paymentProviderMode
  MORT_SUPPORT_AI_ENABLED = ([bool]$profile.chatbotAiEnabled).ToString().ToLowerInvariant()
  MORT_DETERMINISTIC_SUPPORT_ENABLED = ([bool]$profile.deterministicChatbotFallbackEnabled).ToString().ToLowerInvariant()
  MORT_PUBLIC_ACTIVATION_APPROVED = $PublicActivationApproved.ToString().ToLowerInvariant()
  MORT_SUPPORT_ROUTE = [string]$profile.supportRoute
  MORT_ADMIN_ROUTE = [string]$profile.adminRoute
  MORT_TERMS_VERSION = [string]$profile.termsVersion
  MORT_PRIVACY_VERSION = [string]$profile.privacyVersion
  MORT_COMMUNITY_GUIDELINES_VERSION = [string]$profile.communityGuidelinesVersion
  MORT_SAFETY_RULES_VERSION = [string]$profile.safetyRulesVersion
  MORT_MINIMUM_SUPPORTED_APP_VERSION = [string]$profile.minimumSupportedAppVersion
  MORT_MAINTENANCE_MODE = ([bool]$profile.maintenanceMode).ToString().ToLowerInvariant()
  MORT_DEBUG_ENDPOINTS_ENABLED = ([bool]$profile.debugEndpointsEnabled).ToString().ToLowerInvariant()
  PLAY_REVIEW_MODE_ENABLED = $PlayReviewModeEnabled.ToString().ToLowerInvariant()
  GOOGLE_AUTH_ENABLED = $GoogleAuthEnabled.ToString().ToLowerInvariant()
  IAP_ENABLED = 'false'
  ADS_ENABLED = $AdsEnabled.ToString().ToLowerInvariant()
  # USE_TEST_ADS is intentionally not yet wired to its own parameter --
  # this keeps every build serving Google's official test ads even once
  # ADS_ENABLED=true is buildable for production/production_candidate.
  # AppConfig's own release validation fails closed if ads are ever
  # enabled with USE_TEST_ADS still true, so a real (non-test) ads
  # rollout requires a deliberate follow-up change here, not an
  # accidental one.
  USE_TEST_ADS = 'true'
}
foreach ($name in $defines.Keys) {
  if ($name -match '(?i)(SERVICE.?ROLE|ACCESS.?TOKEN|REFRESH.?TOKEN|PASSWORD|CLIENT.?SECRET|PRIVATE.?KEY|WEBHOOK.?SECRET)') {
    throw "Forbidden secret-like dart-define key: $name"
  }
}
$defineJson = $defines | ConvertTo-Json -Compress
if ($defineJson -match '(?i)(service_role|client_secret|db_password|private_key|webhook_secret)') {
  throw 'Release dart-defines contain a forbidden secret marker.'
}
[IO.File]::WriteAllText($defineFile, $defineJson, [Text.UTF8Encoding]::new($false))

Push-Location $flutterRoot
try {
  if ($ArtifactKind -eq 'Aab') {
    & flutter build appbundle --release --obfuscate --split-debug-info=$symbolsDirectory "--dart-define-from-file=$defineFile"
  } else {
    & flutter build apk --release --obfuscate --split-debug-info=$symbolsDirectory "--dart-define-from-file=$defineFile"
  }
  if ($LASTEXITCODE -ne 0) { throw "Flutter $ArtifactKind release build failed." }
} finally {
  Pop-Location
  if ($defineFile -and (Test-Path -LiteralPath $defineFile)) {
    Remove-Item -LiteralPath $defineFile -Force
  }
}

$extension = if ($ArtifactKind -eq 'Aab') { 'aab' } else { 'apk' }
$built = if ($ArtifactKind -eq 'Aab') {
  Join-Path $flutterRoot 'build\app\outputs\bundle\release\app-release.aab'
} else {
  Join-Path $flutterRoot 'build\app\outputs\flutter-apk\app-release.apk'
}
if (-not (Test-Path -LiteralPath $built -PathType Leaf)) { throw "Flutter did not produce the release $extension." }
$artifactBaseName = "mort-$($ReleaseStage.Replace('_','-'))-$($version.versionName)-$($version.versionCode)"
$destination = Join-Path $outputDirectory "$artifactBaseName.$extension"
Copy-Item -LiteralPath $built -Destination $destination -Force

if ($ArtifactKind -eq 'Aab') {
  & (Join-Path $PSScriptRoot 'verify-play-aab.ps1') `
    -BundlePath $destination `
    -ReleaseStage $ReleaseStage `
    -PlayReviewModeEnabled:$PlayReviewModeEnabled
} else {
  & (Join-Path $PSScriptRoot 'qa-android-apk.ps1') -ApkPath $destination -RequireSigned
}
if ($LASTEXITCODE -ne 0) { throw "Release $extension verification failed." }

$commit = (& git -C $root rev-parse HEAD).Trim()
$dirty = @(& git -C $root status --porcelain).Count -gt 0
$artifact = Get-Item -LiteralPath $destination
$artifactHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  artifact = $artifact.FullName
  artifactSizeBytes = $artifact.Length
  artifactSha256 = $artifactHash
  versionName = $version.versionName
  versionCode = [int]$version.versionCode
  gitCommit = $commit
  gitDirty = $dirty
  releaseStage = $ReleaseStage
  releaseProfile = $ReleaseProfile
  operationalMode = $OperationalMode
  supabaseProjectRef = $expectedProjectRef
  targetSdk = 36
  minSdk = 24
  signingCertificateSha256 = $certificateSha256
  flags = [ordered]@{
    playReviewModeEnabled = $PlayReviewModeEnabled
    publicMarketplaceEnabled = $PublicMarketplaceEnabled
    identityVerificationEnabled = $IdentityVerificationEnabled
    marketplacePaymentsEnabled = $false
    remotePushEnabled = $RemotePushEnabled
    crashReportingEnabled = $CrashReportingEnabled
    chatbotAiEnabled = [bool]$profile.chatbotAiEnabled
    deterministicChatbotFallbackEnabled = [bool]$profile.deterministicChatbotFallbackEnabled
    publicActivationApproved = $PublicActivationApproved
    googleAuthEnabled = $GoogleAuthEnabled
    adsEnabled = $false
    iapEnabled = $false
  }
  legalVersions = [ordered]@{
    terms = [string]$profile.termsVersion
    privacy = [string]$profile.privacyVersion
    communityGuidelines = [string]$profile.communityGuidelinesVersion
    safetyRules = [string]$profile.safetyRulesVersion
  }
  auth = [ordered]@{
    provider = 'supabase_google_oauth'
    flow = 'pkce'
    redirectUrl = $expectedAuthRedirectUrl
    providerTokensPersistedByMort = $false
  }
  symbolsDirectory = $symbolsDirectory
}
$manifestPath = Join-Path $outputDirectory "$artifactBaseName-$extension-build-manifest.json"
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))

Write-Output "Created verified $ReleaseStage ${ArtifactKind}: $destination"
Write-Output "Build manifest: $manifestPath"
Write-Output "Obfuscation symbols: $symbolsDirectory"
