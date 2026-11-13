-- Guardian setup and preference writes are teen-owned operations. Require an
-- active teen account; preference writes additionally require mutual consent.
create or replace function public.set_guardian_alert_preferences(
  p_link_id uuid,
  p_safety_ping_alerts boolean,
  p_job_checkin_alerts boolean,
  p_accepted_job_summary boolean,
  p_safety_warning_alerts boolean,
  p_weekly_digest boolean,
  p_optional_job_approval_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  user_id uuid := auth.uid();
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_link_id is null
    or p_safety_ping_alerts is null
    or p_job_checkin_alerts is null
    or p_accepted_job_summary is null
    or p_safety_warning_alerts is null
    or p_weekly_digest is null
    or p_optional_job_approval_enabled is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_preferences_required');
  end if;

  if not exists (
    select 1
    from public.guardian_links link
    where link.id = p_link_id
      and link.teen_user_id = user_id
      and link.status = 'active'
      and link.teen_consent_at is not null
      and link.guardian_consent_at is not null
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_guardian_link_not_found');
  end if;

  insert into public.guardian_preferences (
    link_id, safety_ping_alerts, job_checkin_alerts, accepted_job_summary,
    safety_warning_alerts, weekly_digest, optional_job_approval_enabled
  ) values (
    p_link_id, p_safety_ping_alerts, p_job_checkin_alerts, p_accepted_job_summary,
    p_safety_warning_alerts, p_weekly_digest, p_optional_job_approval_enabled
  )
  on conflict (link_id) do update set
    safety_ping_alerts = excluded.safety_ping_alerts,
    job_checkin_alerts = excluded.job_checkin_alerts,
    accepted_job_summary = excluded.accepted_job_summary,
    safety_warning_alerts = excluded.safety_warning_alerts,
    weekly_digest = excluded.weekly_digest,
    optional_job_approval_enabled = excluded.optional_job_approval_enabled,
    updated_at = now();

  return jsonb_build_object('ok', true, 'link_id', p_link_id);
end;
$function$;

create or replace function public.set_guardian_setup_skipped()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  user_id uuid := auth.uid();
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role
     or not private.is_active_user()
     or not exists (
       select 1
       from public.profiles p
       where p.id = user_id
         and p.date_of_birth is not null
         and extract(year from age(current_date, p.date_of_birth)) between 13 and 17
     ) then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;

  update public.guardian_links
  set status = 'revoked', updated_at = now()
  where teen_user_id = user_id and status = 'pending';

  update private.guardian_invite_codes
  set consumed_at = coalesce(consumed_at, now())
  where teen_user_id = user_id and consumed_at is null;

  update public.profiles
  set guardian_setup_status = 'skipped', updated_at = now()
  where id = user_id;

  return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('ok', true);
end;
$function$;
