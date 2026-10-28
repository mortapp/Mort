-- Run after the current live-model execution status migration.
-- These checks are intentionally data-free and safe to run on the production DB.
do $$
declare
  v_function oid := to_regprocedure('public.get_job_execution_status(uuid)');
begin
  if v_function is null then
    raise exception 'get_job_execution_status(uuid) is missing';
  end if;
  if pg_catalog.has_function_privilege('anon', v_function, 'EXECUTE') then
    raise exception 'anon must not execute get_job_execution_status';
  end if;
  if not pg_catalog.has_function_privilege('authenticated', v_function, 'EXECUTE') then
    raise exception 'authenticated must execute get_job_execution_status';
  end if;
  if (select prosecdef from pg_catalog.pg_proc where oid = v_function) then
    raise exception 'get_job_execution_status must preserve caller RLS';
  end if;
end $$;
