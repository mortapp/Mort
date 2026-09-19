[CmdletBinding()]
param()

& (Join-Path $PSScriptRoot 'build-play-console-aab.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
