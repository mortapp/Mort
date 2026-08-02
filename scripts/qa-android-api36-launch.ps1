[CmdletBinding()]
param(
  [string]$AvdName = 'Medium_Phone_API_36.1',
  [string]$ApkPath = '',
  [ValidateSet('auto-no-window', 'host', 'swiftshader_indirect', 'angle_indirect')]
  [string]$GpuMode = 'swiftshader_indirect',
  [switch]$KeepRunning
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
  $ApkPath = Join-Path $root "build\play\mort-closed-test-$($version.versionName).apk"
}
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$stdout = Join-Path $env:TEMP 'mort-emulator-stdout.log'
$stderr = Join-Path $env:TEMP 'mort-emulator-stderr.log'

foreach ($required in @($adb, $emulator, $ApkPath)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Required Android QA file is missing: $required"
  }
}

Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
$emulatorProcess = Start-Process -FilePath $emulator `
  -ArgumentList @(
    '-avd', $AvdName,
    '-wipe-data', '-no-window', '-no-audio', '-no-boot-anim',
    '-no-snapshot-load', '-no-snapshot-save',
    '-cores', '2', '-memory', '2048',
    '-feature', '-Vulkan',
    '-gpu', $GpuMode
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

  & $adb -s $serial install -r $ApkPath
  if ($LASTEXITCODE -ne 0) { throw 'APK install failed.' }
  & $adb -s $serial shell pm clear com.mortapp.mobile
  & $adb -s $serial logcat -c
  & $adb -s $serial shell am start -W -n com.mortapp.mobile/.MainActivity
  if ($LASTEXITCODE -ne 0) { throw 'Activity launch failed.' }
  Start-Sleep -Seconds 5

  if ($emulatorProcess.HasExited) {
    throw "Emulator exited after launch with code $($emulatorProcess.ExitCode)."
  }
  $appProcessId = @(& $adb -s $serial shell pidof com.mortapp.mobile) |
    Select-Object -First 1
  if (-not $appProcessId -or [string]::IsNullOrWhiteSpace($appProcessId.Trim())) {
    '---APP_FATAL_LOGS---'
    @(& $adb -s $serial logcat -d -v brief 'AndroidRuntime:E' 'flutter:E' '*:S') |
      Select-Object -Last 120
    throw 'MORT app process is absent after launch.'
  }

  $resumed = @(& $adb -s $serial shell dumpsys activity activities) |
    Select-String 'mResumedActivity|topResumedActivity' |
    Select-Object -First 3
  $fatal = @(& $adb -s $serial logcat -d -v brief 'AndroidRuntime:E' 'flutter:E' '*:S')
  if ($fatal.Count -gt 0) {
    $fatal | Select-Object -Last 80
    throw 'Fatal Android or Flutter logs were emitted after launch.'
  }

  "APP_PROCESS_ID=$($appProcessId.Trim())"
  $resumed | ForEach-Object { $_.Line.Trim() }
  'FATAL_LOG_SCAN=PASS'

  $evidenceDirectory = Join-Path $root 'artifacts\native-qa'
  New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
  $screenshot = Join-Path $evidenceDirectory "mort-api36-launch-$($version.versionName).png"
  $screenshotCaptured = $false
  for ($attempt = 1; $attempt -le 3 -and -not $screenshotCaptured; $attempt += 1) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $deviceState = @(& $adb -s $serial get-state 2>$null) | Select-Object -First 1
    $deviceStateExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($deviceStateExitCode -ne 0 -or
        -not $deviceState -or
        $deviceState.Trim() -ne 'device') {
      Start-Sleep -Seconds 2
      continue
    }
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    & $adb -s $serial shell screencap -p /sdcard/mort-api36-launch.png *> $null
    $screenCaptureExitCode = $LASTEXITCODE
    if ($screenCaptureExitCode -eq 0) {
      & $adb -s $serial pull /sdcard/mort-api36-launch.png $screenshot *> $null
      $screenshotCaptured = $LASTEXITCODE -eq 0
    }
    $ErrorActionPreference = $previousPreference
    Start-Sleep -Seconds 1
  }
  if ($screenshotCaptured) {
    & $adb -s $serial shell rm /sdcard/mort-api36-launch.png 2>$null | Out-Null
    "SCREENSHOT=$screenshot"
    "SCREENSHOT_SHA256=$((Get-FileHash -Algorithm SHA256 -LiteralPath $screenshot).Hash)"
  } else {
    'SCREENSHOT_CAPTURE=UNAVAILABLE_AFTER_ADB_DISCONNECT'
  }
} catch {
  "QA_FAILURE=$($_.Exception.Message)"
  '---EMULATOR_STDERR_TAIL---'
  if (Test-Path -LiteralPath $stderr) {
    Get-Content -LiteralPath $stderr -Tail 60
  }
  throw
} finally {
  if (-not $KeepRunning -and $serial -and -not $emulatorProcess.HasExited) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    & $adb -s $serial emu kill 2>$null | Out-Null
    $ErrorActionPreference = $previousPreference
  }
  if (-not $KeepRunning -and -not $emulatorProcess.HasExited) {
    Stop-Process -Id $emulatorProcess.Id -Force -ErrorAction SilentlyContinue
  }
  if ($KeepRunning -and $serial -and -not $emulatorProcess.HasExited) {
    "EMULATOR_KEPT_RUNNING=$serial"
  }
}

# Cleanup-time ADB disconnects must not replace a successful launch verdict.
exit 0
