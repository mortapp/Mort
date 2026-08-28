-- RLS helper execution and adult closed-pilot publishing requirements.
-- These helpers return booleans only and remain outside the exposed Data API
-- schema. Authenticated execution is required when RLS evaluates them.

grant execute on function private.has_active_partner_permission(uuid, uuid, text),
  private.user_has_active_pilot_enrollment(uuid),
  private.is_sandbox_pilot_user(uuid)
to authenticated;

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
  v_required text[] := '{}';
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

create or replace function private.enforce_pilot_poster_requirements()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_setting('mort.pilot_human_review', true) = 'true' then
    return new;
  end if;
  if new.status = 'open'
     and not private.user_meets_closed_pilot_requirements(new.poster_id) then
    new.status := 'pending_review';
    new.applications_open := false;
    new.pilot_review_status := 'manual_review_required';
    if not ('poster_contact_training_or_enrollment_incomplete' = any(new.pilot_restriction_reasons)) then
      new.pilot_restriction_reasons := array_append(
        new.pilot_restriction_reasons,
        'poster_contact_training_or_enrollment_incomplete'
      );
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_pilot_poster_requirements()
from public, anon, authenticated;

create trigger jobs_closed_pilot_poster_requirements
before insert or update of status, applications_open, poster_id
on public.jobs
for each row execute function private.enforce_pilot_poster_requirements();
