$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'android-signing-common.ps1')

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("mort-keytool-secret-transport-$([guid]::NewGuid().ToString('N'))")
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
$keytoolStub = Join-Path $temporaryRoot 'keytool.cmd'
$previousPassword = [Environment]::GetEnvironmentVariable('MORT_UPLOAD_STORE_PASSWORD', 'Process')
$testPassword = 'secret-transport-regression-fixture'

@'
@echo off
echo ARGS=%*
if defined MORT_UPLOAD_STORE_PASSWORD echo STORE_PASSWORD_ENV=present
'@ | Set-Content -LiteralPath $keytoolStub -Encoding Ascii

try {
  $env:MORT_UPLOAD_STORE_PASSWORD = $testPassword
  $output = @(Get-MortUploadCertificateOutput -KeytoolPath $keytoolStub -StorePath 'fake-upload.jks' -Alias 'mort-upload')
  $outputText = $output -join [Environment]::NewLine

  if ($LASTEXITCODE -ne 0) { throw 'The keytool stub failed.' }
  if ($outputText.Contains($testPassword)) { throw 'The keystore password appeared in keytool arguments or output.' }
  if (-not $outputText.Contains('-storepass:env MORT_UPLOAD_STORE_PASSWORD')) {
    throw 'The keytool invocation did not use the password environment-variable option.'
  }
  if (-not $outputText.Contains('STORE_PASSWORD_ENV=present')) {
    throw 'The keytool process did not receive the protected password through its environment.'
  }

  Write-Output 'PASS keytool signing inspection receives the password through its environment, not its command line'
} finally {
  if ($null -eq $previousPassword) {
    Remove-Item Env:MORT_UPLOAD_STORE_PASSWORD -ErrorAction SilentlyContinue
  } else {
    $env:MORT_UPLOAD_STORE_PASSWORD = $previousPassword
  }
  Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}
