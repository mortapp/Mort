function Invoke-DockerImagePull {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Image,
    [ValidateRange(1, 5)][int]$MaxAttempts = 3,
    [ValidateRange(0, 30)][int]$BaseDelaySeconds = 3,
    [scriptblock]$PullCommand = {
      param($ImageReference)
      $pullOutput = & docker pull $ImageReference 2>&1
      [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($pullOutput) }
    }
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $result = & $PullCommand $Image
    $output = @($result.Output | ForEach-Object { [string]$_ })
    foreach ($line in $output) { Write-Host $line }
    if ([int]$result.ExitCode -eq 0) { return }

    $details = $output -join "`n"
    $retryable = $details -match '(?i)(toomanyrequests|too many requests|rate limit|\b429\b|temporarily unavailable|TLS handshake timeout|connection reset|unexpected EOF|i/o timeout)'
    if (-not $retryable -or $attempt -eq $MaxAttempts) {
      throw "Failed to pull image $Image (attempt $attempt of $MaxAttempts). $details"
    }

    $delay = [Math]::Min(30, $BaseDelaySeconds * $attempt)
    Write-Warning "Transient registry failure pulling $Image; retry $($attempt + 1) of $MaxAttempts in $delay seconds."
    if ($delay -gt 0) { Start-Sleep -Seconds $delay }
  }
}
