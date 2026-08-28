-- Resumable onboarding state is private to the authenticated account and is
-- written only through caller-bound RPCs. Product acknowledgements below are
-- closed-pilot safety records, not substitutes for attorney-approved legal
-- acceptances in public.legal_acceptances.

create table public.onboarding_progress (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  current_step text not null default 'age' check (current_step in (
    'age', 'role', 'profile', 'skills', 'availability', 'transportation',
    'payment', 'guardian', 'preferences', 'safety', 'review', 'complete'
  )),
  completed_steps text[] not null default array[]::text[] check (
    completed_steps <@ array[
      'age', 'role', 'profile', 'skills', 'availability', 'transportation',
      'payment', 'guardian', 'preferences', 'safety', 'review', 'complete'
    ]::text[]
  ),
  notification_choice text not null default 'ask_later' check (
    notification_choice in ('ask_later', 'enabled', 'disabled')
  ),
  accessibility_preferences jsonb not null default '{}'::jsonb check (
    jsonb_typeof(accessibility_preferences) = 'object'
  ),
  adult_account_type text check (
    adult_account_type is null or adult_account_type in ('individual', 'business')
  ),
  business_name text check (
    business_name is null or char_length(btrim(business_name)) between 2 and 120
  ),
  safety_setup_choice text not null default 'review_later' check (
    safety_setup_choice in ('review_later', 'configured', 'declined_optional')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.onboarding_acknowledgements (
  user_id uuid not null references public.profiles(id) on delete cascade,
  acknowledgement_version text not null,
  pilot_terms_notice_acknowledged boolean not null,
  privacy_notice_acknowledged boolean not null,
  community_rules_acknowledged boolean not null,
  prohibited_work_acknowledged boolean not null,
  safety_rules_acknowledged boolean not null,
  platform text not null check (char_length(btrim(platform)) between 2 and 40),
  app_version text not null check (char_length(btrim(app_version)) between 1 and 40),
  acknowledged_at timestamptz not null default now(),
  primary key (user_id, acknowledgement_version),
  check (acknowledgement_version = 'mort-closed-pilot-safety-v1'),
  check (
    pilot_terms_notice_acknowledged
    and privacy_notice_acknowledged
    and community_rules_acknowledged
    and prohibited_work_acknowledged
    and safety_rules_acknowledged
  )
);

create table public.onboarding_progress_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check (event_type in (
    'age_saved', 'role_saved', 'step_saved', 'acknowledgement_saved',
    'onboarding_completed'
  )),
  step text,
  changed_fields text[] not null default array[]::text[],
  client_request_id uuid,
  created_at timestamptz not null default now(),
  check (step is null or step in (
    'age', 'role', 'profile', 'skills', 'availability', 'transportation',
    'payment', 'guardian', 'preferences', 'safety', 'review', 'complete'
  ))
);

create unique index onboarding_progress_events_idempotency_idx
on public.onboarding_progress_events(user_id, client_request_id)
where client_request_id is not null;

alter table public.onboarding_progress enable row level security;
alter table public.onboarding_progress force row level security;
alter table public.onboarding_acknowledgements enable row level security;
alter table public.onboarding_acknowledgements force row level security;
alter table public.onboarding_progress_events enable row level security;
alter table public.onboarding_progress_events force row level security;

revoke all on table public.onboarding_progress from public, anon, authenticated;
revoke all on table public.onboarding_acknowledgements from public, anon, authenticated;
revoke all on table public.onboarding_progress_events from public, anon, authenticated;
grant select, insert, update, delete on table public.onboarding_progress to service_role;
grant select, insert, update, delete on table public.onboarding_acknowledgements to service_role;
grant select, insert, update, delete on table public.onboarding_progress_events to service_role;

create or replace function public.enforce_server_authoritative_onboarding_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_internal_update text := current_setting('mort.internal_update', true);
  v_validated_completion text := current_setting('mort.onboarding_completion', true);
  v_jwt_role text := coalesce(auth.jwt()->>'role', '');
  v_trusted_server boolean :=
    session_user in ('postgres', 'supabase_admin')
    or v_jwt_role = 'service_role'
    or v_internal_update = 'true';
begin
  if new.onboarding_completed
     and (tg_op = 'INSERT' or not old.onboarding_completed)
     and not v_trusted_server
     and v_validated_completion <> 'true' then
    raise exception 'onboarding_completion_rpc_required';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_enforce_authoritative_onboarding_completion
on public.profiles;
create trigger profiles_enforce_authoritative_onboarding_completion
before insert or update of onboarding_completed on public.profiles
for each row execute function public.enforce_server_authoritative_onboarding_completion();

revoke all on function public.enforce_server_authoritative_onboarding_completion()
from public, anon, authenticated;

create or replace function public.get_my_onboarding_progress()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_progress public.onboarding_progress%rowtype;
  v_step text;
  v_path text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  select * into v_progress from public.onboarding_progress where user_id = auth.uid();

  v_step := case
    when v_profile.onboarding_completed then 'complete'
    when v_profile.dob is null then 'age'
    when v_profile.role is null then 'role'
    when v_progress.user_id is null then 'profile'
    else v_progress.current_step
  end;
  v_path := case v_step
    when 'age' then '/onboarding/age'
    when 'role' then '/onboarding/role'
    when 'profile' then '/onboarding/profile'
    when 'skills' then '/onboarding/skills'
    when 'availability' then '/onboarding/availability'
    when 'transportation' then '/onboarding/transportation'
    when 'payment' then '/onboarding/payment'
    when 'guardian' then '/onboarding/guardian'
    when 'preferences' then '/onboarding/preferences'
    when 'safety' then '/onboarding/safety'
    when 'review' then '/onboarding/review'
    else '/account-status'
  end;

  return jsonb_build_object(
    'ok', true,
    'current_step', v_step,
    'resume_path', v_path,
    'completed_steps', coalesce(v_progress.completed_steps, array[]::text[]),
    'notification_choice', coalesce(v_progress.notification_choice, 'ask_later'),
    'accessibility_preferences', coalesce(v_progress.accessibility_preferences, '{}'::jsonb),
    'adult_account_type', v_progress.adult_account_type,
    'business_name', v_progress.business_name,
    'safety_setup_choice', coalesce(v_progress.safety_setup_choice, 'review_later'),
    'acknowledgement_version', (
      select acknowledgement.acknowledgement_version
      from public.onboarding_acknowledgements acknowledgement
      where acknowledgement.user_id = auth.uid()
      order by acknowledgement.acknowledged_at desc
      limit 1
    )
  );
end;
$$;

create or replace function public.save_my_onboarding_age(
  p_dob date,
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_age jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_client_request_id is not null and exists (
    select 1 from public.onboarding_progress_events event
    where event.user_id = auth.uid() and event.client_request_id = p_client_request_id
  ) then
    return public.get_my_onboarding_progress();
  end if;

  v_age := public.derive_age_eligibility(p_dob);
  if not coalesce((v_age->>'ok')::boolean, false) then return v_age; end if;
  if not coalesce((v_age->>'eligible')::boolean, false) then
    return jsonb_build_object('ok', false, 'code', 'under_13_not_eligible');
  end if;

  select * into v_profile from public.profiles where id = auth.uid() for update;
  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  if v_profile.onboarding_completed then
    return jsonb_build_object('ok', false, 'code', 'onboarding_already_completed');
  end if;
  if v_profile.dob is not null and v_profile.dob <> p_dob then
    return jsonb_build_object('ok', false, 'code', 'dob_immutable');
  end if;

  update public.profiles set dob = coalesce(dob, p_dob), updated_at = now()
  where id = auth.uid();
  insert into public.onboarding_progress(user_id, current_step, completed_steps)
  values (auth.uid(), 'role', array['age'])
  on conflict (user_id) do update set
    current_step = case
      when array_position(
        array['age', 'role', 'profile', 'skills', 'availability', 'transportation',
              'payment', 'guardian', 'preferences', 'safety', 'review', 'complete']::text[],
        public.onboarding_progress.current_step
      ) > 2 then public.onboarding_progress.current_step
      else 'role'
    end,
    completed_steps = array(
      select distinct value
      from unnest(public.onboarding_progress.completed_steps || array['age']) value
      order by value
    ),
    updated_at = now();
  insert into public.onboarding_progress_events(
    user_id, event_type, step, changed_fields, client_request_id
  ) values (auth.uid(), 'age_saved', 'age', array['dob'], p_client_request_id);
  return public.get_my_onboarding_progress() || jsonb_build_object('age_band', v_age->>'age_band');
exception when unique_violation then
  return public.get_my_onboarding_progress();
end;
$$;

create or replace function public.save_my_onboarding_role(
  p_role text,
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_role public.user_role;
  v_age integer;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if lower(btrim(coalesce(p_role, ''))) not in ('teen', 'adult', 'guardian') then
    return jsonb_build_object('ok', false, 'code', 'role_not_allowed');
  end if;
  v_role := lower(btrim(p_role))::public.user_role;
  if p_client_request_id is not null and exists (
    select 1 from public.onboarding_progress_events event
    where event.user_id = auth.uid() and event.client_request_id = p_client_request_id
  ) then
    return public.get_my_onboarding_progress();
  end if;

  select * into v_profile from public.profiles where id = auth.uid() for update;
  if v_profile.id is null or v_profile.dob is null then
    return jsonb_build_object('ok', false, 'code', 'saved_dob_required');
  end if;
  if v_profile.onboarding_completed then
    return jsonb_build_object('ok', false, 'code', 'onboarding_already_completed');
  end if;
  if v_profile.role is not null and v_profile.role <> v_role then
    return jsonb_build_object('ok', false, 'code', 'role_immutable');
  end if;
  v_age := extract(year from age(current_date, v_profile.dob))::integer;
  if v_role = 'teen' and v_age not between 13 and 17 then
    return jsonb_build_object('ok', false, 'code', 'teen_role_age_mismatch');
  end if;
  if v_role in ('adult', 'guardian') and v_age < 18 then
    return jsonb_build_object('ok', false, 'code', 'adult_role_age_mismatch');
  end if;

  update public.profiles set role = coalesce(role, v_role), updated_at = now()
  where id = auth.uid();
  if v_role = 'teen' then
    insert into public.teen_profiles(user_id) values (auth.uid()) on conflict do nothing;
  elsif v_role = 'adult' then
    insert into public.adult_profiles(user_id) values (auth.uid()) on conflict do nothing;
  else
    insert into public.guardian_profiles(user_id) values (auth.uid()) on conflict do nothing;
  end if;
  insert into public.onboarding_progress(user_id, current_step, completed_steps)
  values (auth.uid(), 'profile', array['age', 'role'])
  on conflict (user_id) do update set
    current_step = case
      when array_position(
        array['age', 'role', 'profile', 'skills', 'availability', 'transportation',
              'payment', 'guardian', 'preferences', 'safety', 'review', 'complete']::text[],
        public.onboarding_progress.current_step
      ) > 3 then public.onboarding_progress.current_step
      else 'profile'
    end,
    completed_steps = array(
      select distinct value
      from unnest(public.onboarding_progress.completed_steps || array['age', 'role']) value
      order by value
    ),
    updated_at = now();
  insert into public.onboarding_progress_events(
    user_id, event_type, step, changed_fields, client_request_id
  ) values (auth.uid(), 'role_saved', 'role', array['role'], p_client_request_id);
  return public.get_my_onboarding_progress();
exception when unique_violation then
  return public.get_my_onboarding_progress();
end;
$$;

create or replace function public.save_my_onboarding_progress(
  p_step text,
  p_preferences jsonb default '{}'::jsonb,
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_step text := lower(btrim(coalesce(p_step, '')));
  v_next text;
  v_preferences jsonb := coalesce(p_preferences, '{}'::jsonb);
  v_unknown text[];
  v_notification text;
  v_accessibility jsonb;
  v_account_type text;
  v_business_name text;
  v_safety_setup text;
  v_previous_step text;
  v_progress public.onboarding_progress%rowtype;
  v_step_order constant text[] := array[
    'age', 'role', 'profile', 'skills', 'availability', 'transportation',
    'payment', 'guardian', 'preferences', 'safety', 'review', 'complete'
  ];
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if v_step not in (
    'profile', 'skills', 'availability', 'transportation', 'payment',
    'guardian', 'preferences', 'safety', 'review'
  ) then
    return jsonb_build_object('ok', false, 'code', 'onboarding_step_invalid');
  end if;
  if jsonb_typeof(v_preferences) <> 'object' then
    return jsonb_build_object('ok', false, 'code', 'onboarding_preferences_invalid');
  end if;
  select coalesce(array_agg(key order by key), array[]::text[]) into v_unknown
  from jsonb_object_keys(v_preferences) key
  where key not in (
    'notification_choice', 'accessibility_preferences', 'adult_account_type',
    'business_name', 'safety_setup_choice'
  );
  if cardinality(v_unknown) > 0 then
    return jsonb_build_object('ok', false, 'code', 'onboarding_preferences_unknown');
  end if;
  if p_client_request_id is not null and exists (
    select 1 from public.onboarding_progress_events event
    where event.user_id = auth.uid() and event.client_request_id = p_client_request_id
  ) then
    return public.get_my_onboarding_progress();
  end if;

  v_previous_step := case v_step
    when 'profile' then 'role'
    when 'skills' then 'profile'
    when 'availability' then 'skills'
    when 'transportation' then 'availability'
    when 'payment' then 'transportation'
    when 'guardian' then 'payment'
    when 'preferences' then 'guardian'
    when 'safety' then 'preferences'
    when 'review' then 'safety'
  end;
  select * into v_progress
  from public.onboarding_progress
  where user_id = auth.uid()
  for update;
  if v_progress.user_id is null
     or not v_previous_step = any(v_progress.completed_steps) then
    return jsonb_build_object(
      'ok', false, 'code', 'onboarding_prerequisite_required',
      'required_step', v_previous_step
    );
  end if;

  v_notification := v_preferences->>'notification_choice';
  if v_notification is not null and v_notification not in ('ask_later', 'enabled', 'disabled') then
    return jsonb_build_object('ok', false, 'code', 'notification_choice_invalid');
  end if;
  v_accessibility := v_preferences->'accessibility_preferences';
  if v_accessibility is not null and (
    jsonb_typeof(v_accessibility) <> 'object'
    or exists (
      select 1 from jsonb_object_keys(v_accessibility) key
      where key not in ('reduced_motion', 'larger_text', 'high_contrast')
    )
    or exists (
      select 1 from jsonb_each(v_accessibility) item
      where jsonb_typeof(item.value) <> 'boolean'
    )
  ) then
    return jsonb_build_object('ok', false, 'code', 'accessibility_preferences_invalid');
  end if;
  v_account_type := v_preferences->>'adult_account_type';
  if v_account_type is not null and v_account_type not in ('individual', 'business') then
    return jsonb_build_object('ok', false, 'code', 'adult_account_type_invalid');
  end if;
  v_business_name := nullif(btrim(v_preferences->>'business_name'), '');
  if v_business_name is not null and char_length(v_business_name) not between 2 and 120 then
    return jsonb_build_object('ok', false, 'code', 'business_name_invalid');
  end if;
  v_safety_setup := v_preferences->>'safety_setup_choice';
  if v_safety_setup is not null and v_safety_setup not in (
    'review_later', 'configured', 'declined_optional'
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_setup_choice_invalid');
  end if;

  v_next := case v_step
    when 'profile' then 'skills'
    when 'skills' then 'availability'
    when 'availability' then 'transportation'
    when 'transportation' then 'payment'
    when 'payment' then 'guardian'
    when 'guardian' then 'preferences'
    when 'preferences' then 'safety'
    when 'safety' then 'review'
    when 'review' then 'review'
  end;
  insert into public.onboarding_progress(
    user_id, current_step, completed_steps, notification_choice,
    accessibility_preferences, adult_account_type, business_name,
    safety_setup_choice
  ) values (
    auth.uid(), v_next, array[v_step], coalesce(v_notification, 'ask_later'),
    coalesce(v_accessibility, '{}'::jsonb), v_account_type, v_business_name,
    coalesce(v_safety_setup, 'review_later')
  )
  on conflict (user_id) do update set
    current_step = case
      when array_position(v_step_order, public.onboarding_progress.current_step)
           > array_position(v_step_order, v_next)
        then public.onboarding_progress.current_step
      else v_next
    end,
    completed_steps = array(
      select distinct value
      from unnest(public.onboarding_progress.completed_steps || array[v_step]) value
      order by value
    ),
    notification_choice = coalesce(v_notification, public.onboarding_progress.notification_choice),
    accessibility_preferences = coalesce(v_accessibility, public.onboarding_progress.accessibility_preferences),
    adult_account_type = coalesce(v_account_type, public.onboarding_progress.adult_account_type),
    business_name = case
      when v_preferences ? 'business_name' then v_business_name
      else public.onboarding_progress.business_name
    end,
    safety_setup_choice = coalesce(v_safety_setup, public.onboarding_progress.safety_setup_choice),
    updated_at = now();
  insert into public.onboarding_progress_events(
    user_id, event_type, step, changed_fields, client_request_id
  ) values (
    auth.uid(), 'step_saved', v_step,
    array(select key from jsonb_object_keys(v_preferences) key order by key),
    p_client_request_id
  );
  return public.get_my_onboarding_progress();
exception when unique_violation then
  return public.get_my_onboarding_progress();
end;
$$;

create or replace function public.record_my_onboarding_acknowledgement(
  p_acknowledgement_version text,
  p_pilot_terms_notice_acknowledged boolean,
  p_privacy_notice_acknowledged boolean,
  p_community_rules_acknowledged boolean,
  p_prohibited_work_acknowledged boolean,
  p_safety_rules_acknowledged boolean,
  p_platform text,
  p_app_version text,
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_acknowledgement_version <> 'mort-closed-pilot-safety-v1' then
    return jsonb_build_object('ok', false, 'code', 'acknowledgement_version_invalid');
  end if;
  if not (
    coalesce(p_pilot_terms_notice_acknowledged, false)
    and coalesce(p_privacy_notice_acknowledged, false)
    and coalesce(p_community_rules_acknowledged, false)
    and coalesce(p_prohibited_work_acknowledged, false)
    and coalesce(p_safety_rules_acknowledged, false)
  ) then
    return jsonb_build_object('ok', false, 'code', 'all_acknowledgements_required');
  end if;
  if char_length(btrim(coalesce(p_platform, ''))) not between 2 and 40
     or char_length(btrim(coalesce(p_app_version, ''))) not between 1 and 40 then
    return jsonb_build_object('ok', false, 'code', 'platform_and_app_version_required');
  end if;
  if p_client_request_id is not null and exists (
    select 1 from public.onboarding_progress_events event
    where event.user_id = auth.uid() and event.client_request_id = p_client_request_id
  ) then
    return public.get_my_onboarding_progress();
  end if;

  insert into public.onboarding_acknowledgements(
    user_id, acknowledgement_version, pilot_terms_notice_acknowledged,
    privacy_notice_acknowledged, community_rules_acknowledged,
    prohibited_work_acknowledged, safety_rules_acknowledged, platform, app_version
  ) values (
    auth.uid(), p_acknowledgement_version, true, true, true, true, true,
    left(btrim(p_platform), 40), left(btrim(p_app_version), 40)
  )
  on conflict (user_id, acknowledgement_version) do update set
    pilot_terms_notice_acknowledged = true,
    privacy_notice_acknowledged = true,
    community_rules_acknowledged = true,
    prohibited_work_acknowledged = true,
    safety_rules_acknowledged = true,
    platform = excluded.platform,
    app_version = excluded.app_version,
    acknowledged_at = now();
  insert into public.onboarding_progress_events(
    user_id, event_type, step, changed_fields, client_request_id
  ) values (
    auth.uid(), 'acknowledgement_saved', 'safety',
    array['acknowledgement_version'], p_client_request_id
  );
  return public.get_my_onboarding_progress();
exception when unique_violation then
  return public.get_my_onboarding_progress();
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
  v_progress public.onboarding_progress%rowtype;
  v_required_steps constant text[] := array[
    'age', 'role', 'profile', 'skills', 'availability', 'transportation',
    'payment', 'guardian', 'preferences', 'safety', 'review'
  ];
  v_missing_steps text[];
  v_age integer;
  v_release_mode text;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles where id = v_user_id for update;
  select * into v_progress from public.onboarding_progress where user_id = v_user_id for update;
  if v_profile.id is null then
    return jsonb_build_object('ok', false, 'code', 'profile_not_found');
  end if;
  if v_profile.onboarding_completed then
    return jsonb_build_object('ok', true, 'replayed', true, 'profile', to_jsonb(v_profile));
  end if;
  if v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_profile_required');
  end if;
  if v_profile.role not in ('teen', 'adult', 'guardian') or v_profile.dob is null then
    return jsonb_build_object('ok', false, 'code', 'role_and_dob_required');
  end if;
  v_age := extract(year from age(current_date, v_profile.dob))::integer;
  if (v_profile.role = 'teen' and v_age not between 13 and 17)
     or (v_profile.role in ('adult', 'guardian') and v_age < 18) then
    return jsonb_build_object('ok', false, 'code', 'role_age_mismatch');
  end if;
  if char_length(btrim(coalesce(v_profile.display_name, ''))) not between 2 and 80
     or v_profile.username is null then
    return jsonb_build_object('ok', false, 'code', 'profile_identity_fields_required');
  end if;
  if v_profile.location_setup_mode = 'city_state'
     and (v_profile.city is null or v_profile.state !~ '^[A-Z]{2}$') then
    return jsonb_build_object('ok', false, 'code', 'city_state_required');
  end if;
  if v_progress.user_id is null then
    return jsonb_build_object('ok', false, 'code', 'onboarding_progress_required');
  end if;
  select coalesce(array_agg(step order by step), array[]::text[]) into v_missing_steps
  from unnest(v_required_steps) step
  where not step = any(v_progress.completed_steps);
  if cardinality(v_missing_steps) > 0 then
    return jsonb_build_object(
      'ok', false, 'code', 'onboarding_steps_incomplete',
      'missing_steps', to_jsonb(v_missing_steps)
    );
  end if;
  if v_profile.role = 'adult' and v_progress.adult_account_type is null then
    return jsonb_build_object('ok', false, 'code', 'adult_account_type_required');
  end if;
  if v_progress.adult_account_type = 'business' and v_progress.business_name is null then
    return jsonb_build_object('ok', false, 'code', 'business_name_required');
  end if;
  if not exists (
    select 1 from public.onboarding_acknowledgements acknowledgement
    where acknowledgement.user_id = v_user_id
      and acknowledgement.acknowledgement_version = 'mort-closed-pilot-safety-v1'
  ) then
    return jsonb_build_object('ok', false, 'code', 'onboarding_acknowledgement_required');
  end if;
  if exists (
    select 1
    from public.legal_role_requirements requirement
    join public.legal_document_versions version
      on version.document_id = requirement.document_id
     and version.publication_status = 'published'
     and version.effective_at <= now()
    where requirement.role = v_profile.role
      and requirement.required
      and requirement.age_band in ('all', private.current_age_band(v_profile.dob))
      and not exists (
        select 1 from public.legal_acceptances acceptance
        where acceptance.user_id = v_user_id
          and acceptance.document_version_id = version.id
          and acceptance.active
      )
  ) then
    return jsonb_build_object('ok', false, 'code', 'published_legal_acceptance_required');
  end if;

  select policy.release_mode into v_release_mode from private.current_pilot_policy() policy;
  if v_release_mode = 'production_public' and not exists (
    select 1
    from public.legal_role_requirements requirement
    join public.legal_document_versions version
      on version.document_id = requirement.document_id
     and version.publication_status = 'published'
     and version.effective_at <= now()
    where requirement.role = v_profile.role and requirement.required
  ) then
    return jsonb_build_object('ok', false, 'code', 'production_legal_documents_unavailable');
  end if;

  perform set_config('mort.onboarding_completion', 'true', true);
  update public.profiles
  set onboarding_completed = true, updated_at = now()
  where id = v_user_id
  returning * into v_profile;
  perform set_config('mort.onboarding_completion', '', true);
  update public.onboarding_progress
  set current_step = 'complete',
      completed_steps = array(
        select distinct value
        from unnest(completed_steps || array['complete']) value
        order by value
      ),
      updated_at = now()
  where user_id = v_user_id;
  insert into public.profile_update_audit_events(
    user_id, actor_id, operation, updated_fields
  ) values (v_user_id, v_user_id, 'onboarding_completed', array['onboarding_completed']);
  insert into public.onboarding_progress_events(
    user_id, event_type, step, changed_fields
  ) values (v_user_id, 'onboarding_completed', 'complete', array['onboarding_completed']);
  return jsonb_build_object('ok', true, 'replayed', false, 'profile', to_jsonb(v_profile));
end;
$$;

revoke all on function public.get_my_onboarding_progress() from public, anon;
revoke all on function public.save_my_onboarding_age(date, uuid) from public, anon;
revoke all on function public.save_my_onboarding_role(text, uuid) from public, anon;
revoke all on function public.save_my_onboarding_progress(text, jsonb, uuid) from public, anon;
revoke all on function public.record_my_onboarding_acknowledgement(
  text, boolean, boolean, boolean, boolean, boolean, text, text, uuid
) from public, anon;
revoke all on function public.complete_my_onboarding() from public, anon;

grant execute on function public.get_my_onboarding_progress() to authenticated, service_role;
grant execute on function public.save_my_onboarding_age(date, uuid) to authenticated, service_role;
grant execute on function public.save_my_onboarding_role(text, uuid) to authenticated, service_role;
grant execute on function public.save_my_onboarding_progress(text, jsonb, uuid) to authenticated, service_role;
grant execute on function public.record_my_onboarding_acknowledgement(
  text, boolean, boolean, boolean, boolean, boolean, text, text, uuid
) to authenticated, service_role;
grant execute on function public.complete_my_onboarding() to authenticated, service_role;

comment on table public.onboarding_acknowledgements is
'Versioned closed-pilot product/safety acknowledgements. These are not attorney-approved legal acceptances.';
comment on function public.complete_my_onboarding() is
'Completes only the authenticated caller after mandatory persisted steps, pilot safety acknowledgement, and any published legal requirements are satisfied.';
comment on function public.enforce_server_authoritative_onboarding_completion() is
'Blocks ordinary authenticated profile writes from bypassing complete_my_onboarding validation.';
