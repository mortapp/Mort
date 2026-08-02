[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
$baseName = "mort-closed-test-$($version.versionName)"
$play = Join-Path $root 'build\play'
$apkPath = Join-Path $play "$baseName.apk"
$aabPath = Join-Path $play "$baseName.aab"
$apkManifestPath = Join-Path $play "$baseName-apk-build-manifest.json"
$aabManifestPath = Join-Path $play "$baseName-aab-build-manifest.json"

foreach ($path in @($apkPath, $aabPath, $apkManifestPath, $aabManifestPath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Google Auth release evidence is missing: $path"
  }
}

foreach ($entry in @(
  @{ Artifact = $apkPath; Manifest = $apkManifestPath; Kind = 'APK' },
  @{ Artifact = $aabPath; Manifest = $aabManifestPath; Kind = 'AAB' }
)) {
  $manifest = Get-Content -Raw -LiteralPath $entry.Manifest | ConvertFrom-Json
  if ($manifest.versionName -ne $version.versionName -or
      [int]$manifest.versionCode -ne [int]$version.versionCode) {
    throw "$($entry.Kind) build manifest has the wrong version."
  }
  if ($manifest.releaseStage -ne 'closed_test' -or
      $manifest.operationalMode -ne 'closed_pilot' -or
      $manifest.supabaseProjectRef -ne 'rakjydmgwwgtdislanbt') {
    throw "$($entry.Kind) build manifest has the wrong release identity."
  }
  if (-not $manifest.flags.googleAuthEnabled -or
      -not $manifest.flags.playReviewModeEnabled -or
      $manifest.flags.publicMarketplaceEnabled -or
      $manifest.flags.identityVerificationEnabled -or
      $manifest.flags.marketplacePaymentsEnabled -or
      $manifest.flags.remotePushEnabled -or
      $manifest.flags.crashReportingEnabled -or
      $manifest.flags.publicActivationApproved -or
      $manifest.flags.adsEnabled -or
      $manifest.flags.iapEnabled) {
    throw "$($entry.Kind) build flags do not match the approved closed-test profile."
  }
  if ($manifest.auth.provider -ne 'supabase_google_oauth' -or
      $manifest.auth.flow -ne 'pkce' -or
      $manifest.auth.redirectUrl -ne 'com.mortapp.mobile://app/auth-callback' -or
      $manifest.auth.providerTokensPersistedByMort) {
    throw "$($entry.Kind) Google Auth contract is invalid."
  }
  $artifact = Get-Item -LiteralPath $entry.Artifact
  $hash = (Get-FileHash -LiteralPath $entry.Artifact -Algorithm SHA256).Hash
  if ($artifact.Length -ne [long]$manifest.artifactSizeBytes -or
      $hash -ne $manifest.artifactSha256) {
    throw "$($entry.Kind) does not match its build manifest."
  }
}

$authRepository = Get-Content -Raw -LiteralPath (
  Join-Path $root 'flutter_mort\lib\data\repositories\auth_repository.dart'
)
$supabaseService = Get-Content -Raw -LiteralPath (
  Join-Path $root 'flutter_mort\lib\data\services\supabase_service.dart'
)
if (-not $authRepository.Contains('signInWithOAuth(') -or
    -not $authRepository.Contains('OAuthProvider.google') -or
    -not $supabaseService.Contains('AuthFlowType.pkce')) {
  throw 'Flutter Google Auth is not using the approved Supabase PKCE flow.'
}
if ($authRepository -match '(?i)(client_secret|service_role|providerToken|providerRefreshToken)') {
  throw 'Flutter Google Auth source contains a forbidden credential boundary.'
}
$credentialFiles = @(& rg --files --hidden `
  -g 'client_secret_*.json' `
  -g '!build/**' `
  -g '!artifacts/**' `
  -g '!temp_old_zip/**' `
  -g '!temp_zip/**' `
  -g '!RorkIOSManualCopy/**' `
  $root)
if ($LASTEXITCODE -gt 1) {
  throw 'Could not scan the repository for Google client-secret files.'
}
if ($credentialFiles.Count -gt 0) {
  throw 'A Google OAuth client-secret JSON file exists inside the MORT repository.'
}

Write-Output 'PASS: Google Auth release manifests match the versioned APK/AAB and approved closed-test profile.'
