-- Keep the exposed RPCs SECURITY INVOKER. The private implementation owns
-- the narrow write path and independently validates auth.uid() and party role.

create index job_safety_agreements_adult_id_idx
  on public.job_safety_agreements(adult_id);
create index job_safety_agreements_job_id_idx
  on public.job_safety_agreements(job_id);
create index job_safety_plans_adult_id_idx
  on public.job_safety_plans(adult_id);
create index job_safety_plans_teen_id_idx
  on public.job_safety_plans(teen_id);

create or replace function private.save_job_safety_plan_internal(
  p_application_id uuid,
  p_expected_people text,
  p_public_or_visible_meeting boolean,
  p_daylight_preferred boolean,
  p_transportation_plan text,
  p_checkin_cadence_minutes integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_plan public.job_safety_plans%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_user uuid := auth.uid();
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if not private.is_job_safety_participant(p_application_id, v_user) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if not exists (
    select 1
    from public.job_applications application
    join public.job_assignments assignment
      on assignment.application_id = application.id
     and assignment.job_id = application.job_id
    where application.id = p_application_id
      and application.status = 'accepted'::public.mort_application_status
      and assignment.status = 'accepted'
  ) then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;
  if char_length(coalesce(p_expected_people, '')) > 500
     or char_length(coalesce(p_transportation_plan, '')) > 1000
     or p_checkin_cadence_minutes is null
     or p_checkin_cadence_minutes not between 15 and 240
     or p_public_or_visible_meeting is null
     or p_daylight_preferred is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_safety_plan');
  end if;

  update public.job_safety_plans
  set expected_people = nullif(left(btrim(coalesce(p_expected_people, '')), 500), ''),
      public_or_visible_meeting = p_public_or_visible_meeting,
      daylight_preferred = p_daylight_preferred,
      transportation_plan = nullif(left(btrim(coalesce(p_transportation_plan, '')), 1000), ''),
      checkin_cadence_minutes = p_checkin_cadence_minutes,
      teen_updated_at = case when teen_id = v_user then now() else teen_updated_at end,
      adult_updated_at = case when adult_id = v_user then now() else adult_updated_at end,
      updated_at = now()
  where application_id = p_application_id
  returning * into v_plan;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_not_found');
  end if;

  perform private.refresh_job_safety_agreement(p_application_id);
  select * into v_agreement from public.job_safety_agreements
  where application_id = p_application_id;

  return jsonb_build_object(
    'ok', true,
    'plan', to_jsonb(v_plan),
    'agreement_version', v_agreement.agreement_version,
    'agreement_status', v_agreement.status
  );
end;
$function$;

create or replace function private.confirm_job_safety_agreement_internal(
  p_application_id uuid,
  p_agreement_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_agreement public.job_safety_agreements%rowtype;
  v_terms jsonb;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if not private.is_job_safety_participant(p_application_id, v_user) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if not exists (
    select 1
    from public.job_applications application
    join public.job_assignments assignment
      on assignment.application_id = application.id
     and assignment.job_id = application.job_id
    where application.id = p_application_id
      and application.status = 'accepted'::public.mort_application_status
      and assignment.status = 'accepted'
  ) then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;

  select * into v_agreement
  from public.job_safety_agreements
  where application_id = p_application_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_not_found');
  end if;
  if p_agreement_version is null
     or p_agreement_version <> v_agreement.agreement_version then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_version_changed');
  end if;

  v_terms := private.job_safety_terms(p_application_id);
  if v_terms is null
     or v_agreement.material_terms_hash <>
       encode(extensions.digest(v_agreement.terms_snapshot::text, 'sha256'), 'hex')
     or v_agreement.material_terms_hash <>
       encode(extensions.digest(v_terms::text, 'sha256'), 'hex') then
    perform private.refresh_job_safety_agreement(p_application_id);
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_version_changed');
  end if;

  if not exists (
    select 1 from public.job_safety_plans plan
    where plan.application_id = p_application_id
      and plan.checkin_cadence_minutes between 15 and 240
      and (plan.expected_people is not null or exists (
        select 1 from public.jobs job
        where job.id = plan.job_id and job.remote_allowed
      ))
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_required');
  end if;

  update public.job_safety_agreements
  set teen_confirmed_at = case when teen_id = v_user then coalesce(teen_confirmed_at, now()) else teen_confirmed_at end,
      adult_confirmed_at = case when adult_id = v_user then coalesce(adult_confirmed_at, now()) else adult_confirmed_at end,
      teen_confirmed_version = case when teen_id = v_user then agreement_version else teen_confirmed_version end,
      adult_confirmed_version = case when adult_id = v_user then agreement_version else adult_confirmed_version end,
      updated_at = now()
  where application_id = p_application_id
  returning * into v_agreement;

  update public.job_safety_agreements
  set status = case
    when teen_confirmed_version = agreement_version
      and adult_confirmed_version = agreement_version then 'confirmed'
    when teen_confirmed_version = agreement_version then 'awaiting_adult'
    when adult_confirmed_version = agreement_version then 'awaiting_teen'
    else 'awaiting_both'
  end,
  updated_at = now()
  where application_id = p_application_id
  returning * into v_agreement;

  return jsonb_build_object(
    'ok', true,
    'status', v_agreement.status,
    'agreement_version', v_agreement.agreement_version,
    'both_confirmed', v_agreement.status = 'confirmed'
  );
end;
$function$;

revoke all on function private.save_job_safety_plan_internal(uuid, text, boolean, boolean, text, integer)
  from public, anon;
revoke all on function private.confirm_job_safety_agreement_internal(uuid, integer)
  from public, anon;
grant execute on function private.save_job_safety_plan_internal(uuid, text, boolean, boolean, text, integer)
  to authenticated;
grant execute on function private.confirm_job_safety_agreement_internal(uuid, integer)
  to authenticated;

create or replace function public.save_job_safety_plan(
  p_application_id uuid,
  p_expected_people text,
  p_public_or_visible_meeting boolean,
  p_daylight_preferred boolean,
  p_transportation_plan text,
  p_checkin_cadence_minutes integer
)
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
  select private.save_job_safety_plan_internal(
    p_application_id,
    p_expected_people,
    p_public_or_visible_meeting,
    p_daylight_preferred,
    p_transportation_plan,
    p_checkin_cadence_minutes
  );
$function$;

create or replace function public.confirm_job_safety_agreement(
  p_application_id uuid,
  p_agreement_version integer
)
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
  select private.confirm_job_safety_agreement_internal(
    p_application_id,
    p_agreement_version
  );
$function$;

revoke all on function public.save_job_safety_plan(uuid, text, boolean, boolean, text, integer)
  from public, anon;
revoke all on function public.confirm_job_safety_agreement(uuid, integer)
  from public, anon;
grant execute on function public.save_job_safety_plan(uuid, text, boolean, boolean, text, integer)
  to authenticated;
grant execute on function public.confirm_job_safety_agreement(uuid, integer)
  to authenticated;
