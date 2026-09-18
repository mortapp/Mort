param(
  [string]$ProjectRef = 'rakjydmgwwgtdislanbt',
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$gate = Join-Path $PSScriptRoot 'stripe-pre-provider-test-gate.ps1'
if (-not (Test-Path -LiteralPath $gate)) {
  throw 'stripe-pre-provider-test-gate.ps1 is missing.'
}

& $gate -ProjectRef $ProjectRef -WhatIf:$WhatIf
exit $LASTEXITCODE
