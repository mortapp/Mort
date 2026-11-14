[CmdletBinding()]
param(
  [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Resolve-Path "$PSScriptRoot\.."
$flutterRoot = Join-Path $root 'flutter_mort'
if (-not $OutputPath) {
  $OutputPath = Join-Path $root 'build\device-test\mort-prod-device-test.apk'
}

# Production-connected device-test build. This exists so launch QA can run the
# real authenticated journeys (teen/adult/guardian signup, onboarding, job
# posting, applications, guardian consent, messaging) against the production
# backend with authorized test accounts -- the QA-pinned device-test build
# intentionally disables sign-in and account actions.
#
# Only the publishable/anon key is compiled into the client; no privileged
# credential is accepted by this script. The closed_test profile keeps
# payments, push, ads, and crash reporting disabled.
$supabaseUrl = 'https://jxbnrkasktbhtiujkhay.supabase.co'
$supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4Ym5ya2Fza3RiaHRpdWpraGF5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwMjE2NjcsImV4cCI6MjEwODU5NzY2N30.oNHdfbR27JrTxVO7-GM1SjS9sOdrkumoGNzMS97KjQE'

$defines = @(
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey",
  '--dart-define=MORT_SUPABASE_PROJECT_REF=jxbnrkasktbhtiujkhay',
  '--dart-define=MORT_RELEASE_STAGE=closed_test',
  '--dart-define=MORT_RELEASE_PROFILE=closed_test',
  '--dart-define=MORT_OPERATIONAL_MODE=closed_pilot',
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
  if ([string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
    throw 'JAVA_HOME must be set to the configured Temurin JDK 17 path.'
  }
  $javaExecutable = Join-Path $env:JAVA_HOME 'bin\java'
  if (-not (Test-Path -LiteralPath $javaExecutable -PathType Leaf)) {
    throw "Java executable not found under JAVA_HOME: $env:JAVA_HOME"
  }
  $javaVersionOutput = (& $javaExecutable -version 2>&1 | Out-String)
  if ($javaVersionOutput -notmatch 'version "17\.') {
    throw "Production device-test build requires JDK 17. Detected: $javaVersionOutput"
  }
  & flutter config --jdk-dir="$env:JAVA_HOME"
  if ($LASTEXITCODE -ne 0) { throw 'Flutter could not select the configured JDK 17.' }

  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

  & flutter build apk --debug @defines
  if ($LASTEXITCODE -ne 0) { throw 'Production device-test APK build failed.' }
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
Write-Output "Production device-test APK: $($artifact.FullName)"
Write-Output "Size bytes: $($artifact.Length)"
Write-Output "SHA256: $sha256"
