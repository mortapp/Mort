$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot '..\android-signing-common.ps1')

$names = @('SUPABASE_URL', 'EXPO_PUBLIC_SUPABASE_URL')
$previous = @{}
foreach ($name in $names) {
  $previous["Process:$name"] = [Environment]::GetEnvironmentVariable($name, 'Process')
  $previous["User:$name"] = [Environment]::GetEnvironmentVariable($name, 'User')
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("mort-config-priority-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
  [Environment]::SetEnvironmentVariable('SUPABASE_URL', $null, 'Process')
  [Environment]::SetEnvironmentVariable('EXPO_PUBLIC_SUPABASE_URL', 'https://legacy.supabase.co', 'Process')
  [Environment]::SetEnvironmentVariable('SUPABASE_URL', 'https://flutter-user.supabase.co', 'User')
  [Environment]::SetEnvironmentVariable('EXPO_PUBLIC_SUPABASE_URL', $null, 'User')

  $resolved = Get-MortPublicConfigValue `
    -PrimaryName 'SUPABASE_URL' `
    -ExpoName 'EXPO_PUBLIC_SUPABASE_URL' `
    -Root $tempRoot
  if ($resolved -ne 'https://flutter-user.supabase.co') {
    throw 'Flutter SUPABASE_URL must take precedence over the legacy Expo URL.'
  }

  [Environment]::SetEnvironmentVariable('SUPABASE_URL', $null, 'User')
  Set-Content -LiteralPath (Join-Path $tempRoot '.env.local') -Value 'SUPABASE_URL=https://flutter-file.supabase.co' -Encoding utf8
  $resolved = Get-MortPublicConfigValue `
    -PrimaryName 'SUPABASE_URL' `
    -ExpoName 'EXPO_PUBLIC_SUPABASE_URL' `
    -Root $tempRoot
  if ($resolved -ne 'https://flutter-file.supabase.co') {
    throw 'Flutter .env.local SUPABASE_URL must take precedence over the legacy Expo URL.'
  }

  Remove-Item -LiteralPath (Join-Path $tempRoot '.env.local') -Force
  [Environment]::SetEnvironmentVariable('SUPABASE_URL', $null, 'User')
  $resolved = Get-MortPublicConfigValue `
    -PrimaryName 'SUPABASE_URL' `
    -ExpoName 'EXPO_PUBLIC_SUPABASE_URL' `
    -Root $tempRoot
  if ($resolved -ne 'https://legacy.supabase.co') {
    throw 'Legacy Expo configuration should remain available as a fallback.'
  }
} finally {
  foreach ($name in $names) {
    [Environment]::SetEnvironmentVariable($name, $previous["Process:$name"], 'Process')
    [Environment]::SetEnvironmentVariable($name, $previous["User:$name"], 'User')
  }
  Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

Write-Output '[android-public-config-priority] PASS: Flutter Supabase values precede Expo fallback values.'
