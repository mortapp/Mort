Set-StrictMode -Version Latest

function Set-MortAndroidBuildJava {
  $candidates = @(
    [pscustomobject]@{ Path = $env:JAVA_HOME_17_X64; ExpectedMajor = 17 },
    [pscustomobject]@{ Path = $env:JAVA_HOME_21_X64; ExpectedMajor = 21 },
    [pscustomobject]@{ Path = $env:JAVA_HOME; ExpectedMajor = $null }
  )

  foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate.Path)) { continue }

    $javaBin = Join-Path $candidate.Path 'bin'
    $javaExecutable = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
      Join-Path $javaBin 'java.exe'
    } else {
      Join-Path $javaBin 'java'
    }
    if (-not (Test-Path -LiteralPath $javaExecutable -PathType Leaf)) { continue }

    $versionOutput = (& $javaExecutable -version 2>&1 | Out-String)
    $versionMatch = [regex]::Match($versionOutput, '(?m)version\s+"(?:1\.)?(\d+)')
    if (-not $versionMatch.Success) { continue }
    $major = [int]$versionMatch.Groups[1].Value
    if ($major -notin @(17, 21)) { continue }
    if ($null -ne $candidate.ExpectedMajor -and $major -ne $candidate.ExpectedMajor) { continue }

    $env:JAVA_HOME = $candidate.Path
    $env:PATH = "$javaBin$([IO.Path]::PathSeparator)$env:PATH"
    Write-Output "ANDROID_BUILD_JAVA_MAJOR=$major"
    return
  }

  throw 'Android Gradle 8.14 requires JDK 17 or 21. Set JAVA_HOME_17_X64 or JAVA_HOME_21_X64 in the build environment.'
}
