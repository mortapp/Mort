param(
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$webRoot = Join-Path $repoRoot 'flutter_mort\build\web'
$buildScript = Join-Path $PSScriptRoot 'build-web-preview.ps1'

foreach ($name in @('NETLIFY_AUTH_TOKEN', 'NETLIFY_SITE_ID')) {
  $value = [Environment]::GetEnvironmentVariable($name, 'Process')
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($name, 'User')
  }
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "$name is required for a real Netlify deployment."
  }
  Set-Item -Path "Env:$name" -Value $value
}

$netlify = Get-Command netlify -ErrorAction SilentlyContinue
if (-not $netlify) {
  throw 'Netlify CLI was not found. Install it with: npm install -g netlify-cli'
}

if (-not $SkipBuild) {
  & $buildScript
  if ($LASTEXITCODE -ne 0) {
    throw "Web preview build failed with exit code $LASTEXITCODE."
  }
}

if (-not (Test-Path (Join-Path $webRoot 'index.html'))) {
  throw 'build/web/index.html is missing. Build the web preview first.'
}

Write-Host 'Deploying the verified MORT web build to the configured Netlify site.'
& $netlify.Source deploy --dir $webRoot --prod --site $env:NETLIFY_SITE_ID
if ($LASTEXITCODE -ne 0) {
  throw "Netlify deployment failed with exit code $LASTEXITCODE."
}
