[CmdletBinding()]
param(
  [string]$AvdName = 'Medium_Phone_API_36.1',
  [ValidateSet('auto-no-window', 'host', 'swiftshader_indirect', 'angle_indirect')]
  [string]$GpuMode = 'host',
  [string]$ResultPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$flutterRoot = Join-Path $root 'flutter_mort'
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$stdout = Join-Path $env:TEMP 'mort-integration-emulator-stdout.log'
$stderr = Join-Path $env:TEMP 'mort-integration-emulator-stderr.log'
$versionJson = & node (Join-Path $PSScriptRoot 'read-mobile-version.mjs') --json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authoritative mobile version.' }
$version = $versionJson | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($ResultPath)) {
  $ResultPath = Join-Path $root 'artifacts\native-qa\android-native-integration-result.json'
}
$resultDirectory = Split-Path $ResultPath -Parent
New-Item -ItemType Directory -Force -Path $resultDirectory | Out-Null

function Write-NativeIntegrationResult {
  param(
    [Parameter(Mandatory)][string]$Status,
    [string]$Failure = '',
    [string]$Serial = '',
    [string]$ApiLevel = '',
    [string]$Abi = ''
  )
  $result = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    status = $Status
    avd = $AvdName
    serial = $Serial
    apiLevel = $ApiLevel
    abi = $Abi
    gpuMode = $GpuMode
    testCommand = 'flutter test integration_test/android_native_smoke_test.dart'
    testFile = 'integration_test/android_native_smoke_test.dart'
    expectedTestCount = 2
    failure = $Failure
  }
  [IO.File]::WriteAllText(
    $ResultPath,
    ($result | ConvertTo-Json),
    [Text.UTF8Encoding]::new($false)
  )
}

Write-NativeIntegrationResult -Status 'running'

foreach ($required in @($adb, $emulator, $flutterRoot)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Android integration resource is missing: $required"
  }
}

Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
& $adb kill-server | Out-Null
& $adb start-server | Out-Null
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
  $deadline = (Get-Date).AddMinutes(5)
  do {
    Start-Sleep -Seconds 3
    if ($emulatorProcess.HasExited) {
      throw 'Emulator exited during integration-test boot.'
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
    throw 'Emulator boot timeout before Android integration tests.'
  }

  & $adb -s $serial wait-for-device
  if ($LASTEXITCODE -ne 0) { throw 'ADB lost the emulator after boot.' }
  & $adb -s $serial shell settings put global window_animation_scale 0
  & $adb -s $serial shell settings put global transition_animation_scale 0
  & $adb -s $serial shell settings put global animator_duration_scale 0
  & $adb -s $serial shell svc power stayon true
  $deviceState = @(& $adb -s $serial get-state) | Select-Object -First 1
  if (-not $deviceState -or $deviceState.Trim() -ne 'device') {
    throw 'Emulator is not online immediately before integration tests.'
  }
  $apiLevel = (@(& $adb -s $serial shell getprop ro.build.version.sdk) | Select-Object -First 1).Trim()
  $abi = (@(& $adb -s $serial shell getprop ro.product.cpu.abi) | Select-Object -First 1).Trim()

  Push-Location $flutterRoot
  try {
    & flutter test integration_test/android_native_smoke_test.dart `
      "--dart-define=MORT_EXPECTED_VERSION_NAME=$($version.versionName)" `
      "--dart-define=MORT_EXPECTED_VERSION_CODE=$($version.versionCode)" `
      -d $serial
    if ($LASTEXITCODE -ne 0) { throw 'Android native integration test failed.' }
  } finally {
    Pop-Location
  }
  "ANDROID_NATIVE_INTEGRATION=PASS"
  "EMULATOR_SERIAL=$serial"
  "EMULATOR_GPU=$GpuMode"
  Write-NativeIntegrationResult -Status 'pass' -Serial $serial -ApiLevel $apiLevel -Abi $abi
} catch {
  "ANDROID_NATIVE_INTEGRATION=FAIL"
  "INTEGRATION_FAILURE=$($_.Exception.Message)"
  '---EMULATOR_STDOUT_TAIL---'
  if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Tail 60 }
  '---EMULATOR_STDERR_TAIL---'
  if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Tail 60 }
  Write-NativeIntegrationResult -Status 'fail' -Failure $_.Exception.Message -Serial $serial
  throw
} finally {
  if ($serial) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    & $adb -s $serial emu kill 2>$null | Out-Null
    $ErrorActionPreference = $previousPreference
  }
  if (-not $emulatorProcess.HasExited) {
    Stop-Process -Id $emulatorProcess.Id -Force -ErrorAction SilentlyContinue
  }
}
