[CmdletBinding()]
param(
  [string]$BundlePath = '',
  [ValidateSet('closed_test','production_pilot','production_public')]
  [string]$ReleaseStage = 'closed_test',
  [switch]$PlayReviewModeEnabled
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'android-signing-common.ps1')

$root = Split-Path $PSScriptRoot -Parent
$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($BundlePath)) {
  $BundlePath = Join-Path $root "build\play\mort-closed-test-$($version.versionName).aab"
}

if (-not (Test-Path -LiteralPath $BundlePath -PathType Leaf)) {
  throw "AAB not found: $BundlePath"
}
$signing = Get-MortUploadSigning
$keytool = (Get-Command keytool -ErrorAction Stop).Source
$jarsigner = (Get-Command jarsigner -ErrorAction Stop).Source
$bundletool = Get-MortBundletoolPath

$jarsignerOutput = & $jarsigner -verify $BundlePath 2>&1
if ($LASTEXITCODE -ne 0 -or ($jarsignerOutput -join "`n") -notmatch 'jar verified\.') {
  throw 'jarsigner rejected the AAB signature.'
}

$ErrorActionPreference = 'Continue'
$expected = & $keytool -list -v -keystore $signing.StorePath `
  -storepass $signing.StorePassword -alias $signing.Alias 2>&1
$expectedExitCode = $LASTEXITCODE
$actual = & $keytool -printcert -jarfile $BundlePath 2>&1
$actualExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($expectedExitCode -ne 0 -or $actualExitCode -ne 0) {
  throw 'keytool could not inspect the expected and actual signing certificates.'
}
$expectedSha256 = ($expected | Select-String '^\s*SHA256:' | Select-Object -First 1).Line.Trim()
$actualSha256 = ($actual | Select-String '^\s*SHA256:' | Select-Object -First 1).Line.Trim()
if ([string]::IsNullOrWhiteSpace($expectedSha256) -or $expectedSha256 -ne $actualSha256) {
  throw 'The AAB signer does not match the protected MORT upload certificate.'
}
if (($actual -join "`n") -match 'Android Debug') {
  throw 'The AAB is signed with an Android debug certificate.'
}

$manifest = & java -jar $bundletool dump manifest --bundle=$BundlePath --module=base
if ($LASTEXITCODE -ne 0) { throw 'bundletool could not inspect the AAB manifest.' }
foreach ($required in @(
  'package="com.mortapp.mobile"',
  'android:minSdkVersion="24"',
  'android:targetSdkVersion="36"',
  ('android:versionCode="{0}"' -f $version.versionCode),
  ('android:versionName="{0}"' -f $version.versionName)
)) {
  if (($manifest -join "`n") -notmatch [regex]::Escape($required)) {
    throw "AAB manifest assertion failed: $required"
  }
}
$manifestText = $manifest -join "`n"
foreach ($forbidden in @(
  'android:debuggable="true"',
  'com.android.vending.BILLING',
  'com.google.android.gms.permission.AD_ID',
  'android.permission.RECORD_AUDIO',
  'android.permission.READ_EXTERNAL_STORAGE',
  'android.permission.WRITE_EXTERNAL_STORAGE',
  'android.permission.MANAGE_EXTERNAL_STORAGE',
  'android.permission.ACCESS_BACKGROUND_LOCATION',
  'android.permission.WAKE_LOCK'
)) {
  if ($manifestText.Contains($forbidden)) {
    throw "AAB manifest contains forbidden release capability: $forbidden"
  }
}
$exportedComponents = [regex]::Matches(
  $manifestText,
  '<(?:activity|activity-alias|service|receiver|provider)\b[^>]*android:exported="true"[^>]*>'
)
foreach ($component in $exportedComponents) {
  $isLauncher = $component.Value -match 'android:name="com\.mortapp\.mobile\.MainActivity"'
  $isProtectedProfileInstaller =
    $component.Value -match 'android:name="androidx\.profileinstaller\.ProfileInstallReceiver"' -and
    $component.Value -match 'android:permission="android\.permission\.DUMP"'
  $isPermissionProtectedFcmReceiver =
    $component.Value -match 'android:name="(?:io\.flutter\.plugins\.firebase\.messaging\.FlutterFirebaseMessagingReceiver|com\.google\.firebase\.iid\.FirebaseInstanceIdReceiver)"' -and
    $component.Value -match 'android:permission="com\.google\.android\.c2dm\.permission\.SEND"'
  if (-not $isLauncher -and
      -not $isProtectedProfileInstaller -and
      -not $isPermissionProtectedFcmReceiver) {
    throw "AAB manifest contains an unexpected exported component: $($component.Value)"
  }
}

$reportDirectory = Join-Path $root 'build\play\reports'
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$manifest | Set-Content -LiteralPath (Join-Path $reportDirectory 'bundle-manifest.xml') -Encoding utf8

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $BundlePath))
try {
  $entries = $archive.Entries | ForEach-Object FullName | Sort-Object
  $entries | Set-Content -LiteralPath (Join-Path $reportDirectory 'bundle-contents.txt') -Encoding utf8
  $entries | Where-Object { $_ -match '^base/lib/.+\.so$' } |
    Set-Content -LiteralPath (Join-Path $reportDirectory 'native-libraries.txt') -Encoding utf8
  if ($ReleaseStage -ne 'closed_test' -or -not $PlayReviewModeEnabled) {
    foreach ($entry in $archive.Entries | Where-Object { $_.FullName -match '^base/dex/.+\.dex$' }) {
      $stream = $entry.Open()
      $memory = [IO.MemoryStream]::new()
      try {
        $stream.CopyTo($memory)
        $ascii = [Text.Encoding]::ASCII.GetString($memory.ToArray())
        if ($ascii.Contains('play-review@mortapp.test')) {
          throw 'Production AAB contains the isolated Play reviewer identifier.'
        }
      } finally {
        $memory.Dispose()
        $stream.Dispose()
      }
    }
  }
} finally {
  $archive.Dispose()
}

$hash = (Get-FileHash -LiteralPath $BundlePath -Algorithm SHA256).Hash
$size = (Get-Item -LiteralPath $BundlePath).Length
@(
  'AAB_SIGNATURE=PASS',
  'DEBUG_CERTIFICATE=REJECTED',
  'PACKAGE_ID=com.mortapp.mobile',
  "VERSION_NAME=$($version.versionName)",
  "VERSION_CODE=$($version.versionCode)",
  'MIN_SDK=24',
  'TARGET_SDK=36',
  "RELEASE_STAGE=$ReleaseStage",
  "PLAY_REVIEW_MODE_ENABLED=$($PlayReviewModeEnabled.IsPresent.ToString().ToLowerInvariant())",
  'FORBIDDEN_PERMISSIONS=ABSENT',
  'UNEXPECTED_EXPORTED_COMPONENTS=ABSENT',
  "SIZE_BYTES=$size",
  "SHA256=$hash",
  "CERTIFICATE_$actualSha256"
) | Set-Content -LiteralPath (Join-Path $reportDirectory 'aab-verification.txt') -Encoding utf8

"AAB signature verified against the MORT upload certificate."
"AAB SHA-256: $hash"
"AAB size: $size bytes"
