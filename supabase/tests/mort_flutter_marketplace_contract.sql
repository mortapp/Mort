-- Production contract for the Flutter marketplace's first server-backed loop.
do $$
declare
  listing_definition text;
  eligibility_definition text;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='jobs'
      and column_name='estimated_duration_minutes'
  ) then
    raise exception 'flutter_job_duration_column_missing';
  end if;
  if to_regprocedure('public.list_open_jobs_page(text,text,integer,text,text,text,boolean,text,text,text,text[],text,text,uuid,integer)') is null then
    raise exception 'flutter_job_listing_rpc_missing';
  end if;
  if to_regprocedure('public.get_job_application_eligibility(uuid)') is null then
    raise exception 'flutter_job_eligibility_rpc_missing';
  end if;
  if to_regprocedure('public.submit_job_application(uuid,text,boolean,uuid[])') is null then
    raise exception 'flutter_job_application_rpc_missing';
  end if;
  select pg_get_functiondef('public.list_open_jobs_page(text,text,integer,text,text,text,boolean,text,text,text,text[],text,text,uuid,integer)'::regprocedure)
    into listing_definition;
  if position('public_marketplace_enabled' in listing_definition) = 0
    or position('exact_address' in listing_definition) > 0 then
    raise exception 'flutter_listing_privacy_or_release_gate_missing';
  end if;
  select pg_get_functiondef('public.get_job_application_eligibility(uuid)'::regprocedure)
    into eligibility_definition;
  if position('public_marketplace_enabled' in eligibility_definition) = 0 then
    raise exception 'flutter_application_release_gate_missing';
  end if;
  if has_function_privilege('authenticated', 'public.mort_submit_job_application(uuid,text)', 'EXECUTE') then
    raise exception 'direct_job_application_bypasses_release_gate';
  end if;
  if not has_function_privilege('authenticated', 'public.submit_job_application(uuid,text,boolean,uuid[])', 'EXECUTE') then
    raise exception 'flutter_application_rpc_not_granted';
  end if;
end;
$$;
