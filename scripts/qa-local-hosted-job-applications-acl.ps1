param(
  [string]$Container = 'supabase_db_mort-proposals-local-20261102'
)

$ErrorActionPreference = 'Stop'

if ($Container -cne 'supabase_db_mort-proposals-local-20261102') {
  throw 'Refusing non-approved container. This bootstrap is only for the disposable local production-baseline container.'
}

$preflight = @'
DO $guard$
DECLARE
  migration_count integer;
  minimum_version text;
  maximum_version text;
BEGIN
  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'refusing database %', current_database();
  END IF;
  SELECT count(*)::integer, min(version), max(version)
    INTO migration_count, minimum_version, maximum_version
  FROM supabase_migrations.schema_migrations;
  IF migration_count <> 73
     OR minimum_version <> '20261026194801'
     OR maximum_version <> '20261102113314' THEN
    RAISE EXCEPTION 'unexpected production baseline: count %, range %..%',
      migration_count, minimum_version, maximum_version;
  END IF;
  IF has_table_privilege('anon', 'public.job_applications', 'SELECT')
     OR has_table_privilege('anon', 'public.job_applications', 'INSERT')
     OR has_table_privilege('anon', 'public.job_applications', 'UPDATE')
     OR has_table_privilege('anon', 'public.job_applications', 'DELETE')
     OR has_table_privilege('anon', 'public.job_applications', 'TRUNCATE')
     OR has_table_privilege('anon', 'public.job_applications', 'REFERENCES')
     OR has_table_privilege('anon', 'public.job_applications', 'TRIGGER')
     OR has_any_column_privilege('anon', 'public.job_applications', 'SELECT')
     OR has_any_column_privilege('anon', 'public.job_applications', 'INSERT')
     OR has_any_column_privilege('anon', 'public.job_applications', 'UPDATE')
     OR has_any_column_privilege('anon', 'public.job_applications', 'REFERENCES')
     OR has_table_privilege('authenticated', 'public.job_applications', 'SELECT')
     OR has_table_privilege('authenticated', 'public.job_applications', 'INSERT')
     OR has_table_privilege('authenticated', 'public.job_applications', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.job_applications', 'DELETE')
     OR has_table_privilege('authenticated', 'public.job_applications', 'TRUNCATE')
     OR has_table_privilege('authenticated', 'public.job_applications', 'REFERENCES')
     OR has_table_privilege('authenticated', 'public.job_applications', 'TRIGGER')
     OR has_any_column_privilege('authenticated', 'public.job_applications', 'SELECT')
     OR has_any_column_privilege('authenticated', 'public.job_applications', 'INSERT')
     OR has_any_column_privilege('authenticated', 'public.job_applications', 'UPDATE')
     OR has_any_column_privilege('authenticated', 'public.job_applications', 'REFERENCES') THEN
    RAISE EXCEPTION 'refusing because anon/authenticated already have table or column privileges';
  END IF;
END
$guard$;
GRANT ALL PRIVILEGES ON TABLE public.job_applications TO service_role;
DO $verify$
BEGIN
  IF NOT has_table_privilege('service_role', 'public.job_applications', 'SELECT') THEN
    RAISE EXCEPTION 'service_role SELECT grant missing after bootstrap';
  END IF;
  IF NOT has_table_privilege('service_role', 'public.job_applications', 'INSERT')
     OR NOT has_table_privilege('service_role', 'public.job_applications', 'UPDATE')
     OR NOT has_table_privilege('service_role', 'public.job_applications', 'DELETE')
     OR NOT has_table_privilege('service_role', 'public.job_applications', 'TRUNCATE')
     OR NOT has_table_privilege('service_role', 'public.job_applications', 'REFERENCES')
     OR NOT has_table_privilege('service_role', 'public.job_applications', 'TRIGGER') THEN
    RAISE EXCEPTION 'service_role hosted table ACL is incomplete';
  END IF;
  IF has_table_privilege('anon', 'public.job_applications', 'SELECT')
     OR has_table_privilege('anon', 'public.job_applications', 'INSERT')
     OR has_table_privilege('anon', 'public.job_applications', 'UPDATE')
     OR has_table_privilege('anon', 'public.job_applications', 'DELETE')
     OR has_table_privilege('anon', 'public.job_applications', 'TRUNCATE')
     OR has_table_privilege('anon', 'public.job_applications', 'REFERENCES')
     OR has_table_privilege('anon', 'public.job_applications', 'TRIGGER')
     OR has_any_column_privilege('anon', 'public.job_applications', 'SELECT')
     OR has_any_column_privilege('anon', 'public.job_applications', 'INSERT')
     OR has_any_column_privilege('anon', 'public.job_applications', 'UPDATE')
     OR has_any_column_privilege('anon', 'public.job_applications', 'REFERENCES')
     OR has_table_privilege('authenticated', 'public.job_applications', 'SELECT')
     OR has_table_privilege('authenticated', 'public.job_applications', 'INSERT')
     OR has_table_privilege('authenticated', 'public.job_applications', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.job_applications', 'DELETE')
     OR has_table_privilege('authenticated', 'public.job_applications', 'TRUNCATE')
     OR has_table_privilege('authenticated', 'public.job_applications', 'REFERENCES')
     OR has_table_privilege('authenticated', 'public.job_applications', 'TRIGGER')
     OR has_any_column_privilege('authenticated', 'public.job_applications', 'SELECT')
     OR has_any_column_privilege('authenticated', 'public.job_applications', 'INSERT')
     OR has_any_column_privilege('authenticated', 'public.job_applications', 'UPDATE')
     OR has_any_column_privilege('authenticated', 'public.job_applications', 'REFERENCES') THEN
    RAISE EXCEPTION 'unexpected API-role table or column privileges after bootstrap';
  END IF;
END
$verify$;
'@

$preflight | docker exec -i $Container psql -U postgres -d postgres -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) {
  throw "Local ACL bootstrap failed with exit code $LASTEXITCODE"
}

$verification = @'
SELECT 'migration_count=' || count(*) || ';first=' || min(version) || ';last=' || max(version)
FROM supabase_migrations.schema_migrations;
SELECT rolname || ':table_select=' || has_table_privilege(rolname, 'public.job_applications', 'SELECT')
  || ';column_select=' || has_any_column_privilege(rolname, 'public.job_applications', 'SELECT')
FROM pg_roles
WHERE rolname IN ('anon', 'authenticated', 'service_role')
ORDER BY rolname;
'@
$verification | docker exec -i $Container psql -U postgres -d postgres -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) {
  throw "Local ACL verification failed with exit code $LASTEXITCODE"
}
