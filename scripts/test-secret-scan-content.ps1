$ErrorActionPreference = 'Stop'

$scanner = Join-Path $PSScriptRoot 'secret-scan.ps1'
$pwsh = (Get-Process -Id $PID).Path
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$fixtureRoot = Join-Path $tempRoot ('mort-secret-scan-' + [guid]::NewGuid().ToString('N'))
$flutterLib = Join-Path $fixtureRoot 'flutter_mort\lib'
New-Item -ItemType Directory -Force -Path $flutterLib | Out-Null
$scannerDirectory = Join-Path $fixtureRoot 'scripts'
New-Item -ItemType Directory -Force -Path $scannerDirectory | Out-Null
$scannerUnderTest = Join-Path $scannerDirectory 'secret-scan.ps1'
Copy-Item -LiteralPath $scanner -Destination $scannerUnderTest

function Invoke-Scanner {
  param([Parameter(Mandatory)][string]$Root)

  $output = & $pwsh -NoProfile -File $scannerUnderTest 2>&1 | Out-String
  [pscustomobject]@{
    ExitCode = $LASTEXITCODE
    Output = $output
  }
}

try {
  $sourceFile = Join-Path $flutterLib 'main.dart'
  Set-Content -LiteralPath $sourceFile -Value '// clean fixture' -Encoding utf8
  $clean = Invoke-Scanner -Root $fixtureRoot
  if ($clean.ExitCode -ne 0 -or $clean.Output -notmatch 'Secret scan passed') {
    throw 'The scanner did not accept a clean Flutter fixture.'
  }

  $fakeJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dGVzdC1qd3QtcGF5bG9hZA.dGVzdC1zaWduYXR1cmU'
  Set-Content -LiteralPath $sourceFile -Value "const testToken = '$fakeJwt';" -Encoding utf8
  $jwt = Invoke-Scanner -Root $fixtureRoot
  if ($jwt.ExitCode -eq 0 -or $jwt.Output -notmatch 'Potential secret exposure found') {
    throw 'The scanner did not reject a JWT-like value embedded in Flutter source.'
  }
  if ($jwt.Output.Contains($fakeJwt)) {
    throw 'The scanner exposed the test credential in its output.'
  }

  Set-Content -LiteralPath $sourceFile -Value "const serviceRole = 'SUPABASE_SERVICE_ROLE_KEY';" -Encoding utf8
  $serviceRole = Invoke-Scanner -Root $fixtureRoot
  if ($serviceRole.ExitCode -eq 0 -or $serviceRole.Output -notmatch 'Potential secret exposure found') {
    throw 'The scanner did not reject a service-role key reference embedded in Flutter source.'
  }

  Write-Output 'PASS: clean Flutter fixture is accepted.'
  Write-Output 'PASS: JWT-like values in source are rejected without echoing the value.'
  Write-Output 'PASS: service-role key references in source are rejected.'
}
finally {
  $resolved = (Resolve-Path -LiteralPath $fixtureRoot).Path
  $requiredPrefix = $tempRoot + '\mort-secret-scan-'
  if (-not $resolved.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing test cleanup outside its temporary fixture directory: $resolved"
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
