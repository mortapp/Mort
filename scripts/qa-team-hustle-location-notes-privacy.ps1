[CmdletBinding()]
param(
  [string]$ContainerName = 'supabase_db_mort-issue70-baseline'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($ContainerName -notmatch '^supabase_db_[A-Za-z0-9_.-]+$') {
  throw 'This test runner accepts only a local Supabase Postgres Docker container name.'
}

$running = (& docker inspect --format '{{.State.Running}}' $ContainerName 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $running -ne 'true') {
  throw "Local Postgres test container '$ContainerName' is not running. No remote database is supported by this runner."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$migrationPath = Join-Path $repoRoot 'supabase\production-baseline-migrations\20261113233000_team_hustle_location_notes_privacy.sql'
$testPath = Join-Path $repoRoot 'supabase\production-baseline-tests\team_hustle_location_notes_privacy.test.sql'
$migration = Get-Content -LiteralPath $migrationPath -Raw
$test = Get-Content -LiteralPath $testPath -Raw

$baselineQuery = @"
select
  (select count(*)::text from supabase_migrations.schema_migrations) || '|' ||
  (select max(version)::text from supabase_migrations.schema_migrations) || '|' ||
  case when to_regprocedure('public.list_team_hustles_v1()') is null then 'missing' else md5(pg_get_functiondef(to_regprocedure('public.list_team_hustles_v1()'))) end || '|' ||
  case when to_regclass('public.team_hustles') is null then 'missing' else has_table_privilege('authenticated', 'public.team_hustles', 'SELECT')::text end || '|' ||
  case when to_regclass('public.team_hustles') is null then 'missing' else has_any_column_privilege('authenticated', 'public.team_hustles', 'SELECT')::text end;
"@
$before = (& docker exec $ContainerName psql -U postgres -d postgres -Atc $baselineQuery | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the disposable production baseline.' }
$baseline = $before.Split('|')
if ($baseline.Count -ne 5 -or $baseline[0] -ne '73' -or $baseline[1] -ne '20261102113314') {
  throw "Refusing to run against an unexpected baseline. Expected 73 migrations through 20261102113314; actual: $before"
}

# The test owns a transaction for standalone use. Strip only its outer
# BEGIN/ROLLBACK so the migration and behavioral test share one rollback scope.
$testSql = [regex]::Replace($test, '(?im)^begin;[ \t]*(?:\r?\n)?', '')
$testSql = [regex]::Replace($testSql, '(?im)^rollback;[ \t]*$', '')
$fixtureSchema = @"
-- The pinned 73-migration production archive predates the Team Hustles table.
-- Create the minimum schema contract only inside this disposable rollback transaction.
CREATE TABLE IF NOT EXISTS public.team_hustles (
  id uuid PRIMARY KEY,
  poster_id uuid NOT NULL,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  category text NOT NULL DEFAULT 'other',
  pay_type text NOT NULL DEFAULT 'fixed',
  pay_amount numeric NOT NULL DEFAULT 0,
  workers_needed integer NOT NULL DEFAULT 1,
  city text NOT NULL DEFAULT '',
  region text NOT NULL DEFAULT '',
  location_notes text,
  age_min integer NOT NULL DEFAULT 13,
  age_max integer NOT NULL DEFAULT 17,
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.team_hustle_members (
  hustle_id uuid NOT NULL,
  user_id uuid NOT NULL,
  PRIMARY KEY (hustle_id, user_id)
);
-- Reproduce the production pre-migration ACL state, including explicit column grants.
GRANT SELECT ON public.team_hustles TO authenticated;
GRANT SELECT (
  id, poster_id, title, description, category, pay_type, pay_amount,
  workers_needed, city, region, location_notes, age_min, age_max,
  status, created_at, updated_at
) ON public.team_hustles TO authenticated;
GRANT SELECT ON public.team_hustles TO service_role;
-- Supabase production has no anon SELECT on this table; normalize local default ACLs.
REVOKE ALL ON public.team_hustles FROM anon;
REVOKE SELECT (
  id, poster_id, title, description, category, pay_type, pay_amount,
  workers_needed, city, region, location_notes, age_min, age_max,
  status, created_at, updated_at
) ON public.team_hustles FROM anon;
"@
$sql = @"
BEGIN;
$fixtureSchema
$migration
$testSql
ROLLBACK;
"@

$output = $sql | & docker exec -i $ContainerName psql -U postgres -d postgres -v ON_ERROR_STOP=1 2>&1
$psqlExitCode = $LASTEXITCODE
$output | Write-Output
if ($psqlExitCode -ne 0 -or ($output -join "`n") -match '(?m)^\s*ERROR:') {
  throw "Team-hustle location-note privacy regression failed (psql exit $psqlExitCode)."
}

$after = (& docker exec $ContainerName psql -U postgres -d postgres -Atc $baselineQuery | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $after -ne $before) {
  throw "Rollback did not preserve the disposable baseline. Before: $before; after: $after"
}

Write-Host '[qa-team-hustle-location-notes-privacy] PASS: table/column ACLs, listing RPC, unrelated viewer, poster, moderator, and rollback verified.' -ForegroundColor Green
