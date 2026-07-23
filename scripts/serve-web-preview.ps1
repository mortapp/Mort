param(
  [int]$Port = 4173
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$webRoot = Join-Path $repoRoot 'flutter_mort\build\web'

if (-not (Test-Path (Join-Path $webRoot 'index.html'))) {
  throw "Web build not found. Run .\scripts\build-web-preview.ps1 first."
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
  $python = Get-Command py -ErrorAction SilentlyContinue
}
if (-not $python) {
  throw "Python was not found. Install Python or serve $webRoot with another static file server."
}

Write-Host "Serving MORT web preview from $webRoot"
Write-Host "Open http://127.0.0.1:$Port on this PC for a desktop sanity check."
Write-Host "Use Netlify or Vercel HTTPS deploy for iPhone Safari testing."

Push-Location $webRoot
try {
  if ($python.Source -like '*\py.exe') {
    py -m http.server $Port --bind 127.0.0.1
  } else {
    python -m http.server $Port --bind 127.0.0.1
  }
} finally {
  Pop-Location
}
