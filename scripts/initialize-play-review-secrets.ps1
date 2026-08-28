[CmdletBinding()]
param(
  [string]$SecretDirectory = (Join-Path $env:USERPROFILE 'MortSecrets\play-review')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function New-RandomBytes([int]$Count) {
  $bytes = [byte[]]::new($Count)
  $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
  $bytes
}

function New-Token([int]$Count = 12) {
  ([Convert]::ToBase64String((New-RandomBytes $Count))).TrimEnd('=').Replace('+', '').Replace('/', '').ToLowerInvariant()
}

$path = Join-Path $SecretDirectory 'play-review.credentials.xml'
if (Test-Path -LiteralPath $path -PathType Leaf) {
  throw "Refusing to overwrite the protected Play review credential file at $path"
}
New-Item -ItemType Directory -Force -Path $SecretDirectory | Out-Null

$suffix = New-Token 8
$password = "M0rt!$(New-Token 24)"
[pscustomobject]@{
  TeenEmail = "review-$suffix-teen@mort.test"
  AdultEmail = "review-$suffix-adult@mort.test"
  GuardianEmail = "review-$suffix-guardian@mort.test"
  Password = ConvertTo-SecureString $password -AsPlainText -Force
  CreatedAt = (Get-Date).ToUniversalTime().ToString('o')
} | Export-Clixml -LiteralPath $path -Force

$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls $SecretDirectory /inheritance:r /grant:r "${identity}:(OI)(CI)F" 'SYSTEM:(OI)(CI)F' | Out-Null
$password = $null
"Protected Play review credentials created outside the repository: $path"
