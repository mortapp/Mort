$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot '..\android-signing-common.ps1')

$previousProcessStorePassword = [Environment]::GetEnvironmentVariable('MORT_KEYTOOL_STOREPASS', 'Process')
$previousProcessKeyPassword = [Environment]::GetEnvironmentVariable('MORT_KEYTOOL_KEYPASS', 'Process')
$env:MORT_KEYTOOL_STOREPASS = 'previous-store-value'
$env:MORT_KEYTOOL_KEYPASS = 'previous-key-value'
$script:observedArguments = @()
$script:observedStorePassword = $null
$script:observedKeyPassword = $null

$invoker = {
  param($Executable, $Arguments)
  $script:observedArguments = @($Arguments)
  $script:observedStorePassword = $env:MORT_KEYTOOL_STOREPASS
  $script:observedKeyPassword = $env:MORT_KEYTOOL_KEYPASS
  [pscustomobject]@{
    Output = @('mock keytool output')
    ExitCode = 0
  }
}

$result = Invoke-MortKeytool `
  -Executable 'mock-keytool' `
  -Arguments @('-list', '-alias', 'mort-upload') `
  -StorePassword 'test-store-password-73e5' `
  -KeyPassword 'test-key-password-4b2c' `
  -Invoker $invoker

if ($result.ExitCode -ne 0) { throw 'keytool exit code was not preserved.' }
if ($result.Output -notcontains 'mock keytool output') {
  throw 'keytool output was not preserved.'
}
if ($script:observedStorePassword -ne 'test-store-password-73e5') {
  throw 'The store password was not available through the child environment.'
}
if ($script:observedKeyPassword -ne 'test-key-password-4b2c') {
  throw 'The key password was not available through the child environment.'
}
if ($script:observedArguments -notcontains 'MORT_KEYTOOL_STOREPASS' -or
  $script:observedArguments -notcontains 'MORT_KEYTOOL_KEYPASS') {
  throw 'keytool was not given the environment-variable references.'
}
if (($script:observedArguments -join ' ') -match 'test-store-password-73e5|test-key-password-4b2c') {
  throw 'A credential value was passed in keytool command-line arguments.'
}
if ($env:MORT_KEYTOOL_STOREPASS -ne 'previous-store-value' -or
  $env:MORT_KEYTOOL_KEYPASS -ne 'previous-key-value') {
  throw 'The prior process environment was not restored.'
}

[Environment]::SetEnvironmentVariable('MORT_KEYTOOL_STOREPASS', $previousProcessStorePassword, 'Process')
[Environment]::SetEnvironmentVariable('MORT_KEYTOOL_KEYPASS', $previousProcessKeyPassword, 'Process')
Write-Output 'PASS keytool receives credential references through process environment only'
