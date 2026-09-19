[CmdletBinding()]
param(
  [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Resolve-Path "$PSScriptRoot\.."
$flutterRoot = Join-Path $root 'flutter_mort'
if (-not $OutputPath) {
  $OutputPath = Join-Path $root 'build\device-test\mort-play-console-backend-fixed.aab'
}

$supabaseUrl = 'https://rakjydmgwwgtdislanbt.supabase.co'
$supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJha2p5ZG1nd3dndGRpc2xhbmJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4NzExNzUsImV4cCI6MjA5NzQ0NzE3NX0.DorOgj6jdPTrPX45Vi0O1dYgx-e3zgO6_S39JDcL2Ww'

$tempDir = Join-Path ([IO.Path]::GetTempPath()) ("mort-play-aab-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$keystore = Join-Path $tempDir 'mort-play-upload.jks'
$storePass = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(24)).Replace('/','A').Replace('+','B').Replace('=','C')
$keyAlias = 'mort-play-upload'

try {
  $keytool = (Get-Command keytool -ErrorAction Stop).Source
  $keyArgs = @(
    '-genkeypair','-v',
    '-keystore',$keystore,
    '-storepass',$storePass,
    '-keypass',$storePass,
    '-alias',$keyAlias,
    '-keyalg','RSA',
    '-keysize','2048',
    '-validity','10000',
    '-dname','CN=MORT Play Test, OU=MORT, O=MORT, L=Indianapolis, ST=Indiana, C=US'
  )
  & $keytool @keyArgs
  if ($LASTEXITCODE -ne 0) { throw 'Temporary upload keystore generation failed.' }

  $env:MORT_UPLOAD_KEYSTORE_PATH = $keystore
  $env:MORT_UPLOAD_STORE_PASSWORD = $storePass
  $env:MORT_UPLOAD_KEY_ALIAS = $keyAlias
  $env:MORT_UPLOAD_KEY_PASSWORD = $storePass

  $defineFile = Join-Path $tempDir 'dart-defines.json'
  $defines = [ordered]@{
    SUPABASE_URL = $supabaseUrl
    SUPABASE_ANON_KEY = $supabaseAnonKey
    MORT_SUPABASE_PROJECT_REF = 'rakjydmgwwgtdislanbt'
    MORT_AUTH_REDIRECT_URL = 'com.mortapp.mobile://app/auth-callback'
    MORT_RELEASE_STAGE = 'closed_test'
    MORT_RELEASE_PROFILE = 'closed_test'
    MORT_OPERATIONAL_MODE = 'closed_pilot'
    MORT_PUBLIC_MARKETPLACE_ENABLED = 'false'
    MORT_IDENTITY_VERIFICATION_ENABLED = 'false'
    MORT_MARKETPLACE_PAYMENTS_ENABLED = 'false'
    MORT_PAYMENT_PROVIDER_MODE = 'disabled'
    MORT_REMOTE_PUSH_ENABLED = 'false'
    MORT_CRASH_REPORTING_ENABLED = 'false'
    MORT_PRODUCT_ANALYTICS_ENABLED = 'false'
    MORT_SUPPORT_AI_ENABLED = 'false'
    MORT_DETERMINISTIC_SUPPORT_ENABLED = 'true'
    MORT_PUBLIC_ACTIVATION_APPROVED = 'false'
    MORT_SUPPORT_ROUTE = '/support'
    MORT_ADMIN_ROUTE = '/admin/home'
    MORT_TERMS_VERSION = 'draft-2026-07'
    MORT_PRIVACY_VERSION = 'draft-2026-07'
    MORT_COMMUNITY_GUIDELINES_VERSION = 'draft-2026-07'
    MORT_SAFETY_RULES_VERSION = 'draft-2026-07'
    MORT_MINIMUM_SUPPORTED_APP_VERSION = '0.9.11'
    MORT_MAINTENANCE_MODE = 'false'
    MORT_DEBUG_ENDPOINTS_ENABLED = 'false'
    PLAY_REVIEW_MODE_ENABLED = 'false'
    GOOGLE_AUTH_ENABLED = 'true'
    APPLE_AUTH_ENABLED = 'false'
    ADS_ENABLED = 'false'
    USE_TEST_ADS = 'true'
    IAP_ENABLED = 'false'
  }
  [IO.File]::WriteAllText(
    $defineFile,
    ($defines | ConvertTo-Json -Compress),
    [Text.UTF8Encoding]::new($false)
  )

  Push-Location $flutterRoot
  try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

    & flutter build appbundle --release "--dart-define-from-file=$defineFile"
    if ($LASTEXITCODE -ne 0) { throw 'Play test AAB build failed.' }
  } finally {
    Pop-Location
  }

  $built = Join-Path $flutterRoot 'build\app\outputs\bundle\release\app-release.aab'
  if (-not (Test-Path -LiteralPath $built -PathType Leaf)) {
    throw 'Flutter did not produce app-release.aab.'
  }

  $parent = Split-Path $OutputPath -Parent
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Copy-Item -LiteralPath $built -Destination $OutputPath -Force

  $archive = [System.IO.Compression.ZipFile]::OpenRead($OutputPath)
  try {
    $backendUrlFound = $false
    $projectRefFound = $false
    foreach ($entry in $archive.Entries) {
      if ($entry.Length -eq 0) { continue }
      $stream = $entry.Open()
      try {
        $memory = New-Object IO.MemoryStream
        $stream.CopyTo($memory)
        $text = [Text.Encoding]::UTF8.GetString($memory.ToArray())
        if ($text.Contains($supabaseUrl)) { $backendUrlFound = $true }
        if ($text.Contains('rakjydmgwwgtdislanbt')) { $projectRefFound = $true }
      } finally {
        $stream.Dispose()
      }
      if ($backendUrlFound -and $projectRefFound) { break }
    }
    if (-not $backendUrlFound -or -not $projectRefFound) {
      throw 'Compiled AAB does not contain the required MORT public backend configuration.'
    }
  } finally {
    $archive.Dispose()
  }

  $item = Get-Item -LiteralPath $OutputPath
  $sha256 = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
  Write-Output 'AAB backend config verification: PASS'
  Write-Output "Play test AAB: $($item.FullName)"
  Write-Output "Size bytes: $($item.Length)"
  Write-Output "SHA256: $sha256"
} finally {
  Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
