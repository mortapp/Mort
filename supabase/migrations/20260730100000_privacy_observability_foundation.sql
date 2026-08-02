-- Phase 10: consent-gated first-party analytics and privacy-minimized client
-- reliability telemetry. External crash export remains a build-time kill switch.

create table public.analytics_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  product_analytics_opt_in boolean not null default false,
  consent_version text,
  consented_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint analytics_preferences_consent_check check (
    (product_analytics_opt_in and consent_version ~ '^analytics-[0-9]{4}-[0-9]{2}$' and consented_at is not null)
    or (not product_analytics_opt_in and consent_version is null and consented_at is null)
  )
);

create trigger analytics_preferences_set_updated_at
before update on public.analytics_preferences
for each row execute function public.set_updated_at();

alter table public.analytics_preferences enable row level security;
alter table public.analytics_preferences force row level security;
revoke all on public.analytics_preferences from public, anon, authenticated;
grant all on public.analytics_preferences to service_role;

create table private.product_analytics_events (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  client_request_id uuid not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[a-f0-9]{64}$'),
  event_name text not null check (event_name in (
    'screen_view', 'onboarding_step_completed', 'job_feed_opened',
    'job_application_started', 'job_application_completed',
    'support_opened', 'safety_center_opened',
    'notification_settings_opened', 'auth_method_selected'
  )),
  surface text not null check (surface in (
    'auth', 'onboarding', 'home', 'jobs', 'applications', 'messages',
    'safety', 'guardian', 'support', 'notifications', 'settings',
    'profile', 'admin', 'legal', 'unknown'
  )),
  outcome text check (outcome is null or outcome in (
    'opened', 'started', 'completed', 'cancelled', 'failed', 'unknown'
  )),
  platform text not null check (platform in ('android', 'ios', 'web', 'unknown')),
  app_version text not null check (app_version ~ '^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$'),
  release_stage text not null check (release_stage in (
    'development', 'internal_test', 'closed_test',
    'production_pilot', 'production_public'
  )),
  occurred_at timestamptz not null default now(),
  unique(user_id, client_request_id)
);

create index product_analytics_event_time_idx
on private.product_analytics_events(event_name, occurred_at desc);

alter table private.product_analytics_events enable row level security;
alter table private.product_analytics_events force row level security;
revoke all on private.product_analytics_events from public, anon, authenticated;
grant all on private.product_analytics_events to service_role;

create table private.client_operational_events (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  client_request_id uuid not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[a-f0-9]{64}$'),
  event_type text not null check (event_type in (
    'api_failure', 'auth_failure', 'job_transition_failure',
    'pin_failure', 'message_delivery_failure', 'support_escalation',
    'deletion_failure', 'storage_failure'
  )),
  safe_code text not null check (safe_code ~ '^[a-z][a-z0-9_.-]{2,79}$'),
  correlation_id uuid not null,
  platform text not null check (platform in ('android', 'ios', 'web', 'unknown')),
  app_version text not null check (app_version ~ '^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$'),
  release_stage text not null check (release_stage in (
    'development', 'internal_test', 'closed_test',
    'production_pilot', 'production_public'
  )),
  occurred_at timestamptz not null default now(),
  unique(user_id, client_request_id)
);

create index client_operational_event_time_idx
on private.client_operational_events(event_type, occurred_at desc);

alter table private.client_operational_events enable row level security;
alter table private.client_operational_events force row level security;
revoke all on private.client_operational_events from public, anon, authenticated;
grant all on private.client_operational_events to service_role;

create table private.client_observability_rate_limits (
  user_id uuid not null references public.profiles(id) on delete cascade,
  action text not null check (action in ('product_analytics', 'operational_event')),
  window_started_at timestamptz not null,
  request_count integer not null check (request_count between 1 and 1000),
  primary key(user_id, action)
);

alter table private.client_observability_rate_limits enable row level security;
alter table private.client_observability_rate_limits force row level security;
revoke all on private.client_observability_rate_limits from public, anon, authenticated;
grant all on private.client_observability_rate_limits to service_role;

create or replace function private.take_client_observability_rate_limit(
  p_user_id uuid,
  p_action text,
  p_maximum integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  allowed boolean;
begin
  insert into private.client_observability_rate_limits(
    user_id, action, window_started_at, request_count
  ) values (p_user_id, p_action, now(), 1)
  on conflict (user_id, action) do update set
    window_started_at = case
      when private.client_observability_rate_limits.window_started_at
        <= now() - make_interval(secs => p_window_seconds)
      then now() else private.client_observability_rate_limits.window_started_at end,
    request_count = case
      when private.client_observability_rate_limits.window_started_at
        <= now() - make_interval(secs => p_window_seconds)
      then 1 else least(
        private.client_observability_rate_limits.request_count + 1,
        1000
      ) end
  returning request_count <= p_maximum into allowed;
  return allowed;
end;
$$;

revoke all on function private.take_client_observability_rate_limit(uuid, text, integer, integer)
from public, anon, authenticated;

create or replace function public.get_my_analytics_preferences()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  preference public.analytics_preferences%rowtype;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  insert into public.analytics_preferences(user_id) values (actor)
  on conflict (user_id) do nothing;
  select * into preference from public.analytics_preferences where user_id = actor;
  return jsonb_build_object(
    'ok', true,
    'product_analytics_opt_in', preference.product_analytics_opt_in,
    'consent_version', preference.consent_version,
    'consented_at', preference.consented_at,
    'updated_at', preference.updated_at
  );
end;
$$;

create or replace function public.update_my_analytics_preferences(
  p_product_analytics_opt_in boolean,
  p_consent_version text default 'analytics-2026-07'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_product_analytics_opt_in
     and p_consent_version !~ '^analytics-[0-9]{4}-[0-9]{2}$' then
    return jsonb_build_object('ok', false, 'code', 'invalid_analytics_consent');
  end if;
  insert into public.analytics_preferences(
    user_id, product_analytics_opt_in, consent_version, consented_at
  ) values (
    actor, p_product_analytics_opt_in,
    case when p_product_analytics_opt_in then p_consent_version else null end,
    case when p_product_analytics_opt_in then now() else null end
  )
  on conflict (user_id) do update set
    product_analytics_opt_in = excluded.product_analytics_opt_in,
    consent_version = excluded.consent_version,
    consented_at = excluded.consented_at;
  return jsonb_build_object(
    'ok', true, 'product_analytics_opt_in', p_product_analytics_opt_in
  );
end;
$$;

create or replace function public.record_my_product_analytics(
  p_event_name text,
  p_surface text,
  p_outcome text,
  p_platform text,
  p_app_version text,
  p_release_stage text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  opted_in boolean;
  payload_hash text;
  prior private.product_analytics_events%rowtype;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  payload_hash := encode(extensions.digest(concat_ws('|', p_event_name,
    p_surface, p_outcome, p_platform, p_app_version, p_release_stage), 'sha256'), 'hex');
  select * into prior from private.product_analytics_events
  where user_id = actor and client_request_id = p_client_request_id;
  if prior.id is not null then
    return jsonb_build_object(
      'ok', prior.payload_sha256 = payload_hash,
      'code', case when prior.payload_sha256 = payload_hash then 'analytics_replayed'
        else 'analytics_request_id_reused' end,
      'recorded', prior.payload_sha256 = payload_hash,
      'replayed', prior.payload_sha256 = payload_hash
    );
  end if;
  select product_analytics_opt_in into opted_in
  from public.analytics_preferences where user_id = actor;
  if not coalesce(opted_in, false) then
    return jsonb_build_object(
      'ok', true, 'code', 'analytics_opt_out', 'recorded', false
    );
  end if;
  if p_event_name not in (
       'screen_view', 'onboarding_step_completed', 'job_feed_opened',
       'job_application_started', 'job_application_completed',
       'support_opened', 'safety_center_opened',
       'notification_settings_opened', 'auth_method_selected'
     )
     or p_surface not in (
       'auth', 'onboarding', 'home', 'jobs', 'applications', 'messages',
       'safety', 'guardian', 'support', 'notifications', 'settings',
       'profile', 'admin', 'legal', 'unknown'
     )
     or (p_outcome is not null and p_outcome not in (
       'opened', 'started', 'completed', 'cancelled', 'failed', 'unknown'
     ))
     or p_platform not in ('android', 'ios', 'web', 'unknown')
     or p_app_version !~ '^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$'
     or p_release_stage not in (
       'development', 'internal_test', 'closed_test',
       'production_pilot', 'production_public'
     ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_analytics_event');
  end if;
  if not private.take_client_observability_rate_limit(
    actor, 'product_analytics', 120, 3600
  ) then
    return jsonb_build_object('ok', false, 'code', 'analytics_rate_limited');
  end if;
  insert into private.product_analytics_events(
    user_id, client_request_id, payload_sha256, event_name, surface,
    outcome, platform, app_version, release_stage
  ) values (
    actor, p_client_request_id, payload_hash, p_event_name, p_surface,
    p_outcome, p_platform, p_app_version, p_release_stage
  );
  return jsonb_build_object('ok', true, 'recorded', true, 'replayed', false);
end;
$$;

create or replace function public.record_my_client_operational_event(
  p_event_type text,
  p_safe_code text,
  p_correlation_id uuid,
  p_platform text,
  p_app_version text,
  p_release_stage text,
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
  prior private.client_operational_events%rowtype;
begin
  if actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  payload_hash := encode(extensions.digest(concat_ws('|', p_event_type,
    p_safe_code, p_correlation_id, p_platform, p_app_version, p_release_stage), 'sha256'), 'hex');
  select * into prior from private.client_operational_events
  where user_id = actor and client_request_id = p_client_request_id;
  if prior.id is not null then
    return jsonb_build_object(
      'ok', prior.payload_sha256 = payload_hash,
      'code', case when prior.payload_sha256 = payload_hash then 'operational_event_replayed'
        else 'operational_request_id_reused' end,
      'recorded', prior.payload_sha256 = payload_hash,
      'replayed', prior.payload_sha256 = payload_hash
    );
  end if;
  if p_event_type not in (
       'api_failure', 'auth_failure', 'job_transition_failure',
       'pin_failure', 'message_delivery_failure', 'support_escalation',
       'deletion_failure', 'storage_failure'
     )
     or p_safe_code !~ '^[a-z][a-z0-9_.-]{2,79}$'
     or p_correlation_id is null
     or p_platform not in ('android', 'ios', 'web', 'unknown')
     or p_app_version !~ '^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$'
     or p_release_stage not in (
       'development', 'internal_test', 'closed_test',
       'production_pilot', 'production_public'
     ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_operational_event');
  end if;
  if not private.take_client_observability_rate_limit(
    actor, 'operational_event', 60, 3600
  ) then
    return jsonb_build_object('ok', false, 'code', 'operational_event_rate_limited');
  end if;
  insert into private.client_operational_events(
    user_id, client_request_id, payload_sha256, event_type, safe_code,
    correlation_id, platform, app_version, release_stage
  ) values (
    actor, p_client_request_id, payload_hash, p_event_type, p_safe_code,
    p_correlation_id, p_platform, p_app_version, p_release_stage
  );
  return jsonb_build_object('ok', true, 'recorded', true, 'replayed', false);
end;
$$;

create or replace function public.get_admin_observability_dashboard(
  p_window_hours integer default 24
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  since_at timestamptz;
  client_failures jsonb;
  push_outcomes jsonb;
  alerts jsonb;
  analytics_events integer;
  analytics_opted_in integer;
begin
  if not private.can_review_operational_alerts(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'operational_review_role_required');
  end if;
  if p_window_hours not between 1 and 720 then
    return jsonb_build_object('ok', false, 'code', 'invalid_observability_window');
  end if;
  since_at := now() - make_interval(hours => p_window_hours);
  select coalesce(jsonb_object_agg(grouped.event_type, grouped.total), '{}'::jsonb)
  into client_failures from (
    select event_type, count(*)::integer as total
    from private.client_operational_events
    where occurred_at >= since_at group by event_type
  ) grouped;
  select coalesce(jsonb_object_agg(grouped.outcome, grouped.total), '{}'::jsonb)
  into push_outcomes from (
    select outcome, count(*)::integer as total
    from public.push_delivery_attempts
    where created_at >= since_at group by outcome
  ) grouped;
  select coalesce(jsonb_object_agg(grouped.category, grouped.total), '{}'::jsonb)
  into alerts from (
    select category, sum(occurrence_count)::integer as total
    from private.operational_alerts
    where last_observed_at >= since_at group by category
  ) grouped;
  select count(*)::integer into analytics_events
  from private.product_analytics_events where occurred_at >= since_at;
  select count(*)::integer into analytics_opted_in
  from public.analytics_preferences where product_analytics_opt_in;
  return jsonb_build_object(
    'ok', true,
    'generated_at', now(),
    'window_hours', p_window_hours,
    'crash_reporting', jsonb_build_object(
      'provider', 'external', 'crash_free_sessions', null,
      'reason', 'read_from_approved_crash_provider_dashboard'
    ),
    'client_failure_counts', client_failures,
    'push_delivery_outcomes', push_outcomes,
    'operational_alert_counts', alerts,
    'product_analytics_events', analytics_events,
    'analytics_opted_in_users', analytics_opted_in
  );
end;
$$;

create or replace function public.service_purge_observability_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  analytics_deleted integer;
  operational_deleted integer;
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  delete from private.product_analytics_events
  where occurred_at < now() - interval '30 days';
  get diagnostics analytics_deleted = row_count;
  delete from private.client_operational_events
  where occurred_at < now() - interval '90 days';
  get diagnostics operational_deleted = row_count;
  return jsonb_build_object(
    'ok', true,
    'analytics_deleted', analytics_deleted,
    'operational_deleted', operational_deleted
  );
end;
$$;

revoke all on function public.get_my_analytics_preferences() from public, anon;
revoke all on function public.update_my_analytics_preferences(boolean, text) from public, anon;
revoke all on function public.record_my_product_analytics(text, text, text, text, text, text, uuid) from public, anon;
revoke all on function public.record_my_client_operational_event(text, text, uuid, text, text, text, uuid) from public, anon;
revoke all on function public.get_admin_observability_dashboard(integer) from public, anon;
revoke all on function public.service_purge_observability_data() from public, anon, authenticated;

grant execute on function public.get_my_analytics_preferences()
to authenticated, service_role;
grant execute on function public.update_my_analytics_preferences(boolean, text)
to authenticated, service_role;
grant execute on function public.record_my_product_analytics(text, text, text, text, text, text, uuid)
to authenticated, service_role;
grant execute on function public.record_my_client_operational_event(text, text, uuid, text, text, text, uuid)
to authenticated, service_role;
grant execute on function public.get_admin_observability_dashboard(integer)
to authenticated, service_role;
grant execute on function public.service_purge_observability_data()
to service_role;

comment on table private.product_analytics_events is
  'Opt-in, first-party, fixed-taxonomy product events. No content, location, advertising IDs, or free-form metadata.';
comment on table private.client_operational_events is
  'Privacy-minimized reliability events with strict codes and finite retention; raw rows are service-only.';
