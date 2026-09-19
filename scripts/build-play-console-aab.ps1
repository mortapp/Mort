[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Resolve-Path "$PSScriptRoot\.."
. (Join-Path $PSScriptRoot 'android-signing-common.ps1')

$expectedSha1 = '7F:3E:52:5C:05:F3:D8:72:C1:68:63:08:EA:F2:79:5A:8E:96:D9:97'
$expectedUrl = 'https://rakjydmgwwgtdislanbt.supabase.co'
$publicAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYXNlIiwicmVmIjoicmFranlkbWd3d2d0ZGlzbGFuYnQiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc4MTg3MTE3NSwiZXhwIjoyMDk3NDQ3MTc1fQ.DorOgj6jdPTrPX45Vi0O1dYgx-e3zgO6_S39JDcL2Ww'

$signing = Get-MortUploadSigning
if (-not (Test-Path -LiteralPath $signing.StorePath -PathType Leaf)) {
  throw "Original MORT upload keystore was not found at $($signing.StorePath)."
}

$keytool = (Get-Command keytool -ErrorAction Stop).Source
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$details = & $keytool -list -v -keystore $signing.StorePath -storepass $signing.StorePassword -alias $signing.Alias 2>&1
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $previousPreference
if ($exitCode -ne 0) { throw 'Could not inspect the original MORT upload certificate.' }

$sha1 = (($details | Select-String '^\s*SHA1:' | Select-Object -First 1).Line -replace '^\s*SHA1:\s*','').Trim()
if ((ConvertTo-MortCertificateDigest $sha1) -ne (ConvertTo-MortCertificateDigest $expectedSha1)) {
  throw "Wrong MORT upload certificate. Play requires SHA1 $expectedSha1 but this key is $sha1."
}

Set-MortUploadSigningEnvironment $signing

# Public Supabase client configuration only; no privileged backend secret is embedded.
$env:SUPABASE_URL = $expectedUrl
$env:SUPABASE_ANON_KEY = $publicAnonKey

& (Join-Path $PSScriptRoot 'build-standard-closed-test-aab.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read mobile version after build.' }
$version = $versionJson | ConvertFrom-Json
$aab = Join-Path $root "build\play\mort-closed-test-$($version.versionName)-$($version.versionCode).aab"
if (-not (Test-Path -LiteralPath $aab -PathType Leaf)) { throw "Expected Play AAB was not created: $aab" }

$actual = & $keytool -printcert -jarfile $aab 2>&1
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the generated AAB certificate.' }
$actualSha1 = (($actual | Select-String '^\s*SHA1:' | Select-Object -First 1).Line -replace '^\s*SHA1:\s*','').Trim()
if ((ConvertTo-MortCertificateDigest $actualSha1) -ne (ConvertTo-MortCertificateDigest $expectedSha1)) {
  throw "Generated AAB has the wrong signer: $actualSha1"
}

Write-Output 'PLAY_SIGNING_SHA1=PASS'
Write-Output 'PUBLIC_BACKEND_CONFIG=PASS'
Write-Output "PLAY_AAB=$aab"
