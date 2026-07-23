[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'android-signing-common.ps1')

$root = Split-Path $PSScriptRoot -Parent
$flutterRoot = Join-Path $root 'flutter_mort'
$outputDirectory = Join-Path $root 'build\play'
$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
$versionLabel = '{0}+{1}' -f $version.versionName, $version.versionCode
$symbolsDirectory = Join-Path $env:USERPROFILE (Join-Path 'MortSymbols\android' $versionLabel)

$signing = Get-MortUploadSigning
Set-MortUploadSigningEnvironment $signing

$supabaseUrl = Get-MortPublicConfigValue -PrimaryName 'SUPABASE_URL' -ExpoName 'EXPO_PUBLIC_SUPABASE_URL' -Root $root
$supabaseAnonKey = Get-MortPublicConfigValue -PrimaryName 'SUPABASE_ANON_KEY' -ExpoName 'EXPO_PUBLIC_SUPABASE_ANON_KEY' -Root $root
if ($supabaseUrl -ne 'https://rakjydmgwwgtdislanbt.supabase.co') {
  throw 'The closed-test build must target Supabase project rakjydmgwwgtdislanbt.'
}
if ([string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  throw 'The public Supabase anonymous key is required for the mobile build.'
}

New-Item -ItemType Directory -Force -Path $outputDirectory, $symbolsDirectory | Out-Null
Push-Location $flutterRoot
try {
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & flutter build appbundle --release --obfuscate --split-debug-info=$symbolsDirectory `
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
  if ($flutterExitCode -ne 0) { throw "Flutter release AAB build failed with exit code $flutterExitCode." }
} finally {
  $ErrorActionPreference = 'Stop'
  Pop-Location
}

$built = Join-Path $flutterRoot 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path -LiteralPath $built -PathType Leaf)) {
  throw 'Flutter did not produce app-release.aab.'
}
$destination = Join-Path $outputDirectory 'mort-closed-test.aab'
Copy-Item -LiteralPath $built -Destination $destination -Force
"Created signed closed-test AAB: $destination"
"Obfuscation symbols retained outside the repository: $symbolsDirectory"
