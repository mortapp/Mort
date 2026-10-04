-- Add only bounded, privacy-safe monetization funnel dimensions. No product
-- identifiers, suggestion identifiers, prices, free-form copy, or behavior
-- counts are accepted by this RPC.
alter table private.product_analytics_events
  drop constraint product_analytics_events_event_name_check,
  add constraint product_analytics_events_event_name_check check (event_name in (
    'screen_view', 'onboarding_step_completed', 'job_feed_opened',
    'job_application_started', 'job_application_completed',
    'support_opened', 'safety_center_opened',
    'notification_settings_opened', 'auth_method_selected',
    'premium_suggestion_impression', 'premium_suggestion_dismissed',
    'premium_suggestion_clicked', 'paywall_viewed', 'purchase_started',
    'purchase_completed', 'purchase_failed', 'purchase_restored'
  ));

alter table private.product_analytics_events
  drop constraint product_analytics_events_surface_check,
  add constraint product_analytics_events_surface_check check (surface in (
    'auth', 'onboarding', 'home', 'jobs', 'applications', 'messages',
    'safety', 'guardian', 'support', 'notifications', 'settings',
    'profile', 'admin', 'legal', 'progression', 'paywall', 'jobFeed',
    'applicationSuccess', 'jobCompletion', 'analytics', 'checkout',
    'unknown'
  ));

alter table private.product_analytics_events
  drop constraint product_analytics_events_outcome_check,
  add constraint product_analytics_events_outcome_check check (
    outcome is null or outcome in (
      'opened', 'started', 'completed', 'cancelled', 'failed', 'unknown',
      'displayed', 'dismissed', 'clicked', 'restored'
    )
  );

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
       'notification_settings_opened', 'auth_method_selected',
       'premium_suggestion_impression', 'premium_suggestion_dismissed',
       'premium_suggestion_clicked', 'paywall_viewed', 'purchase_started',
       'purchase_completed', 'purchase_failed', 'purchase_restored'
     )
     or p_surface not in (
       'auth', 'onboarding', 'home', 'jobs', 'applications', 'messages',
       'safety', 'guardian', 'support', 'notifications', 'settings',
       'profile', 'admin', 'legal', 'progression', 'paywall', 'jobFeed',
       'applicationSuccess', 'jobCompletion', 'analytics', 'checkout',
       'unknown'
     )
     or (p_outcome is not null and p_outcome not in (
       'opened', 'started', 'completed', 'cancelled', 'failed', 'unknown',
       'displayed', 'dismissed', 'clicked', 'restored'
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

revoke all on function public.record_my_product_analytics(
  text, text, text, text, text, text, uuid
) from public, anon;
grant execute on function public.record_my_product_analytics(
  text, text, text, text, text, text, uuid
) to authenticated, service_role;
