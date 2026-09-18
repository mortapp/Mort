$ErrorActionPreference = "Stop"

$root = Resolve-Path "$PSScriptRoot\.."
$sourceDirs = @(
  "app",
  "components",
  "lib",
  "providers",
  "types",
  "flutter_mort\lib",
  "flutter_mort\web",
  "flutter_mort\android",
  "flutter_mort\ios"
)
$clientForbiddenNamePattern = "SUPABASE_SERVICE_ROLE_KEY|SUPABASE_SECRET|STRIPE_(?:TEST|LIVE)_(?:SECRET_KEY|WEBHOOK_SECRET)|MORT_STRIPE_OPERATIONS_SECRET"

Push-Location $root
try {
  & node (Join-Path $PSScriptRoot 'secret_extraction_scan.mjs')
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  $hits = @()
  foreach ($dir in $sourceDirs) {
    $full = Join-Path $root $dir
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $files = Get-ChildItem -LiteralPath $full -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -notin @('.png','.jpg','.jpeg','.gif','.webp','.heic','.zip') }
    foreach ($match in ($files.FullName | Select-String -Pattern $clientForbiddenNamePattern -CaseSensitive:$false -ErrorAction SilentlyContinue)) {
      $hits += [ordered]@{ path = $match.Path; line = $match.LineNumber; type = 'server_secret_name_in_client_source' }
    }
  }

  if ($hits.Count -gt 0) {
    Write-Host "Potential server-secret boundary exposure found:" -ForegroundColor Red
    $hits | ForEach-Object { Write-Host "$($_.type): $($_.path):$($_.line)" }
    exit 1
  }

  Write-Host "Secret scan passed: tracked/generated text has no classified credential values, public anon JWTs are permitted, and client source contains no server-only secret names."
} finally {
  Pop-Location
}
