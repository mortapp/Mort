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
try {
  Write-Output 'MORT guard automatic system sleep blocked for this process; manual sleep and Docker pause remain possible.'
  Push-Location (Join-Path $PSScriptRoot '..\..')
  try {
    & node scripts/auth-email-guard/certify.mjs --allow-external-gates
    $guardExitCode = $LASTEXITCODE
  } finally { Pop-Location }
} finally {
  [void][MortGuardPowerRequest]::SetThreadExecutionState([uint32]2147483648)
}
exit $guardExitCode
