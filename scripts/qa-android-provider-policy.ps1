$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android-provider-policy.ps1')

function Assert-Rejected([scriptblock]$Action) {
  try { & $Action } catch {
    if ($_.Exception.Message -match 'Firebase') { return }
    throw
  }
  throw 'Expected Firebase policy rejection.'
}

# Minimal DEX fixture with one defined class. Non-class string references must
# not be mistaken for an installed SDK (crash tools may detect optional SDKs).
function New-DexFixture([string]$Descriptor, [bool]$DefineClass = $true) {
  $text = [Text.Encoding]::ASCII.GetBytes($Descriptor)
  $bytes = [byte[]]::new(160 + $text.Length + 2)
  [Array]::Copy([Text.Encoding]::ASCII.GetBytes("dex`n035`0"), 0, $bytes, 0, 8)
  foreach ($pair in @(@(56,1), @(60,112), @(64,1), @(68,116), @(96,[int]$DefineClass), @(100,120), @(112,160), @(116,0), @(120,0))) {
    [Array]::Copy([BitConverter]::GetBytes([uint32]$pair[1]), 0, $bytes, $pair[0], 4)
  }
  $bytes[160] = [byte]$text.Length
  [Array]::Copy($text,0,$bytes,161,$text.Length)
  return ,$bytes
}

Assert-MortAndroidProviderPolicy -ManifestText '<provider android:name="io.sentry.android.core.SentryInitProvider" android:exported="false" />'
Assert-MortAndroidProviderPolicy -DexBytes (New-DexFixture 'Lio/sentry/android/core/SentryInitProvider;')
Assert-MortAndroidProviderPolicy -DexBytes (New-DexFixture 'Lcom/google/firebase/FirebaseApp;' $false)
Assert-Rejected { Assert-MortAndroidProviderPolicy -ManifestText '<provider android:name="com.google.firebase.provider.FirebaseInitProvider" android:exported="false" />' }
Assert-Rejected { Assert-MortAndroidProviderPolicy -ManifestText '<receiver android:name="io.flutter.plugins.firebase.messaging.Receiver" android:exported="true" />' }
Assert-Rejected { Assert-MortAndroidProviderPolicy -DexBytes (New-DexFixture 'Lcom/google/firebase/FirebaseApp;') }
Assert-Rejected { Assert-MortAndroidProviderPolicy -DexBytes (New-DexFixture 'Lio/flutter/plugins/firebase/core/FlutterFirebaseCorePlugin;') }
Write-Output 'PASS: Firebase manifest and defined classes rejected; Sentry and optional detection strings accepted.'
