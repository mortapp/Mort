Set-StrictMode -Version Latest

function Set-MortPlayReviewEnvironment {
  foreach ($name in @(
    'PLAY_REVIEW_TEEN_EMAIL','PLAY_REVIEW_TEEN_PASSWORD',
    'PLAY_REVIEW_ADULT_EMAIL','PLAY_REVIEW_ADULT_PASSWORD'
  )) {
    $value = [Environment]::GetEnvironmentVariable($name, 'User')
    if ([string]::IsNullOrWhiteSpace($value)) {
      throw "Missing protected User environment variable: $name"
    }
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
  }
  $env:SUPABASE_SERVICE_ROLE_KEY = [Environment]::GetEnvironmentVariable('SUPABASE_SERVICE_ROLE_KEY', 'User')
  $env:SUPABASE_DB_PASSWORD = [Environment]::GetEnvironmentVariable('SUPABASE_DB_PASSWORD', 'User')

  $envPath = Join-Path (Split-Path $PSScriptRoot -Parent) '.env.local'
  foreach ($line in Get-Content -LiteralPath $envPath) {
    if ($line -match '^\s*EXPO_PUBLIC_SUPABASE_URL\s*=\s*(.+?)\s*$') {
      $env:EXPO_PUBLIC_SUPABASE_URL = $Matches[1].Trim().Trim('"').Trim("'")
    }
    if ($line -match '^\s*EXPO_PUBLIC_SUPABASE_ANON_KEY\s*=\s*(.+?)\s*$') {
      $env:EXPO_PUBLIC_SUPABASE_ANON_KEY = $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  if ([string]::IsNullOrWhiteSpace($env:SUPABASE_SERVICE_ROLE_KEY) -or
      [string]::IsNullOrWhiteSpace($env:SUPABASE_DB_PASSWORD) -or
      [string]::IsNullOrWhiteSpace($env:EXPO_PUBLIC_SUPABASE_ANON_KEY)) {
    throw 'Required Supabase QA credentials are not available.'
  }
}
