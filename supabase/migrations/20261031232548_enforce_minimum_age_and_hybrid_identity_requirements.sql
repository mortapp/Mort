-- Enforce MORT's strict 13+ eligibility at the database boundary.
-- Signup DOB metadata is self-reported and is not identity/age assurance.
-- Identity evidence routes are policy metadata only until an approved provider is enabled.

create or replace function private.mort_age_years(p_date_of_birth date)
returns integer language sql stable set search_path = ''
as $function$
  select case when p_date_of_birth is null then null
    else extract(year from age(current_date, p_date_of_birth))::integer end;
$function$;

create or replace function private.enforce_profile_minimum_age()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare v_age integer;
begin
  if new.date_of_birth is null then
    if tg_op = 'UPDATE' and old.date_of_birth is not null then
      raise exception using errcode = 'check_violation', message = 'MORT_DOB_IMMUTABLE';
    end if;
    return new;
  end if;
  if new.date_of_birth > current_date then
    raise exception using errcode = 'check_violation', message = 'MORT_DOB_INVALID';
  end if;
  v_age := private.mort_age_years(new.date_of_birth);
  if v_age < 13 then
    raise exception using errcode = 'check_violation', message = 'MORT_MINIMUM_AGE_REQUIRED';
  end if;
  if tg_op = 'UPDATE' and old.date_of_birth is not null
     and new.date_of_birth is distinct from old.date_of_birth then
    raise exception using errcode = 'check_violation', message = 'MORT_DOB_IMMUTABLE';
  end if;
  if v_age between 13 and 17 and new.role not in ('pending'::public.mort_role, 'teen'::public.mort_role) then
    raise exception using errcode = 'check_violation', message = 'MORT_MINOR_ROLE_REQUIRED';
  end if;
  if v_age >= 18 and new.role = 'teen'::public.mort_role then
    raise exception using errcode = 'check_violation', message = 'MORT_ADULT_ROLE_REQUIRED';
  end if;
  return new;
end;
$function$;

revoke all on function private.enforce_profile_minimum_age() from public, anon, authenticated;
drop trigger if exists mort_enforce_profile_minimum_age on public.profiles;
create trigger mort_enforce_profile_minimum_age
before insert or update of date_of_birth, role on public.profiles
for each row execute function private.enforce_profile_minimum_age();

-- A supplied DOB is checked in the same transaction as Auth user creation.
-- OAuth signups without a DOB remain pending and must pass the DOB RPC below.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare v_dob_text text; v_dob date;
begin
  v_dob_text := nullif(btrim(coalesce(
    new.raw_user_meta_data ->> 'date_of_birth',
    new.raw_user_meta_data ->> 'dob',
    ''
  )), '');
  if v_dob_text is not null then
    begin v_dob := v_dob_text::date;
    exception when others then
      raise exception using errcode = 'check_violation', message = 'MORT_DOB_INVALID';
    end;
    if v_dob > current_date then
      raise exception using errcode = 'check_violation', message = 'MORT_DOB_INVALID';
    end if;
    if private.mort_age_years(v_dob) < 13 then
      raise exception using errcode = 'check_violation', message = 'MORT_MINIMUM_AGE_REQUIRED';
    end if;
  end if;
  insert into public.profiles (id, display_name, role, account_status, date_of_birth)
  values (
    new.id,
    nullif(left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 80), ''),
    'pending'::public.mort_role,
    'pending',
    v_dob
  )
  on conflict (id) do nothing;
  return new;
end;
$function$;
revoke all on function private.handle_new_user() from public, anon, authenticated;

create or replace function public.save_my_initial_dob_v1(p_date_of_birth date)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_age integer;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_date_of_birth is null or p_date_of_birth > current_date then
    return jsonb_build_object('ok', false, 'code', 'dob_invalid', 'field', 'date_of_birth');
  end if;
  v_age := private.mort_age_years(p_date_of_birth);
  if v_age < 13 then
    return jsonb_build_object('ok', false, 'code', 'minimum_age_required', 'field', 'date_of_birth');
  end if;
  perform public.ensure_my_profile();
  select * into v_profile from public.profiles where id = v_user_id for update;
  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  if v_profile.onboarding_completed_at is not null then
    return jsonb_build_object('ok', false, 'code', 'dob_immutable');
  end if;
  if v_profile.date_of_birth is not null
     and v_profile.date_of_birth is distinct from p_date_of_birth then
    return jsonb_build_object('ok', false, 'code', 'dob_immutable');
  end if;
  update public.profiles
  set date_of_birth = coalesce(date_of_birth, p_date_of_birth), updated_at = now()
  where id = v_user_id;
  return jsonb_build_object(
    'ok', true,
    'age_band', case when v_age between 13 and 17 then 'minor' else 'adult' end,
    'minimum_age', 13
  );
end;
$function$;
revoke all on function public.save_my_initial_dob_v1(date) from public, anon;
grant execute on function public.save_my_initial_dob_v1(date) to authenticated, service_role;

-- Exposes the hybrid evidence policy without accepting sensitive ID uploads.
create or replace function public.get_my_verification_requirements_v1()
returns jsonb language plpgsql stable security definer set search_path = ''
as $function$
declare v_user_id uuid := auth.uid(); v_dob date; v_age integer;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select p.date_of_birth into v_dob from public.profiles p where p.id = v_user_id;
  if v_dob is null then
    return jsonb_build_object('ok', true, 'eligible', false, 'code', 'dob_required',
      'minimum_age', 13, 'verification_available', false);
  end if;
  v_age := private.mort_age_years(v_dob);
  if v_age < 13 then
    return jsonb_build_object('ok', true, 'eligible', false, 'code', 'minimum_age_required',
      'minimum_age', 13, 'verification_available', false);
  end if;
  if v_age between 13 and 17 then
    return jsonb_build_object(
      'ok', true, 'eligible', true, 'age_band', 'minor', 'minimum_age', 13,
      'school_email_required', true,
      'identity_evidence_options', jsonb_build_array('school_photo_id', 'official_enrollment_confirmation'),
      'identity_evidence_rule', 'A current school-issued photo ID is preferred. If the school does not issue one, official enrollment confirmation or direct school administrator verification is an alternative.',
      'verification_available', false, 'submissions_enabled', false,
      'provider_status', 'unavailable', 'documents_collected_by_mort', false
    );
  end if;
  return jsonb_build_object(
    'ok', true, 'eligible', true, 'age_band', 'adult', 'minimum_age', 13,
    'school_email_required', false,
    'identity_evidence_options', jsonb_build_array('government_photo_id'),
    'identity_evidence_rule', 'A valid, unexpired government-issued photo ID such as a driver license, state ID card, or passport is required.',
    'verification_available', false, 'submissions_enabled', false,
    'provider_status', 'unavailable', 'documents_collected_by_mort', false
  );
end;
$function$;
revoke all on function public.get_my_verification_requirements_v1() from public, anon;
grant execute on function public.get_my_verification_requirements_v1() to authenticated, service_role;
