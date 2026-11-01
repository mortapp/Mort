$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$helperPath = Join-Path $PSScriptRoot 'mort-release-push.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
  throw 'Expected a release push-config resolver that requires complete Firebase Android config when remote push is enabled.'
}
. $helperPath

function Assert-Equal([object]$Actual, [object]$Expected, [string]$Message) {
  if ($Actual -cne $Expected) { throw "$Message (expected '$Expected', got '$Actual')" }
}

function Assert-ThrowsWithoutValue([scriptblock]$Action, [string]$SecretFixture) {
  try { & $Action } catch {
    if ($_.Exception.Message.Contains($SecretFixture)) { throw 'Configuration error exposed a Firebase value.' }
    return
  }
  throw 'Incomplete Firebase config must fail when remote push is enabled.'
}

$disabled = [ordered]@{ MORT_REMOTE_PUSH_ENABLED = 'true'; existing_define = 'preserved' }
Set-MortRemotePushDefines -Defines $disabled -Enabled:$false
Assert-Equal $disabled.MORT_REMOTE_PUSH_ENABLED 'false' 'Disabled profile must keep remote push disabled'
Assert-Equal $disabled.existing_define 'preserved' 'Applying push settings must preserve other release defines'
foreach ($name in @('FIREBASE_PROJECT_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_ANDROID_API_KEY', 'FIREBASE_ANDROID_APP_ID')) {
  if ($disabled.Contains($name)) { throw 'Disabled profile must not receive Firebase defines.' }
}

$complete = [ordered]@{}
Set-MortRemotePushDefines -Defines $complete -Enabled:$true `
  -FirebaseProjectId 'mort-project' `
  -FirebaseMessagingSenderId '1234567890' `
  -FirebaseAndroidApiKey 'firebase-api-key-fixture' `
  -FirebaseAndroidAppId '1:1234567890:android:fixture'
Assert-Equal $complete.MORT_REMOTE_PUSH_ENABLED 'true' 'Enabled profile must enable remote push'
Assert-Equal $complete.FIREBASE_PROJECT_ID 'mort-project' 'Enabled profile must pass Firebase project id'
Assert-Equal $complete.FIREBASE_MESSAGING_SENDER_ID '1234567890' 'Enabled profile must pass Firebase sender id'
Assert-Equal $complete.FIREBASE_ANDROID_API_KEY 'firebase-api-key-fixture' 'Enabled profile must pass Android API key'
Assert-Equal $complete.FIREBASE_ANDROID_APP_ID '1:1234567890:android:fixture' 'Enabled profile must pass Android app id'

Assert-ThrowsWithoutValue {
  Set-MortRemotePushDefines -Defines ([ordered]@{}) -Enabled:$true `
    -FirebaseProjectId 'mort-project' `
    -FirebaseMessagingSenderId '1234567890' `
    -FirebaseAndroidApiKey '' `
    -FirebaseAndroidAppId '1:1234567890:android:fixture'
} 'firebase-api-key-fixture'

Write-Output 'MORT release push-config checks passed (3 scenarios).'
