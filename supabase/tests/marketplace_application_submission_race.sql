-- Run only after applying the proposal on an exact production migration clone.
-- The two-session stale-state and accept/retry scenarios are documented in the
-- backend contract diff; this catalog suite alone does not prove concurrency.
begin;
select plan(10);

select has_function('public', 'submit_job_application',
  array['uuid', 'text', 'boolean', 'uuid[]']);
select has_function('public', 'mort_submit_job_application', array['uuid', 'text']);
select ok(has_function_privilege('authenticated',
  'public.submit_job_application(uuid,text,boolean,uuid[])', 'EXECUTE'),
  'authenticated client keeps the existing submission RPC');
select ok(not has_function_privilege('authenticated',
  'public.mort_submit_job_application(uuid,text)', 'EXECUTE'),
  'internal insert routine remains unavailable to authenticated clients');
select ok(exists (
  select 1 from pg_catalog.pg_index index_row
  join pg_catalog.pg_class index_class on index_class.oid = index_row.indexrelid
  join pg_catalog.pg_class table_class on table_class.oid = index_row.indrelid
  join pg_catalog.pg_namespace namespace_row on namespace_row.oid = table_class.relnamespace
  where namespace_row.nspname = 'public'
    and table_class.relname = 'job_applications'
    and index_row.indisunique
    and pg_catalog.pg_get_indexdef(index_class.oid) ilike '%(job_id, applicant_id)%'
), 'unique job/applicant key remains the idempotency boundary');
select ok(coalesce((public.get_runtime_feature_status()->>'new_job_publishing_disabled')::boolean, false),
  'new job publishing remains fail-closed during contract QA');

-- Guard against regression to transaction-start time after a lock wait. These
-- are structural assertions; they do not replace real two-session tests.
select ok(position('clock_timestamp()' in lower(pg_get_functiondef(
  'public.submit_job_application(uuid,text,boolean,uuid[])'::regprocedure
))) > 0, 'submission captures wall-clock time after acquiring locks');
select ok(position('expires_at > v_now' in lower(pg_get_functiondef(
  'public.submit_job_application(uuid,text,boolean,uuid[])'::regprocedure
))) > 0, 'verification expiry is rechecked against captured wall-clock time');
select ok(position('age(v_today, v_profile.date_of_birth)' in lower(pg_get_functiondef(
  'public.submit_job_application(uuid,text,boolean,uuid[])'::regprocedure
))) > 0, 'applicant age is recalculated using post-lock current date');
select ok(position('for share of gl, guardian_profile, guardian_auth' in lower(pg_get_functiondef(
  'public.submit_job_application(uuid,text,boolean,uuid[])'::regprocedure
))) > 0, 'qualifying Guardian relationship and account rows remain locked through insertion');

select * from finish();
rollback;
