-- Phase 7: make user safety actions server-owned, retry-safe, separately rate
-- limited, and connected to the existing private incident/check-in systems.

create table if not exists private.safety_center_runtime_config (
  singleton boolean primary key default true check (singleton),
  country_code text not null,
  region_code text,
  emergency_label text not null,
  emergency_phone_number text,
  emergency_phone_uri text,
  emergency_guidance text not null,
  urgent_support_route text not null default '/support/chat',
  physical_intervention_available boolean not null default false,
  updated_at timestamptz not null default now()
);

insert into private.safety_center_runtime_config(
  singleton, country_code, region_code, emergency_label,
  emergency_phone_number, emergency_phone_uri, emergency_guidance,
  physical_intervention_available
) values (
  true, 'US', 'IN', 'Call 911', '911', 'tel:911',
  'If anyone may be in immediate danger, move to a safer place when possible and call 911. MORT cannot dispatch or guarantee physical help.',
  false
)
on conflict (singleton) do update
set country_code = excluded.country_code,
    region_code = excluded.region_code,
    emergency_label = excluded.emergency_label,
    emergency_phone_number = excluded.emergency_phone_number,
    emergency_phone_uri = excluded.emergency_phone_uri,
    emergency_guidance = excluded.emergency_guidance,
    physical_intervention_available = false,
    updated_at = now();

alter table private.safety_center_runtime_config enable row level security;
alter table private.safety_center_runtime_config force row level security;
revoke all on private.safety_center_runtime_config from public, anon, authenticated;
grant all on private.safety_center_runtime_config to service_role;

create table if not exists private.safety_action_requests (
  actor_id uuid not null references auth.users(id) on delete cascade,
  client_request_id uuid not null,
  action_type text not null check (
    action_type in ('safety_report', 'safety_ping', 'block_user')
  ),
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor_id, client_request_id)
);

alter table private.safety_action_requests enable row level security;
alter table private.safety_action_requests force row level security;
revoke all on private.safety_action_requests from public, anon, authenticated;
grant all on private.safety_action_requests to service_role;

alter table public.safety_pings
  add column if not exists incident_id uuid references public.safety_incidents(id) on delete set null,
  add column if not exists client_request_id uuid;

alter table public.safety_pings
  drop constraint if exists safety_pings_note_length_check;
alter table public.safety_pings
  add constraint safety_pings_note_length_check
  check (note is null or char_length(note) <= 500);

create unique index if not exists safety_pings_teen_request_idx
on public.safety_pings(teen_id, client_request_id)
where client_request_id is not null;

alter table public.job_checkins
  add column if not exists client_request_id uuid,
  add column if not exists completion_request_id uuid,
  add column if not exists completion_actor_id uuid references public.profiles(id) on delete set null;

create unique index if not exists job_checkins_schedule_request_idx
on public.job_checkins(user_id, client_request_id)
where client_request_id is not null;

create unique index if not exists job_checkins_completion_request_idx
on public.job_checkins(completion_actor_id, completion_request_id)
where completion_request_id is not null;

create unique index if not exists job_checkins_expected_unique_idx
on public.job_checkins(application_id, user_id, checkin_type, expected_at)
where expected_at is not null;

create or replace function public.get_safety_center_config()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is null or not public.is_profile_active(auth.uid())
      then jsonb_build_object('ok', false, 'code', 'authentication_required')
    else jsonb_build_object(
      'ok', true,
      'country_code', config.country_code,
      'region_code', config.region_code,
      'emergency_label', config.emergency_label,
      'emergency_phone_number', config.emergency_phone_number,
      'emergency_phone_uri', config.emergency_phone_uri,
      'emergency_guidance', config.emergency_guidance,
      'urgent_support_route', config.urgent_support_route,
      'physical_intervention_available', false
    )
  end
  from private.safety_center_runtime_config config
  where config.singleton
$$;

create or replace function private.normalize_safety_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.category = 'other_urgent_concern' then
    new.category := case lower(coalesce(new.reason, ''))
      when 'harassment' then 'harassment'::public.safety_report_category
      when 'sexual_content' then 'sexual_conduct'::public.safety_report_category
      when 'exploitation' then 'child_safety_concern'::public.safety_report_category
      when 'scam' then 'scam'::public.safety_report_category
      when 'privacy' then 'personal_information_request'::public.safety_report_category
      when 'contact_sharing' then 'off_platform_pressure'::public.safety_report_category
      when 'discrimination' then 'discrimination'::public.safety_report_category
      when 'unsafe_job' then 'unsafe_job_conditions'::public.safety_report_category
      else new.category
    end;
  end if;

  if new.immediate_danger then
    new.severity := 'critical';
  elsif new.category in (
    'kidnapping_abduction_concern', 'assault', 'attempted_assault',
    'sexual_harassment', 'sexual_conduct', 'inappropriate_touching',
    'inappropriate_images', 'child_safety_concern', 'weapons', 'threats',
    'stalking', 'coercion', 'blackmail', 'doxxing'
  ) and new.severity in ('low', 'moderate') then
    new.severity := 'high';
  end if;

  if new.category in (
    'kidnapping_abduction_concern', 'assault', 'attempted_assault',
    'sexual_harassment', 'sexual_conduct', 'inappropriate_touching',
    'inappropriate_images', 'child_safety_concern', 'weapons', 'threats',
    'stalking', 'coercion', 'blackmail', 'doxxing', 'identity_mismatch',
    'account_sharing'
  ) then
    new.evidence_preserved := true;
  end if;

  new.details := nullif(left(btrim(coalesce(new.details, '')), 5000), '');
  new.location_type := nullif(left(btrim(coalesce(new.location_type, '')), 100), '');
  new.desired_outcome := nullif(left(btrim(coalesce(new.desired_outcome, '')), 1000), '');
  return new;
end;
$$;

create or replace function public.submit_safety_report(
  p_target_user_id uuid default null,
  p_target_job_id uuid default null,
  p_target_message_id uuid default null,
  p_target_review_id uuid default null,
  p_application_id uuid default null,
  p_category text default 'other_urgent_concern',
  p_severity text default 'moderate',
  p_immediate_danger boolean default false,
  p_details text default null,
  p_occurred_at timestamptz default null,
  p_location_type text default null,
  p_desired_outcome text default null,
  p_confidential_safety_feedback boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_category public.safety_report_category;
  v_severity public.safety_incident_severity;
  v_report public.reports%rowtype;
  v_incident public.safety_incidents%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'user_account_restricted');
  end if;
  if p_target_user_id is null and p_target_job_id is null
     and p_target_message_id is null and p_target_review_id is null
     and not coalesce(p_immediate_danger, false) then
    return jsonb_build_object('ok', false, 'code', 'report_target_required');
  end if;
  if p_target_user_id = auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'cannot_report_self');
  end if;
  if char_length(btrim(coalesce(p_details, ''))) < 10 then
    return jsonb_build_object('ok', false, 'code', 'report_details_required');
  end if;

  begin
    v_category := lower(btrim(p_category))::public.safety_report_category;
    v_severity := lower(btrim(p_severity))::public.safety_incident_severity;
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'code', 'invalid_report_classification');
  end;

  insert into public.reports (
    reporter_id, target_user_id, target_job_id, target_message_id,
    target_review_id, related_application_id, reason, details,
    category, severity, immediate_danger, occurred_at, location_type,
    desired_outcome, confidential_safety_feedback
  ) values (
    auth.uid(), p_target_user_id, p_target_job_id, p_target_message_id,
    p_target_review_id, p_application_id, v_category::text,
    left(btrim(p_details), 5000), v_category, v_severity,
    coalesce(p_immediate_danger, false), p_occurred_at,
    nullif(left(btrim(coalesce(p_location_type, '')), 100), ''),
    nullif(left(btrim(coalesce(p_desired_outcome, '')), 1000), ''),
    coalesce(p_confidential_safety_feedback, false)
  ) returning * into v_report;

  select * into v_incident
  from public.safety_incidents incident
  where incident.initial_report_id = v_report.id;

  if p_immediate_danger then
    perform public.enqueue_notification(
      auth.uid(),
      'Urgent report recorded',
      'MORT recorded your report. Contact local emergency services now if anyone is in immediate danger.',
      jsonb_build_object('reportId', v_report.id, 'incidentId', v_incident.id)
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'report_id', v_report.id,
    'incident_id', v_incident.id,
    'case_number', v_incident.case_number,
    'status', v_incident.status,
    'severity', v_incident.severity,
    'immediate_danger_guidance', coalesce(p_immediate_danger, false)
  );
end;
$$;

create or replace function private.preserve_reported_message_evidence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_message public.messages%rowtype;
begin
  if new.target_message_id is null then return new; end if;
  select * into v_message from public.messages where id = new.target_message_id;
  if v_message.id is null then return new; end if;
  update public.messages
  set preserved_for_safety = true
  where id = v_message.id;
  insert into public.message_safety_evidence(
    message_id, sender_id, thread_id, raw_body, body_sha256,
    category, severity, preserved_until
  ) values (
    v_message.id, v_message.sender_id, v_message.thread_id, v_message.body,
    encode(extensions.digest(v_message.body, 'sha256'), 'hex'),
    new.category, new.severity, now() + interval '180 days'
  )
  on conflict (message_id) do update
  set preserved_until = greatest(public.message_safety_evidence.preserved_until, excluded.preserved_until),
      severity = case
        when excluded.severity = 'critical' then excluded.severity
        when public.message_safety_evidence.severity in ('low', 'moderate') and excluded.severity = 'high' then excluded.severity
        else public.message_safety_evidence.severity
      end;
  return new;
end;
$$;

drop trigger if exists reports_preserve_message_evidence on public.reports;
create trigger reports_preserve_message_evidence
after insert on public.reports
for each row execute function private.preserve_reported_message_evidence();

create or replace function private.alert_authorized_safety_staff()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_staff record;
begin
  if new.severity not in ('high', 'critical') then return new; end if;
  for v_staff in
    select distinct assignment.user_id
    from public.admin_role_assignments assignment
    join public.profiles profile on profile.id = assignment.user_id
    where assignment.revoked_at is null
      and profile.role = 'admin'
      and profile.account_status = 'active'
      and assignment.role in (
        'senior_safety_moderator', 'child_safety_specialist',
        'incident_manager', 'super_admin'
      )
  loop
    perform public.enqueue_notification(
      v_staff.user_id,
      case when new.severity = 'critical' then 'Urgent safety case queued' else 'High-priority safety case queued' end,
      'An authorized human safety review is required. MORT has not promised or dispatched physical intervention.',
      jsonb_build_object('incidentId', new.id, 'route', '/admin/safety-incidents')
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists safety_incidents_alert_authorized_staff on public.safety_incidents;
create trigger safety_incidents_alert_authorized_staff
after insert on public.safety_incidents
for each row execute function private.alert_authorized_safety_staff();

create or replace function public.submit_safety_report_v2(
  p_target_user_id uuid,
  p_target_job_id uuid,
  p_target_message_id uuid,
  p_target_review_id uuid,
  p_application_id uuid,
  p_category text,
  p_severity text,
  p_immediate_danger boolean,
  p_details text,
  p_occurred_at timestamptz,
  p_location_type text,
  p_desired_outcome text,
  p_confidential_safety_feedback boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request private.safety_action_requests%rowtype;
  v_payload_hash text;
  v_response jsonb;
  v_count integer;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  v_payload_hash := encode(extensions.digest(jsonb_build_object(
    'target_user', p_target_user_id, 'target_job', p_target_job_id,
    'target_message', p_target_message_id, 'target_review', p_target_review_id,
    'application', p_application_id, 'category', p_category, 'severity', p_severity,
    'immediate', coalesce(p_immediate_danger, false),
    'details', btrim(coalesce(p_details, '')), 'occurred_at', p_occurred_at,
    'location_type', p_location_type, 'desired_outcome', p_desired_outcome,
    'confidential', coalesce(p_confidential_safety_feedback, false)
  )::text, 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text || ':' || p_client_request_id::text, 0)
  );
  select * into v_request from private.safety_action_requests request
  where request.actor_id = auth.uid() and request.client_request_id = p_client_request_id;
  if found then
    if v_request.action_type <> 'safety_report' or v_request.payload_sha256 <> v_payload_hash then
      return jsonb_build_object('ok', false, 'code', 'safety_request_payload_mismatch');
    end if;
    return v_request.response || jsonb_build_object('replayed', true);
  end if;
  if p_target_message_id is not null and not exists (
    select 1 from public.messages message
    where message.id = p_target_message_id
      and public.is_thread_participant(message.thread_id)
  ) then return jsonb_build_object('ok', false, 'code', 'report_target_not_authorized'); end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text || ':safety-report:' || coalesce(p_immediate_danger, false)::text, 0)
  );
  if coalesce(p_immediate_danger, false) then
    select count(*) into v_count from public.reports report
    where report.reporter_id = auth.uid() and report.immediate_danger
      and report.created_at >= now() - interval '1 hour';
    if v_count >= 20 then
      return jsonb_build_object('ok', false, 'code', 'urgent_safety_rate_limited', 'emergency_guidance_required', true);
    end if;
  else
    select count(*) into v_count from public.reports report
    where report.reporter_id = auth.uid() and not report.immediate_danger
      and report.created_at >= now() - interval '1 day';
    if v_count >= 15 then return jsonb_build_object('ok', false, 'code', 'safety_report_rate_limited'); end if;
  end if;

  v_response := public.submit_safety_report(
    p_target_user_id, p_target_job_id, p_target_message_id, p_target_review_id,
    p_application_id, p_category, p_severity, p_immediate_danger, p_details,
    p_occurred_at, p_location_type, p_desired_outcome,
    p_confidential_safety_feedback
  );
  if coalesce((v_response->>'ok')::boolean, false) is not true then return v_response; end if;
  insert into private.safety_action_requests(
    actor_id, client_request_id, action_type, payload_sha256, response
  ) values (auth.uid(), p_client_request_id, 'safety_report', v_payload_hash, v_response);
  return v_response || jsonb_build_object('replayed', false);
end;
$$;

create or replace function public.block_user_v2(
  p_blocked_id uuid,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request private.safety_action_requests%rowtype;
  v_payload_hash text;
  v_block public.blocks%rowtype;
  v_response jsonb;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  if p_blocked_id is null or p_blocked_id = auth.uid() then return jsonb_build_object('ok', false, 'code', 'valid_block_target_required'); end if;
  if not exists (select 1 from public.profiles where id = p_blocked_id) then return jsonb_build_object('ok', false, 'code', 'block_target_not_found'); end if;
  v_payload_hash := encode(extensions.digest(p_blocked_id::text, 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text || ':' || p_client_request_id::text, 0)
  );
  select * into v_request from private.safety_action_requests request
  where request.actor_id = auth.uid() and request.client_request_id = p_client_request_id;
  if found then
    if v_request.action_type <> 'block_user' or v_request.payload_sha256 <> v_payload_hash then
      return jsonb_build_object('ok', false, 'code', 'safety_request_payload_mismatch');
    end if;
    return v_request.response || jsonb_build_object('replayed', true);
  end if;
  insert into public.blocks(blocker_id, blocked_id)
  values (auth.uid(), p_blocked_id)
  on conflict (blocker_id, blocked_id) do update set blocker_id = excluded.blocker_id
  returning * into v_block;
  v_response := jsonb_build_object('ok', true, 'block_id', v_block.id, 'blocked_id', v_block.blocked_id);
  insert into private.safety_action_requests(actor_id, client_request_id, action_type, payload_sha256, response)
  values (auth.uid(), p_client_request_id, 'block_user', v_payload_hash, v_response);
  return v_response || jsonb_build_object('replayed', false);
end;
$$;

create or replace function public.unblock_user(p_blocked_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  delete from public.blocks
  where blocker_id = auth.uid() and blocked_id = p_blocked_id;
  get diagnostics v_count = row_count;
  return jsonb_build_object('ok', true, 'removed', v_count > 0);
end;
$$;

create or replace function public.create_safety_ping_v2(
  p_status text,
  p_note text,
  p_job_id uuid,
  p_immediate_danger boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_request private.safety_action_requests%rowtype;
  v_payload_hash text;
  v_response jsonb;
  v_report jsonb;
  v_ping public.safety_pings%rowtype;
  v_count integer;
  v_note text := nullif(left(btrim(coalesce(p_note, '')), 500), '');
  v_scan jsonb;
begin
  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'teen' or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_teen_required');
  end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  if p_status not in ('ok', 'needs_help') then return jsonb_build_object('ok', false, 'code', 'invalid_safety_ping_status'); end if;
  if v_note is not null then
    v_scan := private.classify_message_safety(v_note);
    if coalesce((v_scan->>'blocked')::boolean, false)
       and v_scan->>'category' = 'personal_information_request' then
      return jsonb_build_object('ok', false, 'code', 'exact_location_not_allowed_in_ping');
    end if;
  end if;
  if p_job_id is not null and not exists (
    select 1 from public.applications application
    where application.job_id = p_job_id and application.teen_id = auth.uid()
      and application.status in ('accepted', 'in_progress', 'proof_submitted', 'completion_pending_release')
  ) then return jsonb_build_object('ok', false, 'code', 'active_job_required'); end if;
  v_payload_hash := encode(extensions.digest(jsonb_build_object(
    'status', p_status, 'note', v_note, 'job', p_job_id,
    'immediate', coalesce(p_immediate_danger, false)
  )::text, 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text || ':' || p_client_request_id::text, 0)
  );
  select * into v_request from private.safety_action_requests request
  where request.actor_id = auth.uid() and request.client_request_id = p_client_request_id;
  if found then
    if v_request.action_type <> 'safety_ping' or v_request.payload_sha256 <> v_payload_hash then
      return jsonb_build_object('ok', false, 'code', 'safety_request_payload_mismatch');
    end if;
    return v_request.response || jsonb_build_object('replayed', true);
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text || ':safety-ping:' || coalesce(p_immediate_danger, false)::text, 0)
  );
  select count(*) into v_count from public.safety_pings ping
  where ping.teen_id = auth.uid() and ping.created_at >= now() - interval '1 hour'
    and ping.immediate_danger = coalesce(p_immediate_danger, false);
  if v_count >= (case when p_immediate_danger then 20 else 12 end) then
    return jsonb_build_object(
      'ok', false,
      'code', case when p_immediate_danger then 'urgent_safety_rate_limited' else 'safety_ping_rate_limited' end,
      'emergency_guidance_required', coalesce(p_immediate_danger, false)
    );
  end if;
  if p_immediate_danger then
    v_report := public.submit_safety_report(
      null, p_job_id, null, null, null, 'other_urgent_concern', 'critical', true,
      coalesce(v_note, 'The teen requested urgent safety help through Safety Ping.'),
      now(), null, 'Queue a trained human safety review and preserve relevant records.', true
    );
    if coalesce((v_report->>'ok')::boolean, false) is not true then return v_report; end if;
  end if;
  insert into public.safety_pings(
    teen_id, guardian_id, status, note, job_id, immediate_danger,
    incident_id, client_request_id
  ) values (
    auth.uid(), null, p_status::public.safety_ping_status, v_note, p_job_id,
    coalesce(p_immediate_danger, false), (v_report->>'incident_id')::uuid,
    p_client_request_id
  ) returning * into v_ping;
  v_response := jsonb_build_object(
    'ok', true, 'safety_ping_id', v_ping.id, 'incident_id', v_ping.incident_id,
    'status', v_ping.status, 'immediate_danger', v_ping.immediate_danger,
    'physical_intervention_dispatched', false
  );
  insert into private.safety_action_requests(actor_id, client_request_id, action_type, payload_sha256, response)
  values (auth.uid(), p_client_request_id, 'safety_ping', v_payload_hash, v_response);
  return v_response || jsonb_build_object('replayed', false);
end;
$$;

create or replace function private.schedule_job_cadence_checkins()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cadence integer;
  v_duration integer;
begin
  if old.start_pin_used_at is null and new.start_pin_used_at is not null then
    select plan.checkin_cadence_minutes, coalesce(job.estimated_duration_minutes, 120)
    into v_cadence, v_duration
    from public.job_safety_plans plan
    join public.jobs job on job.id = plan.job_id
    where plan.application_id = new.application_id;
    if v_cadence is not null then
      insert into public.job_checkins(
        application_id, user_id, checkin_type, expected_at, status
      )
      select new.application_id, new.teen_id, 'cadence',
             new.start_pin_used_at + make_interval(mins => minute_offset), 'pending'
      from generate_series(
        v_cadence,
        greatest(v_cadence, least(coalesce(v_duration, 120), 1440)),
        v_cadence
      ) minute_offset
      on conflict (application_id, user_id, checkin_type, expected_at)
      where expected_at is not null do nothing;
    end if;
  end if;
  if old.finish_pin_used_at is null and new.finish_pin_used_at is not null then
    update public.job_checkins
    set status = 'canceled'
    where application_id = new.application_id
      and checkin_type = 'cadence' and status = 'pending';
  end if;
  return new;
end;
$$;

drop trigger if exists job_execution_schedule_cadence_checkins on public.job_arrival_handshakes;
create trigger job_execution_schedule_cadence_checkins
after update of start_pin_used_at, finish_pin_used_at on public.job_arrival_handshakes
for each row execute function private.schedule_job_cadence_checkins();

create or replace function private.cancel_terminal_job_checkins()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in (
    'withdrawn', 'rejected', 'guardian_rejected', 'canceled', 'completed', 'disputed'
  ) then
    update public.job_checkins
    set status = 'canceled'
    where application_id = new.id and status = 'pending';
  end if;
  return new;
end;
$$;

drop trigger if exists applications_cancel_terminal_checkins on public.applications;
create trigger applications_cancel_terminal_checkins
after update of status on public.applications
for each row when (old.status is distinct from new.status)
execute function private.cancel_terminal_job_checkins();

create or replace function public.get_my_active_job_checkins()
returns table(
  checkin_id uuid,
  application_id uuid,
  job_id uuid,
  job_title text,
  checkin_type text,
  expected_at timestamptz,
  completed_at timestamptz,
  status text
)
language sql
stable
security definer
set search_path = ''
as $$
  select checkin.id, checkin.application_id, application.job_id, job.title,
         checkin.checkin_type, checkin.expected_at, checkin.completed_at,
         checkin.status
  from public.job_checkins checkin
  join public.applications application on application.id = checkin.application_id
  join public.jobs job on job.id = application.job_id
  where auth.uid() is not null
    and checkin.user_id = auth.uid()
    and application.teen_id = auth.uid()
    and application.status in ('accepted', 'in_progress', 'proof_submitted', 'completion_pending_release')
    and checkin.status in ('pending', 'missed')
  order by checkin.expected_at nulls last, checkin.created_at
  limit 50
$$;

create or replace function public.schedule_active_job_checkin(
  p_application_id uuid,
  p_minutes_from_now integer,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_checkin public.job_checkins%rowtype;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  select * into v_checkin from public.job_checkins
  where user_id = auth.uid() and client_request_id = p_client_request_id;
  if found then
    if v_checkin.application_id <> p_application_id then
      return jsonb_build_object('ok', false, 'code', 'checkin_request_payload_mismatch');
    end if;
    return jsonb_build_object('ok', true, 'replayed', true, 'checkin_id', v_checkin.id, 'expected_at', v_checkin.expected_at);
  end if;
  if p_minutes_from_now not between 15 and 240 then return jsonb_build_object('ok', false, 'code', 'invalid_checkin_cadence'); end if;
  if not exists (
    select 1 from public.applications application
    where application.id = p_application_id and application.teen_id = auth.uid()
      and application.status in ('in_progress', 'proof_submitted')
  ) then return jsonb_build_object('ok', false, 'code', 'active_job_required'); end if;
  if (select count(*) from public.job_checkins
      where application_id = p_application_id and user_id = auth.uid()
        and status = 'pending') >= 8 then
    return jsonb_build_object('ok', false, 'code', 'pending_checkin_limit_reached');
  end if;
  insert into public.job_checkins(
    application_id, user_id, checkin_type, expected_at, status,
    client_request_id
  ) values (
    p_application_id, auth.uid(), 'cadence',
    now() + make_interval(mins => p_minutes_from_now), 'pending',
    p_client_request_id
  ) returning * into v_checkin;
  return jsonb_build_object('ok', true, 'replayed', false, 'checkin_id', v_checkin.id, 'expected_at', v_checkin.expected_at);
end;
$$;

create or replace function public.complete_active_job_checkin(
  p_checkin_id uuid,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_checkin public.job_checkins%rowtype;
  v_existing public.job_checkins%rowtype;
  v_job_id uuid;
  v_was_missed boolean;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text || ':' || p_client_request_id::text, 0)
  );
  select * into v_existing from public.job_checkins
  where completion_actor_id = auth.uid() and completion_request_id = p_client_request_id;
  if found then
    if v_existing.id <> p_checkin_id then return jsonb_build_object('ok', false, 'code', 'checkin_request_payload_mismatch'); end if;
    return jsonb_build_object('ok', true, 'replayed', true, 'checkin_id', v_existing.id, 'completed_at', v_existing.completed_at);
  end if;
  select * into v_checkin from public.job_checkins where id = p_checkin_id for update;
  if v_checkin.id is null or v_checkin.user_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'checkin_not_authorized');
  end if;
  if v_checkin.status not in ('pending', 'missed') then
    return jsonb_build_object('ok', false, 'code', 'checkin_not_active');
  end if;
  if not exists (
    select 1 from public.applications application
    where application.id = v_checkin.application_id and application.teen_id = auth.uid()
      and application.status in ('in_progress', 'proof_submitted')
  ) then return jsonb_build_object('ok', false, 'code', 'active_job_required'); end if;
  v_was_missed := v_checkin.status = 'missed';
  update public.job_checkins
  set status = 'completed', completed_at = now(),
      completion_actor_id = auth.uid(), completion_request_id = p_client_request_id
  where id = v_checkin.id returning * into v_checkin;
  select application.job_id into v_job_id from public.applications application
  where application.id = v_checkin.application_id;
  insert into public.safety_pings(teen_id, status, note, job_id, immediate_danger)
  values (
    auth.uid(), 'ok',
    case when v_was_missed then 'A previously missed scheduled check-in was completed.' else 'A scheduled active-job check-in was completed.' end,
    v_job_id, false
  );
  return jsonb_build_object('ok', true, 'replayed', false, 'checkin_id', v_checkin.id, 'completed_at', v_checkin.completed_at, 'was_missed', v_was_missed);
end;
$$;

create or replace function private.escalate_missed_job_checkins_worker()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_checkin public.job_checkins%rowtype;
  v_job_id uuid;
  v_count integer := 0;
begin
  for v_checkin in
    update public.job_checkins checkin
    set status = 'missed', escalation_sent_at = now()
    from public.applications application
    where checkin.application_id = application.id
      and checkin.status = 'pending'
      and checkin.expected_at is not null
      and checkin.expected_at < now() - interval '10 minutes'
      and application.status in ('in_progress', 'proof_submitted')
    returning checkin.*
  loop
    select application.job_id into v_job_id from public.applications application
    where application.id = v_checkin.application_id;
    insert into public.safety_pings(teen_id, status, note, job_id, immediate_danger)
    values (
      v_checkin.user_id, 'missed',
      'A scheduled active-job check-in was missed. This is an automated alert, not emergency dispatch.',
      v_job_id, false
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.escalate_missed_job_checkins()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  return private.escalate_missed_job_checkins_worker();
end;
$$;

create extension if not exists pg_cron with schema pg_catalog;
do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname = 'mort-missed-job-checkins';
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
  perform cron.schedule(
    'mort-missed-job-checkins',
    '*/5 * * * *',
    'select private.escalate_missed_job_checkins_worker();'
  );
end;
$$;

-- Direct writes bypass retry/rate controls. Security-definer functions and the
-- service role retain the narrow internal paths required by triggers and QA.
revoke insert, update, delete on public.reports from authenticated;
revoke insert, update, delete on public.blocks from authenticated;
revoke insert, update, delete on public.safety_pings from authenticated;

revoke all on function public.submit_safety_report(uuid,uuid,uuid,uuid,uuid,text,text,boolean,text,timestamptz,text,text,boolean)
from public, anon, authenticated;
grant execute on function public.submit_safety_report(uuid,uuid,uuid,uuid,uuid,text,text,boolean,text,timestamptz,text,text,boolean)
to service_role;

do $$
declare
  signature text;
begin
  foreach signature in array array[
    'public.get_safety_center_config()',
    'public.submit_safety_report_v2(uuid,uuid,uuid,uuid,uuid,text,text,boolean,text,timestamptz,text,text,boolean,uuid)',
    'public.block_user_v2(uuid,uuid)',
    'public.unblock_user(uuid)',
    'public.create_safety_ping_v2(text,text,uuid,boolean,uuid)',
    'public.get_my_active_job_checkins()',
    'public.schedule_active_job_checkin(uuid,integer,uuid)',
    'public.complete_active_job_checkin(uuid,uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', signature);
    execute format('grant execute on function %s to authenticated, service_role', signature);
  end loop;
end;
$$;

revoke all on function private.preserve_reported_message_evidence(),
  private.alert_authorized_safety_staff(),
  private.schedule_job_cadence_checkins(),
  private.cancel_terminal_job_checkins(),
  private.escalate_missed_job_checkins_worker()
from public, anon, authenticated;
grant execute on function private.preserve_reported_message_evidence(),
  private.alert_authorized_safety_staff(),
  private.schedule_job_cadence_checkins(),
  private.cancel_terminal_job_checkins(),
  private.escalate_missed_job_checkins_worker()
to service_role;

revoke all on function public.escalate_missed_job_checkins()
from public, anon, authenticated;
grant execute on function public.escalate_missed_job_checkins() to service_role;

comment on table private.safety_action_requests is
'Server-only payload-bound replay ledger for report, Safety Ping, and block actions.';
comment on function private.escalate_missed_job_checkins_worker() is
'Idempotent five-minute cron worker. Creates privacy-minimized missed check-in alerts and does not dispatch emergency services.';
