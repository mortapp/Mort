param(
  [switch]$LoadEnvLocal
)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath (Resolve-Path "$PSScriptRoot\..")

if ($LoadEnvLocal) {
  $envPath = Join-Path (Get-Location) ".env.local"
  if (-not (Test-Path -LiteralPath $envPath)) {
    throw ".env.local was not found. Create it or omit -LoadEnvLocal and set env vars in the shell."
  }

  Get-Content -LiteralPath $envPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
      $parts = $line.Split("=", 2)
      [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
    }
  }
}

node .\scripts\qa-rls.mjs
