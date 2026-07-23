$ErrorActionPreference = "Stop"

Set-Location -LiteralPath (Resolve-Path "$PSScriptRoot\..")
. "$PSScriptRoot\resolve-supabase-cli.ps1"

$output = Join-Path (Get-Location) "types\supabase.generated.ts"
$supabaseCli = Resolve-SupabaseCli
$outputFile = New-TemporaryFile
$errorFile = New-TemporaryFile

try {
  $process = Start-Process `
    -FilePath $supabaseCli `
    -ArgumentList @("gen", "types", "typescript", "--local") `
    -Wait `
    -PassThru `
    -NoNewWindow `
    -RedirectStandardOutput $outputFile `
    -RedirectStandardError $errorFile

  $generated = Get-Content -LiteralPath $outputFile -ErrorAction SilentlyContinue
  $exitCode = $process.ExitCode
  $errors = Get-Content -LiteralPath $errorFile -ErrorAction SilentlyContinue

  if ($errors) {
    $errors | ForEach-Object { Write-Host $_ }
  }

  if ($exitCode -ne 0 -or ($generated -join "`n") -notmatch "export type Database") {
    throw "Supabase type generation failed. Start local Supabase first; no generated type file was written."
  }

  $generatedLines = @($generated)
  $typeStart = -1
  for ($index = 0; $index -lt $generatedLines.Count; $index += 1) {
    if ($generatedLines[$index] -match "^export type Json" -or $generatedLines[$index] -match "^export type Database") {
      $typeStart = $index
      break
    }
  }

  if ($typeStart -lt 0) {
    throw "Supabase type generation did not include export type Database; no generated type file was written."
  }

  if ($typeStart -gt 0) {
    Write-Host "Filtered Supabase CLI progress output from generated type file."
  }

  $generatedTypes = $generatedLines[$typeStart..($generatedLines.Count - 1)]
  $generatedTypes | Set-Content -LiteralPath $output -Encoding UTF8
  Write-Host "Generated $output"
} finally {
  Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $errorFile -Force -ErrorAction SilentlyContinue
}
