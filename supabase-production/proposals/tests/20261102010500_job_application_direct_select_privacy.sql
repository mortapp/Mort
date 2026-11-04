-- Run only in an isolated PostgreSQL 17 clone after applying the proposal.
-- Supabase ships pgTAP as an available extension; install it only in the test DB.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(5);

select extensions.ok(
  not has_table_privilege('authenticated','public.job_applications','SELECT'),
  'authenticated clients cannot directly select application rows'
);
select extensions.ok(
  not has_column_privilege('authenticated','public.job_applications','guardian_id','SELECT'),
  'Guardian identifiers are not directly selectable by posters'
);
select extensions.ok(
  has_function_privilege('authenticated','public.get_my_job_applications(uuid)','EXECUTE'),
  'the scoped application reader RPC remains available'
);
select extensions.ok(
  (select prosecdef from pg_proc where oid='public.get_my_job_applications(uuid)'::regprocedure),
  'the scoped reader remains SECURITY DEFINER'
);
select extensions.ok(
  has_table_privilege('service_role','public.job_applications','SELECT'),
  'the server-side service role retains its required access'
);

select * from extensions.finish();
rollback;
