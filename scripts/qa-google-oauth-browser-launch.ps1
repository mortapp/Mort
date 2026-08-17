[CmdletBinding()]
param(
  [string]$AvdName = 'Medium_Phone_API_36.1',
  [string]$ApkPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
  $versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
  if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
  $version = $versionJson | ConvertFrom-Json
  $ApkPath = Join-Path $root "build\play\mort-closed-test-$($version.versionName)-$($version.versionCode).apk"
}

$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$stdout = Join-Path $env:TEMP 'mort-google-oauth-emulator-stdout.log'
$stderr = Join-Path $env:TEMP 'mort-google-oauth-emulator-stderr.log'

foreach ($required in @($adb, $emulator, $ApkPath)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Required Google OAuth QA file is missing: $required"
  }
}

function Get-MortUiXml {
  param([Parameter(Mandatory)][string]$Serial)
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'
  & $adb -s $Serial shell uiautomator dump /sdcard/mort-window.xml *> $null
  $dumpExitCode = $LASTEXITCODE
  if ($dumpExitCode -eq 0) {
    $xml = @(& $adb -s $Serial exec-out cat /sdcard/mort-window.xml 2>$null) -join "`n"
    $catExitCode = $LASTEXITCODE
  } else {
    $xml = ''
    $catExitCode = 1
  }
  $ErrorActionPreference = $previousPreference
  if ($dumpExitCode -ne 0 -or $catExitCode -ne 0) { return '' }
  return $xml
}

function Invoke-UiTextTap {
  param(
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$Xml,
    [Parameter(Mandatory)][string]$Text
  )
  $escaped = [regex]::Escape($Text)
  $pattern = '<node[^>]*(?:text|content-desc)="[^"]*{0}[^"]*"[^>]*clickable="true"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"' -f $escaped
  $match = [regex]::Match($Xml, $pattern)
  if (-not $match.Success) { return $false }
  $x = [int](([int]$match.Groups[1].Value + [int]$match.Groups[3].Value) / 2)
  $y = [int](([int]$match.Groups[2].Value + [int]$match.Groups[4].Value) / 2)
  & $adb -s $Serial shell input tap $x $y | Out-Null
  return $LASTEXITCODE -eq 0
}

function Test-UiContainsText {
  param(
    [Parameter(Mandatory)][string]$Xml,
    [Parameter(Mandatory)][string]$Text
  )
  $escaped = [regex]::Escape($Text)
  return $Xml -match "(?:text|content-desc)=`"[^`"]*$escaped[^`"]*`""
}

function Wait-MortDevice {
  param(
    [Parameter(Mandatory)][string]$Serial,
    [int]$Seconds = 30
  )
  $deadline = (Get-Date).AddSeconds($Seconds)
  do {
    $state = @(& $adb -s $Serial get-state 2>$null) | Select-Object -First 1
    if ($state -and $state.Trim() -eq 'device') { return $true }
    Start-Sleep -Seconds 2
  } while ((Get-Date) -lt $deadline)
  return $false
}

function Save-MortDiagnosticScreenshot {
  param([Parameter(Mandatory)][string]$Serial)
  $localPath = Join-Path $env:TEMP 'mort-google-oauth-diagnostic.png'
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'
  & $adb -s $Serial shell screencap -p /sdcard/mort-google-oauth-diagnostic.png *> $null
  if ($LASTEXITCODE -eq 0) {
    & $adb -s $Serial pull /sdcard/mort-google-oauth-diagnostic.png $localPath *> $null
    $captured = $LASTEXITCODE -eq 0
  } else {
    $captured = $false
  }
  $ErrorActionPreference = $previousPreference
  if ($captured) { return $localPath }
  return $null
}

$emulatorProcess = Start-Process -FilePath $emulator `
  -ArgumentList @(
    '-avd', $AvdName,
    '-no-window', '-no-audio', '-no-boot-anim',
    '-no-snapshot-load', '-no-snapshot-save',
    '-gpu', 'swiftshader_indirect'
  ) `
  -WindowStyle Hidden `
  -RedirectStandardOutput $stdout `
  -RedirectStandardError $stderr `
  -PassThru

$serial = $null
try {
  $deadline = (Get-Date).AddMinutes(4)
  do {
    Start-Sleep -Seconds 3
    if ($emulatorProcess.HasExited) {
      throw "Emulator exited during boot with code $($emulatorProcess.ExitCode)."
    }
    $deviceLine = @(& $adb devices) |
      Where-Object { $_ -match '^emulator-\d+\s+device$' } |
      Select-Object -First 1
    if ($deviceLine) {
      $serial = ($deviceLine -split '\s+')[0]
      $boot = @(& $adb -s $serial shell getprop sys.boot_completed 2>$null) |
        Select-Object -First 1
      if ($boot -and $boot.Trim() -eq '1') { break }
    }
  } while ((Get-Date) -lt $deadline)
  if (-not $serial -or -not $boot -or $boot.Trim() -ne '1') {
    throw 'Emulator boot timeout.'
  }

  & $adb -s $serial shell input keyevent KEYCODE_WAKEUP | Out-Null
  & $adb -s $serial shell wm dismiss-keyguard | Out-Null
  & $adb -s $serial shell svc power stayon true | Out-Null
  Start-Sleep -Seconds 5

  $installed = $false
  for ($attempt = 1; $attempt -le 3 -and -not $installed; $attempt += 1) {
    if (-not (Wait-MortDevice -Serial $serial -Seconds 30)) { continue }
    & $adb -s $serial install -r $ApkPath 2>$null | Out-Null
    $installed = $LASTEXITCODE -eq 0
    if (-not $installed) { Start-Sleep -Seconds 3 }
  }
  if (-not $installed) { throw 'APK install failed after three ADB attempts.' }
  & $adb -s $serial shell pm clear com.mortapp.mobile | Out-Null
  & $adb -s $serial logcat -c
  & $adb -s $serial shell am start -n com.mortapp.mobile/.MainActivity | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'MORT launch failed.' }
  $uiDeadline = (Get-Date).AddSeconds(60)
  $xml = ''
  do {
    Start-Sleep -Seconds 3
    $xml = Get-MortUiXml -Serial $serial
    if ([string]::IsNullOrWhiteSpace($xml)) { continue }
    if (Test-UiContainsText -Xml $xml -Text 'Continue with Google') { break }
    if (Test-UiContainsText -Xml $xml -Text 'Wait') {
      [void](Invoke-UiTextTap -Serial $serial -Xml $xml -Text 'Wait')
      continue
    }
    if (Test-UiContainsText -Xml $xml -Text 'Sign in') {
      [void](Invoke-UiTextTap -Serial $serial -Xml $xml -Text 'Sign in')
    }
  } while ((Get-Date) -lt $uiDeadline)
  if ([string]::IsNullOrWhiteSpace($xml)) {
    throw 'Android emulator UI automation became unavailable before the Google button check.'
  }
  if (-not (Test-UiContainsText -Xml $xml -Text 'Continue with Google')) {
    $visibleStates = @(
      'Connecting securely',
      'Restoring your session',
      'MORT could not start',
      'Welcome to MORT',
      'Create account',
      'Sign in'
    ) | Where-Object {
      -not [string]::IsNullOrWhiteSpace($xml) -and
      (Test-UiContainsText -Xml $xml -Text $_)
    }
    $packages = @([regex]::Matches($xml, 'package="([^"]+)"') |
      ForEach-Object { $_.Groups[1].Value } |
      Sort-Object -Unique)
    $visibleLabels = @([regex]::Matches(
      $xml,
      '(?:text|content-desc)="([^"]+)"'
    ) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique |
      Select-Object -First 20)
    throw "Continue with Google was not visible in the signed APK. Visible states: $($visibleStates -join ', '); packages: $($packages -join ', '); labels: $($visibleLabels -join ', ')."
  }
  'GOOGLE_BUTTON_VISIBLE=PASS'

  if (-not (Invoke-UiTextTap -Serial $serial -Xml $xml -Text 'Continue with Google')) {
    throw 'Continue with Google could not be tapped.'
  }
  Start-Sleep -Seconds 8

  $resumed = @(& $adb -s $serial shell dumpsys activity activities) |
    Select-String 'topResumedActivity|mResumedActivity' |
    Select-Object -First 1
  if (-not $resumed) { throw 'No resumed activity was reported after the Google tap.' }
  $resumedText = $resumed.Line.Trim()
  if ($resumedText -match 'com\.mortapp\.mobile/.MainActivity') {
    throw 'Google tap did not leave MORT for an external browser activity.'
  }
  $fatal = @(& $adb -s $serial logcat -d -v brief 'AndroidRuntime:E' 'flutter:E' '*:S')
  if ($fatal.Count -gt 0) { throw 'Fatal logs were emitted during Google OAuth launch.' }

  'GOOGLE_BUTTON_TAP=PASS'
  "EXTERNAL_BROWSER_ACTIVITY=$resumedText"
  'GOOGLE_OAUTH_BROWSER_LAUNCH=PASS'
  'GOOGLE_ACCOUNT_SELECTION=NOT_PERFORMED'
  'GOOGLE_CALLBACK_AND_SESSION=NOT_VERIFIED'
} finally {
  if ($serial -and -not $emulatorProcess.HasExited) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    & $adb -s $serial emu kill 2>$null | Out-Null
    $ErrorActionPreference = $previousPreference
  }
  if (-not $emulatorProcess.HasExited) {
    Stop-Process -Id $emulatorProcess.Id -Force -ErrorAction SilentlyContinue
  }
}
