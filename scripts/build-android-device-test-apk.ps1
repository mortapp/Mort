[CmdletBinding()]
param(
  [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Resolve-Path "$PSScriptRoot\.."
$flutterRoot = Join-Path $root 'flutter_mort'
if (-not $OutputPath) {
  $OutputPath = Join-Path $root 'build\device-test\mort-device-test.apk'
}

# Public client configuration only. This is intentionally safe to compile into
# the Android app; no service-role, database password, webhook secret, or other
# privileged credential is used here.
$supabaseUrl = 'https://rakjydmgwwgtdislanbt.supabase.co'
$supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYXNlIiwicmVmIjoicmFranlkbWd3d2d0ZGlzbGFuYnQiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc4MTg3MTE3NSwiZXhwIjoyMDk3NDQ3MTc1fQ.DorOgj6jdPTrPX45Vi0O1dYgx-e3zgO6_S39JDcL2Ww'

$defines = @(
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey",
  '--dart-define=MORT_SUPABASE_PROJECT_REF=rakjydmgwwgtdislanbt',
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
