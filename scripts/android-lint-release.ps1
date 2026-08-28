[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'android-signing-common.ps1')

$root = Split-Path $PSScriptRoot -Parent
$androidRoot = Join-Path $root 'flutter_mort\android'
$localPropertiesPath = Join-Path $androidRoot 'local.properties'

if (-not (Test-Path -LiteralPath $localPropertiesPath -PathType Leaf)) {
  throw 'flutter_mort/android/local.properties is missing. Run flutter pub get first.'
}

# Flutter writes valid Windows paths that Android lint still flags unless the
# drive separator is escaped according to Java properties syntax.
$localProperties = Get-Content -LiteralPath $localPropertiesPath
$normalizedProperties = $localProperties | ForEach-Object {
  if ($_ -match '^(sdk\.dir|flutter\.sdk)=([A-Za-z]):(.*)$') {
    '{0}={1}\:{2}' -f $Matches[1], $Matches[2], $Matches[3]
  } else {
    $_
  }
}
Set-Content -LiteralPath $localPropertiesPath -Value $normalizedProperties -Encoding ASCII

$signing = Get-MortUploadSigning
Set-MortUploadSigningEnvironment $signing

Push-Location $androidRoot
try {
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & .\gradlew.bat :app:lintRelease
  $gradleExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  if ($gradleExitCode -ne 0) {
    throw "Android application release lint failed with exit code $gradleExitCode."
  }
} finally {
  $ErrorActionPreference = 'Stop'
  Pop-Location
}

Write-Output 'Android application release lint passed.'
