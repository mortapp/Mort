-- Keep push settings distinct from the server's actual ability to deliver.
-- A user preference or Firebase client config must not imply delivery is live.

create or replace function private.push_delivery_available()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce(public.get_release_mode_status() -> 'remote_push' = 'true'::jsonb, false)
    and exists (
      select 1 from public.push_delivery_runtime runtime
      where runtime.singleton = true and runtime.remote_push_enabled
    );
$$;

revoke all on function private.push_delivery_available() from public, anon, authenticated;

create or replace function public.get_push_delivery_availability()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'ok', true,
    'delivery_available', private.push_delivery_available()
  );
$$;

revoke all on function public.get_push_delivery_availability() from public;
grant execute on function public.get_push_delivery_availability() to anon, authenticated, service_role;

create or replace function public.get_my_push_status_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  status jsonb;
  preference_enabled boolean;
  delivery_available boolean;
begin
  status := public.get_my_push_status();
  if status ->> 'ok' <> 'true' then
    return status;
  end if;
  preference_enabled := coalesce(status ->> 'remote_push_enabled' = 'true', false);
  delivery_available := private.push_delivery_available();
  return status || jsonb_build_object(
    'push_preference_enabled', preference_enabled,
    'delivery_available', delivery_available,
    'remote_push_enabled', preference_enabled and delivery_available
  );
end;
$$;

revoke all on function public.get_my_push_status_v2() from public, anon;
grant execute on function public.get_my_push_status_v2() to authenticated, service_role;
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
  if not private.push_delivery_available() then
    return jsonb_build_object('ok', false, 'code', 'remote_push_disabled');
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
    'remote_push_enabled', private.push_delivery_available(),
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
  if not private.push_delivery_available() then
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

revoke all on function public.register_my_push_device_v2(uuid, text, text, text, text, text, text, text, text, uuid) from public, anon;
grant execute on function public.register_my_push_device_v2(uuid, text, text, text, text, text, text, text, text, uuid) to authenticated, service_role;