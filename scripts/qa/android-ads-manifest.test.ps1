$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../android-ads-manifest-common.ps1')

function New-Fixture {
  param([string]$Entries = '', [string]$Permissions = '')
  return @"
<manifest xmlns:mobile="http://schemas.android.com/apk/res/android" package="com.mortapp.mobile">
  <uses-permission mobile:name="android.permission.WAKE_LOCK" />
  $Permissions
  <application>
    <activity mobile:name="com.mortapp.mobile.MainActivity" />
    $Entries
  </application>
</manifest>
"@
}

function Assert-Rejected {
  param([string]$ManifestText, [string]$ExpectedAds, [string]$ExpectedMessage)
  try {
    Assert-MortAndroidAdsManifest -ManifestText $ManifestText -ExpectedAds $ExpectedAds
  } catch {
    if ($_.Exception.Message -match $ExpectedMessage) { return }
    throw
  }
  throw "Manifest should have been rejected: $ExpectedMessage"
}

$clean = New-Fixture
$provider = '<provider mobile:name="com.google.android.gms.ads.MobileAdsInitProvider" />'
$appId = '<meta-data mobile:name="com.google.android.gms.ads.APPLICATION_ID" mobile:value="ca-app-pub-1~2" />'
$control = New-Fixture -Entries "$appId $provider"
Assert-MortAndroidAdsManifest -ManifestText $clean -ExpectedAds Disabled
Assert-MortAndroidAdsManifest -ManifestText $control -ExpectedAds Enabled
foreach ($entry in @(
  $provider,
  $appId,
  '<activity mobile:name="com.google.android.gms.ads.NotificationHandlerActivity" />',
  '<service mobile:name="com.google.android.gms.ads.AdService" />',
  '<property mobile:name="android.adservices.AD_SERVICES_CONFIG" />'
)) {
  Assert-Rejected (New-Fixture -Entries $entry) Disabled 'forbidden manifest entry'
}
foreach ($name in @(
  'com.google.android.gms.permission.AD_ID',
  'android.permission.ACCESS_ADSERVICES_AD_ID',
  'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
  'android.permission.ACCESS_ADSERVICES_TOPICS',
  'com.android.vending.BILLING'
)) {
  Assert-Rejected (New-Fixture -Permissions "<uses-permission-sdk-23 mobile:name='$name' />") Disabled 'forbidden manifest entry'
}
Assert-Rejected $clean Enabled 'missing the AdMob application ID or initializer'
Assert-Rejected ($clean.Replace('android.permission.WAKE_LOCK', 'android.permission.INTERNET')) Disabled 'did not retain'
Assert-Rejected ($clean.Replace('package="com.mortapp.mobile"', 'package="com.example.wrong"')) Disabled 'packaged MORT'
Assert-Rejected '<manifest' Disabled 'unexpected end'
Write-Output 'PASS: 16 Android manifest policy cases.'
