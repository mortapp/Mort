-- MORT marketplace safety catalog/privilege assertions.
-- Run after applying the candidate migration to a disposable/local Supabase database.
do $$
declare v_count integer;
begin
  if to_regclass('private.job_locations') is null then raise exception 'missing private.job_locations'; end if;
  if to_regclass('private.user_location_origins') is null then raise exception 'missing private.user_location_origins'; end if;
  if to_regprocedure('public.get_job_private_location(uuid)') is null then raise exception 'missing private location RPC'; end if;
  if to_regprocedure('public.get_job_distance_bands(uuid[])') is null then raise exception 'missing distance RPC'; end if;
  if not exists (select 1 from pg_trigger where tgrelid='public.messages'::regclass
    and tgname='messages_enforce_block_contract' and not tgisinternal) then
    raise exception 'message block trigger missing';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid='public.user_blocks'::regclass
    and tgname='user_blocks_serialize_contract' and not tgisinternal) then
    raise exception 'block serialization trigger missing';
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.jobs'::regclass
    and conname='jobs_exact_address_must_be_private' and convalidated) then
    raise exception 'exact address privacy constraint missing or unvalidated';
  end if;
  if has_table_privilege('authenticated','private.job_locations','SELECT')
    or has_table_privilege('anon','private.job_locations','SELECT')
    or has_table_privilege('authenticated','private.user_location_origins','SELECT')
    or has_table_privilege('anon','private.user_location_origins','SELECT') then
    raise exception 'private location table grants are too broad';
  end if;
  if has_function_privilege('authenticated',
      'private.set_job_geocode_result(uuid,double precision,double precision,text)','EXECUTE')
    or has_function_privilege('anon',
      'private.set_job_geocode_result(uuid,double precision,double precision,text)','EXECUTE')
    or has_function_privilege('authenticated',
      'private.set_user_location_origin(uuid,double precision,double precision,text,timestamp with time zone,text)','EXECUTE')
    or has_function_privilege('anon',
      'private.set_user_location_origin(uuid,double precision,double precision,text,timestamp with time zone,text)','EXECUTE') then
    raise exception 'untrusted role can write geocoded coordinates';
  end if;
  if not has_function_privilege('authenticated','public.get_job_private_location(uuid)','EXECUTE')
    or not has_function_privilege('authenticated','public.get_job_distance_bands(uuid[])','EXECUTE') then
    raise exception 'authenticated RPC grants missing';
  end if;
  select count(*) into v_count from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in ('mort_submit_job_application','update_my_job_application_status')
    and p.prosecdef and 'search_path=""'=any(p.proconfig);
  if v_count <> 2 then raise exception 'application RPC security-definer/search_path contract failed'; end if;
  raise notice 'MORT marketplace safety catalog checks passed';
end $$;
