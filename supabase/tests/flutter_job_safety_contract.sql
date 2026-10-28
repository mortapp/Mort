do $$
declare
  required_table text;
begin
  foreach required_table in array array[
    'job_safety_plans',
    'job_safety_agreements'
  ] loop
    if to_regclass(format('public.%I', required_table)) is null then
      raise exception 'missing public.% table', required_table;
    end if;
    if not (
      select relrowsecurity
      from pg_class
      where oid = to_regclass(format('public.%I', required_table))
    ) then
      raise exception 'RLS is not enabled on public.%', required_table;
    end if;
    if pg_catalog.has_table_privilege('anon', format('public.%I', required_table), 'SELECT')
       or pg_catalog.has_table_privilege('anon', format('public.%I', required_table), 'INSERT')
       or pg_catalog.has_table_privilege('anon', format('public.%I', required_table), 'UPDATE') then
      raise exception 'anon has access to public.%', required_table;
    end if;
    if pg_catalog.has_table_privilege('authenticated', format('public.%I', required_table), 'INSERT')
       or pg_catalog.has_table_privilege('authenticated', format('public.%I', required_table), 'UPDATE')
       or pg_catalog.has_table_privilege('authenticated', format('public.%I', required_table), 'DELETE') then
      raise exception 'authenticated can mutate public.% directly', required_table;
    end if;
  end loop;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'job_safety_agreements'
      and policyname = 'job_safety_agreement_participants_read'
      and cmd = 'SELECT'
      and roles = array['authenticated']::name[]
  ) then
    raise exception 'participant-only safety agreement read policy is missing';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'job_safety_plans'
      and policyname = 'job_safety_plan_participants_read'
      and cmd = 'SELECT'
      and roles = array['authenticated']::name[]
  ) then
    raise exception 'participant-only safety plan read policy is missing';
  end if;
  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.job_applications'::regclass
      and tgname = 'job_applications_create_safety_agreement'
      and not tgisinternal
      and tgenabled <> 'D'
  ) then
    raise exception 'accepted application safety-agreement trigger is missing or disabled';
  end if;
  if not pg_catalog.has_function_privilege(
    'authenticated',
    'public.save_job_safety_plan(uuid,text,boolean,boolean,text,integer)',
    'EXECUTE'
  ) or not pg_catalog.has_function_privilege(
    'authenticated',
    'public.confirm_job_safety_agreement(uuid,integer)',
    'EXECUTE'
  ) then
    raise exception 'authenticated safety-plan RPC grants are missing';
  end if;
  if pg_catalog.has_function_privilege(
    'anon',
    'public.save_job_safety_plan(uuid,text,boolean,boolean,text,integer)',
    'EXECUTE'
  ) or pg_catalog.has_function_privilege(
    'anon',
    'public.confirm_job_safety_agreement(uuid,integer)',
    'EXECUTE'
  ) then
    raise exception 'anon can execute a safety-plan RPC';
  end if;
  if exists (
    select 1
    from pg_proc procedure_row
    join pg_namespace schema_row on schema_row.oid = procedure_row.pronamespace
    where schema_row.nspname = 'public'
      and procedure_row.proname in (
        'save_job_safety_plan', 'confirm_job_safety_agreement'
      )
      and procedure_row.prosecdef
  ) then
    raise exception 'public safety RPCs must not run with caller-independent privileges';
  end if;
end;
$$;

select 'Flutter job safety database contract passed' as result;

begin;
set local role authenticated;
select set_config('request.jwt.claims', '{}', true);
do $$
declare
  v_result jsonb;
begin
  v_result := public.save_job_safety_plan(
    'ffffffff-ffff-ffff-ffff-ffffffffffff', null, true, true, null, 30
  );
  if v_result->>'code' <> 'active_account_required' then
    raise exception 'safety-plan RPC did not reject a missing auth user: %', v_result;
  end if;

  v_result := public.confirm_job_safety_agreement(
    'ffffffff-ffff-ffff-ffff-ffffffffffff', 1
  );
  if v_result->>'code' <> 'active_account_required' then
    raise exception 'safety-confirm RPC did not reject a missing auth user: %', v_result;
  end if;
end;
$$;
rollback;

select 'Flutter job safety unauthenticated RPC checks passed' as result;
