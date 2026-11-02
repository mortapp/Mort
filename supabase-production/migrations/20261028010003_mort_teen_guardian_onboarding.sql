-- Bring the first-run Flutter teen/guardian flow onto the new MORT schema.
-- Self-reported dates remain pending; this does not approve an age check,
-- activate a user, publish the marketplace, or collect identity documents.

alter type public.mort_role add value if not exists 'guardian';

alter table public.profiles
  add column if not exists username text,
  add column if not exists location_setup_mode text not null default 'city_state',
  add column if not exists approximate_area text,
  add column if not exists availability text,
  add column if not exists preferred_job_categories text[] not null default '{}',
  add column if not exists transportation_methods text[] not null default '{}',
  add column if not exists max_travel_distance_miles integer,
  add column if not exists max_travel_minutes integer,
  add column if not exists walking_distance_only boolean not null default false,
  add column if not exists guardian_transportation_possible boolean not null default false,
  add column if not exists guardian_setup_status text not null default 'not_started',
  add column if not exists verification_status text not null default 'not_started',
  add column if not exists avatar_moderation_status text not null default 'active',
  add column if not exists avatar_updated_at timestamptz;

alter table public.profiles
  add constraint profiles_username_format_check
    check (username is null or username ~ '^[a-z0-9_]{3,24}$') not valid,
  add constraint profiles_location_setup_mode_check
    check (location_setup_mode in ('city_state', 'partner_supported', 'location_deferred')) not valid,
  add constraint profiles_guardian_setup_status_check
    check (guardian_setup_status in ('not_started', 'skipped', 'invite_pending', 'linked')) not valid,
  add constraint profiles_travel_distance_check
    check (max_travel_distance_miles is null or max_travel_distance_miles between 1 and 100) not valid,
  add constraint profiles_travel_minutes_check
    check (max_travel_minutes is null or max_travel_minutes between 1 and 240) not valid;

create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username)) where username is not null;

alter table public.guardian_links alter column guardian_user_id drop not null;
create unique index if not exists guardian_links_one_active_guardian_per_teen
  on public.guardian_links (teen_user_id) where status = 'active';
create unique index if not exists guardian_links_one_pending_invite_per_teen
  on public.guardian_links (teen_user_id) where status = 'pending';

create table if not exists private.guardian_invite_codes (
  id uuid primary key default gen_random_uuid(),
  guardian_link_id uuid not null unique references public.guardian_links(id) on delete cascade,
  teen_user_id uuid not null references auth.users(id) on delete cascade,
  code_sha256 text not null unique check (code_sha256 ~ '^[a-f0-9]{64}$'),
  invited_email text,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists guardian_invite_codes_teen_recent_idx
  on private.guardian_invite_codes (teen_user_id, created_at desc);
alter table private.guardian_invite_codes enable row level security;
alter table private.guardian_invite_codes force row level security;
revoke all on table private.guardian_invite_codes from public, anon, authenticated;
grant select, insert, update, delete on table private.guardian_invite_codes to service_role;

create table if not exists private.guardian_invite_accept_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  attempt_count integer not null check (attempt_count > 0),
  primary key (user_id, window_started_at)
);
alter table private.guardian_invite_accept_limits enable row level security;
alter table private.guardian_invite_accept_limits force row level security;
revoke all on table private.guardian_invite_accept_limits from public, anon, authenticated;
grant select, insert, update, delete on table private.guardian_invite_accept_limits to service_role;

create table if not exists private.mort_onboarding_safety (
  user_id uuid primary key references auth.users(id) on delete cascade,
  notification_intent text not null check (
    notification_intent in ('ask_later', 'preferred', 'not_preferred')
  ),
  saved_at timestamptz not null default now()
);
alter table private.mort_onboarding_safety enable row level security;
alter table private.mort_onboarding_safety force row level security;
revoke all on table private.mort_onboarding_safety from public, anon, authenticated;
grant select, insert, update, delete on table private.mort_onboarding_safety to service_role;

create or replace function private.evaluate_mort_onboarding(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  profile public.profiles%rowtype;
  missing text[] := array[]::text[];
  completed_steps text[] := array[]::text[];
  active_step text := 'account';
  current_age integer;
  safety_saved boolean;
begin
  select * into profile from public.profiles where id = p_user_id;
  if profile.id is null then
    missing := array['profile'];
  else
    if profile.role not in ('teen'::public.mort_role, 'adult'::public.mort_role, 'guardian'::public.mort_role) then
      missing := missing || array['role'];
    end if;
    if profile.date_of_birth is null then missing := missing || array['date_of_birth']; end if;
    if coalesce(length(btrim(profile.display_name)), 0) < 2 then missing := missing || array['display_name']; end if;
    if profile.username is null then missing := missing || array['username']; end if;
    if profile.role in ('adult'::public.mort_role, 'guardian'::public.mort_role)
      and (nullif(btrim(profile.city), '') is null or profile.region !~ '^[A-Z]{2}$') then
      missing := missing || array['general_location'];
    elsif profile.role = 'teen'::public.mort_role
      and (profile.location_setup_mode <> 'location_deferred'
        or nullif(btrim(profile.approximate_area), '') is null) then
      missing := missing || array['approximate_area'];
    end if;
    if profile.date_of_birth is not null then
      current_age := extract(year from age(current_date, profile.date_of_birth))::integer;
      if current_age < 13
        or (profile.role = 'teen'::public.mort_role and current_age not between 13 and 17)
        or (profile.role in ('adult'::public.mort_role, 'guardian'::public.mort_role) and current_age < 18) then
        missing := missing || array['age_role_eligibility'];
      end if;
    end if;
  end if;

  if cardinality(missing) = 0 then
    completed_steps := completed_steps || array['account'];
    active_step := 'work_preferences';
    if profile.role = 'teen'::public.mort_role then
      if nullif(btrim(profile.availability), '') is null then missing := missing || array['availability']; end if;
      if cardinality(profile.preferred_job_categories) = 0 then missing := missing || array['preferred_job_categories']; end if;
      if cardinality(profile.transportation_methods) = 0 then missing := missing || array['transportation_methods']; end if;
    end if;
  end if;

  if cardinality(missing) = 0 then
    completed_steps := completed_steps || array['work_preferences'];
    active_step := 'safety_support';
    select exists (select 1 from private.mort_onboarding_safety where user_id = p_user_id)
      into safety_saved;
    if not safety_saved then missing := missing || array['safety_support_intent']; end if;
    if profile.role = 'teen'::public.mort_role
      and profile.guardian_setup_status not in ('skipped', 'invite_pending', 'linked') then
      missing := missing || array['guardian_setup_choice'];
    end if;
  end if;

  if cardinality(missing) = 0 then
    completed_steps := completed_steps || array['safety_support'];
    active_step := 'review';
    if profile.onboarding_completed_at is not null then
      completed_steps := completed_steps || array['review'];
      active_step := 'complete';
    else
      -- This project has no published legal-document version to accept yet.
      missing := array['published_legal_documents'];
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'completed', active_step = 'complete',
    'active_step', active_step,
    'primary_steps', jsonb_build_array('account','work_preferences','safety_support','review'),
    'completed_steps', to_jsonb(completed_steps),
    'missing_requirements', to_jsonb(missing),
    'role', profile.role::text,
    'revision', profile.updated_at,
    'replayed', false
  );
end;
$$;
revoke all on function private.evaluate_mort_onboarding(uuid) from public, anon, authenticated;

create or replace function public.get_my_onboarding_progress_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  return private.evaluate_mort_onboarding(auth.uid());
end;
$$;
revoke all on function public.get_my_onboarding_progress_v2() from public, anon;
grant execute on function public.get_my_onboarding_progress_v2() to authenticated, service_role;

create or replace function public.save_my_onboarding_account_v2(
  p_payload jsonb,
  p_client_request_id uuid,
  p_payload_version integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  user_id uuid := auth.uid();
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
begin
  if user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
    or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into unknown_keys
  from jsonb_object_keys(p_payload) key
  where key not in ('role','display_name','username','dob','city','state','location_setup_mode','approximate_area','adult_account_type','business_name');
  if cardinality(unknown_keys) > 0 then return jsonb_build_object('ok', false, 'code', 'onboarding_payload_unknown_fields'); end if;

  begin dob := (p_payload->>'dob')::date;
  exception when others then return jsonb_build_object('ok', false, 'code', 'dob_invalid', 'field', 'dob'); end;
  if dob is null then return jsonb_build_object('ok', false, 'code', 'dob_invalid', 'field', 'dob'); end if;
  age_years := extract(year from age(current_date, dob))::integer;
  if age_years < 13 then return jsonb_build_object('ok', false, 'code', 'minimum_age_required', 'field', 'dob'); end if;
  selected_role := lower(btrim(coalesce(p_payload->>'role', '')));
  if age_years < 18 then
    chosen_role := 'teen'::public.mort_role;
  elsif selected_role in ('adult','guardian') then
    chosen_role := selected_role::public.mort_role;
  else
    return jsonb_build_object('ok', false, 'code', 'adult_role_required', 'field', 'role');
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
    city_value := null;
    region_value := null;
  else
    city_value := nullif(btrim(p_payload->>'city'), '');
    region_value := upper(btrim(coalesce(p_payload->>'state', '')));
    if mode_value <> 'city_state' or city_value is null or region_value !~ '^[A-Z]{2}$' then
      return jsonb_build_object('ok', false, 'code', 'general_location_required');
    end if;
  end if;

  perform public.ensure_my_profile();
  select * into profile from public.profiles where id = user_id for update;
  if profile.id is null then return jsonb_build_object('ok', false, 'code', 'profile_not_found'); end if;
  if profile.onboarding_completed_at is not null then
    return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('replayed', true);
  end if;
  if profile.date_of_birth is not null and profile.date_of_birth <> dob then
    return jsonb_build_object('ok', false, 'code', 'dob_immutable', 'field', 'dob');
  end if;
  if profile.role <> 'pending'::public.mort_role and profile.role is distinct from chosen_role then
    return jsonb_build_object('ok', false, 'code', 'role_immutable', 'field', 'role');
  end if;
  update public.profiles
  set role = chosen_role,
      date_of_birth = coalesce(date_of_birth, dob),
      display_name = display_name_value,
      username = username_value,
      city = city_value,
      region = region_value,
      location_setup_mode = mode_value,
      approximate_area = area_value,
      updated_at = now()
  where id = user_id;

  -- A self-reported DOB starts a pending age case; only a verified provider or authorized reviewer may approve it.
  insert into public.verification_cases(user_id, verification_type, status, provider, submitted_at)
  select user_id, 'age', 'pending'::public.mort_verification_status, 'self_reported', now()
  where not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = user_id and vc.verification_type = 'age'
      and vc.status in ('pending'::public.mort_verification_status, 'verified'::public.mort_verification_status)
  );
  return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('replayed', false);
exception when unique_violation then
  return jsonb_build_object('ok', false, 'code', 'username_taken', 'field', 'username');
end;
$$;
revoke all on function public.save_my_onboarding_account_v2(jsonb,uuid,integer) from public, anon;
grant execute on function public.save_my_onboarding_account_v2(jsonb,uuid,integer) to authenticated, service_role;

create or replace function public.save_my_onboarding_work_v2(
  p_payload jsonb,
  p_client_request_id uuid,
  p_payload_version integer default 1,
  p_expected_revision text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  user_id uuid := auth.uid();
  profile public.profiles%rowtype;
  unknown_keys text[];
  categories text[];
  transport text[];
  availability_value text;
  distance_value integer;
  minutes_value integer;
begin
  if user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into unknown_keys
  from jsonb_object_keys(p_payload) key where key not in (
    'availability','preferred_job_categories','transportation_methods','max_travel_distance_miles',
    'max_travel_minutes','walking_distance_only','guardian_transportation_possible'
  );
  if cardinality(unknown_keys) > 0 then return jsonb_build_object('ok', false, 'code', 'onboarding_payload_unknown_fields'); end if;
  select * into profile from public.profiles where id = user_id for update;
  if profile.id is null or profile.role not in ('teen'::public.mort_role, 'adult'::public.mort_role, 'guardian'::public.mort_role) then
    return jsonb_build_object('ok', false, 'code', 'onboarding_account_required');
  end if;
  if p_expected_revision is not null and profile.updated_at is distinct from p_expected_revision::timestamptz then
    return jsonb_build_object('ok', false, 'code', 'onboarding_revision_conflict', 'revision', profile.updated_at);
  end if;
  if profile.role <> 'teen'::public.mort_role then return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('replayed', false); end if;
  availability_value := nullif(btrim(p_payload->>'availability'), '');
  if availability_value is null or char_length(availability_value) > 240 then
    return jsonb_build_object('ok', false, 'code', 'availability_required');
  end if;
  if jsonb_typeof(coalesce(p_payload->'preferred_job_categories','[]'::jsonb)) <> 'array'
    or jsonb_typeof(coalesce(p_payload->'transportation_methods','[]'::jsonb)) <> 'array' then
    return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid');
  end if;
  select coalesce(array_agg(distinct lower(btrim(value))), array[]::text[]) into categories
  from jsonb_array_elements_text(coalesce(p_payload->'preferred_job_categories','[]'::jsonb)) value
  where char_length(btrim(value)) between 1 and 60;
  select coalesce(array_agg(distinct lower(btrim(value))), array[]::text[]) into transport
  from jsonb_array_elements_text(coalesce(p_payload->'transportation_methods','[]'::jsonb)) value
  where lower(btrim(value)) in ('walking','bicycle','public_transit','car','rideshare','other');
  if cardinality(categories) = 0 or cardinality(categories) > 20 or cardinality(transport) = 0 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_required');
  end if;
  begin
    distance_value := nullif(p_payload->>'max_travel_distance_miles','')::integer;
    minutes_value := nullif(p_payload->>'max_travel_minutes','')::integer;
  exception when others then return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid'); end;
  if distance_value is not null and distance_value not between 1 and 100 then return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid'); end if;
  if minutes_value is not null and minutes_value not between 1 and 240 then return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid'); end if;
  update public.profiles set
    availability = availability_value,
    preferred_job_categories = categories,
    transportation_methods = transport,
    max_travel_distance_miles = distance_value,
    max_travel_minutes = minutes_value,
    walking_distance_only = coalesce((p_payload->>'walking_distance_only')::boolean, false),
    guardian_transportation_possible = coalesce((p_payload->>'guardian_transportation_possible')::boolean, false),
    updated_at = now()
  where id = user_id;
  return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('replayed', false);
exception when invalid_text_representation then
  return jsonb_build_object('ok', false, 'code', 'onboarding_work_preferences_invalid');
end;
$$;
revoke all on function public.save_my_onboarding_work_v2(jsonb,uuid,integer,text) from public, anon;
grant execute on function public.save_my_onboarding_work_v2(jsonb,uuid,integer,text) to authenticated, service_role;

create or replace function public.set_guardian_setup_skipped()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  user_id uuid := auth.uid();
begin
  if user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = user_id and p.role = 'teen'::public.mort_role
      and p.date_of_birth is not null and extract(year from age(current_date, p.date_of_birth)) between 13 and 17
  ) then return jsonb_build_object('ok', false, 'code', 'active_teen_account_required'); end if;
  update public.guardian_links set status = 'revoked', updated_at = now()
  where teen_user_id = user_id and status = 'pending';
  update private.guardian_invite_codes set consumed_at = coalesce(consumed_at, now())
  where teen_user_id = user_id and consumed_at is null;
  update public.profiles set guardian_setup_status = 'skipped', updated_at = now() where id = user_id;
  return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.set_guardian_setup_skipped() from public, anon;
grant execute on function public.set_guardian_setup_skipped() to authenticated, service_role;

create or replace function public.create_guardian_invite_v2(p_invite_email text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  teen_id uuid := auth.uid();
  teen_profile public.profiles%rowtype;
  email_value text := nullif(lower(btrim(p_invite_email)), '');
  invite_code text;
  link_id uuid;
  invite_limit integer;
  expires_at_value timestamptz := now() + interval '7 days';
begin
  if teen_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  select * into teen_profile from public.profiles where id = teen_id for update;
  if not found or teen_profile.role <> 'teen'::public.mort_role
    or teen_profile.date_of_birth is null
    or extract(year from age(current_date, teen_profile.date_of_birth)) not between 13 and 17 then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if email_value is not null and (char_length(email_value) > 254 or email_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then
    return jsonb_build_object('ok', false, 'code', 'guardian_email_invalid');
  end if;
  select count(*) into invite_limit from private.guardian_invite_codes
  where teen_user_id = teen_id and created_at > now() - interval '24 hours';
  if invite_limit >= 3 then return jsonb_build_object('ok', false, 'code', 'guardian_invite_limit_reached'); end if;

  update public.guardian_links set status = 'revoked', updated_at = now()
  where teen_user_id = teen_id and status = 'pending';
  invite_code := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.guardian_links(teen_user_id, guardian_user_id, status, initiated_by, teen_consent_at)
  values (teen_id, null, 'pending', teen_id, now()) returning id into link_id;
  insert into private.guardian_invite_codes(guardian_link_id, teen_user_id, code_sha256, invited_email, expires_at)
  values (link_id, teen_id, encode(extensions.digest(convert_to(invite_code, 'utf8'), 'sha256'), 'hex'), email_value, expires_at_value);
  update public.profiles set guardian_setup_status = 'invite_pending', updated_at = now() where id = teen_id;
  return jsonb_build_object(
    'ok', true,
    'link_id', link_id,
    'invite_code', upper(invite_code),
    'expires_at', expires_at_value,
    'delivery', 'share_code_with_guardian'
  );
end;
$$;
revoke all on function public.create_guardian_invite_v2(text) from public, anon;
grant execute on function public.create_guardian_invite_v2(text) to authenticated, service_role;

create or replace function public.accept_guardian_invite(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  guardian_id uuid := auth.uid();
  guardian_profile public.profiles%rowtype;
  auth_email text;
  invite private.guardian_invite_codes%rowtype;
  link public.guardian_links%rowtype;
  code_hash text;
  window_start timestamptz := date_trunc('minute', now());
  attempts integer;
begin
  if guardian_id is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  insert into private.guardian_invite_accept_limits(user_id, window_started_at, attempt_count)
  values (guardian_id, window_start, 1)
  on conflict (user_id, window_started_at) do update
  set attempt_count = private.guardian_invite_accept_limits.attempt_count + 1
  returning attempt_count into attempts;
  if attempts > 10 then raise exception 'guardian_invite_accept_rate_limit_reached' using errcode = '42501'; end if;

  select * into guardian_profile from public.profiles where id = guardian_id for update;
  if not found or guardian_profile.role <> 'guardian'::public.mort_role
    or guardian_profile.date_of_birth is null
    or extract(year from age(current_date, guardian_profile.date_of_birth)) < 18 then
    raise exception 'adult_guardian_account_required' using errcode = '42501';
  end if;
  select lower(u.email) into auth_email from auth.users u where u.id = guardian_id;
  if p_invite_code is null or p_invite_code !~* '^[a-f0-9]{64}$' then
    raise exception 'guardian_invite_invalid_or_expired' using errcode = '22023';
  end if;
  code_hash := encode(extensions.digest(convert_to(lower(p_invite_code), 'utf8'), 'sha256'), 'hex');
  select * into invite from private.guardian_invite_codes
  where code_sha256 = code_hash and consumed_at is null and expires_at > now()
  for update;
  if not found or (invite.invited_email is not null and invite.invited_email <> coalesce(auth_email, '')) then
    raise exception 'guardian_invite_invalid_or_expired' using errcode = '22023';
  end if;
  select * into link from public.guardian_links where id = invite.guardian_link_id for update;
  if not found or link.status <> 'pending' or link.guardian_user_id is not null
    or link.teen_user_id = guardian_id then
    raise exception 'guardian_invite_invalid_or_expired' using errcode = '22023';
  end if;
  if exists (select 1 from public.guardian_links active
    where active.teen_user_id = link.teen_user_id and active.status = 'active') then
    raise exception 'guardian_link_already_exists' using errcode = '23505';
  end if;
  update public.guardian_links
  set guardian_user_id = guardian_id, status = 'active', guardian_consent_at = now(), updated_at = now()
  where id = link.id;
  update private.guardian_invite_codes set consumed_at = now() where id = invite.id;
  update public.profiles set guardian_setup_status = 'linked', updated_at = now() where id = link.teen_user_id;
  return link.id;
end;
$$;
revoke all on function public.accept_guardian_invite(text) from public, anon;
grant execute on function public.accept_guardian_invite(text) to authenticated, service_role;

create or replace function public.save_my_onboarding_safety_v2(
  p_payload jsonb,
  p_client_request_id uuid,
  p_payload_version integer default 1,
  p_expected_revision text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  user_id uuid := auth.uid();
  profile public.profiles%rowtype;
  intent text := coalesce(p_payload->>'notification_intent', 'ask_later');
  guardian_choice text := coalesce(p_payload->>'guardian_choice', 'not_applicable');
  unknown_keys text[];
begin
  if user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into unknown_keys
  from jsonb_object_keys(p_payload) key where key not in ('notification_intent','guardian_choice');
  if cardinality(unknown_keys) > 0 or intent not in ('ask_later','preferred','not_preferred') then
    return jsonb_build_object('ok', false, 'code', 'onboarding_safety_support_invalid');
  end if;
  select * into profile from public.profiles where id = user_id for update;
  if profile.id is null then return jsonb_build_object('ok', false, 'code', 'onboarding_account_required'); end if;
  if p_expected_revision is not null and profile.updated_at is distinct from p_expected_revision::timestamptz then
    return jsonb_build_object('ok', false, 'code', 'onboarding_revision_conflict', 'revision', profile.updated_at);
  end if;
  if profile.role = 'teen'::public.mort_role then
    if guardian_choice = 'skip' then
      perform public.set_guardian_setup_skipped();
    elsif guardian_choice = 'existing' and profile.guardian_setup_status not in ('invite_pending','linked') then
      return jsonb_build_object('ok', false, 'code', 'guardian_invite_required_or_skip');
    elsif guardian_choice not in ('existing','skip') then
      return jsonb_build_object('ok', false, 'code', 'guardian_invite_required_or_skip');
    end if;
  end if;
  insert into private.mort_onboarding_safety(user_id, notification_intent)
  values (user_id, intent)
  on conflict (user_id) do update set notification_intent = excluded.notification_intent, saved_at = now();
  return private.evaluate_mort_onboarding(user_id) || jsonb_build_object('replayed', false);
end;
$$;
revoke all on function public.save_my_onboarding_safety_v2(jsonb,uuid,integer,text) from public, anon;
grant execute on function public.save_my_onboarding_safety_v2(jsonb,uuid,integer,text) to authenticated, service_role;

create or replace function public.complete_my_onboarding_v2(
  p_payload jsonb,
  p_client_request_id uuid,
  p_payload_version integer default 1,
  p_expected_revision text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  user_id uuid := auth.uid();
  progress jsonb;
begin
  if user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_client_request_id is null or p_payload_version <> 1 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_request_invalid');
  end if;
  progress := private.evaluate_mort_onboarding(user_id);
  if progress->>'active_step' <> 'review' then
    return jsonb_build_object('ok', false, 'code', 'onboarding_steps_incomplete', 'missing_requirements', progress->'missing_requirements');
  end if;
  -- No published, approved legal documents exist in this project yet.
  return jsonb_build_object('ok', false, 'code', 'published_legal_acceptance_required');
end;
$$;
revoke all on function public.complete_my_onboarding_v2(jsonb,uuid,integer,text) from public, anon;
grant execute on function public.complete_my_onboarding_v2(jsonb,uuid,integer,text) to authenticated, service_role;

comment on table private.guardian_invite_codes is
  'Private, expiring one-use guardian invite hashes. Raw invitation codes are returned only once to the teen who initiated the invite.';
comment on function public.create_guardian_invite_v2(text) is
  'Creates a teen-consented, expiring guardian invite. The code is not emailed; the teen must share it directly.';
comment on function public.accept_guardian_invite(text) is
  'Links an adult guardian only after authenticated role/age checks, optional invite-email match, and explicit guardian consent.';

