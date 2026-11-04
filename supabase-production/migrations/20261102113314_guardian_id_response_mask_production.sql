do $migration$
declare
  v_def text;
  v_old text := $old$'guardian_id',ja.guardian_id,$old$;
  v_new text := $new$'guardian_id',case
  when ja.applicant_id=v_user or exists(
    select 1
    from public.guardian_links gl
    join public.profiles guardian_profile on guardian_profile.id=gl.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id=gl.guardian_user_id
    where gl.teen_user_id=ja.applicant_id
      and gl.guardian_user_id=v_user
      and gl.status='active'
      and gl.teen_consent_at is not null
      and gl.guardian_consent_at is not null
      and guardian_profile.role='guardian'::public.mort_role
      and guardian_profile.account_status='active'
      and guardian_profile.date_of_birth is not null
      and extract(year from age(current_date,guardian_profile.date_of_birth))>=18
      and guardian_auth.email_confirmed_at is not null
  ) then ja.guardian_id
  else null
end,$new$;
begin
  if to_regprocedure('public.get_my_job_applications(uuid)') is null then
    raise exception 'guardian_id_privacy_missing_rpc';
  end if;

  if not has_function_privilege('authenticated','public.get_my_job_applications(uuid)','EXECUTE') then
    raise exception 'guardian_id_privacy_authenticated_execute_grant_missing';
  end if;

  select pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure)
    into v_def;

  if length(v_def)-length(replace(v_def,v_old,'')) <> length(v_old) then
    raise exception 'guardian_id_privacy_expected_exactly_one_unmasked_field';
  end if;

  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end;
$migration$;