-- Issue #70: align Guardian application-row access with Guardian-ID disclosure.
-- This is an exact-source-guarded replacement against the production function
-- body. pg_get_functiondef and CREATE OR REPLACE preserve the existing owner,
-- EXECUTE ACL, SECURITY DEFINER mode, and empty search_path.
do $migration$
declare
  v_function_oid oid;
  v_function_definition text;
  v_old_account_gate text := $old_gate$if v_user is null or not private.is_active_user() then$old_gate$;
  v_new_account_gate text := $new_gate$if v_user is null or (
    not private.is_active_user()
    and not exists (
      select 1
      from public.profiles guardian_profile
      join auth.users guardian_auth on guardian_auth.id = guardian_profile.id
      where guardian_profile.id = v_user
        and guardian_profile.role = 'guardian'::public.mort_role
        and guardian_profile.account_status = 'active'
        and guardian_profile.date_of_birth is not null
        and extract(year from age(current_date, guardian_profile.date_of_birth)) >= 18
        and guardian_auth.email_confirmed_at is not null
    )
  ) then$new_gate$;
  v_old_guardian_scope text := $old_scope$exists(select 1 from public.guardian_links gl where gl.teen_user_id=ja.applicant_id and gl.guardian_user_id=v_user and gl.status='active' and gl.teen_consent_at is not null and gl.guardian_consent_at is not null)$old_scope$;
  v_new_guardian_scope text := $new_scope$exists (
    select 1
    from public.guardian_links gl
    join public.profiles guardian_profile on guardian_profile.id = gl.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id = gl.guardian_user_id
    where gl.teen_user_id = ja.applicant_id
      and gl.guardian_user_id = v_user
      and gl.status = 'active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
      and guardian_profile.role = 'guardian'::public.mort_role
      and guardian_profile.account_status = 'active'
      and guardian_profile.date_of_birth is not null
      and extract(year from age(current_date, guardian_profile.date_of_birth)) >= 18
      and guardian_auth.email_confirmed_at is not null
  )$new_scope$;
  v_source_count integer;
  v_is_security_definer boolean;
  v_function_config text[];
begin
  select p.oid, p.prosecdef, p.proconfig
  into v_function_oid, v_is_security_definer, v_function_config
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.oid = 'public.get_my_job_applications(uuid)'::regprocedure;

  if v_function_oid is null then
    raise exception 'Issue 70 migration stopped: expected public.get_my_job_applications(uuid) was not found';
  end if;
  if not v_is_security_definer or not ('search_path=""' = any(coalesce(v_function_config, array[]::text[]))) then
    raise exception 'Issue 70 migration stopped: function SECURITY DEFINER/search_path contract differs from the reviewed production definition';
  end if;

  v_function_definition := pg_catalog.pg_get_functiondef(v_function_oid);

  v_source_count := (
    length(v_function_definition) - length(replace(v_function_definition, v_old_account_gate, ''))
  ) / length(v_old_account_gate);
  if v_source_count <> 1 then
    raise exception 'Issue 70 migration stopped: expected one account-gate source anchor, found %', v_source_count;
  end if;

  v_source_count := (
    length(v_function_definition) - length(replace(v_function_definition, v_old_guardian_scope, ''))
  ) / length(v_old_guardian_scope);
  if v_source_count <> 1 then
    raise exception 'Issue 70 migration stopped: expected one Guardian row-scope source anchor, found %', v_source_count;
  end if;

  v_function_definition := replace(v_function_definition, v_old_account_gate, v_new_account_gate);
  v_function_definition := replace(v_function_definition, v_old_guardian_scope, v_new_guardian_scope);
  execute v_function_definition;
end;
$migration$;
