$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$requiredPublic = @(
  'MORT_PUBLIC_PUBLISHER_NAME',
  'MORT_PUBLIC_SUPPORT_EMAIL',
  'MORT_PUBLIC_PRIVACY_EMAIL',
  'MORT_PUBLIC_CHILD_SAFETY_EMAIL',
  'MORT_PUBLIC_WEBSITE_URL',
  'MORT_PUBLIC_EFFECTIVE_DATE'
)
$sensitive = @('NETLIFY_AUTH_TOKEN', 'NETLIFY_SITE_ID')

foreach ($name in $requiredPublic + $sensitive) {
  $value = [Environment]::GetEnvironmentVariable($name, 'User')
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Deployment blocked: missing protected User environment variable $name."
  }
  [Environment]::SetEnvironmentVariable($name, $value, 'Process')
}

try {
  Push-Location $root
  node scripts\build-public-legal-site.mjs
  if ($LASTEXITCODE -ne 0) { throw 'Legal site build failed.' }
  node scripts\validate-public-legal-site.mjs
  if ($LASTEXITCODE -ne 0) { throw 'Legal site validation failed.' }
  npx netlify-cli deploy --dir web\public --prod --site $env:NETLIFY_SITE_ID --auth $env:NETLIFY_AUTH_TOKEN --json
  if ($LASTEXITCODE -ne 0) { throw 'Netlify deployment failed.' }
  Write-Output 'Netlify deployment command completed. Run hosted HTTPS validation before using the URLs in Play Console.'
} finally {
  Pop-Location
  foreach ($name in $requiredPublic + $sensitive) {
    [Environment]::SetEnvironmentVariable($name, $null, 'Process')
  }
}
