param(
  [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$flutterRoot = Join-Path $repoRoot 'flutter_mort'
$envLocalPath = Join-Path $repoRoot '.env.local'

if (-not (Test-Path $flutterRoot)) {
  throw "Flutter app folder not found: $flutterRoot"
}

function Get-PublicConfigValue {
  param(
    [Parameter(Mandatory = $true)][string]$PrimaryName,
    [Parameter(Mandatory = $true)][string]$ExpoName
  )

  $value = [Environment]::GetEnvironmentVariable($PrimaryName, 'Process')
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    return $value.Trim()
  }

  $value = [Environment]::GetEnvironmentVariable($ExpoName, 'Process')
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    return $value.Trim()
  }

  if (Test-Path $envLocalPath) {
    $envLocal = Get-Content -Raw -Path $envLocalPath
    if ($envLocal -match '(^|\r?\n)\s*SUPABASE_SERVICE_ROLE_KEY\s*=') {
      throw '.env.local contains SUPABASE_SERVICE_ROLE_KEY. Remove it before building Flutter Web.'
    }

    foreach ($line in ($envLocal -split '\r?\n')) {
      if ($line -match "^\s*$ExpoName\s*=\s*(.+)\s*$") {
        return $Matches[1].Trim().Trim('"').Trim("'")
      }
    }
  }

  return $null
}

$supabaseUrl = Get-PublicConfigValue -PrimaryName 'SUPABASE_URL' -ExpoName 'EXPO_PUBLIC_SUPABASE_URL'
$supabaseAnonKey = Get-PublicConfigValue -PrimaryName 'SUPABASE_ANON_KEY' -ExpoName 'EXPO_PUBLIC_SUPABASE_ANON_KEY'

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or -not $supabaseUrl.StartsWith('https://')) {
  throw 'Set SUPABASE_URL or EXPO_PUBLIC_SUPABASE_URL to the hosted Supabase HTTPS URL.'
}
if ([string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
  throw 'Set SUPABASE_ANON_KEY or EXPO_PUBLIC_SUPABASE_ANON_KEY before building Flutter Web.'
}

function Get-EnvironmentStatus {
  param([Parameter(Mandatory = $true)][string]$Name)

  $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, 'User')
  }
  if ([string]::IsNullOrWhiteSpace($value)) { return 'MISSING' }
  return 'SET'
}

$configReportPath = Join-Path $repoRoot 'docs\WEB_BUILD_CONFIG_STATUS.md'
$configReport = @(
  '# Web Build Configuration Status',
  '',
  "Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))",
  '',
  'Values are intentionally omitted. Only public mobile configuration is passed to Flutter Web.',
  '',
  "- SUPABASE_URL: $(if ([string]::IsNullOrWhiteSpace($supabaseUrl)) { 'MISSING' } else { 'SET' })",
  "- SUPABASE_ANON_KEY: $(if ([string]::IsNullOrWhiteSpace($supabaseAnonKey)) { 'MISSING' } else { 'SET' })",
  "- REVENUECAT_IOS_API_KEY: $(Get-EnvironmentStatus 'REVENUECAT_IOS_API_KEY') (not passed to web preview)",
  "- ADMOB_IOS_APP_ID: $(Get-EnvironmentStatus 'ADMOB_IOS_APP_ID') (not passed to web preview)",
  "- ADMOB_IOS_BANNER_AD_UNIT_ID: $(Get-EnvironmentStatus 'ADMOB_IOS_BANNER_AD_UNIT_ID') (not passed to web preview)",
  "- ADMOB_IOS_REWARDED_AD_UNIT_ID: $(Get-EnvironmentStatus 'ADMOB_IOS_REWARDED_AD_UNIT_ID') (not passed to web preview)",
  '- WEB_PREVIEW_MODE: SET_BY_SCRIPT',
  '- IAP_ENABLED: SET_BY_SCRIPT_FALSE',
  '- ADS_ENABLED: SET_BY_SCRIPT_FALSE',
  '- USE_TEST_ADS: SET_BY_SCRIPT_TRUE',
  '- SUPABASE_SERVICE_ROLE_KEY: NOT_INCLUDED',
  '- SUPABASE_ACCESS_TOKEN: NOT_INCLUDED',
  '- SUPABASE_DB_PASSWORD: NOT_INCLUDED',
  '- REVENUECAT_V1_SECRET_API_KEY: NOT_INCLUDED',
  '- REVENUECAT_WEBHOOK_AUTH_HEADER: NOT_INCLUDED',
  '- NETLIFY_AUTH_TOKEN: NOT_INCLUDED'
)
[System.IO.File]::WriteAllLines($configReportPath, $configReport)

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  Write-Host "Running $Label"
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE."
  }
}

Write-Host "Building MORT web preview against hosted Supabase: $supabaseUrl"
Write-Host 'Using Supabase anon key as a public browser key. Not printing key value.'

Push-Location $flutterRoot
try {
  Invoke-Checked 'flutter pub get' { flutter pub get }
  Invoke-Checked 'dart format lib test' { dart format lib test }
  Invoke-Checked 'flutter analyze' { flutter analyze }
  if (-not $SkipTests) {
    Invoke-Checked 'flutter test' { flutter test }
  }
  $buildArgs = @(
    'build',
    'web',
    '--release',
    "--dart-define=SUPABASE_URL=$supabaseUrl",
    "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey",
    '--dart-define=WEB_PREVIEW_MODE=true',
    '--dart-define=IAP_ENABLED=false',
    '--dart-define=ADS_ENABLED=false',
    '--dart-define=USE_TEST_ADS=true'
  )
  Invoke-Checked 'flutter build web release preview' { flutter @buildArgs }
} finally {
  Pop-Location
}
