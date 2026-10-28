-- Run after mort_job_execution_pins_live_model. No production user rows are read.
do $$
declare
  v_name text;
  v_oid oid;
  v_table oid := to_regclass('private.job_execution_sessions');
  v_required text[] := array[
    'public.generate_job_start_pin(uuid,uuid)',
    'public.confirm_job_start_pin_v2(uuid,text,boolean,uuid)',
    'public.generate_job_finish_pin(uuid,uuid)',
    'public.confirm_job_finish_pin_v2(uuid,text,uuid)',
    'public.get_job_execution_status(uuid)',
    'public.report_finish_pin_unavailable(uuid,timestamp with time zone,timestamp with time zone,text,text,uuid)',
    'public.request_adult_job_cancellation(uuid,text,uuid)',
    'public.report_possible_teen_abandonment(uuid,text,uuid)',
    'public.respond_to_teen_abandonment(uuid,text,boolean,uuid)'
  ];
begin
  foreach v_name in array v_required loop
    v_oid := to_regprocedure(v_name);
    if v_oid is null then
      raise exception 'required execution RPC is missing: %', v_name;
    end if;
    if (select prosecdef from pg_catalog.pg_proc where oid = v_oid) then
      raise exception 'public execution wrapper must preserve caller privileges: %', v_name;
    end if;
    if pg_catalog.has_function_privilege('anon', v_oid, 'EXECUTE') then
      raise exception 'anon can execute execution RPC: %', v_name;
    end if;
    if not pg_catalog.has_function_privilege('authenticated', v_oid, 'EXECUTE') then
      raise exception 'authenticated cannot execute execution RPC: %', v_name;
    end if;
  end loop;

  if v_table is null then
    raise exception 'private execution session table is missing';
  end if;
  if not (select relrowsecurity from pg_catalog.pg_class where oid = v_table) then
    raise exception 'execution session table must have RLS enabled';
  end if;

  if to_regclass('public.job_execution_review_responses') is null then
    raise exception 'participant-scoped review response table is missing';
  end if;
  if not (
    select relrowsecurity
      from pg_catalog.pg_class
     where oid = to_regclass('public.job_execution_review_responses')
  ) then
    raise exception 'review response table must have RLS enabled';
  end if;
  if pg_catalog.has_table_privilege('anon', 'public.job_execution_review_responses', 'SELECT')
     or pg_catalog.has_table_privilege('authenticated', 'public.job_execution_review_responses', 'INSERT')
     or pg_catalog.has_table_privilege('authenticated', 'public.job_execution_review_responses', 'UPDATE')
     or pg_catalog.has_table_privilege('authenticated', 'public.job_execution_review_responses', 'DELETE') then
    raise exception 'review response writes must use the checked RPC only';
  end if;
  if pg_catalog.has_table_privilege('anon', v_table, 'SELECT')
     or pg_catalog.has_table_privilege('authenticated', v_table, 'SELECT')
     or pg_catalog.has_table_privilege('authenticated', v_table, 'INSERT')
     or pg_catalog.has_table_privilege('authenticated', v_table, 'UPDATE') then
    raise exception 'execution sessions must not be directly accessible to clients';
  end if;

  foreach v_name in array array[
    'private.generate_job_start_pin_internal(uuid,uuid)',
    'private.confirm_job_start_pin_internal(uuid,text,boolean,uuid)',
    'private.generate_job_finish_pin_internal(uuid,uuid)',
    'private.confirm_job_finish_pin_internal(uuid,text,uuid)',
    'private.report_finish_pin_unavailable_internal(uuid,timestamptz,timestamptz,text,text,uuid)',
    'private.request_adult_job_cancellation_internal(uuid,text,uuid)',
    'private.report_possible_teen_abandonment_internal(uuid,text,uuid)',
    'private.respond_to_teen_abandonment_internal(uuid,text,boolean,uuid)'
  ] loop
    v_oid := to_regprocedure(v_name);
    if v_oid is null then
      raise exception 'private execution implementation is missing: %', v_name;
    end if;
    if not (select prosecdef from pg_catalog.pg_proc where oid = v_oid) then
      raise exception 'private execution implementation must use its narrow write path: %', v_name;
    end if;
    if pg_catalog.has_function_privilege('anon', v_oid, 'EXECUTE') then
      raise exception 'anon can execute private implementation: %', v_name;
    end if;
  end loop;
end;
$$;
