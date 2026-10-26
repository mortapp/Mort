[CmdletBinding()]
param(
  [string]$OutputPath = '',
  [switch]$BrowserStackQa
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Resolve-Path "$PSScriptRoot\.."
$flutterRoot = Join-Path $root 'flutter_mort'
. (Join-Path $PSScriptRoot 'android-signing-common.ps1')
if (-not $OutputPath) {
  $OutputPath = Join-Path $root 'build\device-test\mort-device-test.apk'
}

# Public client configuration only. This is intentionally safe to compile into
# the Android app; no service-role, database password, webhook secret, or other
# privileged credential is used here.
$supabaseUrl = Get-MortPublicConfigValue -PrimaryName 'SUPABASE_URL' -ExpoName 'EXPO_PUBLIC_SUPABASE_URL' -Root $root
$supabaseAnonKey = Get-MortPublicConfigValue -PrimaryName 'SUPABASE_ANON_KEY' -ExpoName 'EXPO_PUBLIC_SUPABASE_ANON_KEY' -Root $root
$configuredExpectedProjectRef = Get-MortPublicConfigValue `
  -PrimaryName 'MORT_EXPECTED_SUPABASE_PROJECT_REF' `
  -ExpoName 'MORT_EXPECTED_SUPABASE_PROJECT_REF' `
  -Root $root
$supabaseUri = $null
if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or
    -not [Uri]::TryCreate($supabaseUrl, [UriKind]::Absolute, [ref]$supabaseUri) -or
    $supabaseUri.Scheme -ne 'https' -or
    $supabaseUri.Host -notmatch '^(?<projectRef>[a-z0-9]+)\.supabase\.co$') {
  throw 'Device-test build requires an HTTPS Supabase project URL.'
}
$projectRef = $Matches.projectRef
if ([string]::IsNullOrWhiteSpace($supabaseAnonKey) -or
    (-not [string]::IsNullOrWhiteSpace($configuredExpectedProjectRef) -and
      $configuredExpectedProjectRef.Trim() -ne $projectRef)) {
  throw 'Device-test Supabase configuration is incomplete or inconsistent.'
}

$defines = @(
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey",
  "--dart-define=MORT_SUPABASE_PROJECT_REF=$projectRef",
  "--dart-define=MORT_EXPECTED_SUPABASE_PROJECT_REF=$projectRef",
  '--dart-define=MORT_RELEASE_STAGE=internal_test',
  '--dart-define=MORT_RELEASE_PROFILE=automated_test',
  '--dart-define=MORT_OPERATIONAL_MODE=automated_test',
  '--dart-define=MORT_PUBLIC_MARKETPLACE_ENABLED=false',
  '--dart-define=MORT_IDENTITY_VERIFICATION_ENABLED=false',
  '--dart-define=MORT_MARKETPLACE_PAYMENTS_ENABLED=false',
  '--dart-define=MORT_PAYMENT_PROVIDER_MODE=disabled',
  '--dart-define=MORT_REMOTE_PUSH_ENABLED=false',
  '--dart-define=MORT_CRASH_REPORTING_ENABLED=false',
  '--dart-define=MORT_PRODUCT_ANALYTICS_ENABLED=false',
  '--dart-define=MORT_SUPPORT_AI_ENABLED=false',
  '--dart-define=MORT_DETERMINISTIC_SUPPORT_ENABLED=true',
  '--dart-define=MORT_PUBLIC_ACTIVATION_APPROVED=false',
  '--dart-define=GOOGLE_AUTH_ENABLED=true',
  '--dart-define=APPLE_AUTH_ENABLED=false',
  '--dart-define=ADS_ENABLED=false',
  '--dart-define=USE_TEST_ADS=true',
  '--dart-define=IAP_ENABLED=false'
) 

if ($BrowserStackQa) {
  $defines += '--dart-define=MORT_BROWSERSTACK_QA_MODE=true'
}

Push-Location $flutterRoot
try {
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

  & flutter build apk --debug @defines
  if ($LASTEXITCODE -ne 0) { throw 'Device-test APK build failed.' }
} finally {
  Pop-Location
}

$builtApk = Join-Path $flutterRoot 'build\app\outputs\flutter-apk\app-debug.apk'
if (-not (Test-Path -LiteralPath $builtApk -PathType Leaf)) {
  throw 'Flutter did not produce app-debug.apk.'
}

$parent = Split-Path $OutputPath -Parent
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
Copy-Item -LiteralPath $builtApk -Destination $OutputPath -Force

$artifact = Get-Item -LiteralPath $OutputPath
$sha256 = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
Write-Output "Device-test APK: $($artifact.FullName)"
Write-Output "Size bytes: $($artifact.Length)"
Write-Output "SHA256: $sha256"
