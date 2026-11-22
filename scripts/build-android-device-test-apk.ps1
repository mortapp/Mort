[CmdletBinding()]
param(
  [string]$OutputPath = '',
  [switch]$BrowserStackQa,
  [switch]$RamusX64,
  [switch]$ReleaseBundle
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Resolve-Path "$PSScriptRoot\.."
$flutterRoot = Join-Path $root 'flutter_mort'
if (-not $OutputPath) {
  if ($ReleaseBundle) { throw 'Provide a new absolute path ending in mort-android-qa.aab.' }
  $filename = if ($RamusX64) { 'mort-ramus-x64-qa.apk' } else { 'mort-device-test.apk' }
  $OutputPath = Join-Path $root "build\device-test\$filename"
}

if ($ReleaseBundle) {
  if ($BrowserStackQa -or $RamusX64 -or
      -not [IO.Path]::IsPathFullyQualified($OutputPath) -or
      [IO.Path]::GetFileName($OutputPath) -cne 'mort-android-qa.aab' -or
      (Test-Path -LiteralPath $OutputPath)) {
    throw 'ReleaseBundle requires its own unused absolute mort-android-qa.aab path and normal app mode.'
  }
  # Built only with the dedicated non-store fixture from android-qa-bundle.sh.
  if ($env:MORT_UPLOAD_KEY_ALIAS -cne 'mort-ephemeral-qa' -or
      [IO.Path]::GetFileName($env:MORT_UPLOAD_KEYSTORE_PATH) -cne 'mort-ephemeral-qa.p12' -or
      (Test-Path -LiteralPath (Join-Path $flutterRoot 'android/key.properties')) -or
      (Test-Path -LiteralPath (Join-Path $flutterRoot 'build/app/outputs/bundle/release/app-release.aab'))) {
    throw 'Use the ephemeral QA keystore in a fresh checkout; an existing AAB must not be overwritten.'
  }
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

if ($RamusX64) {
  if ($BrowserStackQa) { throw 'Ramus launch QA must exercise the normal app, not BrowserStack fixture mode.' }
  if ([IO.Path]::GetFileName($OutputPath) -ne 'mort-ramus-x64-qa.apk') {
    throw 'Use the separate mort-ramus-x64-qa.apk output filename for this build.'
  }
  $defines += '--target-platform=android-x64'
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

  if ($ReleaseBundle) {
    & flutter build appbundle --release --target-platform=android-arm,android-arm64,android-x64 @defines
  } else {
    & flutter build apk --debug @defines
  }
  if ($LASTEXITCODE -ne 0) { throw 'Device-test build failed.' }
} finally {
  Pop-Location
}

$builtArtifact = if ($ReleaseBundle) {
  Join-Path $flutterRoot 'build/app/outputs/bundle/release/app-release.aab'
} else {
  Join-Path $flutterRoot 'build\app\outputs\flutter-apk\app-debug.apk'
}
if (-not (Test-Path -LiteralPath $builtArtifact -PathType Leaf)) {
  throw 'Flutter did not produce the expected Android artifact.'
}
if ($RamusX64 -and (Get-Item -LiteralPath $builtArtifact).Length -gt 157286400) {
  throw 'The x86_64-engine QA APK still exceeds the measured Ramus trial upload limit (150 MiB).'
}

$parent = Split-Path $OutputPath -Parent
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
if ($ReleaseBundle) {
  [IO.File]::Copy($builtArtifact, $OutputPath, $false)
} else {
  Copy-Item -LiteralPath $builtArtifact -Destination $OutputPath -Force
}

$artifact = Get-Item -LiteralPath $OutputPath
$sha256 = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
Write-Output "Device-test Android artifact: $($artifact.FullName)"
Write-Output "Size bytes: $($artifact.Length)"
Write-Output "SHA256: $sha256"
