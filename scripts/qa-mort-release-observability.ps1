$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$helperPath = Join-Path $PSScriptRoot 'mort-release-observability.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
  throw 'Expected a release observability resolver that gates production crash reporting on a valid DSN.'
}
. $helperPath

function Assert-Equal([object]$Actual, [object]$Expected, [string]$Message) {
  if ($Actual -cne $Expected) { throw "$Message (expected '$Expected', got '$Actual')" }
}

function Assert-Throws([scriptblock]$Action, [string]$Message) {
  try { & $Action } catch { return }
  throw $Message
}

$disabled = [ordered]@{ MORT_CRASH_REPORTING_ENABLED = 'true'; existing_define = 'preserved' }
Set-MortCrashReportingDefines -Defines $disabled -Enabled:$false -SentryDsn 'https://public@example.ingest.sentry.io/1'
Assert-Equal $disabled.MORT_CRASH_REPORTING_ENABLED 'false' 'Crash reporting must remain disabled when the profile says disabled'
Assert-Equal $disabled.existing_define 'preserved' 'Applying observability settings must preserve other release defines'
if ($disabled.Contains('SENTRY_DSN')) { throw 'Disabled profile must not receive a Sentry DSN build define.' }

$enabled = [ordered]@{}
Set-MortCrashReportingDefines -Defines $enabled -Enabled:$true -SentryDsn 'https://public@example.ingest.sentry.io/1'
Assert-Equal $enabled.MORT_CRASH_REPORTING_ENABLED 'true' 'Enabled profile must enable crash reporting'
Assert-Equal $enabled.SENTRY_DSN 'https://public@example.ingest.sentry.io/1' 'Enabled profile must pass its configured DSN to the app'

Assert-Throws { Set-MortCrashReportingDefines -Defines ([ordered]@{}) -Enabled:$true -SentryDsn '' } 'Missing Sentry DSN must fail a crash-reporting release'
Assert-Throws { Set-MortCrashReportingDefines -Defines ([ordered]@{}) -Enabled:$true -SentryDsn 'not-a-url' } 'Malformed Sentry DSN must fail a crash-reporting release'
Assert-Throws { Set-MortCrashReportingDefines -Defines ([ordered]@{}) -Enabled:$true -SentryDsn 'http://public@example.ingest.sentry.io/1' } 'Non-HTTPS Sentry DSN must fail a crash-reporting release'

Write-Output 'MORT release observability checks passed (5 cases).'
