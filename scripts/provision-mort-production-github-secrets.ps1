[CmdletBinding()]
param(
  [string]$Repository = 'mortapp/Mort',
  [string]$Environment = 'Production'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'android-signing-common.ps1')

function Read-MortEnvFile {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required local configuration file is missing: $Path"
  }
  $values = @{}
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\s*([^#=]+)\s*=\s*(.*)\s*$') {
      $key = $Matches[1].Trim()
      $value = $Matches[2].Trim().Trim('"').Trim("'")
      $values[$key] = $value
    }
  }
  return $values
}

function Invoke-GhSecretSet {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Value
  )
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = (Get-Command gh -ErrorAction Stop).Source
  $psi.Arguments = "secret set $Name --env $Environment --repo $Repository"
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $process = [System.Diagnostics.Process]::Start($psi)
  $process.StandardInput.Write($Value)
  $process.StandardInput.Close()
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) {
    throw "Could not configure GitHub environment secret '$Name'. $stderr"
  }
  Write-Host "Configured GitHub environment secret: $Name"
}

function Invoke-GhVariableSet {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Value
  )
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = (Get-Command gh -ErrorAction Stop).Source
  $psi.Arguments = "variable set $Name --env $Environment --repo $Repository"
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $process = [System.Diagnostics.Process]::Start($psi)
  $process.StandardInput.Write($Value)
  $process.StandardInput.Close()
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) {
    throw "Could not configure GitHub environment variable '$Name'. $stderr"
  }
  Write-Host "Configured GitHub environment variable: $Name"
}

$null = Get-Command gh -ErrorAction Stop
$null = Get-Command keytool -ErrorAction Stop
& gh auth status --hostname github.com *> $null
if ($LASTEXITCODE -ne 0) {
  throw 'GitHub CLI is not authenticated. Authenticate with a GitHub account allowed to manage the Production environment secrets.'
}

$signing = Get-MortUploadSigning
$storePath = [string]$signing.StorePath
if (-not (Test-Path -LiteralPath $storePath -PathType Leaf)) {
  $credentialPath = Get-MortSigningCredentialPath
  $fallbackPath = Join-Path (Split-Path -Parent $credentialPath) 'mort-upload-key.jks'
  if (Test-Path -LiteralPath $fallbackPath -PathType Leaf) {
    $storePath = $fallbackPath
  } else {
    throw 'The configured upload keystore path does not exist.'
  }
}

$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$certificateOutput = & keytool -list -v -keystore $storePath -storepass $signing.StorePassword -alias $signing.Alias 2>&1
$certificateExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousPreference
if ($certificateExitCode -ne 0) {
  throw 'The upload keystore could not be inspected. Check the original Windows account, alias, and protected credential file.'
}
$actualFingerprint = (($certificateOutput | Select-String '^\s*SHA256:' | Select-Object -First 1).Line -replace '^\s*SHA256:\s*','').Trim()
if ((ConvertTo-MortCertificateDigest $actualFingerprint) -ne (ConvertTo-MortCertificateDigest (Get-MortUploadCertificateSha256))) {
  throw 'The upload keystore certificate does not match the repository-pinned Google Play upload certificate.'
}

$credentialDirectory = Split-Path -Parent (Get-MortSigningCredentialPath)
$supabase = Read-MortEnvFile -Path (Join-Path $credentialDirectory 'supabase-public.env')
$sentry = Read-MortEnvFile -Path (Join-Path $credentialDirectory 'sentry.env')
$supabaseUrl = [string]$supabase.SUPABASE_URL
$anonKey = [string]$supabase.SUPABASE_ANON_KEY
$sentryDsn = [string]$sentry.SENTRY_DSN
if ($supabaseUrl -ne 'https://jxbnrkasktbhtiujkhay.supabase.co') {
  throw 'The local Supabase URL does not match the approved Flutter production project.'
}
if ([string]::IsNullOrWhiteSpace($anonKey)) { throw 'The public Supabase anon key is missing.' }
if ([string]::IsNullOrWhiteSpace($sentryDsn) -or -not $sentryDsn.StartsWith('https://')) {
  throw 'The Sentry client ingestion DSN is missing or invalid.'
}

$keystoreBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($storePath))
$secrets = [ordered]@{
  MORT_UPLOAD_KEYSTORE_BASE64 = $keystoreBase64
  MORT_UPLOAD_KEY_ALIAS = [string]$signing.Alias
  MORT_UPLOAD_STORE_PASSWORD = [string]$signing.StorePassword
  MORT_UPLOAD_KEY_PASSWORD = [string]$signing.KeyPassword
  SUPABASE_ANON_KEY = $anonKey
  SENTRY_DSN = $sentryDsn
}

foreach ($entry in $secrets.GetEnumerator()) {
  Invoke-GhSecretSet -Name $entry.Key -Value $entry.Value
}
Invoke-GhVariableSet -Name 'SUPABASE_URL' -Value $supabaseUrl

Write-Host 'Production environment signing/configuration names were submitted without printing any secret values.'
Write-Host 'This script does not publish an AAB or change Google Play releases.'
