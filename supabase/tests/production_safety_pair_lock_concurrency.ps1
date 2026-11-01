param(
  [int] $LockHoldSeconds = 12,
  [int] $WaitTimeoutSeconds = 10
)

$ErrorActionPreference = 'Stop'

# This test requires an explicitly isolated Supabase/Postgres database and
# pre-seeded QA users plus an active conversation containing both users.
# Credentials are read only from the process environment and never printed.
$required = @(
  'MORT_QA_PROJECT_REF',
  'MORT_QA_DB_HOST',
  'MORT_QA_DB_NAME',
  'MORT_QA_DB_USER',
  'MORT_QA_DB_PASSWORD',
  'MORT_QA_TEEN_ID',
  'MORT_QA_ADULT_ID',
  'MORT_QA_CONVERSATION_ID'
)
foreach ($name in $required) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
    throw "Required isolated-QA environment variable is missing: $name"
  }
}

$projectRef = $env:MORT_QA_PROJECT_REF
$dbHost = $env:MORT_QA_DB_HOST
if ($projectRef -eq 'jxbnrkasktbhtiujkhay' -or
    $projectRef -eq 'rakjydmgwwgtdislanbt' -or
    $dbHost -match 'jxbnrkasktbhtiujkhay|rakjydmgwwgtdislanbt') {
  throw 'Refusing to run the two-session test against a production or deleted project.'
}

$teenId = [guid]::Empty
$adultId = [guid]::Empty
$conversationId = [guid]::Empty
if (-not [guid]::TryParse($env:MORT_QA_TEEN_ID, [ref] $teenId) -or
    -not [guid]::TryParse($env:MORT_QA_ADULT_ID, [ref] $adultId) -or
    -not [guid]::TryParse($env:MORT_QA_CONVERSATION_ID, [ref] $conversationId) -or
    $teenId -eq $adultId) {
  throw 'QA participant/conversation identifiers must be distinct UUIDs.'
}

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
  throw 'psql is required to start two independent database sessions.'
}

function New-QaPsqlStartInfo([string] $ApplicationName, [string] $Sql) {
  $info = [System.Diagnostics.ProcessStartInfo]::new('psql')
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $info.ArgumentList.Add('-X')
  $info.ArgumentList.Add('-q')
  $info.ArgumentList.Add('-v')
  $info.ArgumentList.Add('ON_ERROR_STOP=1')
  $info.ArgumentList.Add('-c')
  $info.ArgumentList.Add($Sql)
  $info.Environment['PGHOST'] = $dbHost
  if ($env:MORT_QA_DB_PORT) { $info.Environment['PGPORT'] = $env:MORT_QA_DB_PORT }
  $info.Environment['PGDATABASE'] = $env:MORT_QA_DB_NAME
  $info.Environment['PGUSER'] = $env:MORT_QA_DB_USER
  $info.Environment['PGPASSWORD'] = $env:MORT_QA_DB_PASSWORD
  $info.Environment['PGAPPNAME'] = $ApplicationName
  if ($env:MORT_QA_DB_SSLMODE) { $info.Environment['PGSSLMODE'] = $env:MORT_QA_DB_SSLMODE }
  return $info
}

function Invoke-QaPsql([string] $Sql, [string] $ApplicationName = 'mort_pair_lock_preflight') {
  $info = New-QaPsqlStartInfo $ApplicationName $Sql
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $info
  $null = $process.Start()
  $stdout = $process.StandardOutput.ReadToEndAsync()
  $stderr = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  $outText = $stdout.GetAwaiter().GetResult()
  $errText = $stderr.GetAwaiter().GetResult()
  if ($process.ExitCode -ne 0) {
    throw "Isolated-QA SQL failed with exit code $($process.ExitCode): $($errText.Trim())"
  }
  return $outText.Trim()
}

$pairCheckSql = @"
select case
  when exists (
    select 1 from public.user_blocks
    where (blocker_id = '$teenId'::uuid and blocked_id = '$adultId'::uuid)
       or (blocker_id = '$adultId'::uuid and blocked_id = '$teenId'::uuid)
  ) then 'BLOCK_EXISTS'
  when not exists (
    select 1 from public.conversations c
    join public.conversation_members teen_member
      on teen_member.conversation_id = c.id and teen_member.user_id = '$teenId'::uuid
    join public.conversation_members adult_member
      on adult_member.conversation_id = c.id and adult_member.user_id = '$adultId'::uuid
    where c.id = '$conversationId'::uuid and c.status = 'active'
  ) then 'CONVERSATION_NOT_READY'
  else 'READY'
end;
"@
if ((Invoke-QaPsql $pairCheckSql) -ne 'READY') {
  throw 'QA fixture is not ready or a pre-existing block would be touched; no test was run.'
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('mort-pair-lock-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $tempRoot
$sessionAOut = Join-Path $tempRoot 'session-a.stdout'
$sessionAErr = Join-Path $tempRoot 'session-a.stderr'
$sessionBOut = Join-Path $tempRoot 'session-b.stdout'
$sessionBErr = Join-Path $tempRoot 'session-b.stderr'
$sessionA = $null
$sessionB = $null
$passed = $false
$blockCreated = $false

try {
  $blockRequestId = [guid]::NewGuid()
  $sessionASql = @"
begin;
set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub', '$teenId', true);
select public.block_user_v2('$adultId'::uuid, '$blockRequestId'::uuid);
select pg_catalog.pg_sleep($LockHoldSeconds);
commit;
"@
  $infoA = New-QaPsqlStartInfo 'mort_pair_lock_session_a' $sessionASql
  $sessionA = [System.Diagnostics.Process]::new()
  $sessionA.StartInfo = $infoA
  $null = $sessionA.Start()
  $aOutTask = $sessionA.StandardOutput.ReadToEndAsync()
  $aErrTask = $sessionA.StandardError.ReadToEndAsync()

  $deadline = [DateTime]::UtcNow.AddSeconds($WaitTimeoutSeconds)
  $lockHeld = $false
  do {
    $lockHeld = (Invoke-QaPsql @"
select exists (
  select 1 from pg_catalog.pg_locks l
  join pg_catalog.pg_stat_activity a on a.pid = l.pid
  where a.application_name = 'mort_pair_lock_session_a'
    and l.locktype = 'advisory' and l.granted
);
"@) -eq 't'
    if (-not $lockHeld) { Start-Sleep -Milliseconds 100 }
  } while (-not $lockHeld -and [DateTime]::UtcNow -lt $deadline)
  if (-not $lockHeld) { throw 'Session A did not acquire its pair lock within the timeout.' }

  $requestId = [guid]::NewGuid()
  $sessionBSql = @"
begin;
set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.sub', '$adultId', true);
select public.send_safe_message_v2('$conversationId'::uuid, 'pair-lock concurrency probe', '$requestId'::uuid);
commit;
"@
  $infoB = New-QaPsqlStartInfo 'mort_pair_lock_session_b' $sessionBSql
  $sessionB = [System.Diagnostics.Process]::new()
  $sessionB.StartInfo = $infoB
  $null = $sessionB.Start()
  $bOutTask = $sessionB.StandardOutput.ReadToEndAsync()
  $bErrTask = $sessionB.StandardError.ReadToEndAsync()

  $sessionBFinished = $sessionB.WaitForExit(($LockHoldSeconds + $WaitTimeoutSeconds) * 1000)
  if (-not $sessionBFinished) {
    throw 'Session B did not finish after Session A released the pair lock.'
  }
  $bError = $bErrTask.GetAwaiter().GetResult()
  if (-not $sessionA.WaitForExit(5000) -or $sessionA.ExitCode -ne 0) {
    throw 'Session A failed to commit the isolated QA block fixture.'
  }
  $blockCreated = $true
  if ($sessionB.ExitCode -eq 0) {
    throw 'FAIL: message RPC committed while the block transaction held/committed the same user pair lock.'
  }
  if ($bError -notmatch 'message_blocked_by_safety_control|Messaging is unavailable|message_blocked') {
    throw 'Session B failed for an unexpected reason; inspect isolated test logs before interpreting the result.'
  }
  $passed = $true
  Write-Output 'PASS: independent Session B could not commit a message after Session A serialized and committed a block for the same user pair.'
}
finally {
  if ($sessionA -and -not $sessionA.HasExited) { $sessionA.Kill(); $sessionA.WaitForExit() }
  if ($sessionB -and -not $sessionB.HasExited) { $sessionB.Kill(); $sessionB.WaitForExit() }
  if ($sessionA -and $sessionA.HasExited -and $sessionA.ExitCode -eq 0) {
    $blockCreated = $true
  }
  if ($blockCreated) {
    try {
      $cleanupSql = "delete from public.user_blocks where blocker_id = '$teenId'::uuid and blocked_id = '$adultId'::uuid;"
      $null = Invoke-QaPsql $cleanupSql 'mort_pair_lock_cleanup'
    } catch {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
      throw 'Concurrency test passed but its isolated QA block fixture cleanup failed.'
    }
  }
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
