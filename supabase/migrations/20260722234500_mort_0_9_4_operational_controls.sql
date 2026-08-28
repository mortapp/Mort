-- MORT 0.9.4 emergency controls and redacted operational alert queues.
-- Provider webhooks remain writable during an emergency so existing events can
-- reconcile, while new publishing and provider-creation paths fail closed.

create table private.runtime_feature_controls (
  singleton boolean primary key default true check (singleton),
  maintenance_mode boolean not null default false,
  ai_provider_disabled boolean not null default true,
  payments_disabled boolean not null default true,
  new_job_publishing_disabled boolean not null default false,
  public_marketplace_closed boolean not null default true,
  updated_by uuid references auth.users(id) on delete set null,
  update_reason text not null default 'Initial fail-closed MORT 0.9.4 controls.',
  updated_at timestamptz not null default now(),
  constraint runtime_control_reason_check check (
    char_length(btrim(update_reason)) between 12 and 500
  ),
  constraint runtime_public_marketplace_closed_check check (
    public_marketplace_closed
  )
);

insert into private.runtime_feature_controls (singleton)
values (true)
on conflict (singleton) do nothing;

alter table private.runtime_feature_controls enable row level security;
alter table private.runtime_feature_controls force row level security;
revoke all on private.runtime_feature_controls from public, anon, authenticated;
grant all on private.runtime_feature_controls to service_role;

create or replace function private.runtime_feature_enabled(p_feature text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_feature
    when 'maintenance_mode' then control.maintenance_mode
    when 'ai_provider_disabled' then control.ai_provider_disabled
    when 'payments_disabled' then control.payments_disabled
    when 'new_job_publishing_disabled' then control.new_job_publishing_disabled
    when 'public_marketplace_closed' then control.public_marketplace_closed
    else true
  end
  from private.runtime_feature_controls control
  where control.singleton;
$$;

revoke all on function private.runtime_feature_enabled(text)
from public, anon, authenticated;
grant execute on function private.runtime_feature_enabled(text) to service_role;

create or replace function public.get_runtime_feature_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'ok', true,
    'maintenance_mode', control.maintenance_mode,
    'ai_provider_disabled', control.ai_provider_disabled,
    'payments_disabled', control.payments_disabled,
    'new_job_publishing_disabled', control.new_job_publishing_disabled,
    'public_marketplace_closed', control.public_marketplace_closed,
    'status_updated_at', control.updated_at,
    'maintenance_message', case
      when control.maintenance_mode then 'MORT is temporarily unavailable while safety or reliability work is completed.'
      else null
    end
  )
  from private.runtime_feature_controls control
  where control.singleton;
$$;

revoke all on function public.get_runtime_feature_status() from public;
grant execute on function public.get_runtime_feature_status() to anon, authenticated, service_role;

create or replace function public.admin_update_runtime_feature_controls(
  p_maintenance_mode boolean,
  p_ai_provider_disabled boolean,
  p_payments_disabled boolean,
  p_new_job_publishing_disabled boolean,
  p_public_marketplace_closed boolean,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_before private.runtime_feature_controls%rowtype;
  v_after private.runtime_feature_controls%rowtype;
begin
  if v_actor is null or not private.has_admin_safety_role(
    v_actor,
    array['incident_manager', 'super_admin']::public.admin_safety_role[]
  ) then
    return jsonb_build_object('ok', false, 'code', 'incident_manager_role_required');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 12 and 500 then
    return jsonb_build_object('ok', false, 'code', 'control_change_reason_required');
  end if;
  if not p_public_marketplace_closed then
    return jsonb_build_object('ok', false, 'code', 'public_marketplace_activation_not_authorized');
  end if;

  select * into v_before
  from private.runtime_feature_controls
  where singleton
  for update;

  update private.runtime_feature_controls
  set maintenance_mode = p_maintenance_mode,
      ai_provider_disabled = p_ai_provider_disabled,
      payments_disabled = p_payments_disabled,
      new_job_publishing_disabled = p_new_job_publishing_disabled,
      public_marketplace_closed = p_public_marketplace_closed,
      updated_by = v_actor,
      update_reason = btrim(p_reason),
      updated_at = now()
  where singleton
  returning * into v_after;

  insert into public.admin_action_logs (
    admin_id, action, target_table, details
  ) values (
    v_actor,
    'runtime_feature_controls_updated',
    'private.runtime_feature_controls',
    jsonb_build_object(
      'maintenance_mode', jsonb_build_array(v_before.maintenance_mode, v_after.maintenance_mode),
      'ai_provider_disabled', jsonb_build_array(v_before.ai_provider_disabled, v_after.ai_provider_disabled),
      'payments_disabled', jsonb_build_array(v_before.payments_disabled, v_after.payments_disabled),
      'new_job_publishing_disabled', jsonb_build_array(v_before.new_job_publishing_disabled, v_after.new_job_publishing_disabled),
      'public_marketplace_closed', jsonb_build_array(v_before.public_marketplace_closed, v_after.public_marketplace_closed),
      'reason', btrim(p_reason)
    )
  );

  return jsonb_build_object('ok', true, 'updated_at', v_after.updated_at);
end;
$$;

revoke all on function public.admin_update_runtime_feature_controls(
  boolean, boolean, boolean, boolean, boolean, text
) from public, anon;
grant execute on function public.admin_update_runtime_feature_controls(
  boolean, boolean, boolean, boolean, boolean, text
) to authenticated, service_role;

create or replace function private.enforce_runtime_job_publish_control()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_control private.runtime_feature_controls%rowtype;
  v_was_publishable boolean := false;
begin
  select * into v_control
  from private.runtime_feature_controls
  where singleton;

  if tg_op = 'UPDATE' then
    v_was_publishable := old.status::text in ('open', 'pending_review');
  end if;
  if new.status::text in ('open', 'pending_review') and not v_was_publishable then
    if v_control.maintenance_mode then
      raise exception 'maintenance_mode_active';
    end if;
    if v_control.new_job_publishing_disabled then
      raise exception 'new_job_publishing_disabled';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_runtime_job_publish_control()
from public, anon, authenticated;

drop trigger if exists jobs_runtime_publish_control on public.jobs;
create trigger jobs_runtime_publish_control
before insert or update of status on public.jobs
for each row execute function private.enforce_runtime_job_publish_control();

create table private.operational_alerts (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in (
    'webhook_failure', 'payment_failure', 'payout_restriction',
    'support_safety_critical', 'pin_abuse', 'evidence_upload_failure'
  )),
  severity text not null check (severity in ('warning', 'high', 'critical')),
  source text not null check (source ~ '^[a-z0-9_.-]{2,80}$'),
  safe_code text not null check (safe_code ~ '^[a-z0-9_.-]{2,120}$'),
  resource_type text check (resource_type is null or resource_type ~ '^[a-z0-9_.-]{2,80}$'),
  resource_id uuid,
  correlation_id uuid,
  occurrence_count integer not null default 1 check (occurrence_count between 1 and 1000000),
  status text not null default 'open' check (status in ('open', 'acknowledged', 'resolved')),
  first_observed_at timestamptz not null default now(),
  last_observed_at timestamptz not null default now(),
  acknowledged_by uuid references auth.users(id) on delete set null,
  acknowledged_at timestamptz,
  resolution_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint operational_alert_resolution_reason_check check (
    resolution_reason is null or char_length(btrim(resolution_reason)) between 10 and 500
  )
);

create unique index operational_alert_open_dedup_idx
on private.operational_alerts (
  category, source, (coalesce(resource_id, '00000000-0000-0000-0000-000000000000'::uuid)), safe_code
)
where status = 'open';
create index operational_alert_queue_idx
on private.operational_alerts(status, severity, last_observed_at desc);

alter table private.operational_alerts enable row level security;
alter table private.operational_alerts force row level security;
revoke all on private.operational_alerts from public, anon, authenticated;
grant all on private.operational_alerts to service_role;

create or replace function private.raise_operational_alert(
  p_category text,
  p_severity text,
  p_source text,
  p_safe_code text,
  p_resource_type text default null,
  p_resource_id uuid default null,
  p_correlation_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  insert into private.operational_alerts (
    category, severity, source, safe_code, resource_type, resource_id,
    correlation_id
  ) values (
    p_category, p_severity, p_source, p_safe_code, p_resource_type,
    p_resource_id, p_correlation_id
  )
  on conflict (
    category, source,
    (coalesce(resource_id, '00000000-0000-0000-0000-000000000000'::uuid)),
    safe_code
  ) where status = 'open'
  do update set
    severity = excluded.severity,
    occurrence_count = least(private.operational_alerts.occurrence_count + 1, 1000000),
    last_observed_at = now(),
    correlation_id = coalesce(excluded.correlation_id, private.operational_alerts.correlation_id),
    updated_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function private.raise_operational_alert(
  text, text, text, text, text, uuid, uuid
) from public, anon, authenticated;
grant execute on function private.raise_operational_alert(
  text, text, text, text, text, uuid, uuid
) to service_role;

create or replace function private.capture_operational_alert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new jsonb := to_jsonb(new);
  v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) else '{}'::jsonb end;
  v_id uuid := nullif(v_new->>'id', '')::uuid;
begin
  if tg_table_name = 'support_tickets'
     and v_new->>'priority' = 'urgent_safety'
     and coalesce(v_old->>'priority', '') <> 'urgent_safety' then
    perform private.raise_operational_alert(
      'support_safety_critical', 'critical', 'support.ticket',
      'urgent_safety_ticket', 'support_ticket', v_id
    );
  elsif tg_table_name = 'job_arrival_handshakes'
     and (
       (nullif(v_new->>'start_pin_locked_until', '')::timestamptz > now()
        and coalesce(v_old->>'start_pin_locked_until', '') is distinct from coalesce(v_new->>'start_pin_locked_until', ''))
       or
       (nullif(v_new->>'finish_pin_locked_until', '')::timestamptz > now()
        and coalesce(v_old->>'finish_pin_locked_until', '') is distinct from coalesce(v_new->>'finish_pin_locked_until', ''))
     ) then
    perform private.raise_operational_alert(
      'pin_abuse', 'high', 'job.pin', 'pin_attempt_lockout',
      'job_arrival_handshake', v_id
    );
  elsif tg_table_name = 'stripe_webhook_events'
     and v_new->>'processing_status' = 'failed'
     and coalesce(v_old->>'processing_status', '') <> 'failed' then
    perform private.raise_operational_alert(
      'webhook_failure', 'high', 'stripe.webhook',
      coalesce(nullif(v_new->>'safe_failure_code', ''), 'webhook_processing_failed'),
      'stripe_webhook_event', v_id
    );
  elsif tg_table_name = 'stripe_job_payment_intents'
     and v_new->>'status' in ('requires_action', 'funding_failed', 'transfer_failed')
     and coalesce(v_old->>'status', '') <> v_new->>'status' then
    perform private.raise_operational_alert(
      'payment_failure', 'high', 'stripe.payment',
      'payment_' || replace(v_new->>'status', 'requires_action', 'action_required'),
      'stripe_payment_record', v_id
    );
  elsif tg_table_name = 'stripe_payout_events'
     and v_new->>'status' in ('failed', 'canceled')
     and coalesce(v_old->>'status', '') <> v_new->>'status' then
    perform private.raise_operational_alert(
      'payout_restriction', 'critical', 'stripe.payout',
      'payout_' || v_new->>'status', 'stripe_payout_event', v_id
    );
  end if;
  return new;
end;
$$;

revoke all on function private.capture_operational_alert()
from public, anon, authenticated;

drop trigger if exists support_tickets_operational_alert on public.support_tickets;
create trigger support_tickets_operational_alert
after insert or update of priority on public.support_tickets
for each row execute function private.capture_operational_alert();

drop trigger if exists job_pin_operational_alert on public.job_arrival_handshakes;
create trigger job_pin_operational_alert
after update of start_pin_locked_until, finish_pin_locked_until
on public.job_arrival_handshakes
for each row execute function private.capture_operational_alert();

drop trigger if exists stripe_webhook_operational_alert on private.stripe_webhook_events;
create trigger stripe_webhook_operational_alert
after insert or update of processing_status on private.stripe_webhook_events
for each row execute function private.capture_operational_alert();

drop trigger if exists stripe_payment_operational_alert on private.stripe_job_payment_intents;
create trigger stripe_payment_operational_alert
after insert or update of status on private.stripe_job_payment_intents
for each row execute function private.capture_operational_alert();

drop trigger if exists stripe_payout_operational_alert on private.stripe_payout_events;
create trigger stripe_payout_operational_alert
after insert or update of status on private.stripe_payout_events
for each row execute function private.capture_operational_alert();

create or replace function public.record_my_evidence_upload_failure(
  p_upload_kind text,
  p_safe_code text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_upload_kind not in ('proof', 'support_evidence', 'avatar', 'verification')
     or p_safe_code !~ '^[a-z0-9_.-]{2,80}$'
     or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_upload_failure');
  end if;
  if not public.check_rate_limit('evidence_upload_failure', 10, 3600) then
    return jsonb_build_object('ok', false, 'code', 'rate_limit_exceeded');
  end if;
  perform private.raise_operational_alert(
    'evidence_upload_failure', 'warning', 'upload.' || p_upload_kind,
    p_safe_code, 'profile', v_user, p_client_request_id
  );
  perform public.record_rate_limit_event('evidence_upload_failure');
  return jsonb_build_object('ok', true, 'recorded', true);
end;
$$;

revoke all on function public.record_my_evidence_upload_failure(text, text, uuid)
from public, anon;
grant execute on function public.record_my_evidence_upload_failure(text, text, uuid)
to authenticated, service_role;

create or replace function private.can_review_operational_alerts(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_admin_safety_role(
    p_user_id,
    array['senior_safety_moderator', 'incident_manager', 'super_admin']::public.admin_safety_role[]
  ) or private.has_stripe_financial_role(
    p_user_id,
    array['financial_admin', 'super_admin']
  );
$$;

revoke all on function private.can_review_operational_alerts(uuid)
from public, anon, authenticated;

create or replace function public.get_admin_operational_alerts(
  p_status text default 'open',
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_items jsonb;
begin
  if not private.can_review_operational_alerts(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'operational_review_role_required');
  end if;
  if p_status not in ('open', 'acknowledged', 'resolved', 'all')
     or p_limit not between 1 and 200 then
    return jsonb_build_object('ok', false, 'code', 'invalid_queue_filter');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', alert.id,
    'category', alert.category,
    'severity', alert.severity,
    'source', alert.source,
    'safe_code', alert.safe_code,
    'resource_type', alert.resource_type,
    'resource_id', alert.resource_id,
    'correlation_id', alert.correlation_id,
    'occurrence_count', alert.occurrence_count,
    'status', alert.status,
    'first_observed_at', alert.first_observed_at,
    'last_observed_at', alert.last_observed_at
  ) order by
    case alert.severity when 'critical' then 0 when 'high' then 1 else 2 end,
    alert.last_observed_at desc), '[]'::jsonb)
  into v_items
  from (
    select *
    from private.operational_alerts item
    where p_status = 'all' or item.status = p_status
    order by
      case item.severity when 'critical' then 0 when 'high' then 1 else 2 end,
      item.last_observed_at desc
    limit p_limit
  ) alert;

  return jsonb_build_object('ok', true, 'items', v_items);
end;
$$;

create or replace function public.admin_acknowledge_operational_alert(
  p_alert_id uuid,
  p_resolution_status text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_alert private.operational_alerts%rowtype;
begin
  if not private.can_review_operational_alerts(v_actor) then
    return jsonb_build_object('ok', false, 'code', 'operational_review_role_required');
  end if;
  if p_resolution_status not in ('acknowledged', 'resolved')
     or char_length(btrim(coalesce(p_reason, ''))) not between 10 and 500 then
    return jsonb_build_object('ok', false, 'code', 'valid_resolution_reason_required');
  end if;

  update private.operational_alerts
  set status = p_resolution_status,
      acknowledged_by = v_actor,
      acknowledged_at = now(),
      resolution_reason = btrim(p_reason),
      updated_at = now()
  where id = p_alert_id
    and status in ('open', 'acknowledged')
  returning * into v_alert;
  if v_alert.id is null then
    return jsonb_build_object('ok', false, 'code', 'operational_alert_not_actionable');
  end if;

  insert into public.admin_action_logs (
    admin_id, action, target_table, target_id, details
  ) values (
    v_actor, 'operational_alert_' || p_resolution_status,
    'private.operational_alerts', p_alert_id,
    jsonb_build_object('category', v_alert.category, 'safe_code', v_alert.safe_code, 'reason', btrim(p_reason))
  );
  return jsonb_build_object('ok', true, 'status', v_alert.status);
end;
$$;

revoke all on function public.get_admin_operational_alerts(text, integer)
from public, anon;
revoke all on function public.admin_acknowledge_operational_alert(uuid, text, text)
from public, anon;
grant execute on function public.get_admin_operational_alerts(text, integer)
to authenticated, service_role;
grant execute on function public.admin_acknowledge_operational_alert(uuid, text, text)
to authenticated, service_role;
