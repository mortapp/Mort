begin;

create or replace function private.evaluate_closed_pilot_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_policy private.pilot_policy_versions%rowtype;
  v_profile public.profiles%rowtype;
  v_enrollment public.pilot_enrollments%rowtype;
  v_content text;
  v_reasons text[] := '{}';
  v_blocked boolean := false;
  v_manual boolean := false;
  v_allowed_locations text[] := array[
    'verified_business', 'school', 'nonprofit', 'community_center',
    'public_event', 'staffed_community_project',
    'visible_outdoor_community_space'
  ];
begin
  if current_setting('mort.pilot_human_review', true) = 'true' then
    return new;
  end if;
  select * into v_policy from private.current_pilot_policy();
  select * into v_profile from public.profiles profile where profile.id = new.poster_id;
  if new.pilot_location_class = 'unclassified' then
    new.pilot_location_class := case lower(coalesce(new.location_type, ''))
      when 'business' then 'verified_business' when 'verified_business' then 'verified_business'
      when 'school' then 'school' when 'nonprofit' then 'nonprofit'
      when 'community_center' then 'community_center' when 'public_event' then 'public_event'
      when 'public' then 'public_event' when 'staffed_community_project' then 'staffed_community_project'
      when 'visible_outdoor' then 'visible_outdoor_community_space'
      when 'private_residence' then 'private_residence' when 'hotel' then 'hotel'
      when 'isolated_property' then 'isolated_property' when 'unknown' then 'unknown_location'
      else 'unknown_location'
    end;
  end if;
  new.pilot_staffed_or_visible := new.pilot_staffed_or_visible
    or coalesce(new.adult_supervision_present, false)
    or coalesce(new.public_meeting_available, false)
    or new.pilot_location_class in ('verified_business', 'school', 'nonprofit', 'community_center', 'public_event');
  v_content := lower(concat_ws(' ', new.title, new.summary, new.description, new.special_instructions, new.safety_notes, new.equipment_provided, new.equipment_worker_brings, array_to_string(new.physical_requirements, ' ')));
  if new.pilot_location_class in ('private_residence', 'hotel', 'isolated_property', 'unknown_location') then v_reasons := array_append(v_reasons, 'pilot_location_not_allowed'); v_blocked := true;
  elsif not (new.pilot_location_class = any(v_allowed_locations)) then v_reasons := array_append(v_reasons, 'pilot_location_unclassified'); v_manual := true; end if;
  if not new.pilot_staffed_or_visible then v_reasons := array_append(v_reasons, 'staffed_or_visible_location_required'); v_blocked := true; end if;
  if v_content ~ '(\mbedroom\M|\mhotel\M|\movernight\M|\misolated\M|private property|secret|do not tell|keep this private)' then v_reasons := array_append(v_reasons, 'isolation_or_secrecy_prohibited'); v_blocked := true; end if;
  if v_content ~ '(\mroof\M|dangerous height|scaffold|firearm|\mweapon\M|\mgun\M|hazardous chemical|pesticide|alcohol|illegal drug|adult service|sexual service|heavy machinery|industrial machinery)' then v_reasons := array_append(v_reasons, 'hazardous_or_prohibited_work'); v_blocked := true; end if;
  if v_content ~ '(poster will drive|I will drive|ride with me|private ride|pick you up|transport you)' then v_reasons := array_append(v_reasons, 'poster_transportation_prohibited'); v_blocked := true;
  elsif coalesce(new.transportation_required, false) then v_reasons := array_append(v_reasons, 'transportation_plan_manual_review'); v_manual := true; end if;
  if new.risk_tier::text in ('higher_risk', 'prohibited') then v_reasons := array_append(v_reasons, 'job_risk_tier_not_pilot_eligible'); v_blocked := true; end if;
  if new.starts_at is not null and extract(hour from new.starts_at at time zone coalesce(new.timezone, 'America/Indianapolis')) not between 6 and 19 then v_reasons := array_append(v_reasons, 'overnight_or_late_work_prohibited'); v_blocked := true; end if;
  if new.ends_at is not null and extract(hour from new.ends_at at time zone coalesce(new.timezone, 'America/Indianapolis')) > 21 then v_reasons := array_append(v_reasons, 'overnight_or_late_work_prohibited'); v_blocked := true; end if;
  if not coalesce(v_profile.is_test_account, false) then
    select * into v_enrollment from public.pilot_enrollments enrollment where enrollment.user_id = new.poster_id and enrollment.status = 'approved' and enrollment.revoked_at is null and enrollment.expires_at > now() order by enrollment.approved_at desc limit 1;
    if v_enrollment.id is null or not private.user_has_active_pilot_enrollment(new.poster_id) then v_reasons := array_append(v_reasons, 'approved_adult_pilot_enrollment_required'); v_manual := true;
    else if new.pilot_organization_id is null then new.pilot_organization_id := v_enrollment.organization_id;
      elsif new.pilot_organization_id <> v_enrollment.organization_id then v_reasons := array_append(v_reasons, 'pilot_organization_mismatch'); v_blocked := true; end if;
    end if;
  end if;
  if not v_policy.pilot_mode_enabled or v_policy.unrestricted_public_access_enabled then v_reasons := array_append(v_reasons, 'closed_pilot_policy_unavailable'); v_blocked := true; end if;
  new.pilot_policy_version := v_policy.version; new.pilot_restriction_reasons := v_reasons; new.pilot_reviewed_at := now();
  if v_blocked then new.pilot_review_status := 'blocked'; elsif v_manual then new.pilot_review_status := 'manual_review_required'; else new.pilot_review_status := 'eligible'; end if;
  if new.status = 'open' and new.pilot_review_status <> 'eligible' then
    new.status := 'pending_review';
    new.applications_open := false;
  elsif new.status = 'open' and (tg_op = 'INSERT' or old.status is distinct from 'open') then
    new.applications_open := true;
  end if;
  return new;
end;
$$;

comment on function private.evaluate_closed_pilot_job()
is 'Evaluates closed-pilot job safety without reopening an explicitly closed application window.';

commit;
