$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$play = Join-Path $root 'build\play'
$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
$builtApk = Join-Path $play "mort-closed-test-$($version.versionName).apk"
$builtAab = Join-Path $play "mort-closed-test-$($version.versionName).aab"

& (Join-Path $PSScriptRoot 'build-closed-test-apk.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Signed QA APK build failed.' }
& (Join-Path $PSScriptRoot 'qa-android-apk.ps1') -ApkPath $builtApk -RequireSigned
if ($LASTEXITCODE -ne 0) { throw 'Signed QA APK verification failed.' }

& (Join-Path $PSScriptRoot 'build-play-aab.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Signed Play AAB build failed.' }
& (Join-Path $PSScriptRoot 'verify-play-aab.ps1') `
  -BundlePath $builtAab `
  -ReleaseStage closed_test `
  -PlayReviewModeEnabled
if ($LASTEXITCODE -ne 0) { throw 'Signed Play AAB verification failed.' }

Write-Output "Created final closed-test APK: $builtApk"
Write-Output "Created final closed-test AAB: $builtAab"
