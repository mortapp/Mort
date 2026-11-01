function Resolve-MortRemotePushDefines {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][bool]$Enabled,
    [AllowNull()][string]$FirebaseProjectId,
    [AllowNull()][string]$FirebaseMessagingSenderId,
    [AllowNull()][string]$FirebaseAndroidApiKey,
    [AllowNull()][string]$FirebaseAndroidAppId
  )

  if (-not $Enabled) {
    return [ordered]@{ MORT_REMOTE_PUSH_ENABLED = 'false' }
  }

  $firebaseDefines = [ordered]@{
    FIREBASE_PROJECT_ID = $FirebaseProjectId
    FIREBASE_MESSAGING_SENDER_ID = $FirebaseMessagingSenderId
    FIREBASE_ANDROID_API_KEY = $FirebaseAndroidApiKey
    FIREBASE_ANDROID_APP_ID = $FirebaseAndroidAppId
  }
  $missing = @($firebaseDefines.Keys | Where-Object { [string]::IsNullOrWhiteSpace($firebaseDefines[$_]) })
  if ($missing.Count -gt 0) {
    throw "Remote push requires complete Firebase Android configuration: $($missing -join ', ')."
  }

  return [ordered]@{
    MORT_REMOTE_PUSH_ENABLED = 'true'
    FIREBASE_PROJECT_ID = $FirebaseProjectId
    FIREBASE_MESSAGING_SENDER_ID = $FirebaseMessagingSenderId
    FIREBASE_ANDROID_API_KEY = $FirebaseAndroidApiKey
    FIREBASE_ANDROID_APP_ID = $FirebaseAndroidAppId
  }
}

function Set-MortRemotePushDefines {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Defines,
    [Parameter(Mandatory)][bool]$Enabled,
    [AllowNull()][string]$FirebaseProjectId,
    [AllowNull()][string]$FirebaseMessagingSenderId,
    [AllowNull()][string]$FirebaseAndroidApiKey,
    [AllowNull()][string]$FirebaseAndroidAppId
  )

  $resolved = Resolve-MortRemotePushDefines `
    -Enabled:$Enabled `
    -FirebaseProjectId $FirebaseProjectId `
    -FirebaseMessagingSenderId $FirebaseMessagingSenderId `
    -FirebaseAndroidApiKey $FirebaseAndroidApiKey `
    -FirebaseAndroidAppId $FirebaseAndroidAppId
  foreach ($key in $resolved.Keys) {
    $Defines[$key] = $resolved[$key]
  }
}
