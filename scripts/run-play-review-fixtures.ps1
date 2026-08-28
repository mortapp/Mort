$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'play-review-secrets-common.ps1')
Set-MortPlayReviewEnvironment
try {
  & node (Join-Path $PSScriptRoot 'create-play-review-fixtures.mjs')
  if ($LASTEXITCODE -ne 0) { throw 'Play review fixture creation failed.' }
} finally {
  $env:PLAY_REVIEW_TEEN_PASSWORD = $null
  $env:PLAY_REVIEW_ADULT_PASSWORD = $null
  $env:PLAY_REVIEW_TEEN_EMAIL = $null
  $env:PLAY_REVIEW_ADULT_EMAIL = $null
  $env:SUPABASE_SERVICE_ROLE_KEY = $null
  $env:SUPABASE_DB_PASSWORD = $null
}
