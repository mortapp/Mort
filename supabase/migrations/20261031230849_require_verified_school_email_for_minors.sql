-- Require a verified, administratively approved school email for minors.
-- Domains are deliberately fail-closed: no domain is accepted until an
-- authorized operator verifies and activates it in private.school_email_domains.

create table if not exists private.school_email_domains (
  domain text primary key,
  school_name text not null,
  status text not null default 'pending' check (status in ('pending', 'active', 'rejected', 'suspended')),
  verification_source text,
  verified_at timestamptz,
  approved_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint school_email_domains_domain_format check (
    domain = lower(btrim(domain))
    and domain !~ '[@[:space:]/]'
    and position('.' in domain) > 1
  ),
  constraint school_email_domains_active_verified check (
    status <> 'active' or (verified_at is not null and verification_source is not null)
  )
);

alter table private.school_email_domains enable row level security;
revoke all on table private.school_email_domains from public, anon, authenticated;
grant all on table private.school_email_domains to service_role;

create or replace function private.is_approved_school_email(p_email text)
returns boolean language sql stable security definer set search_path = ''
as $function$
  select case
    when p_email is null or btrim(p_email) = '' then false
    when p_email !~* '^[^@[:space:]]+@[^@[:space:]]+$' then false
    else exists (
      select 1 from private.school_email_domains d
      where d.domain = lower(split_part(btrim(p_email), '@', 2))
        and d.status = 'active'
        and d.verified_at is not null
        and d.verification_source is not null
    )
  end;
$function$;

revoke all on function private.is_approved_school_email(text) from public, anon, authenticated;
grant execute on function private.is_approved_school_email(text) to service_role;

create or replace function private.enforce_minor_school_email_on_auth_email_change()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare v_dob date;
begin
  if new.email is not distinct from old.email then return new; end if;
  select p.date_of_birth into v_dob
  from public.profiles p where p.id = new.id;

  if v_dob is not null
    and extract(year from age(current_date, v_dob))::integer between 13 and 17
    and not private.is_approved_school_email(new.email) then
    raise exception using errcode = 'check_violation', message = 'MORT_SCHOOL_EMAIL_REQUIRED';
  end if;
  return new;
end;
$function$;

revoke all on function private.enforce_minor_school_email_on_auth_email_change() from public, anon, authenticated;
drop trigger if exists mort_enforce_minor_school_email_on_auth_email_change on auth.users;
create trigger mort_enforce_minor_school_email_on_auth_email_change
before update of email on auth.users
for each row
when (old.email is distinct from new.email)
execute function private.enforce_minor_school_email_on_auth_email_change();

create or replace function public.save_my_onboarding_account_v2(
  p_payload jsonb, p_client_request_id uuid, p_payload_version integer default 1
)
returns jsonb language plpgsql security definer set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  profile public.profiles%rowtype;
  dob date;
  age_years integer;
  selected_role text;
  chosen_role public.mort_role;
  display_name_value text;
  username_value text;
  city_value text;
  region_value text;
  area_value text;
  mode_value text;
  unknown_keys text[];
  v_auth_email text;
  v_email_confirmed_at timestamptz;
begin
  if v_user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
    or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;

  select coalesce(array_agg(key order by key), array[]::text[])
  into unknown_keys
  from jsonb_object_keys(p_payload) key
  where key not in ('role','display_name','username','dob','city','state',
    'location_setup_mode','approximate_area','adult_account_type','business_name');
  if cardinality(unknown_keys) > 0 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_payload_unknown_fields');
  end if;

  begin dob := (p_payload->>'dob')::date;
  exception when others then return jsonb_build_object('ok', false, 'code', 'dob_invalid', 'field', 'dob');
  end;
  if dob is null then return jsonb_build_object('ok', false, 'code', 'dob_invalid', 'field', 'dob'); end if;

  age_years := extract(year from age(current_date, dob))::integer;
  if age_years < 13 then return jsonb_build_object('ok', false, 'code', 'minimum_age_required', 'field', 'dob'); end if;

  selected_role := lower(btrim(coalesce(p_payload->>'role', '')));
  if age_years < 18 then chosen_role := 'teen'::public.mort_role;
  elsif selected_role in ('adult','guardian') then chosen_role := selected_role::public.mort_role;
  else return jsonb_build_object('ok', false, 'code', 'adult_role_required', 'field', 'role');
  end if;

  -- Server-derived minor status; email must be confirmed by Supabase and its
  -- exact domain must be approved in the private registry.
  if age_years between 13 and 17 then
    select u.email, u.email_confirmed_at into v_auth_email, v_email_confirmed_at
    from auth.users u where u.id = v_user_id;
    if v_email_confirmed_at is null then
      return jsonb_build_object('ok', false, 'code', 'school_email_verification_required', 'field', 'email');
    end if;
    if not private.is_approved_school_email(v_auth_email) then
      return jsonb_build_object('ok', false, 'code', 'school_email_required', 'field', 'email');
    end if;
  end if;

  display_name_value := btrim(coalesce(p_payload->>'display_name', ''));
  username_value := lower(btrim(coalesce(p_payload->>'username', '')));
  if char_length(display_name_value) not between 2 and 80 or display_name_value ~ '[[:cntrl:]]' then
    return jsonb_build_object('ok', false, 'code', 'display_name_invalid', 'field', 'display_name');
  end if;
  if username_value !~ '^[a-z0-9_]{3,24}$' then
    return jsonb_build_object('ok', false, 'code', 'username_invalid', 'field', 'username');
  end if;

  mode_value := coalesce(p_payload->>'location_setup_mode', 'city_state');
  if chosen_role = 'teen'::public.mort_role then
    mode_value := 'location_deferred';
    area_value := nullif(btrim(p_payload->>'approximate_area'), '');
    if area_value is null or char_length(area_value) > 80 then
      return jsonb_build_object('ok', false, 'code', 'approximate_area_required', 'field', 'approximate_area');
    end if;
    city_value := null; region_value := null;
  else
    city_value := nullif(btrim(p_payload->>'city'), '');
    region_value := upper(btrim(coalesce(p_payload->>'state', '')));
    if mode_value <> 'city_state' or city_value is null or region_value !~ '^[A-Z]{2}$' then
      return jsonb_build_object('ok', false, 'code', 'general_location_required');
    end if;
  end if;

  perform public.ensure_my_profile();
  select * into profile from public.profiles where id = v_user_id for update;
  if profile.id is null then return jsonb_build_object('ok', false, 'code', 'profile_not_found'); end if;
  if profile.onboarding_completed_at is not null then
    return private.evaluate_mort_onboarding(v_user_id) || jsonb_build_object('replayed', true);
  end if;
  if profile.date_of_birth is not null and profile.date_of_birth <> dob then
    return jsonb_build_object('ok', false, 'code', 'dob_immutable', 'field', 'dob');
  end if;
  if profile.role <> 'pending'::public.mort_role and profile.role is distinct from chosen_role then
    return jsonb_build_object('ok', false, 'code', 'role_immutable', 'field', 'role');
  end if;

  update public.profiles set role = chosen_role, date_of_birth = coalesce(date_of_birth, dob),
    display_name = display_name_value, username = username_value, city = city_value,
    region = region_value, location_setup_mode = mode_value, approximate_area = area_value,
    updated_at = now()
  where id = v_user_id;

  insert into public.verification_cases(user_id, verification_type, status, provider, submitted_at)
  select v_user_id, 'age', 'pending'::public.mort_verification_status, 'self_reported', now()
  where not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_user_id and vc.verification_type = 'age'
      and vc.status in ('pending'::public.mort_verification_status, 'verified'::public.mort_verification_status)
  );

  return private.evaluate_mort_onboarding(v_user_id) || jsonb_build_object('replayed', false);
exception when unique_violation then
  return jsonb_build_object('ok', false, 'code', 'username_taken', 'field', 'username');
end;
$function$;

revoke all on function public.save_my_onboarding_account_v2(jsonb,uuid,integer) from public, anon;
grant execute on function public.save_my_onboarding_account_v2(jsonb,uuid,integer) to authenticated, service_role;
