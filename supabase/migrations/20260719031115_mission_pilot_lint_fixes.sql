create or replace function public.get_closed_pilot_eligibility(
  p_action text default 'browse',
  p_job_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_policy private.pilot_policy_versions%rowtype;
  v_enrollment public.pilot_enrollments%rowtype;
  v_email_confirmed boolean := false;
  v_phone_confirmed boolean := false;
  v_missing jsonb := '[]'::jsonb;
  v_reasons jsonb := '[]'::jsonb;
  v_required_acknowledgements text[] := array[]::text[];
  v_allowed boolean := false;
  v_job_eligible boolean := true;
begin
  if p_action not in (
    'browse', 'publish_job', 'apply', 'message', 'start_job',
    'submit_proof', 'complete_job', 'manage_support_circle',
    'manage_independence_plan'
  ) then
    return jsonb_build_object(
      'allowed', false,
      'code', 'unsupported_action',
      'guardian_mode_optional', true,
      'permanent_address_required', false
    );
  end if;

  if v_user_id is null then
    return jsonb_build_object(
      'allowed', false,
      'code', 'authentication_required',
      'guardian_mode_optional', true,
      'permanent_address_required', false
    );
  end if;

  select * into v_profile
  from public.profiles profile
  where profile.id = v_user_id;
  select * into v_policy from private.current_pilot_policy();

  if v_profile.id is null or v_profile.account_status <> 'active'
     or (v_profile.blocked_until is not null and v_profile.blocked_until > now()) then
    v_missing := v_missing || jsonb_build_array('active_account');
    v_reasons := v_reasons || jsonb_build_array('account_restricted');
  end if;

  select user_record.email_confirmed_at is not null,
         user_record.phone_confirmed_at is not null
  into v_email_confirmed, v_phone_confirmed
  from auth.users user_record
  where user_record.id = v_user_id;

  if not v_email_confirmed then
    v_missing := v_missing || jsonb_build_array('confirmed_email');
    v_reasons := v_reasons || jsonb_build_array('email_not_confirmed');
  end if;

  select * into v_enrollment
  from public.pilot_enrollments enrollment
  where enrollment.user_id = v_user_id
    and enrollment.status = 'approved'
    and enrollment.revoked_at is null
    and enrollment.expires_at > now()
  order by enrollment.approved_at desc
  limit 1;

  if v_enrollment.id is null
     or not private.user_has_active_pilot_enrollment(v_user_id) then
    v_missing := v_missing || jsonb_build_array('approved_partner_supported_pilot_enrollment');
    v_reasons := v_reasons || jsonb_build_array('closed_pilot_enrollment_required');
  end if;

  if v_profile.role = 'teen' then
    v_required_acknowledgements := array['teen_safety_training', 'pilot_rules', 'explicit_consent'];
  elsif v_profile.role in ('adult', 'admin') then
    v_required_acknowledgements := array[
      'adult_safety_training', 'prohibited_work', 'payment_scope',
      'incident_policy', 'pilot_rules'
    ];
    if not v_phone_confirmed then
      v_missing := v_missing || jsonb_build_array('confirmed_phone');
      v_reasons := v_reasons || jsonb_build_array('adult_phone_not_confirmed');
    end if;
  end if;

  if exists (
    select 1
    from unnest(v_required_acknowledgements) required_acknowledgement
    where not exists (
      select 1
      from public.pilot_participant_acknowledgements acknowledgement
      where acknowledgement.user_id = v_user_id
        and acknowledgement.acknowledgement_type = required_acknowledgement
        and acknowledgement.policy_version = v_policy.version
        and acknowledgement.revoked_at is null
    )
  ) then
    v_missing := v_missing || jsonb_build_array('current_pilot_training_and_acknowledgements');
    v_reasons := v_reasons || jsonb_build_array('pilot_training_incomplete');
  end if;

  if p_job_id is not null then
    select exists (
      select 1 from public.jobs job
      where job.id = p_job_id
        and job.status = 'open'
        and job.applications_open
        and job.pilot_review_status = 'eligible'
    ) into v_job_eligible;
    if not v_job_eligible then
      v_missing := v_missing || jsonb_build_array('pilot_eligible_job');
      v_reasons := v_reasons || jsonb_build_array('job_not_pilot_eligible');
    end if;
  end if;

  if not v_policy.pilot_mode_enabled then
    v_missing := v_missing || jsonb_build_array('active_closed_pilot_policy');
    v_reasons := v_reasons || jsonb_build_array('pilot_disabled');
  end if;

  v_allowed := jsonb_array_length(v_missing) = 0
    and v_policy.pilot_mode_enabled
    and not v_policy.unrestricted_public_access_enabled;

  return jsonb_build_object(
    'allowed', v_allowed,
    'action', p_action,
    'code', case when v_allowed then 'closed_pilot_eligible' else 'closed_pilot_requirements_missing' end,
    'missing_requirements', v_missing,
    'reason_codes', v_reasons,
    'policy_version', v_policy.version,
    'pilot_mode_enabled', v_policy.pilot_mode_enabled,
    'unrestricted_public_access_enabled', false,
    'real_document_collection_enabled', false,
    'guardian_mode_optional', true,
    'guardian_connection_required', false,
    'permanent_address_required', false,
    'housing_status_collected', false,
    'support_circle_affects_eligibility', false
  );
end;
$$;

create or replace function private.user_meets_closed_pilot_requirements(p_user_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_policy private.pilot_policy_versions%rowtype;
  v_email_confirmed boolean := false;
  v_phone_confirmed boolean := false;
  v_required text[] := array[]::text[];
begin
  select * into v_profile
  from public.profiles profile
  where profile.id = p_user_id;
  if v_profile.id is null
     or v_profile.account_status <> 'active'
     or (v_profile.blocked_until is not null and v_profile.blocked_until > now()) then
    return false;
  end if;
  if v_profile.is_test_account then
    return true;
  end if;
  if not private.user_has_active_pilot_enrollment(p_user_id) then
    return false;
  end if;
  select user_record.email_confirmed_at is not null,
         user_record.phone_confirmed_at is not null
  into v_email_confirmed, v_phone_confirmed
  from auth.users user_record
  where user_record.id = p_user_id;
  if not v_email_confirmed then
    return false;
  end if;
  select * into v_policy from private.current_pilot_policy();
  if v_profile.role = 'teen' then
    v_required := array['teen_safety_training', 'pilot_rules', 'explicit_consent'];
  elsif v_profile.role in ('adult', 'admin') then
    if not v_phone_confirmed then
      return false;
    end if;
    v_required := array[
      'adult_safety_training', 'prohibited_work', 'payment_scope',
      'incident_policy', 'pilot_rules'
    ];
  else
    return false;
  end if;
  return not exists (
    select 1
    from unnest(v_required) required_acknowledgement
    where not exists (
      select 1
      from public.pilot_participant_acknowledgements acknowledgement
      where acknowledgement.user_id = p_user_id
        and acknowledgement.acknowledgement_type = required_acknowledgement
        and acknowledgement.policy_version = v_policy.version
        and acknowledgement.revoked_at is null
    )
  );
end;
$$;

revoke all on function private.user_meets_closed_pilot_requirements(uuid)
from public, anon, authenticated;
