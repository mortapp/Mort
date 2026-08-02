param(
  [string]$ApkPath = (Join-Path $PSScriptRoot '..\flutter_mort\build\app\outputs\flutter-apk\app-release.apk'),
  [switch]$RequireSigned
)

$ErrorActionPreference = 'Stop'
$apk = Resolve-Path -LiteralPath $ApkPath
$buildTools = Join-Path $env:ANDROID_HOME 'build-tools\36.1.0'
$aapt = Join-Path $buildTools 'aapt2.exe'
$apksigner = Join-Path $buildTools 'apksigner.bat'
$apkanalyzer = Get-ChildItem (Join-Path $env:ANDROID_HOME 'cmdline-tools') -Recurse -Filter apkanalyzer.bat | Select-Object -First 1 -ExpandProperty FullName
if (-not (Test-Path $aapt) -or -not (Test-Path $apksigner) -or -not $apkanalyzer) {
  throw 'Required Android SDK artifact tools were not found.'
}

$badging = (& $aapt dump badging $apk) -join "`n"
$permissions = [regex]::Matches($badging, "uses-permission: name='([^']+)'" ) | ForEach-Object { $_.Groups[1].Value }
$required = @(
  'android.permission.INTERNET',
  'android.permission.ACCESS_NETWORK_STATE',
  'android.permission.CAMERA',
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.USE_BIOMETRIC',
  'android.permission.ACCESS_COARSE_LOCATION',
  'android.permission.ACCESS_FINE_LOCATION'
)
$forbidden = @(
  'android.permission.ACCESS_BACKGROUND_LOCATION',
  'android.permission.FOREGROUND_SERVICE_LOCATION',
  'android.permission.FOREGROUND_SERVICE',
  'com.android.vending.BILLING',
  'com.google.android.gms.permission.AD_ID',
  'android.permission.ACCESS_ADSERVICES_AD_ID',
  'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
  'android.permission.ACCESS_ADSERVICES_TOPICS'
)
foreach ($permission in $required) {
  if ($permissions -notcontains $permission) { throw "Required APK permission missing: $permission" }
}
foreach ($permission in $forbidden) {
  if ($permissions -contains $permission) { throw "Forbidden APK permission present: $permission" }
}
if ((& $apkanalyzer manifest application-id $apk) -ne 'com.mortapp.mobile') { throw 'APK application ID mismatch.' }
if ((& $apkanalyzer manifest min-sdk $apk) -ne '24') { throw 'APK min SDK mismatch.' }
if ((& $apkanalyzer manifest target-sdk $apk) -ne '36') { throw 'APK target SDK mismatch.' }
$root = Split-Path $PSScriptRoot -Parent
$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
if ((& $apkanalyzer manifest version-code $apk) -ne [string]$version.versionCode) { throw 'APK version code mismatch.' }
if ((& $apkanalyzer manifest version-name $apk) -ne [string]$version.versionName) { throw 'APK version name mismatch.' }

$ErrorActionPreference = 'Continue'
& $apksigner verify --verbose $apk *> $null
$signed = $LASTEXITCODE -eq 0
$ErrorActionPreference = 'Stop'
if ($RequireSigned -and -not $signed) { throw 'APK is unsigned.' }
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $apk).Hash
$size = (Get-Item -LiteralPath $apk).Length
Write-Output "PASS: package=com.mortapp.mobile version=$($version.versionName)+$($version.versionCode) minSdk=24 targetSdk=36 permissions=$($permissions.Count) signed=$signed bytes=$size sha256=$hash"
