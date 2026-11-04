[CmdletBinding()]
param(
  [string]$ContainerName = 'supabase_db_mort-proposals-local-20261102'
)

$ErrorActionPreference = 'Stop'

if ($ContainerName -notmatch '^supabase_db_[A-Za-z0-9_.-]+$') {
  throw 'This test runner accepts only a local Supabase Postgres Docker container name.'
}

$running = (& docker inspect --format '{{.State.Running}}' $ContainerName 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $running -ne 'true') {
  throw "Local Postgres test container '$ContainerName' is not running. No remote database is supported by this runner."
}

$baselineQuery = @"
select current_setting('server_version_num') || '|' ||
  (select count(*)::text from supabase_migrations.schema_migrations) || '|' ||
  (select max(version)::text from supabase_migrations.schema_migrations) || '|' ||
  md5(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure)) || '|' ||
  has_function_privilege('service_role', 'public.get_my_job_applications(uuid)', 'EXECUTE')::text;
"@

$before = (& docker exec $ContainerName psql -U postgres -d postgres -Atc $baselineQuery | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the local migration baseline.' }
$baseline = $before.Split('|')
if ($baseline.Count -ne 5 -or
    [int]$baseline[0] -lt 170000 -or [int]$baseline[0] -ge 180000 -or
    $baseline[1] -ne '73' -or
    $baseline[2] -ne '20261102113314' -or
    $baseline[3] -ne '94a1b987774f994019ba6269b9abeb16') {
  throw "Local test DB is not the reviewed production-equivalent baseline (PostgreSQL 17, 73 migrations through 20261102113314, function MD5 94a1b987774f994019ba6269b9abeb16). Actual fingerprint: $before"
}

$migrationPath = Join-Path $PSScriptRoot '..\supabase\migrations\20261104182914_issue_70_guardian_application_reader_scope.sql'
$testPath = Join-Path $PSScriptRoot '..\supabase\tests\database\guardian_application_reader_scope.test.sql'
$migration = Get-Content -LiteralPath $migrationPath -Raw
$test = Get-Content -LiteralPath $testPath -Raw

# The hosted ACL grants service_role EXECUTE. The recovered 73-migration local
# baseline does not, so mirror only that existing trusted-role ACL in this
# rollback transaction before applying the migration and checking preservation.
$sql = @"
BEGIN;
GRANT EXECUTE ON FUNCTION public.get_my_job_applications(uuid) TO service_role;
$migration
$test
"@

$output = $sql | & docker exec -i $ContainerName psql -U postgres -d postgres -v ON_ERROR_STOP=1 2>&1
$psqlExitCode = $LASTEXITCODE
$output | Write-Output
if ($psqlExitCode -ne 0 -or ($output -join "`n") -match '(?m)^\s*not ok\b') {
  throw "Issue #70 database regression failed (psql exit $psqlExitCode)."
}
if (($output -join "`n") -notmatch '1\.\.33') {
  throw 'Issue #70 database regression did not report the expected 33-test plan.'
}

$after = (& docker exec $ContainerName psql -U postgres -d postgres -Atc $baselineQuery | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $after -ne $before) {
  throw "Rollback did not preserve the local baseline. Before: $before; after: $after"
}

Write-Host "[qa-issue-70-guardian-application-reader] PASS: 33 assertions; baseline unchanged ($after)." -ForegroundColor Green
