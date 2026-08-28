[CmdletBinding()]
param(
  [ValidateSet('reviewer_demo','closed_test','production_candidate','production','production_pilot','production_public')]
  [string]$Profile = 'reviewer_demo',
  [switch]$Apk
)

$script = switch ($Profile) {
  'reviewer_demo' {
    if ($Apk) { 'build-closed-test-apk.ps1' } else { 'build-closed-test-aab.ps1' }
  }
  'closed_test' {
    if ($Apk) { 'build-standard-closed-test-apk.ps1' } else { 'build-standard-closed-test-aab.ps1' }
  }
  'production_candidate' {
    if ($Apk) { throw 'Production candidate builds are distributed as verified AABs only.' }
    'build-production-pilot-aab.ps1'
  }
  'production_pilot' {
    if ($Apk) { throw 'Production pilot builds are distributed as verified AABs only.' }
    'build-production-pilot-aab.ps1'
  }
  'production_public' {
    if ($Apk) { throw 'Public production builds are distributed as verified AABs only.' }
    'build-production-public-aab.ps1'
  }
  'production' {
    if ($Apk) { throw 'Public production builds are distributed as verified AABs only.' }
    'build-production-public-aab.ps1'
  }
}

& (Join-Path $PSScriptRoot $script)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
