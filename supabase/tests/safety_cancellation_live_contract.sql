-- Run after the current job safety cancellation migration. This test avoids
-- production rows and verifies the exposed RPC contract and access boundary.
do $$
declare
  v_public_function oid := to_regprocedure(
    'public.submit_safety_cancellation(uuid,text,text)'
  );
  v_private_function oid := to_regprocedure(
    'private.submit_safety_cancellation_internal(uuid,text,text)'
  );
begin
  if v_public_function is null then
    raise exception 'submit_safety_cancellation(uuid,text,text) is missing';
  end if;
  if v_private_function is null then
    raise exception 'private cancellation implementation is missing';
  end if;
  if (select prosecdef from pg_catalog.pg_proc where oid = v_public_function) then
    raise exception 'public RPC must preserve caller privileges';
  end if;
  if not (select prosecdef from pg_catalog.pg_proc where oid = v_private_function) then
    raise exception 'private cancellation implementation must use its narrow write path';
  end if;
  if pg_catalog.has_function_privilege('anon', v_public_function, 'EXECUTE') then
    raise exception 'anon must not execute submit_safety_cancellation';
  end if;
  if not pg_catalog.has_function_privilege('authenticated', v_public_function, 'EXECUTE') then
    raise exception 'authenticated must execute submit_safety_cancellation';
  end if;
  if pg_catalog.has_function_privilege('anon', v_private_function, 'EXECUTE') then
    raise exception 'anon must not execute the private implementation';
  end if;
  if not pg_catalog.has_function_privilege('authenticated', v_private_function, 'EXECUTE') then
    raise exception 'authenticated must execute the private implementation through its wrapper';
  end if;
  if pg_catalog.pg_get_functiondef(v_private_function)
       not like '%private.is_job_safety_participant%'
     or pg_catalog.pg_get_functiondef(v_private_function)
       not like '%private.is_active_user%' then
    raise exception 'private implementation must check active participant authorization';
  end if;
  if not (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.job_safety_cancellations'::regclass
  ) then
    raise exception 'RLS is not enabled on job_safety_cancellations';
  end if;
  if pg_catalog.has_table_privilege('anon', 'public.job_safety_cancellations', 'SELECT')
     or pg_catalog.has_table_privilege('authenticated', 'public.job_safety_cancellations', 'SELECT')
     or pg_catalog.has_table_privilege('authenticated', 'public.job_safety_cancellations', 'INSERT')
     or pg_catalog.has_table_privilege('authenticated', 'public.job_safety_cancellations', 'UPDATE')
     or pg_catalog.has_table_privilege('authenticated', 'public.job_safety_cancellations', 'DELETE') then
    raise exception 'safety cancellation audit table must not be directly accessible to clients';
  end if;
end;
$$;

begin;
set local role authenticated;
select set_config('request.jwt.claims', '{}', true);
do $$
declare
  v_result jsonb;
begin
  v_result := public.submit_safety_cancellation(
    'ffffffff-ffff-ffff-ffff-ffffffffffff', 'unsafe_condition',
    'Test cancellation with no authenticated session.'
  );
  if v_result->>'code' <> 'active_account_required' then
    raise exception 'unauthenticated cancellation was not rejected: %', v_result;
  end if;
end;
$$;
rollback;

select 'Current-model safety cancellation contract passed' as result;
