function Resolve-MortCrashReportingDefines {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][bool]$Enabled,
    [AllowNull()][string]$SentryDsn
  )

  if (-not $Enabled) {
    return [ordered]@{ MORT_CRASH_REPORTING_ENABLED = 'false' }
  }

  $parsedDsn = $null
  $validUri = -not [string]::IsNullOrWhiteSpace($SentryDsn) -and
    [Uri]::TryCreate($SentryDsn, [UriKind]::Absolute, [ref]$parsedDsn)
  if (-not $validUri -or $parsedDsn.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($parsedDsn.Host)) {
    throw 'Production crash reporting requires a valid HTTPS Sentry DSN in the SENTRY_DSN environment variable.'
  }

  return [ordered]@{
    MORT_CRASH_REPORTING_ENABLED = 'true'
    SENTRY_DSN = $SentryDsn
  }
}

function Set-MortCrashReportingDefines {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Defines,
    [Parameter(Mandatory)][bool]$Enabled,
    [AllowNull()][string]$SentryDsn
  )

  $resolved = Resolve-MortCrashReportingDefines -Enabled:$Enabled -SentryDsn $SentryDsn
  foreach ($key in $resolved.Keys) {
    $Defines[$key] = $resolved[$key]
  }
}
