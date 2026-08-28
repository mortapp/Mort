[CmdletBinding()]
param(
  [string]$SecretDirectory = (Join-Path $env:USERPROFILE 'MortSecrets\android'),
  [string]$Alias = 'mort-upload'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'android-signing-common.ps1')

function New-StrongPassword {
  $bytes = [byte[]]::new(32)
  $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $generator.GetBytes($bytes)
  } finally {
    $generator.Dispose()
  }
  ([Convert]::ToBase64String($bytes)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

$keytool = (Get-Command keytool -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path $SecretDirectory | Out-Null
$storePath = Join-Path $SecretDirectory 'mort-upload-key.jks'
$credentialPath = Join-Path $SecretDirectory 'mort-upload-key.credentials.xml'
$certificatePath = Join-Path $SecretDirectory 'mort-upload-certificate.pem'

if (Test-Path -LiteralPath $storePath -PathType Leaf) {
  throw "Refusing to overwrite the existing upload keystore at $storePath"
}
if (Test-Path -LiteralPath $credentialPath -PathType Leaf) {
  throw "Refusing to overwrite the existing protected credential file at $credentialPath"
}

$storePassword = New-StrongPassword
$keyPassword = New-StrongPassword

try {
  $ErrorActionPreference = 'Continue'
  $generationOutput = & $keytool -genkeypair -v -keystore $storePath -storetype JKS `
    -storepass $storePassword -keypass $keyPassword -alias $Alias `
    -keyalg RSA -keysize 4096 -validity 10000 `
    -dname 'CN=MORT Upload Key, OU=Mobile Release, O=MORT, L=Indianapolis, ST=Indiana, C=US' 2>&1
  $generationExitCode = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  $generationOutput | Where-Object { $_ -notmatch '(?i)password' }
  if ($generationExitCode -ne 0) { throw 'keytool failed to generate the upload key.' }

  [pscustomobject]@{
    StorePath = $storePath
    Alias = $Alias
    StorePassword = ConvertTo-SecureString $storePassword -AsPlainText -Force
    KeyPassword = ConvertTo-SecureString $keyPassword -AsPlainText -Force
    CreatedAt = (Get-Date).ToUniversalTime().ToString('o')
  } | Export-Clixml -LiteralPath $credentialPath -Force

  $ErrorActionPreference = 'Continue'
  $exportOutput = & $keytool -exportcert -rfc -keystore $storePath -storepass $storePassword `
    -alias $Alias -file $certificatePath 2>&1
  $exportExitCode = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  $exportOutput | Where-Object { $_ -notmatch '(?i)password' }
  if ($exportExitCode -ne 0) { throw 'keytool failed to export the public upload certificate.' }

  $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
  & icacls $SecretDirectory /inheritance:r /grant:r "${identity}:(OI)(CI)F" 'SYSTEM:(OI)(CI)F' | Out-Null

  $ErrorActionPreference = 'Continue'
  $details = & $keytool -list -v -keystore $storePath -storepass $storePassword -alias $Alias 2>&1
  $detailsExitCode = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($detailsExitCode -ne 0) { throw 'keytool could not inspect the upload certificate.' }
  $safeDetails = $details | Where-Object {
    $_ -match '^(Alias name:|Valid from:|\s*SHA1:|\s*SHA256:)'
  }
  $reportDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'docs\mobile'
  New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
  $report = @(
    '# MORT Upload Certificate Report',
    '',
    "Generated: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))",
    '',
    "- Alias: $Alias",
    "- Keystore location: outside repository ($storePath)",
    '- Private key: not included',
    '- Credential storage: Windows DPAPI-protected file outside repository',
    '',
    '```text',
    $safeDetails,
    '```'
  )
  $report | Set-Content -LiteralPath (Join-Path $reportDirectory 'MORT_UPLOAD_CERTIFICATE_REPORT.md') -Encoding utf8

  "Upload keystore created outside the repository: $storePath"
  "Protected credential file created outside the repository: $credentialPath"
  "Public upload certificate exported: $certificatePath"
  $safeDetails
} finally {
  $ErrorActionPreference = 'Stop'
  $storePassword = $null
  $keyPassword = $null
}
