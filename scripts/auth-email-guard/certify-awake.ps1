$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class MortGuardPowerRequest {
  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern uint SetThreadExecutionState(uint flags);
}
'@
$guardAwakeResult = [MortGuardPowerRequest]::SetThreadExecutionState([uint32]2147483649)
if ($guardAwakeResult -eq 0) { throw 'MORT guard sleep prevention could not be established.' }
$guardPreviousPowerMarker = $env:MORT_GUARD_POWER_REQUEST_VERIFIED
$env:MORT_GUARD_POWER_REQUEST_VERIFIED = 'process-scoped-windows'
try {
  # Read capabilities without emitting hardware/user values; marker is a harness
  # assertion by this trusted wrapper, not an application authorization token.
  $guardSleepCapabilities = & powercfg /a 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'MORT guard sleep/hibernate capability query failed.' }
  Write-Output 'MORT guard sleep/hibernate capabilities recorded locally; system-required power request established by Windows API. Manual sleep is not prevented.'
  Write-Output 'MORT guard automatic system sleep blocked for this process; manual sleep and Docker pause remain possible.'
  Push-Location (Join-Path $PSScriptRoot '..\..')
  try {
    & node scripts/auth-email-guard/certify.mjs --allow-external-gates
    $guardExitCode = $LASTEXITCODE
  } finally { Pop-Location }
} finally {
  $env:MORT_GUARD_POWER_REQUEST_VERIFIED = $guardPreviousPowerMarker
  [void][MortGuardPowerRequest]::SetThreadExecutionState([uint32]2147483648)
}
exit $guardExitCode
