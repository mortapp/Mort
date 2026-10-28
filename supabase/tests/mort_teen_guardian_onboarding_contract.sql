-- Contract checks for onboarding against the new minimal MORT schema.
do $$
begin
  if not exists (
    select 1 from pg_enum e join pg_type t on t.oid=e.enumtypid
    join pg_namespace n on n.oid=t.typnamespace
    where n.nspname='public' and t.typname='mort_role' and e.enumlabel='guardian'
  ) then raise exception 'guardian_role_missing'; end if;
  if to_regprocedure('public.save_my_onboarding_account_v2(jsonb,uuid,integer)') is null then
    raise exception 'onboarding_account_rpc_missing'; end if;
  if to_regprocedure('public.save_my_onboarding_work_v2(jsonb,uuid,integer,text)') is null then
    raise exception 'onboarding_work_rpc_missing'; end if;
  if to_regprocedure('public.save_my_onboarding_safety_v2(jsonb,uuid,integer,text)') is null then
    raise exception 'onboarding_safety_rpc_missing'; end if;
  if to_regprocedure('public.create_guardian_invite_v2(text)') is null then
    raise exception 'guardian_invite_rpc_missing'; end if;
  if to_regprocedure('public.accept_guardian_invite(text)') is null then
    raise exception 'guardian_accept_rpc_missing'; end if;
  if to_regprocedure('public.set_guardian_setup_skipped()') is null then
    raise exception 'guardian_skip_rpc_missing'; end if;
  if to_regprocedure('public.cancel_guardian_invite(uuid)') is null then
    raise exception 'guardian_cancel_rpc_missing'; end if;
  if to_regprocedure('public.unlink_guardian(uuid)') is null then
    raise exception 'guardian_unlink_rpc_missing'; end if;
  if to_regclass('private.guardian_invite_codes') is null then
    raise exception 'private_guardian_invite_store_missing'; end if;
  if has_table_privilege('authenticated', 'private.guardian_invite_codes', 'SELECT') then
    raise exception 'guardian_invite_secret_exposed'; end if;
  if not has_function_privilege('authenticated', 'public.create_guardian_invite_v2(text)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.accept_guardian_invite(text)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.cancel_guardian_invite(uuid)', 'EXECUTE')
    or not has_function_privilege('authenticated', 'public.unlink_guardian(uuid)', 'EXECUTE') then
    raise exception 'guardian_onboarding_rpc_not_granted'; end if;
  if has_function_privilege('anon', 'public.cancel_guardian_invite(uuid)', 'EXECUTE')
    or has_function_privilege('anon', 'public.unlink_guardian(uuid)', 'EXECUTE') then
    raise exception 'anonymous_guardian_link_lifecycle_allowed'; end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='guardian_links' and column_name='revoked_by'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='guardian_links' and column_name='revoked_at'
  ) then raise exception 'guardian_revocation_audit_missing'; end if;
  if not exists (
    select 1 from pg_trigger where tgname='guardian_links_audit_revocation' and not tgisinternal
  ) then raise exception 'guardian_revocation_audit_trigger_missing'; end if;
  if position('pending' in pg_get_functiondef('public.save_my_onboarding_account_v2(jsonb,uuid,integer)'::regprocedure)) = 0 then
    raise exception 'self_reported_age_must_not_be_verified'; end if;
end;
$$;
