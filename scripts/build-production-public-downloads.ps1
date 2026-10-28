[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$downloads = Join-Path $env:USERPROFILE 'Downloads'
if (-not (Test-Path -LiteralPath $downloads -PathType Container)) {
  throw 'The Downloads folder does not exist.'
}

$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
$artifactBaseName = "mort-production-public-$($version.versionName)-$($version.versionCode)"
$artifacts = @(
  [pscustomobject]@{
    Source = Join-Path $root "build\play\$artifactBaseName.aab"
    Destination = Join-Path $downloads "$artifactBaseName.aab"
    Kind = 'AAB'
  },
  [pscustomobject]@{
    Source = Join-Path $root "build\play\$artifactBaseName.apk"
    Destination = Join-Path $downloads "$artifactBaseName.apk"
    Kind = 'APK'
  }
)

foreach ($artifact in $artifacts) {
  if (Test-Path -LiteralPath $artifact.Destination) {
    throw "Refusing to overwrite existing Downloads artifact: $($artifact.Destination)"
  }
}

& (Join-Path $PSScriptRoot 'build-production-public-aab.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot 'build-production-public-apk.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

foreach ($artifact in $artifacts) {
  if (-not (Test-Path -LiteralPath $artifact.Source -PathType Leaf)) {
    throw "The verified production $($artifact.Kind) is missing from the build output."
  }
}

foreach ($artifact in $artifacts) {
  Copy-Item -LiteralPath $artifact.Source -Destination $artifact.Destination -NoClobber
  Write-Output "Copied verified production $($artifact.Kind): $($artifact.Destination)"
}
