# Only the client ingestion DSN belongs in Dart defines. Auth tokens stay server-side.
function Get-MortSentryClientDsn {
  param([bool]$Required = $false)
  $value = [Environment]::GetEnvironmentVariable('SENTRY_DSN', 'Process')
  if ([string]::IsNullOrWhiteSpace($value)) {
    $configPath = Join-Path $env:USERPROFILE 'OneDrive\Documents\mort credientals\sentry.env'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
      foreach ($line in Get-Content -LiteralPath $configPath) {
        if ($line -match '^\s*SENTRY_DSN\s*=\s*(.*?)\s*$') {
          $value = $Matches[1].Trim().Trim('"').Trim("'")
          break
        }
      }
    }
  }
  if ([string]::IsNullOrWhiteSpace($value)) {
    if ($Required) { throw 'SENTRY_DSN is required when crash reporting is enabled.' }
    return ''
  }
  $uri = $null
  if (-not [Uri]::TryCreate($value, [UriKind]::Absolute, [ref]$uri) -or
      $uri.Scheme -cne 'https' -or
      [string]::IsNullOrWhiteSpace($uri.Host) -or
      [string]::IsNullOrWhiteSpace($uri.UserInfo) -or
      $uri.UserInfo.Contains(':') -or
      $uri.AbsolutePath -cnotmatch '^/[1-9][0-9]*$' -or
      $uri.Query -ne '' -or $uri.Fragment -ne '') {
    throw 'SENTRY_DSN must be a valid HTTPS client ingestion DSN.'
  }
  return $value
}
