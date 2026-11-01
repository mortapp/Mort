-- Run after applying jobs_exact_address_privilege_reconciliation.sql in a
-- disposable production-equivalent database. No production execution.
begin;
select plan(5);
select ok(not has_table_privilege('authenticated', 'public.jobs', 'INSERT'),
  'authenticated clients cannot directly insert public job rows');
select ok(not has_column_privilege('authenticated', 'public.jobs', 'exact_address', 'INSERT'),
  'authenticated clients cannot submit exact addresses in direct inserts');
select ok(not has_column_privilege('authenticated', 'public.jobs', 'exact_address', 'UPDATE'),
  'authenticated clients cannot change exact addresses directly');
select ok(has_function_privilege('authenticated',
  'public.save_job_draft_or_publish(uuid,uuid,jsonb,boolean)', 'EXECUTE'),
  'authorized website and mobile job creation RPC remains executable');
select ok((select prosecdef from pg_proc
  where oid='public.save_job_draft_or_publish(uuid,uuid,jsonb,boolean)'::regprocedure),
  'authorized job creation continues through a security-definer server contract');
select * from finish();
rollback;
