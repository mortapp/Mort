-- Canonical, caller-bound profile writes. No client-supplied user ID is accepted,
-- and audit records contain field names only, never profile values.

create table if not exists public.profile_update_audit_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete cascade,
  operation text not null check (operation in ('onboarding_saved', 'profile_updated', 'onboarding_completed')),
  updated_fields text[] not null default array[]::text[],
  client_request_id uuid,
  created_at timestamptz not null default now(),
  check (user_id = actor_id)
);

create unique index if not exists profile_update_audit_idempotency_idx
on public.profile_update_audit_events(actor_id, client_request_id)
where client_request_id is not null;

alter table public.profile_update_audit_events enable row level security;
revoke all on table public.profile_update_audit_events from public, anon, authenticated;
grant select, insert, update, delete on table public.profile_update_audit_events to service_role;

create or replace function public.derive_age_eligibility(p_dob date)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_age integer;
  v_band text;
begin
  if p_dob is null then
    return jsonb_build_object('ok', false, 'code', 'dob_required');
  end if;
  if p_dob > current_date then
    return jsonb_build_object('ok', false, 'code', 'future_dob_rejected');
  end if;
  if p_dob < current_date - interval '120 years' then
    return jsonb_build_object('ok', false, 'code', 'dob_out_of_range');
  end if;

  v_age := extract(year from age(current_date, p_dob))::integer;
  v_band := case
    when v_age < 13 then 'under_13'
    when v_age <= 15 then 'teen_13_15'
    when v_age <= 17 then 'teen_16_17'
    else 'adult_18_plus'
  end;
  return jsonb_build_object(
    'ok', true,
    'age', v_age,
    'age_band', v_band,
    'eligible', v_age >= 13,
    'server_date', current_date
  );
end;
$$;

create or replace function public.save_my_onboarding_profile(
  p_role text,
  p_display_name text,
  p_dob date,
  p_city text default null,
  p_state text default null,
  p_location_setup_mode text default 'city_state',
  p_complete_onboarding boolean default false,
  p_payment_preference text default 'none',
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_existing public.profiles%rowtype;
  v_age jsonb;
  v_age_value integer;
  v_role public.user_role;
  v_name text := nullif(btrim(p_display_name), '');
  v_city text := nullif(btrim(p_city), '');
  v_state text := nullif(upper(btrim(p_state)), '');
  v_mode text := lower(btrim(coalesce(p_location_setup_mode, 'city_state')));
  v_payment public.payment_preference;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_client_request_id is not null and exists (
    select 1 from public.profile_update_audit_events event
    where event.actor_id = v_user_id and event.client_request_id = p_client_request_id
  ) then
    select * into v_profile from public.profiles where id = v_user_id;
    return jsonb_build_object('ok', true, 'replayed', true, 'profile', to_jsonb(v_profile));
  end if;
  if lower(btrim(coalesce(p_role, ''))) not in ('teen', 'adult', 'guardian') then
    return jsonb_build_object('ok', false, 'code', 'role_not_allowed');
  end if;
  v_role := lower(btrim(p_role))::public.user_role;
  if v_name is null or char_length(v_name) not between 2 and 80 then
    return jsonb_build_object('ok', false, 'code', 'display_name_invalid');
  end if;
  if v_name ~ '[[:cntrl:]]' then
    return jsonb_build_object('ok', false, 'code', 'display_name_invalid');
  end if;

  v_age := public.derive_age_eligibility(p_dob);
  if not coalesce((v_age->>'ok')::boolean, false) then return v_age; end if;
  v_age_value := (v_age->>'age')::integer;
  if v_age_value < 13 then
    return jsonb_build_object('ok', false, 'code', 'under_13_not_eligible');
  end if;
  if v_role = 'teen' and v_age_value not between 13 and 17 then
    return jsonb_build_object('ok', false, 'code', 'teen_role_age_mismatch');
  end if;
  if v_role in ('adult', 'guardian') and v_age_value < 18 then
    return jsonb_build_object('ok', false, 'code', 'adult_role_age_mismatch');
  end if;
  if v_mode not in ('city_state', 'partner_supported', 'location_deferred') then
    return jsonb_build_object('ok', false, 'code', 'location_setup_mode_invalid');
  end if;
  if v_role <> 'teen' and v_mode <> 'city_state' then
    return jsonb_build_object('ok', false, 'code', 'location_setup_mode_role_mismatch');
  end if;
  if v_mode = 'city_state' and (v_city is null or v_state !~ '^[A-Z]{2}$') then
    return jsonb_build_object('ok', false, 'code', 'city_state_required');
  end if;
  if p_payment_preference not in ('cash', 'cash_app', 'square_link', 'flexible', 'none') then
    return jsonb_build_object('ok', false, 'code', 'payment_preference_invalid');
  end if;
  v_payment := p_payment_preference::public.payment_preference;

  select * into v_existing
  from public.profiles profile
  where profile.id = v_user_id
  for update;

  if v_existing.id is not null then
    if v_existing.onboarding_completed then
      return jsonb_build_object('ok', false, 'code', 'onboarding_already_completed');
    end if;
    if v_existing.role is not null and v_existing.role <> v_role then
      return jsonb_build_object('ok', false, 'code', 'role_immutable');
    end if;
    if v_existing.dob is not null and v_existing.dob <> p_dob then
      return jsonb_build_object('ok', false, 'code', 'dob_immutable');
    end if;
    update public.profiles
    set role = coalesce(role, v_role),
        display_name = v_name,
        dob = coalesce(dob, p_dob),
        city = case when v_mode = 'city_state' then v_city else null end,
        state = case when v_mode = 'city_state' then v_state else null end,
        location_setup_mode = v_mode,
        payment_preference = v_payment,
        onboarding_completed = p_complete_onboarding,
        updated_at = now()
    where id = v_user_id
    returning * into v_profile;
  else
    insert into public.profiles (
      id, role, display_name, dob, city, state, location_setup_mode,
      payment_preference, onboarding_completed
    ) values (
      v_user_id, v_role, v_name, p_dob,
      case when v_mode = 'city_state' then v_city else null end,
      case when v_mode = 'city_state' then v_state else null end,
      v_mode, v_payment, p_complete_onboarding
    ) returning * into v_profile;
  end if;

  if v_role = 'teen' then
    insert into public.teen_profiles(user_id) values (v_user_id) on conflict (user_id) do nothing;
  elsif v_role = 'adult' then
    insert into public.adult_profiles(user_id) values (v_user_id) on conflict (user_id) do nothing;
  elsif v_role = 'guardian' then
    insert into public.guardian_profiles(user_id) values (v_user_id) on conflict (user_id) do nothing;
  end if;

  insert into public.profile_update_audit_events (
    user_id, actor_id, operation, updated_fields, client_request_id
  ) values (
    v_user_id, v_user_id, 'onboarding_saved',
    array['role', 'display_name', 'dob', 'city', 'state', 'location_setup_mode', 'payment_preference', 'onboarding_completed'],
    p_client_request_id
  );
  return jsonb_build_object('ok', true, 'replayed', false, 'profile', to_jsonb(v_profile));
exception when unique_violation then
  if p_client_request_id is not null and exists (
    select 1 from public.profile_update_audit_events event
    where event.actor_id = v_user_id and event.client_request_id = p_client_request_id
  ) then
    select * into v_profile from public.profiles where id = v_user_id;
    return jsonb_build_object('ok', true, 'replayed', true, 'profile', to_jsonb(v_profile));
  end if;
  raise;
end;
$$;

create or replace function public.update_my_profile(
  p_patch jsonb,
  p_expected_updated_at timestamptz default null,
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_result public.profiles%rowtype;
  v_unknown text[];
  v_fields text[];
  v_name text;
  v_bio text;
  v_availability text;
  v_categories text[];
  v_area text;
  v_goals text;
  v_avatar_path text;
  v_payment public.payment_preference;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    return jsonb_build_object('ok', false, 'code', 'profile_patch_required');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into v_fields
  from jsonb_object_keys(p_patch) key;
  if cardinality(v_fields) = 0 then
    return jsonb_build_object('ok', false, 'code', 'profile_patch_empty');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into v_unknown
  from unnest(v_fields) key
  where key not in (
    'display_name', 'bio', 'availability', 'preferred_job_categories',
    'approximate_area', 'goals', 'avatar_path', 'payment_preference'
  );
  if cardinality(v_unknown) > 0 then
    return jsonb_build_object(
      'ok', false, 'code', 'protected_or_unknown_profile_field',
      'fields', to_jsonb(v_unknown)
    );
  end if;
  if p_client_request_id is not null and exists (
    select 1 from public.profile_update_audit_events event
    where event.actor_id = v_user_id and event.client_request_id = p_client_request_id
  ) then
    select * into v_result from public.profiles where id = v_user_id;
    return jsonb_build_object('ok', true, 'replayed', true, 'profile', to_jsonb(v_result));
  end if;

  select * into v_profile
  from public.profiles profile
  where profile.id = v_user_id
  for update;
  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  if p_expected_updated_at is not null
     and abs(extract(epoch from (v_profile.updated_at - p_expected_updated_at))) > 0.001 then
    return jsonb_build_object(
      'ok', false, 'code', 'profile_conflict_detected',
      'current_updated_at', v_profile.updated_at
    );
  end if;

  v_name := case when p_patch ? 'display_name'
    then nullif(btrim(p_patch->>'display_name'), '') else v_profile.display_name end;
  v_bio := case when p_patch ? 'bio'
    then nullif(btrim(p_patch->>'bio'), '') else v_profile.bio end;
  v_availability := case when p_patch ? 'availability'
    then nullif(btrim(p_patch->>'availability'), '') else v_profile.availability end;
  v_area := case when p_patch ? 'approximate_area'
    then nullif(btrim(p_patch->>'approximate_area'), '') else v_profile.approximate_area end;
  v_goals := case when p_patch ? 'goals'
    then nullif(btrim(p_patch->>'goals'), '') else v_profile.goals end;
  v_avatar_path := case when p_patch ? 'avatar_path'
    then nullif(btrim(p_patch->>'avatar_path'), '') else v_profile.avatar_path end;
  v_payment := case when p_patch ? 'payment_preference'
    then (p_patch->>'payment_preference')::public.payment_preference
    else v_profile.payment_preference end;

  if v_name is null or char_length(v_name) not between 2 and 80 or v_name ~ '[[:cntrl:]]' then
    return jsonb_build_object('ok', false, 'code', 'display_name_invalid');
  end if;
  if v_bio is not null and char_length(v_bio) > 500 then
    return jsonb_build_object('ok', false, 'code', 'bio_invalid');
  end if;
  if v_availability is not null and char_length(v_availability) > 240 then
    return jsonb_build_object('ok', false, 'code', 'availability_invalid');
  end if;
  if v_area is not null and char_length(v_area) > 120 then
    return jsonb_build_object('ok', false, 'code', 'approximate_area_invalid');
  end if;
  if v_goals is not null and char_length(v_goals) > 500 then
    return jsonb_build_object('ok', false, 'code', 'goals_invalid');
  end if;
  if v_avatar_path is not null and (
    v_avatar_path not like v_user_id::text || '/%'
    or v_avatar_path !~* '\.jpg$'
    or char_length(v_avatar_path) > 160
  ) then
    return jsonb_build_object('ok', false, 'code', 'avatar_path_invalid');
  end if;

  if p_patch ? 'preferred_job_categories' then
    if jsonb_typeof(p_patch->'preferred_job_categories') <> 'array'
       or jsonb_array_length(p_patch->'preferred_job_categories') > 12
       or exists (
         select 1 from jsonb_array_elements(p_patch->'preferred_job_categories') item
         where jsonb_typeof(item) <> 'string'
            or char_length(btrim(item #>> '{}')) not between 2 and 50
       ) then
      return jsonb_build_object('ok', false, 'code', 'preferred_job_categories_invalid');
    end if;
    select coalesce(array_agg(value order by value), array[]::text[]) into v_categories
    from (
      select distinct lower(btrim(item #>> '{}')) value
      from jsonb_array_elements(p_patch->'preferred_job_categories') item
    ) normalized;
  else
    v_categories := v_profile.preferred_job_categories;
  end if;

  update public.profiles
  set display_name = v_name,
      bio = v_bio,
      availability = v_availability,
      preferred_job_categories = v_categories,
      approximate_area = v_area,
      goals = v_goals,
      avatar_path = v_avatar_path,
      avatar_moderation_status = case
        when p_patch ? 'avatar_path' and v_avatar_path is null then 'removed'
        when p_patch ? 'avatar_path' then 'active'
        else avatar_moderation_status
      end,
      avatar_updated_at = case when p_patch ? 'avatar_path' then now() else avatar_updated_at end,
      payment_preference = v_payment,
      updated_at = now()
  where id = v_user_id
  returning * into v_result;

  insert into public.profile_update_audit_events (
    user_id, actor_id, operation, updated_fields, client_request_id
  ) values (v_user_id, v_user_id, 'profile_updated', v_fields, p_client_request_id);
  return jsonb_build_object('ok', true, 'replayed', false, 'profile', to_jsonb(v_result));
exception
  when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'profile_value_invalid');
  when unique_violation then
    if p_client_request_id is not null and exists (
      select 1 from public.profile_update_audit_events event
      where event.actor_id = v_user_id and event.client_request_id = p_client_request_id
    ) then
      select * into v_result from public.profiles where id = v_user_id;
      return jsonb_build_object('ok', true, 'replayed', true, 'profile', to_jsonb(v_result));
    end if;
    raise;
end;
$$;

create or replace function public.complete_my_onboarding()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  update public.profiles
  set onboarding_completed = true, updated_at = now()
  where id = v_user_id
  returning * into v_profile;
  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  insert into public.profile_update_audit_events (
    user_id, actor_id, operation, updated_fields
  ) values (v_user_id, v_user_id, 'onboarding_completed', array['onboarding_completed']);
  return jsonb_build_object('ok', true, 'profile', to_jsonb(v_profile));
end;
$$;

revoke all on function public.derive_age_eligibility(date) from public, anon;
revoke all on function public.save_my_onboarding_profile(text, text, date, text, text, text, boolean, text, uuid) from public, anon;
revoke all on function public.update_my_profile(jsonb, timestamptz, uuid) from public, anon;
revoke all on function public.complete_my_onboarding() from public, anon;
grant execute on function public.derive_age_eligibility(date) to authenticated, service_role;
grant execute on function public.save_my_onboarding_profile(text, text, date, text, text, text, boolean, text, uuid) to authenticated, service_role;
grant execute on function public.update_my_profile(jsonb, timestamptz, uuid) to authenticated, service_role;
grant execute on function public.complete_my_onboarding() to authenticated, service_role;
