do $$
declare
  v_status jsonb;
  v_function regprocedure := to_regprocedure('public.get_release_mode_status()');
  v_is_security_definer boolean;
begin
  if v_function is null then
    raise exception 'RELEASE_MODE_RPC_MISSING';
  end if;
  if not has_function_privilege('anon', v_function, 'EXECUTE') then
    raise exception 'Anonymous clients cannot read the public release status';
  end if;
  select p.prosecdef into v_is_security_definer
  from pg_proc p where p.oid = v_function;
  if v_is_security_definer then
    raise exception 'The release status RPC must use invoker privileges';
  end if;
  if to_regclass('public.mort_release_control') is null then
    raise exception 'The public release status table is missing';
  end if;
  if not has_table_privilege('anon', 'public.mort_release_control', 'SELECT') then
    raise exception 'Anonymous clients cannot select the public status row';
  end if;
  if has_table_privilege('anon', 'public.mort_release_control', 'UPDATE') then
    raise exception 'Anonymous clients can modify release controls';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.mort_release_control'::regclass) then
    raise exception 'Row level security is not enabled for public release status';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='mort_release_control'
      and policyname='mort_release_control_public_status_read'
      and cmd='SELECT'
  ) then
    raise exception 'Public release status read policy is missing';
  end if;

  v_status := public.get_release_mode_status();
  if v_status ->> 'release_mode' <> 'production_public' then
    raise exception 'Release stage does not reflect the public production track';
  end if;
  if v_status -> 'maintenance_mode' <> 'false'::jsonb then
    raise exception 'Release status has an unexpected maintenance value';
  end if;
  if v_status -> 'public_marketplace_enabled' <> 'false'::jsonb then
    raise exception 'The public marketplace must remain disabled until its API is production-ready';
  end if;
  if v_status -> 'real_document_collection' <> 'false'::jsonb then
    raise exception 'Production identity collection must remain disabled until an approved provider is wired';
  end if;
end;
$$;
