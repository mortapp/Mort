$ErrorActionPreference = "Stop"

$root = Resolve-Path "$PSScriptRoot\.."
$excludedDirNames = @(
  "node_modules", ".expo", ".supabase-cli-config", "dist", ".git",
  "outputs", "build", "coverage", ".temp", ".dart_tool", "backups",
  "logs", "DerivedData", "Pods", "test", "integration_test", "web"
)
$flutterSourceRoot = Join-Path $root "flutter_mort"
$jwtPattern = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"

function Get-ScannableFiles {
  param([Parameter(Mandatory = $true)][string]$Directory)

  foreach ($entry in Get-ChildItem -LiteralPath $Directory -Force) {
    if ($entry.PSIsContainer) {
      if ($excludedDirNames -notcontains $entry.Name) {
        Get-ScannableFiles -Directory $entry.FullName
      }
      continue
    }
    if ($entry.Name -match "^\.env($|\.|local$)") { continue }
    if ($entry.Extension -in @(".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".zip")) { continue }
    $entry
  }
}

$files = @(Get-ScannableFiles -Directory $flutterSourceRoot)

$jwtHits = foreach ($file in $files) {
  Select-String -LiteralPath $file.FullName -Pattern $jwtPattern -AllMatches
}

$serviceRoleHits = foreach ($file in $files) {
  Select-String -LiteralPath $file.FullName `
    -Pattern "service_role|SUPABASE_SERVICE_ROLE_KEY|SUPABASE_SECRET" `
    -CaseSensitive:$false
}

if ($jwtHits -or $serviceRoleHits) {
  Write-Host "Potential secret exposure found:" -ForegroundColor Red
  $jwtHits | ForEach-Object { Write-Host "JWT-like key: $($_.Path):$($_.LineNumber)" }
  $serviceRoleHits | ForEach-Object { Write-Host "Service-role reference in app source: $($_.Path):$($_.LineNumber)" }
  exit 1
}

Write-Host "Secret scan passed for source files. Edge Function/docs may mention server-only secret variable names without containing secret values."
