param(
  [switch]$SkipTests,
  [switch]$BuildAppBundle,
  [switch]$DebugQaOnly
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$flutterRoot = Join-Path $repoRoot 'flutter_mort'
$envLocalPath = Join-Path $repoRoot '.env.local'
$defineFile = $null

function Get-PublicConfigValue {
  param(
    [Parameter(Mandatory = $true)][string]$PrimaryName,
    [Parameter(Mandatory = $true)][string]$ExpoName
  )

  foreach ($scope in @('Process', 'User')) {
    foreach ($name in @($PrimaryName, $ExpoName)) {
      $value = [Environment]::GetEnvironmentVariable($name, $scope)
      if (-not [string]::IsNullOrWhiteSpace($value)) { return $value.Trim() }
    }
  }

  if (Test-Path $envLocalPath) {
    $envLocal = Get-Content -Raw -LiteralPath $envLocalPath
    if ($envLocal -match '(?m)^\s*SUPABASE_SERVICE_ROLE_KEY\s*=') {
      throw '.env.local contains SUPABASE_SERVICE_ROLE_KEY. Remove it before building Android.'
    }
    foreach ($line in ($envLocal -split '\r?\n')) {
      if ($line -match "^\s*$ExpoName\s*=\s*(.+)\s*$") {
        return $Matches[1].Trim().Trim('"').Trim("'")
      }
    }
  }
  return $null
}

function Get-UserOrProcessValue {
  param([Parameter(Mandatory = $true)][string]$Name)
  $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, 'User')
  }
  return $value
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )
  Write-Host "Running $Label"
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE." }
}

$supabaseUrl = Get-PublicConfigValue -PrimaryName 'SUPABASE_URL' -ExpoName 'EXPO_PUBLIC_SUPABASE_URL'
$supabaseAnonKey = Get-PublicConfigValue -PrimaryName 'SUPABASE_ANON_KEY' -ExpoName 'EXPO_PUBLIC_SUPABASE_ANON_KEY'
if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or -not $supabaseUrl.StartsWith('https://')) {
  throw 'A hosted HTTPS Supabase URL is required.'
}
if ([string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  throw 'A public Supabase anon/publishable key is required.'
}

$signingNames = @(
  'MORT_ANDROID_KEYSTORE_PATH',
  'MORT_ANDROID_KEYSTORE_PASSWORD',
  'MORT_ANDROID_KEY_ALIAS',
  'MORT_ANDROID_KEY_PASSWORD'
)
$signingValues = @{}
foreach ($name in $signingNames) { $signingValues[$name] = Get-UserOrProcessValue $name }
$hasSigning = ($signingNames | Where-Object { [string]::IsNullOrWhiteSpace($signingValues[$_]) }).Count -eq 0
if ($hasSigning -and -not (Test-Path -LiteralPath $signingValues['MORT_ANDROID_KEYSTORE_PATH'])) {
  throw 'MORT_ANDROID_KEYSTORE_PATH is set but the keystore file does not exist.'
}
if ($BuildAppBundle -and -not $hasSigning) {
  throw 'A signed App Bundle requires all MORT_ANDROID_KEYSTORE_* variables. No AAB was created.'
}
if ($BuildAppBundle -and $DebugQaOnly) {
  throw 'DebugQaOnly cannot be combined with BuildAppBundle.'
}

$statusPath = Join-Path $repoRoot 'docs\mobile\MORT_ANDROID_BUILD_CONFIG_STATUS.md'
$statusDirectory = Split-Path -Parent $statusPath
New-Item -ItemType Directory -Path $statusDirectory -Force | Out-Null
$status = @(
  '# MORT Android Build Configuration Status',
  '',
  "Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))",
  '',
  '- Hosted Supabase URL: SET',
  '- Public Supabase anon/publishable key: SET',
  "- Release signing variables: $(if ($hasSigning) { 'SET' } else { 'MISSING' })",
  '- Service-role key passed to Flutter: NO',
  '- Supabase access token passed to Flutter: NO',
  '- Database password passed to Flutter: NO',
  '- Ads enabled: NO',
  '- IAP enabled: NO',
  '',
  $(if ($DebugQaOnly) {
    'Debug APK output uses the local Android debug key for QA installation only. It is not a Play release.'
  } else {
    'Unsigned APK output is compile validation only. It is not installable as a Play release. A signed AAB is blocked until release signing is configured.'
  })
)
[IO.File]::WriteAllLines($statusPath, $status)

$defineFile = Join-Path ([IO.Path]::GetTempPath()) ("mort-android-defines-$([guid]::NewGuid().ToString('N')).json")
$defines = [ordered]@{
  SUPABASE_URL = $supabaseUrl
  SUPABASE_ANON_KEY = $supabaseAnonKey
  IAP_ENABLED = 'false'
  ADS_ENABLED = 'false'
  USE_TEST_ADS = 'true'
}
[IO.File]::WriteAllText(
  $defineFile,
  ($defines | ConvertTo-Json -Compress),
  [Text.UTF8Encoding]::new($false)
)

Push-Location $flutterRoot
try {
  Invoke-Checked 'flutter pub get' { flutter pub get }
  Invoke-Checked 'dart format lib test' { dart format lib test }
  Invoke-Checked 'flutter analyze' { flutter analyze }
  if (-not $SkipTests) { Invoke-Checked 'flutter test' { flutter test } }
  if ($DebugQaOnly) {
    Invoke-Checked 'flutter build apk --debug' {
      flutter build apk --debug "--dart-define-from-file=$defineFile"
    }
  } else {
    Invoke-Checked 'flutter build apk --release' {
      flutter build apk --release "--dart-define-from-file=$defineFile"
    }
  }
  if ($BuildAppBundle) {
    Invoke-Checked 'flutter build appbundle --release' {
      flutter build appbundle --release "--dart-define-from-file=$defineFile"
    }
  }
} finally {
  Pop-Location
  if ($defineFile -and (Test-Path -LiteralPath $defineFile)) {
    Remove-Item -LiteralPath $defineFile -Force
  }
}
