Set-StrictMode -Version Latest

$script:MortUploadCertificateSha256 = '04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF'

function Get-MortUploadCertificateSha256 {
  $script:MortUploadCertificateSha256
}

function ConvertTo-MortCertificateDigest {
  param([Parameter(Mandatory)][string]$Value)
  ($Value -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
}

function Get-MortSigningCredentialPath {
  Join-Path $env:USERPROFILE 'MortSecrets\android\mort-upload-key.credentials.xml'
}

function ConvertFrom-MortSecureString {
  param([Parameter(Mandatory)][Security.SecureString]$Value)
  [System.Net.NetworkCredential]::new('', $Value).Password
}

function Get-MortUploadSigning {
  $names = @(
    'MORT_UPLOAD_KEYSTORE_PATH',
    'MORT_UPLOAD_KEY_ALIAS',
    'MORT_UPLOAD_STORE_PASSWORD',
    'MORT_UPLOAD_KEY_PASSWORD'
  )
  $values = @{}
  foreach ($name in $names) {
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
      $value = [Environment]::GetEnvironmentVariable($name, 'User')
    }
    $values[$name] = $value
  }

  $present = @($names | Where-Object { -not [string]::IsNullOrWhiteSpace($values[$_]) })
  if ($present.Count -gt 0 -and $present.Count -ne $names.Count) {
    throw 'Android upload-signing environment variables are incomplete. Set all four MORT_UPLOAD_* values.'
  }
  if ($present.Count -eq $names.Count) {
    return [pscustomobject]@{
      StorePath = $values.MORT_UPLOAD_KEYSTORE_PATH
      Alias = $values.MORT_UPLOAD_KEY_ALIAS
      StorePassword = $values.MORT_UPLOAD_STORE_PASSWORD
      KeyPassword = $values.MORT_UPLOAD_KEY_PASSWORD
      Source = 'environment'
    }
  }

  $credentialPath = Get-MortSigningCredentialPath
  if (-not (Test-Path -LiteralPath $credentialPath -PathType Leaf)) {
    throw "No protected upload-signing credentials exist. Run scripts\generate-play-upload-key.ps1 first."
  }

  $protected = Import-Clixml -LiteralPath $credentialPath
  return [pscustomobject]@{
    StorePath = [string]$protected.StorePath
    Alias = [string]$protected.Alias
    StorePassword = ConvertFrom-MortSecureString $protected.StorePassword
    KeyPassword = ConvertFrom-MortSecureString $protected.KeyPassword
    Source = 'windows-dpapi'
  }
}

function Set-MortUploadSigningEnvironment {
  param([Parameter(Mandatory)]$Signing)
  $env:MORT_UPLOAD_KEYSTORE_PATH = $Signing.StorePath
  $env:MORT_UPLOAD_KEY_ALIAS = $Signing.Alias
  $env:MORT_UPLOAD_STORE_PASSWORD = $Signing.StorePassword
  $env:MORT_UPLOAD_KEY_PASSWORD = $Signing.KeyPassword
}

function Get-MortPublicConfigValue {
  param(
    [Parameter(Mandatory)][string]$PrimaryName,
    [Parameter(Mandatory)][string]$ExpoName,
    [Parameter(Mandatory)][string]$Root
  )

  foreach ($scope in @('Process', 'User')) {
    foreach ($name in @($PrimaryName, $ExpoName)) {
      $value = [Environment]::GetEnvironmentVariable($name, $scope)
      if (-not [string]::IsNullOrWhiteSpace($value)) { return $value.Trim() }
    }
  }

  $envPath = Join-Path $Root '.env.local'
  if (Test-Path -LiteralPath $envPath) {
    foreach ($line in Get-Content -LiteralPath $envPath) {
      if ($line -match '^\s*([^#=]+)\s*=\s*(.*)\s*$') {
        $name = $Matches[1].Trim()
        $value = $Matches[2].Trim().Trim('"').Trim("'")
        if ($name -in @($PrimaryName, $ExpoName) -and -not [string]::IsNullOrWhiteSpace($value)) {
          return $value
        }
      }
    }
  }
  return $null
}

function Get-MortBundletoolPath {
  $version = '1.18.3'
  $expectedSha256 = 'A099CFA1543F55593BC2ED16A70A7C67FE54B1747BB7301F37FDFD6D91028E29'
  $directory = Join-Path $env:USERPROFILE 'MortTools\bundletool'
  $path = Join-Path $directory "bundletool-all-$version.jar"
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $url = "https://github.com/google/bundletool/releases/download/$version/bundletool-all-$version.jar"
    Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
  }
  $actualSha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
  if ($actualSha256 -ne $expectedSha256) {
    throw 'The downloaded bundletool executable failed its pinned SHA-256 check.'
  }
  $path
}
