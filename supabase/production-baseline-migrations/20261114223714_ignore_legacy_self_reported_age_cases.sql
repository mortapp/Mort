-- Do not let obsolete self_reported age rows block a real private evidence
-- submission or count against its rate limit. Preserve historical rows; only
-- trusted, explicitly enabled provider/type results can satisfy activation.
begin;

create or replace function private.mort_is_eligible_for_role_activation(
  p_user_id uuid,
  p_role public.mort_role
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select case p_role
    when 'teen'::public.mort_role then (
      exists (
        select 1
        from public.verification_cases vc
        join private.verification_provider_allowlist pa
          on pa.provider_key = vc.provider
         and pa.verification_type = vc.verification_type
         and pa.is_enabled
        where vc.user_id = p_user_id
          and vc.verification_type = 'age'
          and vc.status = 'verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at > now())
      )
      and exists (
        select 1
        from public.verification_cases vc
        join private.verification_provider_allowlist pa
          on pa.provider_key = vc.provider
         and pa.verification_type = vc.verification_type
         and pa.is_enabled
        where vc.user_id = p_user_id
          and vc.verification_type = 'school_id'
          and vc.status = 'verified'::public.mort_verification_status
          and (vc.expires_at is null or vc.expires_at > now())
      )
      and exists (
        select 1 from auth.users u
        where u.id = p_user_id
          and u.email_confirmed_at is not null
          and private.is_approved_school_email(u.email)
      )
    )
    when 'adult'::public.mort_role then exists (
      select 1
      from public.verification_cases vc
      join private.verification_provider_allowlist pa
        on pa.provider_key = vc.provider
       and pa.verification_type = vc.verification_type
       and pa.is_enabled
      where vc.user_id = p_user_id
        and vc.verification_type = 'identity'
        and vc.status = 'verified'::public.mort_verification_status
        and (vc.expires_at is null or vc.expires_at > now())
    )
    else false
  end;
$function$;
revoke all on function private.mort_is_eligible_for_role_activation(uuid,public.mort_role)
  from public, anon, authenticated;
grant execute on function private.mort_is_eligible_for_role_activation(uuid,public.mort_role)
  to service_role;

do $repair$
declare
  v_def text;
  v_old_duplicate text := $old$where vc.user_id = v_user and vc.verification_type = p_verification_type and vc.status in ('pending','needs_review')$old$;
  v_old_limit text := $old$where vc.user_id = v_user and vc.created_at > now() - interval '24 hours'$old$;
begin
  select pg_get_functiondef('public.submit_my_verification_evidence_v1(text,text)'::regprocedure)
    into v_def;

  if position(v_old_duplicate in v_def) > 0 then
    v_def := replace(v_def, v_old_duplicate,
      $new$where vc.user_id = v_user and vc.verification_type = p_verification_type and vc.status in ('pending','needs_review') and not (p_verification_type = 'age' and vc.provider = 'self_reported')$new$);
  elsif position('not (p_verification_type = ''age'' and vc.provider = ''self_reported'')' in v_def) = 0 then
    raise exception 'repair_source_mismatch:legacy_age_pending_guard';
  end if;

  if position(v_old_limit in v_def) > 0 then
    v_def := replace(v_def, v_old_limit,
      $new$where vc.user_id = v_user and vc.created_at > now() - interval '24 hours' and not (vc.verification_type = 'age' and vc.provider = 'self_reported')$new$);
  elsif position('not (vc.verification_type = ''age'' and vc.provider = ''self_reported'')' in v_def) = 0 then
    raise exception 'repair_source_mismatch:legacy_age_rate_limit';
  end if;

  execute v_def;
end;
$repair$;

commit;
