function Assert-MortAndroidAdsManifest {
  param(
    [Parameter(Mandatory)][string]$ManifestText,
    [Parameter(Mandatory)][ValidateSet('Disabled','Enabled')][string]$ExpectedAds
  )

  $android = 'http://schemas.android.com/apk/res/android'
  $settings = [System.Xml.XmlReaderSettings]::new()
  $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
  $inputReader = [IO.StringReader]::new($ManifestText)
  $reader = [System.Xml.XmlReader]::Create($inputReader, $settings)
  try {
    $manifest = [System.Xml.XmlDocument]::new()
    $manifest.Load($reader)
  } finally {
    $reader.Dispose()
    $inputReader.Dispose()
  }

  if ($manifest.SelectNodes('/manifest/application').Count -ne 1 -or
      $manifest.DocumentElement.GetAttribute('package') -cne 'com.mortapp.mobile') {
    throw 'Expected a packaged MORT Android manifest with one application.'
  }

  $names = [System.Xml.XmlNamespaceManager]::new($manifest.NameTable)
  $names.AddNamespace('android', $android)
  if (-not $manifest.SelectSingleNode('/manifest/uses-permission[@android:name="android.permission.WAKE_LOCK"]', $names)) {
    throw 'Packaged manifest did not retain the wake-lock permission used by FCM.'
  }

  if ($ExpectedAds -eq 'Enabled') {
    $appId = $manifest.SelectSingleNode('/manifest/application/meta-data[@android:name="com.google.android.gms.ads.APPLICATION_ID"]', $names)
    $provider = $manifest.SelectSingleNode('/manifest/application/provider[@android:name="com.google.android.gms.ads.MobileAdsInitProvider"]', $names)
    if (-not $appId -or [string]::IsNullOrWhiteSpace($appId.GetAttribute('value', $android)) -or -not $provider) {
      throw 'Ads-enabled control is missing the AdMob application ID or initializer.'
    }
    return
  }

  foreach ($node in $manifest.SelectNodes('//*[@android:name]', $names)) {
    $name = $node.GetAttribute('name', $android)
    if ($name -cmatch '^(com\.google\.android\.gms\.ads\.|android\.permission\.ACCESS_ADSERVICES_)' -or
        $name -cin @('android.adservices.AD_SERVICES_CONFIG', 'com.google.android.gms.permission.AD_ID', 'com.android.vending.BILLING')) {
      throw "No-ads Android package contains a forbidden manifest entry: $name"
    }
  }
}
