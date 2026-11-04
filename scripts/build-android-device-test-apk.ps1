[CmdletBinding()]
param(
  [string]$OutputPath = '',
  [switch]$BrowserStackQa
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Resolve-Path "$PSScriptRoot\.."
$flutterRoot = Join-Path $root 'flutter_mort'
if (-not $OutputPath) {
  $OutputPath = Join-Path $root 'build\device-test\mort-device-test.apk'
}

# Device-test builds are isolated to the QA Supabase project. Only the
# publishable/anon key is compiled into the client; no privileged credential
# is accepted by this script.
$supabaseUrl = 'https://ckcxakhxqlkhppsxxjhv.supabase.co'
$supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNrY3hha2h4cWxraHBwc3h4amh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM1Nzc1NjAsImV4cCI6MjEwOTE1MzU2MH0.8E8sGxUv7a1on8BHxq7_72TGASVkIcK4X5b1PgNO_d8'

$defines = @(
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey",
  '--dart-define=MORT_SUPABASE_PROJECT_REF=ckcxakhxqlkhppsxxjhv',
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
  if ([string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
    throw 'JAVA_HOME must be set to the configured Temurin JDK 17 path.'
  }
  $javaExecutable = Join-Path $env:JAVA_HOME 'bin/java'
  if (-not (Test-Path -LiteralPath $javaExecutable -PathType Leaf)) {
    throw "Java executable not found under JAVA_HOME: $env:JAVA_HOME"
  }
  $javaVersionOutput = (& $javaExecutable -version 2>&1 | Out-String)
  if ($javaVersionOutput -notmatch 'version "17\.') {
    throw "Android device-test build requires JDK 17. Detected: $javaVersionOutput"
  }
  & flutter config --jdk-dir="$env:JAVA_HOME"
  if ($LASTEXITCODE -ne 0) { throw 'Flutter could not select the configured JDK 17.' }

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
