$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\docker-image-pull.ps1')

function Assert-Equal {
  param([object]$Actual, [object]$Expected, [string]$Message)
  if ($Actual -ne $Expected) { throw "$Message (expected $Expected, got $Actual)" }
}

$script:transientAttempts = 0
$transientPull = {
  param($Image)
  $script:transientAttempts++
  if ($script:transientAttempts -lt 3) {
    return [pscustomobject]@{ ExitCode = 1; Output = @('toomanyrequests: rate limit') }
  }
  return [pscustomobject]@{ ExitCode = 0; Output = @('image pulled') }
}

Invoke-DockerImagePull `
  -Image 'ghcr.io/supabase/postgres:test' `
  -PullCommand $transientPull `
  -BaseDelaySeconds 0 | Out-Null
Assert-Equal $script:transientAttempts 3 'Transient registry limit should retry and then succeed'

$script:permanentAttempts = 0
$permanentPull = {
  param($Image)
  $script:permanentAttempts++
  return [pscustomobject]@{ ExitCode = 1; Output = @('manifest unknown') }
}

$permanentFailed = $false
try {
  Invoke-DockerImagePull `
    -Image 'ghcr.io/supabase/postgres:missing' `
    -PullCommand $permanentPull `
    -BaseDelaySeconds 0 | Out-Null
} catch {
  $permanentFailed = $_.Exception.Message -match 'manifest unknown'
}
Assert-Equal $permanentFailed $true 'Permanent image errors should fail immediately'
Assert-Equal $script:permanentAttempts 1 'Permanent image errors must not be retried'

Write-Output '[local-supabase-image-pull-retry] PASS: transient registry failures retry; permanent failures stop immediately.'
