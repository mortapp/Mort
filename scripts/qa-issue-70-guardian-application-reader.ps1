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
  has_function_privilege('service_role', 'public.get_my_job_applications(uuid)', 'EXECUTE')::text || '|' ||
  md5(pg_get_functiondef('public.update_my_job_application_status(uuid,text,timestamptz)'::regprocedure));
"@

$before = (& docker exec $ContainerName psql -U postgres -d postgres -Atc $baselineQuery | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the local migration baseline.' }
$baseline = $before.Split('|')
if ($baseline.Count -ne 6 -or
    [int]$baseline[0] -lt 170000 -or [int]$baseline[0] -ge 180000 -or
    $baseline[1] -ne '73' -or
    $baseline[2] -ne '20261102113314' -or
    $baseline[3] -ne '94a1b987774f994019ba6269b9abeb16' -or
    $baseline[5] -notmatch '^[0-9a-f]{32}$') {
  throw "Local test DB is not the reviewed production-equivalent baseline (PostgreSQL 17, 73 migrations through 20261102113314, verified reader/status function fingerprints). Actual fingerprint: $before"
}

$migrationPath = Join-Path $PSScriptRoot '..\supabase\production-baseline-migrations\20261104182914_issue_70_guardian_application_reader_scope.sql'
$testPath = Join-Path $PSScriptRoot '..\supabase\production-baseline-tests\guardian_application_reader_scope.test.sql'
$migration = Get-Content -LiteralPath $migrationPath -Raw
$test = Get-Content -LiteralPath $testPath -Raw
$testSql = [regex]::Replace($test, '(?im)^begin;[ \t]*(?:\r?\n)?', '')
$testSql = [regex]::Replace($testSql, '(?im)^rollback;[ \t]*$', '')

# The hosted ACL grants service_role EXECUTE and direct SELECT. The recovered
# 73-migration local baseline does not, so mirror only those existing trusted-
# role ACLs in this rollback transaction before applying the migration and
# checking preservation. No grant is added to anon or authenticated.
# Strip the test file's standalone transaction wrapper so Windows psql does not
# emit a nested-BEGIN warning under PowerShell's stop-on-error semantics.
$sql = @"
BEGIN;
GRANT EXECUTE ON FUNCTION public.get_my_job_applications(uuid) TO service_role;
GRANT SELECT ON TABLE public.job_applications TO service_role;
$migration
$testSql
ROLLBACK;
"@

$output = $sql | & docker exec -i $ContainerName psql -U postgres -d postgres -v ON_ERROR_STOP=1 2>&1
$psqlExitCode = $LASTEXITCODE
$output | Write-Output
if ($psqlExitCode -ne 0 -or ($output -join "`n") -match '(?m)^\s*not ok\b') {
  throw "Issue #70 database regression failed (psql exit $psqlExitCode)."
}
$planMatch = [regex]::Match($test, '(?im)^\s*select\s+plan\((\d+)\);\s*$')
if (-not $planMatch.Success) {
  throw 'Issue #70 regression SQL does not declare a single-line pgTAP plan.'
}
$expectedAssertions = [int]$planMatch.Groups[1].Value
if (($output -join "`n") -notmatch "(?m)^\s*1\.\.$expectedAssertions\s*$") {
  throw "Issue #70 database regression did not report its declared $expectedAssertions-test plan."
}

$after = (& docker exec $ContainerName psql -U postgres -d postgres -Atc $baselineQuery | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $after -ne $before) {
  throw "Rollback did not preserve the local baseline. Before: $before; after: $after"
}

Write-Host "[qa-issue-70-guardian-application-reader] PASS: $expectedAssertions assertions; baseline unchanged ($after)." -ForegroundColor Green
