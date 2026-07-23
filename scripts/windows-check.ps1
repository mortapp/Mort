$ErrorActionPreference = "Stop"

Set-Location -LiteralPath (Resolve-Path "$PSScriptRoot\..")

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  Write-Host "Running $Label"
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE."
  }
}

Invoke-Checked 'pnpm check' { pnpm check }
Invoke-Checked 'pnpm lint' { pnpm lint }
Invoke-Checked 'pnpm build' { pnpm build }
Invoke-Checked 'npx expo-doctor' { npx expo-doctor }
