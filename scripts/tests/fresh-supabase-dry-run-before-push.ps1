$ErrorActionPreference = 'Stop'

function Assert-Equal {
  param([object]$Actual, [object]$Expected, [string]$Message)
  if ($Actual -ne $Expected) { throw "$Message (expected '$Expected', got '$Actual')" }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mort-supabase-bootstrap-test-" + [guid]::NewGuid().ToString('N'))
$fakeCliDirectory = Join-Path $tempRoot 'bin'
$logPath = Join-Path $tempRoot 'calls.txt'
New-Item -ItemType Directory -Path $fakeCliDirectory -Force | Out-Null

$runningOnWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
  [System.Runtime.InteropServices.OSPlatform]::Windows
)
if ($runningOnWindows) {
  $cliPath = Join-Path $fakeCliDirectory 'supabase.cmd'
  @'
@echo off
echo %*>>"%MORT_SUPABASE_TEST_LOG%"
if "%*"=="db push --dry-run" if "%MORT_SUPABASE_TEST_FAIL_DRY_RUN%"=="1" exit /b 23
exit /b 0
'@ | Set-Content -LiteralPath $cliPath -Encoding Ascii
} else {
  $cliPath = Join-Path $fakeCliDirectory 'supabase'
  @'
#!/bin/sh
printf '%s\n' "$*" >> "$MORT_SUPABASE_TEST_LOG"
if [ "$*" = "db push --dry-run" ] && [ "$MORT_SUPABASE_TEST_FAIL_DRY_RUN" = "1" ]; then exit 23; fi
exit 0
'@ | Set-Content -LiteralPath $cliPath -Encoding Ascii
  & chmod +x $cliPath
  if ($LASTEXITCODE -ne 0) { throw 'Could not make the fake Supabase CLI executable.' }
}

$oldPath = $env:Path
$oldLog = $env:MORT_SUPABASE_TEST_LOG
$oldFailDryRun = $env:MORT_SUPABASE_TEST_FAIL_DRY_RUN
$oldProjectRef = $env:MORT_SUPABASE_PROJECT_REF
$oldConfirmProjectRef = $env:MORT_CONFIRM_PROJECT_REF
$oldFreshConfirmation = $env:MORT_CONFIRM_FRESH_SUPABASE
$oldLocation = Get-Location

try {
  $env:PATH = "$fakeCliDirectory$([System.IO.Path]::PathSeparator)$oldPath"
  $resolvedFakeCli = Get-Command supabase -ErrorAction Stop
  if ([System.IO.Path]::GetFullPath($resolvedFakeCli.Source) -ne [System.IO.Path]::GetFullPath($cliPath)) {
    throw "The test must resolve its fake Supabase CLI before invoking the bootstrap (resolved '$($resolvedFakeCli.Source)')."
  }
  $env:MORT_SUPABASE_TEST_LOG = $logPath
  $env:MORT_SUPABASE_TEST_FAIL_DRY_RUN = '0'
  $env:MORT_SUPABASE_PROJECT_REF = 'freshproject123'
  $env:MORT_CONFIRM_PROJECT_REF = 'freshproject123'
  $env:MORT_CONFIRM_FRESH_SUPABASE = 'YES_FRESH_PROJECT'

  & (Join-Path $repoRoot 'scripts\apply-fresh-supabase.ps1') -SkipLink

  $calls = @(Get-Content -LiteralPath $logPath)
  Assert-Equal $calls.Count 2 'Fresh project bootstrap should preflight and then apply migrations'
  Assert-Equal $calls[0] 'db push --dry-run' 'Migration dry-run must happen before any schema write'
  Assert-Equal $calls[1] 'db push' 'Migration apply should follow a successful dry-run'

  Set-Content -LiteralPath $logPath -Value '' -NoNewline
  $env:MORT_SUPABASE_TEST_FAIL_DRY_RUN = '1'
  $preflightFailed = $false
  try {
    & (Join-Path $repoRoot 'scripts\apply-fresh-supabase.ps1') -SkipLink
  } catch {
    $preflightFailed = $_.Exception.Message -match 'dry-run failed'
  }
  Assert-Equal $preflightFailed $true 'A failed migration dry-run should stop the bootstrap'
  $failedCalls = @(Get-Content -LiteralPath $logPath)
  Assert-Equal $failedCalls.Count 1 'A failed dry-run must not invoke the migration apply command'
  Assert-Equal $failedCalls[0] 'db push --dry-run' 'Only the preflight should run when it fails'
} finally {
  Set-Location -LiteralPath $oldLocation
  $env:PATH = $oldPath
  $env:MORT_SUPABASE_TEST_LOG = $oldLog
  $env:MORT_SUPABASE_TEST_FAIL_DRY_RUN = $oldFailDryRun
  $env:MORT_SUPABASE_PROJECT_REF = $oldProjectRef
  $env:MORT_CONFIRM_PROJECT_REF = $oldConfirmProjectRef
  $env:MORT_CONFIRM_FRESH_SUPABASE = $oldFreshConfirmation
  Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

$global:LASTEXITCODE = 0
Write-Output '[fresh-supabase-dry-run-before-push] PASS: a dry-run precedes the migration push and failure prevents schema writes.'
