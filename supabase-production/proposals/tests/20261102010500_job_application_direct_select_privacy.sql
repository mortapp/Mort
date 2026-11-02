-- Run only in an isolated PostgreSQL 17 clone after applying the proposal.
begin;
select plan(5);

select ok(
  not has_table_privilege('authenticated','public.job_applications','SELECT'),
  'authenticated clients cannot directly select application rows'
);
select ok(
  not has_column_privilege('authenticated','public.job_applications','guardian_id','SELECT'),
  'Guardian identifiers are not directly selectable by posters'
);
select ok(
  has_function_privilege('authenticated','public.get_my_job_applications(uuid)','EXECUTE'),
  'the scoped application reader RPC remains available'
);
select ok(
  (select prosecdef from pg_proc where oid='public.get_my_job_applications(uuid)'::regprocedure),
  'the scoped reader remains SECURITY DEFINER'
);
select ok(
  has_table_privilege('service_role','public.job_applications','SELECT'),
  'the server-side service role retains its required access'
);

select * from finish();
rollback;
