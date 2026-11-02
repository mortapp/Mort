function Resolve-MortRemotePushDefines {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][bool]$Enabled,
    [AllowNull()][string]$FirebaseProjectId,
    [AllowNull()][string]$FirebaseMessagingSenderId,
    [AllowNull()][string]$FirebaseAndroidApiKey,
    [AllowNull()][string]$FirebaseAndroidAppId
  )

  if ($Enabled) {
    throw 'Remote push is disabled in MORT builds. Supabase in-app notifications remain available.'
  }
  return [ordered]@{ MORT_REMOTE_PUSH_ENABLED = 'false' }
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

  $resolved = Resolve-MortRemotePushDefines -Enabled:$Enabled
  foreach ($key in $resolved.Keys) {
    $Defines[$key] = $resolved[$key]
  }
}
