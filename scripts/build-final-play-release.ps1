$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$play = Join-Path $root 'build\play'
$finalApk = Join-Path $root 'mort-play-production-pilot-final-qa.apk'
$finalAab = Join-Path $root 'mort-play-production-pilot-final.aab'

& (Join-Path $PSScriptRoot 'build-closed-test-apk.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Signed QA APK build failed.' }
$builtApk = Join-Path $play 'mort-play-closed-test-qa.apk'
& (Join-Path $PSScriptRoot 'qa-android-apk.ps1') -ApkPath $builtApk -RequireSigned
if ($LASTEXITCODE -ne 0) { throw 'Signed QA APK verification failed.' }
Copy-Item -LiteralPath $builtApk -Destination $finalApk -Force

& (Join-Path $PSScriptRoot 'build-play-aab.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Signed Play AAB build failed.' }
$builtAab = Join-Path $play 'mort-closed-test.aab'
& (Join-Path $PSScriptRoot 'verify-play-aab.ps1') -BundlePath $builtAab
if ($LASTEXITCODE -ne 0) { throw 'Signed Play AAB verification failed.' }
Copy-Item -LiteralPath $builtAab -Destination $finalAab -Force

Write-Output "Created final QA APK: $finalApk"
Write-Output "Created final Play AAB: $finalAab"
