-- Phase 9: server-authoritative FCM registration, preferences, queue claiming,
-- and privacy-safe delivery accounting. Remote delivery remains disabled until
-- provider credentials and physical-device verification exist.

alter table public.push_tokens
  alter column expo_push_token drop not null,
  add column if not exists provider text not null default 'expo_legacy',
  add column if not exists registration_token text,
  add column if not exists token_sha256 text,
  add column if not exists device_id uuid,
  add column if not exists permission_status text not null default 'authorized',
  add column if not exists app_version text,
  add column if not exists locale text,
  add column if not exists timezone_name text not null default 'UTC',
  add column if not exists environment text not null default 'legacy',
  add column if not exists last_registered_at timestamptz not null default now(),
  add column if not exists last_seen_at timestamptz not null default now(),
  add column if not exists deactivated_at timestamptz;

update public.push_tokens
set registration_token = expo_push_token,
    token_sha256 = encode(extensions.digest(expo_push_token, 'sha256'), 'hex'),
    device_id = coalesce(device_id, extensions.gen_random_uuid()),
    provider = 'expo_legacy'
where registration_token is null and expo_push_token is not null;

delete from public.push_tokens where registration_token is null;

alter table public.push_tokens
  alter column registration_token set not null,
  alter column token_sha256 set not null,
  alter column device_id set not null,
  drop constraint if exists push_tokens_provider_check,
  add constraint push_tokens_provider_check check (provider in ('fcm', 'expo_legacy')),
  drop constraint if exists push_tokens_platform_check,
  add constraint push_tokens_platform_check check (platform in ('android', 'ios', 'web', 'unknown')),
  drop constraint if exists push_tokens_permission_status_check,
  add constraint push_tokens_permission_status_check check (
    permission_status in ('authorized', 'provisional')
  ),
  drop constraint if exists push_tokens_registration_token_check,
  add constraint push_tokens_registration_token_check check (
    char_length(registration_token) between 20 and 4096
    and registration_token ~ '^[A-Za-z0-9_:\-\[\]]+$'
  ),
  drop constraint if exists push_tokens_hash_check,
  add constraint push_tokens_hash_check check (token_sha256 ~ '^[a-f0-9]{64}$'),
  drop constraint if exists push_tokens_app_version_check,
  add constraint push_tokens_app_version_check check (
    app_version is null or char_length(app_version) between 1 and 40
  ),
  drop constraint if exists push_tokens_locale_check,
  add constraint push_tokens_locale_check check (
    locale is null or locale ~ '^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})?$'
  ),
  drop constraint if exists push_tokens_environment_check,
  add constraint push_tokens_environment_check check (
    environment in ('development', 'internal_test', 'closed_test', 'production_pilot', 'production_public', 'legacy')
  );

drop index if exists public.push_tokens_fcm_token_unique_idx;
create unique index push_tokens_fcm_token_unique_idx
on public.push_tokens(provider, registration_token);
drop index if exists public.push_tokens_user_device_provider_idx;
create unique index push_tokens_user_device_provider_idx
on public.push_tokens(user_id, device_id, provider);
create index if not exists push_tokens_active_user_idx
on public.push_tokens(user_id, provider, last_seen_at desc)
where is_active;

create or replace function private.set_push_token_hash()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.token_sha256 := encode(extensions.digest(new.registration_token, 'sha256'), 'hex');
  new.updated_at := now();
  if new.is_active then
    new.deactivated_at := null;
  elsif new.deactivated_at is null then
    new.deactivated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists push_tokens_set_hash on public.push_tokens;
create trigger push_tokens_set_hash
before insert or update of registration_token, is_active on public.push_tokens
for each row execute function private.set_push_token_hash();

update public.profiles set expo_push_token = null where expo_push_token is not null;
alter table public.profiles drop constraint if exists profiles_legacy_expo_push_token_retired;
alter table public.profiles add constraint profiles_legacy_expo_push_token_retired
check (expo_push_token is null);

alter table public.push_tokens enable row level security;
alter table public.push_tokens force row level security;
drop policy if exists push_tokens_select_owner_or_admin on public.push_tokens;
drop policy if exists push_tokens_upsert_owner on public.push_tokens;
revoke all on public.push_tokens from public, anon, authenticated;
grant all on public.push_tokens to service_role;

create table public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  push_enabled boolean not null default false,
  categories jsonb not null default jsonb_build_object(
    'application_updates', true,
    'job_updates', true,
    'schedule_changes', true,
    'new_messages', true,
    'work_reminders', true,
    'support_updates', true,
    'guardian_updates', true,
    'verification_updates', true,
    'dispute_updates', true
  ),
  quiet_hours_enabled boolean not null default false,
  quiet_start time not null default time '21:00',
  quiet_end time not null default time '07:00',
  timezone_name text not null default 'UTC',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_preferences_categories_check check (
    jsonb_typeof(categories) = 'object'
    and categories - array[
      'application_updates', 'job_updates', 'schedule_changes',
      'new_messages', 'work_reminders', 'support_updates',
      'guardian_updates', 'verification_updates', 'dispute_updates'
    ] = '{}'::jsonb
    and jsonb_typeof(categories -> 'application_updates') = 'boolean'
    and jsonb_typeof(categories -> 'job_updates') = 'boolean'
    and jsonb_typeof(categories -> 'schedule_changes') = 'boolean'
    and jsonb_typeof(categories -> 'new_messages') = 'boolean'
    and jsonb_typeof(categories -> 'work_reminders') = 'boolean'
    and jsonb_typeof(categories -> 'support_updates') = 'boolean'
    and jsonb_typeof(categories -> 'guardian_updates') = 'boolean'
    and jsonb_typeof(categories -> 'verification_updates') = 'boolean'
    and jsonb_typeof(categories -> 'dispute_updates') = 'boolean'
  )
);

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

alter table public.notification_preferences enable row level security;
alter table public.notification_preferences force row level security;
revoke all on public.notification_preferences from public, anon, authenticated;
grant all on public.notification_preferences to service_role;

create table public.push_device_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  client_request_id uuid not null,
  action text not null check (action in ('register', 'unregister_local', 'unregister_all')),
  payload_sha256 text not null check (payload_sha256 ~ '^[a-f0-9]{64}$'),
  safe_response jsonb not null check (jsonb_typeof(safe_response) = 'object'),
  created_at timestamptz not null default now(),
  unique(user_id, client_request_id)
);

alter table public.push_device_requests enable row level security;
alter table public.push_device_requests force row level security;
revoke all on public.push_device_requests from public, anon, authenticated;
grant all on public.push_device_requests to service_role;

create table public.push_delivery_runtime (
  singleton boolean primary key default true check (singleton),
  provider text not null default 'fcm' check (provider = 'fcm'),
  remote_push_enabled boolean not null default false,
  maximum_attempts integer not null default 5 check (maximum_attempts between 1 and 10),
  stale_token_days integer not null default 60 check (stale_token_days between 7 and 365),
  updated_at timestamptz not null default now()
);

insert into public.push_delivery_runtime (singleton)
values (true)
on conflict (singleton) do nothing;

alter table public.push_delivery_runtime enable row level security;
alter table public.push_delivery_runtime force row level security;
revoke all on public.push_delivery_runtime from public, anon, authenticated;
grant all on public.push_delivery_runtime to service_role;

alter table public.notification_events
  add column if not exists notification_type text not null default 'general_update',
  add column if not exists sensitivity text not null default 'standard',
  add column if not exists next_attempt_at timestamptz not null default now(),
  add column if not exists processing_started_at timestamptz,
  add column if not exists attempt_count integer not null default 0,
  add column if not exists completed_at timestamptz,
  drop constraint if exists notification_events_type_check,
  add constraint notification_events_type_check check (notification_type in (
    'application_update', 'job_update', 'schedule_change', 'new_message',
    'start_time_reminder', 'checkin_reminder', 'completion_reminder',
    'support_ticket_update', 'safety_alert', 'guardian_update',
    'verification_update', 'dispute_update', 'account_security_alert',
    'general_update'
  )),
  drop constraint if exists notification_events_sensitivity_check,
  add constraint notification_events_sensitivity_check check (
    sensitivity in ('standard', 'sensitive', 'urgent')
  ),
  drop constraint if exists notification_events_attempt_count_check,
  add constraint notification_events_attempt_count_check check (
    attempt_count between 0 and 10
  );

create index if not exists notification_events_delivery_queue_idx
on public.notification_events(next_attempt_at, created_at)
where status = 'pending';

revoke insert, update, delete on public.notification_events from authenticated;
grant select on public.notification_events to authenticated;
drop policy if exists notification_events_update_admin on public.notification_events;

create table public.push_delivery_attempts (
  id uuid primary key default extensions.gen_random_uuid(),
  notification_event_id uuid not null references public.notification_events(id) on delete cascade,
  push_token_id uuid references public.push_tokens(id) on delete set null,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (provider = 'fcm'),
  outcome text not null check (outcome in (
    'sent', 'transient_failure', 'permanent_failure', 'invalid_token',
    'suppressed_preference', 'suppressed_quiet_hours', 'no_active_token'
  )),
  error_code text check (
    error_code is null or error_code ~ '^[a-z][a-z0-9_]{2,63}$'
  ),
  provider_message_sha256 text check (
    provider_message_sha256 is null or provider_message_sha256 ~ '^[a-f0-9]{64}$'
  ),
  latency_ms integer check (latency_ms is null or latency_ms between 0 and 120000),
  created_at timestamptz not null default now()
);

create index push_delivery_attempts_event_idx
on public.push_delivery_attempts(notification_event_id, created_at);
create index push_delivery_attempts_outcome_idx
on public.push_delivery_attempts(outcome, created_at desc);

alter table public.push_delivery_attempts enable row level security;
alter table public.push_delivery_attempts force row level security;
revoke all on public.push_delivery_attempts from public, anon, authenticated;
grant all on public.push_delivery_attempts to service_role;

create table private.push_rate_limits (
  user_id uuid not null references public.profiles(id) on delete cascade,
  action text not null,
  window_started_at timestamptz not null,
  event_count integer not null check (event_count between 1 and 1000),
  primary key(user_id, action, window_started_at)
);

alter table private.push_rate_limits enable row level security;
alter table private.push_rate_limits force row level security;
revoke all on private.push_rate_limits from public, anon, authenticated;
grant all on private.push_rate_limits to service_role;

create or replace function private.take_push_rate_limit(
  p_user_id uuid,
  p_action text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  window_start timestamptz;
  count_after integer;
begin
  if p_limit not between 1 and 1000 or p_window_seconds not between 1 and 86400 then
    return false;
  end if;
  window_start := to_timestamp(
    floor(extract(epoch from clock_timestamp()) / p_window_seconds) * p_window_seconds
  );
  insert into private.push_rate_limits(user_id, action, window_started_at, event_count)
  values (p_user_id, p_action, window_start, 1)
  on conflict (user_id, action, window_started_at) do update
  set event_count = private.push_rate_limits.event_count + 1
  returning event_count into count_after;
  return count_after <= p_limit;
end;
$$;

create or replace function private.valid_timezone(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(select 1 from pg_catalog.pg_timezone_names where name = p_name)
$$;

create or replace function private.push_category_key(p_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_type
    when 'application_update' then 'application_updates'
    when 'job_update' then 'job_updates'
    when 'schedule_change' then 'schedule_changes'
    when 'new_message' then 'new_messages'
    when 'start_time_reminder' then 'work_reminders'
    when 'checkin_reminder' then 'work_reminders'
    when 'completion_reminder' then 'work_reminders'
    when 'support_ticket_update' then 'support_updates'
    when 'guardian_update' then 'guardian_updates'
    when 'verification_update' then 'verification_updates'
    when 'dispute_update' then 'dispute_updates'
    else null
  end
$$;

create or replace function private.push_quiet_until(
  p_preferences public.notification_preferences,
  p_type text,
  p_now timestamptz default now()
)
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  local_now timestamp;
  local_time time;
  local_end timestamp;
begin
  if not p_preferences.quiet_hours_enabled
     or p_type in ('safety_alert', 'account_security_alert')
     or p_preferences.quiet_start = p_preferences.quiet_end then
    return null;
  end if;
  local_now := timezone(p_preferences.timezone_name, p_now);
  local_time := local_now::time;
  if p_preferences.quiet_start < p_preferences.quiet_end then
    if local_time < p_preferences.quiet_start or local_time >= p_preferences.quiet_end then
      return null;
    end if;
    local_end := local_now::date + p_preferences.quiet_end;
  else
    if local_time >= p_preferences.quiet_start then
      local_end := (local_now::date + 1) + p_preferences.quiet_end;
    elsif local_time < p_preferences.quiet_end then
      local_end := local_now::date + p_preferences.quiet_end;
    else
      return null;
    end if;
  end if;
  return local_end at time zone p_preferences.timezone_name;
end;
$$;

create or replace function private.safe_push_data(p_type text, p_data jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  result jsonb := jsonb_build_object('type', p_type);
  key text;
  value text;
begin
  if jsonb_typeof(coalesce(p_data, '{}'::jsonb)) <> 'object' then
    return result;
  end if;
  foreach key in array array[
    'threadId', 'supportTicketId', 'reviewId', 'guardianLinkId',
    'applicationId', 'jobId', 'safetyPingId', 'verificationId', 'disputeId'
  ] loop
    value := p_data ->> key;
    if value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
      result := result || jsonb_build_object(key, lower(value));
    end if;
  end loop;
  return result;
end;
$$;

create or replace function private.normalize_notification_event()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.notification_type = 'general_update' then
    new.notification_type := case
      when new.data ? 'threadId' then 'new_message'
      when new.data ? 'supportTicketId' then 'support_ticket_update'
      when new.data ? 'safetyPingId' then 'safety_alert'
      when new.data ? 'verificationId' then 'verification_update'
      when new.data ? 'disputeId' then 'dispute_update'
      when new.data ? 'guardianLinkId' then 'guardian_update'
      when new.data ? 'applicationId' then 'application_update'
      when new.data ? 'jobId' then 'job_update'
      else 'general_update'
    end;
  end if;
  new.sensitivity := case
    when new.notification_type = 'safety_alert' then 'urgent'
    when new.notification_type in (
      'new_message', 'support_ticket_update', 'verification_update',
      'dispute_update', 'account_security_alert'
    ) then 'sensitive'
    else 'standard'
  end;
  new.data := private.safe_push_data(new.notification_type, new.data);
  return new;
end;
$$;

drop trigger if exists notification_events_normalize on public.notification_events;
create trigger notification_events_normalize
before insert or update of notification_type, data on public.notification_events
for each row execute function private.normalize_notification_event();

update public.notification_events
set notification_type = 'general_update', data = data;

create or replace function public.get_my_notification_preferences()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  preferences public.notification_preferences%rowtype;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  insert into public.notification_preferences(user_id)
  values (actor)
  on conflict (user_id) do nothing;
  select * into preferences from public.notification_preferences where user_id = actor;
  return jsonb_build_object(
    'ok', true,
    'preferences', jsonb_build_object(
      'push_enabled', preferences.push_enabled,
      'categories', preferences.categories,
      'quiet_hours_enabled', preferences.quiet_hours_enabled,
      'quiet_start', preferences.quiet_start,
      'quiet_end', preferences.quiet_end,
      'timezone_name', preferences.timezone_name,
      'updated_at', preferences.updated_at
    )
  );
end;
$$;

create or replace function public.update_my_notification_preferences(
  p_push_enabled boolean,
  p_categories jsonb,
  p_quiet_hours_enabled boolean,
  p_quiet_start time,
  p_quiet_end time,
  p_timezone_name text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  preferences public.notification_preferences%rowtype;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.take_push_rate_limit(actor, 'preference_update', 20, 3600) then
    return jsonb_build_object('ok', false, 'code', 'notification_preference_rate_limited');
  end if;
  if jsonb_typeof(coalesce(p_categories, 'null'::jsonb)) <> 'object'
     or exists (
       select 1 from jsonb_each(p_categories) item
       where item.key not in (
         'application_updates', 'job_updates', 'schedule_changes',
         'new_messages', 'work_reminders', 'support_updates',
         'guardian_updates', 'verification_updates', 'dispute_updates'
       ) or jsonb_typeof(item.value) <> 'boolean'
     )
     or not private.valid_timezone(p_timezone_name) then
    return jsonb_build_object('ok', false, 'code', 'invalid_notification_preferences');
  end if;
  insert into public.notification_preferences(
    user_id, push_enabled, categories, quiet_hours_enabled,
    quiet_start, quiet_end, timezone_name
  ) values (
    actor, p_push_enabled, p_categories, p_quiet_hours_enabled,
    p_quiet_start, p_quiet_end, p_timezone_name
  )
  on conflict (user_id) do update set
    push_enabled = excluded.push_enabled,
    categories = excluded.categories,
    quiet_hours_enabled = excluded.quiet_hours_enabled,
    quiet_start = excluded.quiet_start,
    quiet_end = excluded.quiet_end,
    timezone_name = excluded.timezone_name
  returning * into preferences;
  return jsonb_build_object('ok', true, 'preferences', jsonb_build_object(
    'push_enabled', preferences.push_enabled,
    'categories', preferences.categories,
    'quiet_hours_enabled', preferences.quiet_hours_enabled,
    'quiet_start', preferences.quiet_start,
    'quiet_end', preferences.quiet_end,
    'timezone_name', preferences.timezone_name,
    'updated_at', preferences.updated_at
  ));
end;
$$;

create or replace function public.register_my_push_device_v2(
  p_device_id uuid,
  p_provider text,
  p_registration_token text,
  p_platform text,
  p_permission_status text,
  p_app_version text,
  p_locale text,
  p_timezone_name text,
  p_environment text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  payload_hash text;
  prior public.push_device_requests%rowtype;
  token public.push_tokens%rowtype;
  response jsonb;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  payload_hash := encode(extensions.digest(concat_ws('|', p_device_id, p_provider,
    p_registration_token, p_platform, p_permission_status, p_app_version,
    p_locale, p_timezone_name, p_environment), 'sha256'), 'hex');
  select * into prior from public.push_device_requests
  where user_id = actor and client_request_id = p_client_request_id;
  if prior.id is not null then
    if prior.payload_sha256 <> payload_hash or prior.action <> 'register' then
      return jsonb_build_object('ok', false, 'code', 'push_request_id_reused');
    end if;
    return prior.safe_response || jsonb_build_object('replayed', true);
  end if;
  if p_provider <> 'fcm'
     or p_platform not in ('android', 'ios')
     or p_permission_status not in ('authorized', 'provisional')
     or char_length(coalesce(p_registration_token, '')) not between 20 and 4096
     or p_registration_token !~ '^[A-Za-z0-9_:\-]+$'
     or char_length(coalesce(p_app_version, '')) not between 1 and 40
     or p_locale !~ '^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})?$'
     or p_environment not in (
       'development', 'internal_test', 'closed_test',
       'production_pilot', 'production_public'
     )
     or not private.valid_timezone(p_timezone_name)
     or not exists (
       select 1 from public.profiles profile
       where profile.id = actor and profile.account_status = 'active'
     )
     or exists (
       select 1 from public.account_deletion_requests request
       where request.user_id = actor
         and request.status in ('requested', 'processing', 'retry_pending')
     ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_push_registration');
  end if;
  if not private.take_push_rate_limit(actor, 'device_register', 20, 3600) then
    return jsonb_build_object('ok', false, 'code', 'push_registration_rate_limited');
  end if;

  select * into token from public.push_tokens item
  where item.provider = 'fcm' and item.registration_token = p_registration_token
  for update;
  if token.id is not null then
    update public.push_tokens item set
      user_id = actor, device_id = p_device_id, platform = p_platform,
      permission_status = p_permission_status, app_version = p_app_version,
      locale = p_locale, timezone_name = p_timezone_name,
      environment = p_environment, is_active = true, last_error = null,
      last_registered_at = now(), last_seen_at = now(), deactivated_at = null
    where item.id = token.id
    returning * into token;
  else
    select * into token from public.push_tokens item
    where item.user_id = actor and item.device_id = p_device_id and item.provider = 'fcm'
    for update;
    if token.id is not null then
      update public.push_tokens item set
        registration_token = p_registration_token, platform = p_platform,
        permission_status = p_permission_status, app_version = p_app_version,
        locale = p_locale, timezone_name = p_timezone_name,
        environment = p_environment, is_active = true, last_error = null,
        last_registered_at = now(), last_seen_at = now(), deactivated_at = null
      where item.id = token.id
      returning * into token;
    else
      insert into public.push_tokens(
        user_id, provider, registration_token, token_sha256, device_id,
        platform, permission_status, app_version, locale, timezone_name,
        environment, is_active, last_registered_at, last_seen_at
      ) values (
        actor, 'fcm', p_registration_token,
        encode(extensions.digest(p_registration_token, 'sha256'), 'hex'),
        p_device_id, p_platform, p_permission_status, p_app_version,
        p_locale, p_timezone_name, p_environment, true, now(), now()
      ) returning * into token;
    end if;
  end if;
  update public.push_tokens item
  set is_active = false, deactivated_at = now(), last_error = 'token_rotated'
  where item.user_id = actor and item.provider = 'fcm'
    and item.device_id = p_device_id and item.id <> token.id and item.is_active;
  insert into public.notification_preferences(user_id, push_enabled, timezone_name)
  values (actor, true, p_timezone_name)
  on conflict (user_id) do update set push_enabled = true,
    timezone_name = excluded.timezone_name;
  response := jsonb_build_object(
    'ok', true, 'replayed', false,
    'device', jsonb_build_object(
      'id', token.id, 'device_id', token.device_id, 'provider', token.provider,
      'platform', token.platform, 'is_active', token.is_active,
      'last_registered_at', token.last_registered_at
    )
  );
  insert into public.push_device_requests(
    user_id, client_request_id, action, payload_sha256, safe_response
  ) values (actor, p_client_request_id, 'register', payload_hash, response);
  return response;
end;
$$;

create or replace function public.unregister_my_push_devices_v2(
  p_device_id uuid,
  p_all_devices boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  action_name text := case when p_all_devices then 'unregister_all' else 'unregister_local' end;
  payload_hash text;
  prior public.push_device_requests%rowtype;
  affected integer;
  response jsonb;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  payload_hash := encode(extensions.digest(concat_ws('|', p_device_id, p_all_devices), 'sha256'), 'hex');
  select * into prior from public.push_device_requests
  where user_id = actor and client_request_id = p_client_request_id;
  if prior.id is not null then
    if prior.payload_sha256 <> payload_hash or prior.action <> action_name then
      return jsonb_build_object('ok', false, 'code', 'push_request_id_reused');
    end if;
    return prior.safe_response || jsonb_build_object('replayed', true);
  end if;
  if not private.take_push_rate_limit(actor, 'device_unregister', 20, 3600) then
    return jsonb_build_object('ok', false, 'code', 'push_unregister_rate_limited');
  end if;
  update public.push_tokens item
  set is_active = false, deactivated_at = now(), last_error = 'user_unregistered'
  where item.user_id = actor and item.is_active
    and (p_all_devices or item.device_id = p_device_id);
  get diagnostics affected = row_count;
  if p_all_devices then
    update public.notification_preferences set push_enabled = false where user_id = actor;
  end if;
  response := jsonb_build_object(
    'ok', true, 'replayed', false, 'deactivated_count', affected,
    'scope', case when p_all_devices then 'all_devices' else 'local_device' end
  );
  insert into public.push_device_requests(
    user_id, client_request_id, action, payload_sha256, safe_response
  ) values (actor, p_client_request_id, action_name, payload_hash, response);
  return response;
end;
$$;

create or replace function public.get_my_push_status()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  preferences public.notification_preferences%rowtype;
  active_count integer;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  insert into public.notification_preferences(user_id) values (actor)
  on conflict (user_id) do nothing;
  select * into preferences from public.notification_preferences where user_id = actor;
  select count(*)::integer into active_count from public.push_tokens item
  where item.user_id = actor and item.provider = 'fcm' and item.is_active;
  return jsonb_build_object(
    'ok', true,
    'remote_push_enabled', preferences.push_enabled,
    'active_device_count', active_count,
    'provider', 'fcm',
    'provider_delivery_verified', false
  );
end;
$$;

create or replace function public.service_get_push_runtime()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  runtime public.push_delivery_runtime%rowtype;
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  select * into runtime from public.push_delivery_runtime where singleton = true;
  return jsonb_build_object(
    'ok', true, 'provider', runtime.provider,
    'remote_push_enabled', runtime.remote_push_enabled,
    'maximum_attempts', runtime.maximum_attempts,
    'stale_token_days', runtime.stale_token_days
  );
end;
$$;

create or replace function public.service_claim_push_events(
  p_limit integer default 25,
  p_notification_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  runtime public.push_delivery_runtime%rowtype;
  event public.notification_events%rowtype;
  preferences public.notification_preferences%rowtype;
  quiet_until timestamptz;
  category_key text;
  targets jsonb;
  events jsonb := '[]'::jsonb;
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  if p_limit not between 1 and 100 then
    return jsonb_build_object('ok', false, 'code', 'invalid_batch_size');
  end if;
  select * into runtime from public.push_delivery_runtime where singleton = true;
  if not runtime.remote_push_enabled then
    return jsonb_build_object(
      'ok', true, 'provider', runtime.provider,
      'remote_push_enabled', false, 'events', events
    );
  end if;

  for event in
    select item.* from public.notification_events item
    where item.status = 'pending'
      and (p_notification_id is null or item.id = p_notification_id)
      and item.next_attempt_at <= now()
      and item.attempt_count < runtime.maximum_attempts
      and (
        item.processing_started_at is null
        or item.processing_started_at < now() - interval '10 minutes'
      )
    order by case when item.sensitivity = 'urgent' then 0 else 1 end,
      item.created_at
    for update skip locked
    limit p_limit
  loop
    insert into public.notification_preferences(user_id)
    values (event.recipient_id) on conflict (user_id) do nothing;
    select * into preferences from public.notification_preferences
    where user_id = event.recipient_id;
    category_key := private.push_category_key(event.notification_type);
    if not preferences.push_enabled
       or (category_key is not null and coalesce((preferences.categories ->> category_key)::boolean, true) = false) then
      update public.notification_events set status = 'failed', completed_at = now(),
        last_error = 'suppressed_by_preference', processing_started_at = null
      where id = event.id;
      insert into public.push_delivery_attempts(
        notification_event_id, recipient_id, provider, outcome, error_code
      ) values (
        event.id, event.recipient_id, 'fcm', 'suppressed_preference',
        'suppressed_by_preference'
      );
      continue;
    end if;
    quiet_until := private.push_quiet_until(preferences, event.notification_type, now());
    if quiet_until is not null then
      update public.notification_events set next_attempt_at = quiet_until,
        processing_started_at = null, last_error = 'deferred_quiet_hours'
      where id = event.id;
      insert into public.push_delivery_attempts(
        notification_event_id, recipient_id, provider, outcome, error_code
      ) values (
        event.id, event.recipient_id, 'fcm', 'suppressed_quiet_hours',
        'deferred_quiet_hours'
      );
      continue;
    end if;
    select coalesce(jsonb_agg(jsonb_build_object(
      'token_id', item.id,
      'registration_token', item.registration_token,
      'platform', item.platform
    )), '[]'::jsonb) into targets
    from public.push_tokens item
    where item.user_id = event.recipient_id and item.provider = 'fcm'
      and item.is_active
      and item.last_seen_at >= now() - make_interval(days => runtime.stale_token_days);
    if jsonb_array_length(targets) = 0 then
      update public.notification_events set status = 'failed', completed_at = now(),
        last_error = 'no_active_push_token', processing_started_at = null
      where id = event.id;
      insert into public.push_delivery_attempts(
        notification_event_id, recipient_id, provider, outcome, error_code
      ) values (
        event.id, event.recipient_id, 'fcm', 'no_active_token',
        'no_active_push_token'
      );
      continue;
    end if;
    update public.notification_events set processing_started_at = now(),
      attempt_count = attempt_count + 1, last_error = null
    where id = event.id;
    events := events || jsonb_build_array(jsonb_build_object(
      'id', event.id,
      'recipient_id', event.recipient_id,
      'notification_type', event.notification_type,
      'sensitivity', event.sensitivity,
      'safe_data', private.safe_push_data(event.notification_type, event.data),
      'targets', targets
    ));
  end loop;
  return jsonb_build_object(
    'ok', true, 'provider', runtime.provider,
    'remote_push_enabled', true, 'events', events
  );
end;
$$;

create or replace function public.service_complete_push_event(
  p_event_id uuid,
  p_results jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  event public.notification_events%rowtype;
  result jsonb;
  token public.push_tokens%rowtype;
  outcome text;
  error_code text;
  message_id text;
  latency integer;
  sent_count integer := 0;
  transient_count integer := 0;
  permanent_count integer := 0;
  maximum_attempts integer;
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  if jsonb_typeof(p_results) <> 'array' or jsonb_array_length(p_results) not between 1 and 50 then
    return jsonb_build_object('ok', false, 'code', 'invalid_delivery_results');
  end if;
  select * into event from public.notification_events item
  where item.id = p_event_id and item.status = 'pending'
    and item.processing_started_at is not null
  for update;
  if event.id is null then
    return jsonb_build_object('ok', false, 'code', 'push_event_not_claimed');
  end if;
  select runtime.maximum_attempts into maximum_attempts
  from public.push_delivery_runtime runtime where singleton = true;
  for result in select value from jsonb_array_elements(p_results)
  loop
    outcome := result ->> 'outcome';
    error_code := lower(coalesce(result ->> 'error_code', ''));
    message_id := result ->> 'provider_message_id';
    latency := nullif(result ->> 'latency_ms', '')::integer;
    if outcome not in ('sent', 'transient_failure', 'permanent_failure', 'invalid_token')
       or (error_code <> '' and error_code !~ '^[a-z][a-z0-9_]{2,63}$')
       or latency is not null and latency not between 0 and 120000 then
      raise exception 'invalid_delivery_result';
    end if;
    select * into token from public.push_tokens item
    where item.id = (result ->> 'token_id')::uuid
      and item.user_id = event.recipient_id and item.provider = 'fcm';
    if token.id is null then raise exception 'push_token_scope_mismatch'; end if;
    insert into public.push_delivery_attempts(
      notification_event_id, push_token_id, recipient_id, provider, outcome,
      error_code, provider_message_sha256, latency_ms
    ) values (
      event.id, token.id, event.recipient_id, 'fcm', outcome,
      nullif(error_code, ''),
      case when message_id is null or message_id = '' then null
        else encode(extensions.digest(message_id, 'sha256'), 'hex') end,
      latency
    );
    if outcome = 'sent' then
      sent_count := sent_count + 1;
      update public.push_tokens set last_error = null, last_seen_at = now()
      where id = token.id;
    elsif outcome = 'transient_failure' then
      transient_count := transient_count + 1;
      update public.push_tokens set last_error = nullif(error_code, '')
      where id = token.id;
    else
      permanent_count := permanent_count + 1;
      update public.push_tokens set last_error = nullif(error_code, ''),
        is_active = case when outcome = 'invalid_token' then false else is_active end,
        deactivated_at = case when outcome = 'invalid_token' then now() else deactivated_at end
      where id = token.id;
    end if;
  end loop;
  if sent_count > 0 then
    update public.notification_events set status = 'sent', sent_at = now(),
      completed_at = now(), processing_started_at = null, last_error = null
    where id = event.id;
  elsif transient_count > 0 and event.attempt_count < maximum_attempts then
    update public.notification_events set processing_started_at = null,
      next_attempt_at = now() + make_interval(secs => least(3600, 30 * (2 ^ event.attempt_count)::integer)),
      last_error = 'provider_transient_failure'
    where id = event.id;
  else
    update public.notification_events set status = 'failed', completed_at = now(),
      processing_started_at = null,
      last_error = case when permanent_count > 0 then 'provider_permanent_failure'
        else 'provider_retry_exhausted' end
    where id = event.id;
  end if;
  return jsonb_build_object(
    'ok', true, 'sent', sent_count, 'transient_failed', transient_count,
    'permanent_failed', permanent_count
  );
exception when invalid_text_representation or numeric_value_out_of_range then
  return jsonb_build_object('ok', false, 'code', 'invalid_delivery_results');
end;
$$;

create or replace function private.deactivate_push_on_deletion_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.user_id is not null
     and new.status in ('requested', 'processing', 'retry_pending') then
    update public.push_tokens set is_active = false, deactivated_at = now(),
      last_error = 'account_deletion_requested'
    where user_id = new.user_id and is_active;
    update public.notification_preferences set push_enabled = false
    where user_id = new.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists account_deletion_deactivate_push on public.account_deletion_requests;
create trigger account_deletion_deactivate_push
after insert or update of status on public.account_deletion_requests
for each row execute function private.deactivate_push_on_deletion_request();

do $$
declare
  signature text;
begin
  foreach signature in array array[
    'public.get_my_notification_preferences()',
    'public.update_my_notification_preferences(boolean,jsonb,boolean,time without time zone,time without time zone,text)',
    'public.register_my_push_device_v2(uuid,text,text,text,text,text,text,text,text,uuid)',
    'public.unregister_my_push_devices_v2(uuid,boolean,uuid)',
    'public.get_my_push_status()',
    'public.service_get_push_runtime()',
    'public.service_claim_push_events(integer,uuid)',
    'public.service_complete_push_event(uuid,jsonb)'
  ] loop
    execute format('revoke all on function %s from public, anon', signature);
  end loop;
end;
$$;

grant execute on function public.get_my_notification_preferences()
to authenticated, service_role;
grant execute on function public.update_my_notification_preferences(boolean, jsonb, boolean, time, time, text)
to authenticated, service_role;
grant execute on function public.register_my_push_device_v2(uuid, text, text, text, text, text, text, text, text, uuid)
to authenticated, service_role;
grant execute on function public.unregister_my_push_devices_v2(uuid, boolean, uuid)
to authenticated, service_role;
grant execute on function public.get_my_push_status()
to authenticated, service_role;
revoke all on function public.service_get_push_runtime() from authenticated;
revoke all on function public.service_claim_push_events(integer, uuid) from authenticated;
revoke all on function public.service_complete_push_event(uuid, jsonb) from authenticated;
grant execute on function public.service_get_push_runtime() to service_role;
grant execute on function public.service_claim_push_events(integer, uuid) to service_role;
grant execute on function public.service_complete_push_event(uuid, jsonb) to service_role;
