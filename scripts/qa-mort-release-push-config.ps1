$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$helperPath = Join-Path $PSScriptRoot 'mort-release-push.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
  throw 'Expected the remote-push release guard.'
}
. $helperPath

$disabled = [ordered]@{ MORT_REMOTE_PUSH_ENABLED = 'true'; existing_define = 'preserved' }
Set-MortRemotePushDefines -Defines $disabled -Enabled:$false `
  -FirebaseProjectId 'dormant' `
  -FirebaseMessagingSenderId 'dormant' `
  -FirebaseAndroidApiKey 'dormant' `
  -FirebaseAndroidAppId 'dormant'
if ($disabled.MORT_REMOTE_PUSH_ENABLED -cne 'false') {
  throw 'A disabled release profile did not force push off.'
}
if ($disabled.existing_define -cne 'preserved') {
  throw 'The disabled release guard modified unrelated definitions.'
}
foreach ($name in @('FIREBASE_PROJECT_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_ANDROID_API_KEY', 'FIREBASE_ANDROID_APP_ID')) {
  if ($disabled.Contains($name)) { throw 'A disabled profile must not emit Firebase build configuration.' }
}

try {
  Resolve-MortRemotePushDefines -Enabled:$true `
    -FirebaseProjectId 'dormant' `
    -FirebaseMessagingSenderId 'dormant' `
    -FirebaseAndroidApiKey 'dormant' `
    -FirebaseAndroidAppId 'dormant' | Out-Null
} catch {
  if (-not $_.Exception.Message.Contains('Remote push is disabled')) {
    throw 'Enabling remote push failed without the explicit MORT-disabled reason.'
  }
  Write-Output '[qa-mort-release-push-config] PASS: Firebase retained but disabled.'
  exit 0
}
throw 'Remote push unexpectedly enabled.'
