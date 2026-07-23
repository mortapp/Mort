[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'android-signing-common.ps1')

$root = Split-Path $PSScriptRoot -Parent
$flutterRoot = Join-Path $root 'flutter_mort'
$outputDirectory = Join-Path $root 'build\play'
$signing = Get-MortUploadSigning
Set-MortUploadSigningEnvironment $signing

$supabaseUrl = Get-MortPublicConfigValue -PrimaryName 'SUPABASE_URL' -ExpoName 'EXPO_PUBLIC_SUPABASE_URL' -Root $root
$supabaseAnonKey = Get-MortPublicConfigValue -PrimaryName 'SUPABASE_ANON_KEY' -ExpoName 'EXPO_PUBLIC_SUPABASE_ANON_KEY' -Root $root
if ($supabaseUrl -ne 'https://rakjydmgwwgtdislanbt.supabase.co' -or [string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  throw 'Hosted MORT Supabase public configuration is missing or points to the wrong project.'
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Push-Location $flutterRoot
try {
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & flutter build apk --release `
    --dart-define=SUPABASE_URL=$supabaseUrl `
    --dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey `
    --dart-define=MORT_RELEASE_STAGE=closed_test `
    --dart-define=MORT_OPERATIONAL_MODE=closed_pilot `
    --dart-define=MORT_PUBLIC_MARKETPLACE_ENABLED=false `
    --dart-define=MORT_IDENTITY_VERIFICATION_ENABLED=false `
    --dart-define=IAP_ENABLED=false `
    --dart-define=ADS_ENABLED=false `
    --dart-define=USE_TEST_ADS=true
  $flutterExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  if ($flutterExitCode -ne 0) { throw "Flutter closed-test APK build failed with exit code $flutterExitCode." }
} finally {
  $ErrorActionPreference = 'Stop'
  Pop-Location
}

$built = Join-Path $flutterRoot 'build\app\outputs\flutter-apk\app-release.apk'
$destination = Join-Path $outputDirectory 'mort-play-closed-test-qa.apk'
Copy-Item -LiteralPath $built -Destination $destination -Force
"Created release-signed QA APK: $destination"
