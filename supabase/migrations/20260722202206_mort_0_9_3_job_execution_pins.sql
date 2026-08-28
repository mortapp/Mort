-- MORT 0.9.3 two-step job execution controls.
-- PINs confirm an in-person handoff action only. They do not verify identity,
-- job quality, or legal classification, and they never move money directly.

alter table public.job_contracts drop constraint if exists job_contract_status_check;
alter table public.job_contracts add constraint job_contract_status_check check (
  status in ('pending_confirmation', 'active', 'change_pending', 'completion_pending_release', 'completed', 'disputed', 'cancelled')
);

alter table public.job_payment_obligations drop constraint if exists job_payment_obligation_status_check;
alter table public.job_payment_obligations add constraint job_payment_obligation_status_check check (
  status in ('pending_completion', 'pending_release', 'due', 'poster_marked_sent', 'worker_confirmed_received', 'disputed', 'superseded', 'waived_after_review')
);

create table if not exists private.job_execution_runtime_controls (
  singleton boolean primary key default true check (singleton),
  start_window_minutes_before integer not null default 120,
  start_window_minutes_after integer not null default 240,
  pin_ttl_seconds integer not null default 600,
  pin_generation_cooldown_seconds integer not null default 60,
  maximum_pin_attempts integer not null default 5,
  pin_lock_minutes integer not null default 30,
  completion_review_hours integer not null default 24,
  require_funding_for_start boolean not null default true,
  closed_test_mode boolean not null default true,
  teen_abandonment_cooldown_seconds integer not null default 60,
  production_compensation_execution_enabled boolean not null default false,
  pre_start_compensation_bps integer not null default 0,
  post_start_compensation_bps integer not null default 2500,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint job_execution_windows_check check (
    start_window_minutes_before between 0 and 1440
    and start_window_minutes_after between 1 and 1440
    and pin_ttl_seconds between 60 and 600
    and pin_generation_cooldown_seconds between 30 and 600
    and maximum_pin_attempts between 3 and 10
    and pin_lock_minutes between 5 and 1440
    and completion_review_hours between 1 and 168
    and teen_abandonment_cooldown_seconds between 60 and 3600
    and pre_start_compensation_bps between 0 and 10000
    and post_start_compensation_bps between 0 and 10000
  )
);

insert into private.job_execution_runtime_controls(singleton) values (true)
on conflict (singleton) do nothing;
alter table private.job_execution_runtime_controls enable row level security;
alter table private.job_execution_runtime_controls force row level security;
revoke all on private.job_execution_runtime_controls from public, anon, authenticated;
grant all on private.job_execution_runtime_controls to service_role;

alter table public.job_arrival_handshakes
  add column if not exists execution_state text not null default 'awaiting_start',
  add column if not exists start_pin_hash text,
  add column if not exists start_pin_generated_at timestamptz,
  add column if not exists start_pin_expires_at timestamptz,
  add column if not exists start_pin_used_at timestamptz,
  add column if not exists start_pin_attempt_count integer not null default 0,
  add column if not exists start_pin_locked_until timestamptz,
  add column if not exists start_contract_version_id uuid references public.job_contract_versions(id) on delete restrict,
  add column if not exists start_confirmed_by uuid references public.profiles(id) on delete restrict,
  add column if not exists start_client_request_id uuid,
  add column if not exists finish_pin_hash text,
  add column if not exists finish_pin_generation integer not null default 0,
  add column if not exists finish_pin_generated_at timestamptz,
  add column if not exists finish_pin_expires_at timestamptz,
  add column if not exists finish_pin_used_at timestamptz,
  add column if not exists finish_pin_attempt_count integer not null default 0,
  add column if not exists finish_pin_locked_until timestamptz,
  add column if not exists finish_contract_version_id uuid references public.job_contract_versions(id) on delete restrict,
  add column if not exists finish_requested_by uuid references public.profiles(id) on delete restrict,
  add column if not exists finish_confirmed_by uuid references public.profiles(id) on delete restrict,
  add column if not exists finish_client_request_id uuid,
  add column if not exists completion_pending_at timestamptz,
  add column if not exists review_window_ends_at timestamptz;

update public.job_arrival_handshakes
set start_pin_hash = case when code_hash is null then null else encode(code_hash, 'hex') end,
    start_pin_generated_at = coalesce(start_pin_generated_at, updated_at),
    start_pin_expires_at = coalesce(start_pin_expires_at, code_expires_at),
    start_pin_used_at = coalesce(start_pin_used_at, code_used_at),
    execution_state = case when checkin_at is not null then 'in_progress' else execution_state end
where start_pin_hash is null and code_hash is not null;

alter table public.job_arrival_handshakes add constraint job_execution_state_check check (
  execution_state in ('awaiting_start', 'start_pin_active', 'in_progress', 'finish_pin_active', 'completion_pending_release', 'disputed', 'cancelled', 'completed')
);
alter table public.job_arrival_handshakes add constraint job_start_attempt_check check (start_pin_attempt_count between 0 and 100);
alter table public.job_arrival_handshakes add constraint job_finish_attempt_check check (finish_pin_attempt_count between 0 and 100);
create unique index if not exists job_start_request_idx on public.job_arrival_handshakes(application_id, start_client_request_id) where start_client_request_id is not null;
create unique index if not exists job_finish_request_idx on public.job_arrival_handshakes(application_id, finish_client_request_id) where finish_client_request_id is not null;

create table if not exists public.job_execution_events (
  id bigint generated always as identity primary key,
  application_id uuid not null references public.applications(id) on delete restrict,
  contract_id uuid references public.job_contracts(id) on delete restrict,
  contract_version_id uuid references public.job_contract_versions(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  from_state text,
  to_state text,
  request_id uuid,
  safe_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint job_execution_event_type_check check (event_type in (
    'start_pin_generated', 'start_pin_generation_replayed', 'start_pin_failed_attempt',
    'start_pin_locked', 'start_confirmed', 'finish_pin_generated',
    'finish_pin_generation_replayed', 'finish_pin_failed_attempt', 'finish_pin_locked',
    'finish_confirmed', 'finish_pin_unavailable_reported', 'adult_cancelled',
    'teen_abandonment_reported', 'completion_review_started'
  ))
);
create index if not exists job_execution_events_application_idx on public.job_execution_events(application_id, created_at);
create unique index if not exists job_execution_event_request_idx
on public.job_execution_events(application_id, event_type, actor_id, request_id)
where request_id is not null;

alter table public.job_execution_events enable row level security;
alter table public.job_execution_events force row level security;
create policy job_execution_events_select_participants
on public.job_execution_events for select to authenticated
using (
  exists (
    select 1 from public.applications application
    join public.jobs job on job.id = application.job_id
    where application.id = job_execution_events.application_id
      and (application.teen_id = (select auth.uid()) or job.poster_id = (select auth.uid()) or public.is_admin())
  )
);
revoke all on public.job_execution_events from anon, authenticated;
grant select on public.job_execution_events to authenticated;
grant all on public.job_execution_events to service_role;

create table if not exists public.job_execution_cancellations (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete restrict,
  contract_id uuid references public.job_contracts(id) on delete restrict,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  actor_role text not null,
  cancellation_stage text not null,
  reason text not null,
  safety_related boolean not null default false,
  recommended_compensation_cents integer not null default 0,
  compensation_policy_bps integer not null default 0,
  execution_status text not null default 'disabled_pending_review',
  support_ticket_id uuid references public.support_tickets(id) on delete set null,
  dispute_id uuid references public.payment_disputes(id) on delete set null,
  client_request_id uuid not null,
  created_at timestamptz not null default now(),
  constraint job_execution_cancellation_role_check check (actor_role in ('adult', 'teen')),
  constraint job_execution_cancellation_stage_check check (cancellation_stage in ('before_start', 'after_start')),
  constraint job_execution_cancellation_reason_check check (char_length(btrim(reason)) between 3 and 2000),
  constraint job_execution_cancellation_amount_check check (recommended_compensation_cents >= 0 and compensation_policy_bps between 0 and 10000),
  constraint job_execution_cancellation_execution_check check (execution_status in ('disabled_pending_review', 'review_required', 'resolved_no_payment', 'resolved_provider_operation')),
  unique (actor_id, client_request_id)
);

create table if not exists public.teen_abandonment_reports (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete restrict,
  contract_id uuid references public.job_contracts(id) on delete restrict,
  teen_id uuid not null references public.profiles(id) on delete restrict,
  statement text not null,
  final_non_safety_confirmation boolean not null,
  cooldown_until timestamptz,
  support_ticket_id uuid references public.support_tickets(id) on delete set null,
  dispute_id uuid references public.payment_disputes(id) on delete set null,
  client_request_id uuid not null,
  created_at timestamptz not null default now(),
  constraint teen_abandonment_statement_check check (char_length(btrim(statement)) between 10 and 2000),
  constraint teen_abandonment_final_check check (final_non_safety_confirmation),
  unique (teen_id, client_request_id)
);

alter table public.job_execution_cancellations enable row level security;
alter table public.job_execution_cancellations force row level security;
alter table public.teen_abandonment_reports enable row level security;
alter table public.teen_abandonment_reports force row level security;
create policy job_execution_cancellations_select_participants
on public.job_execution_cancellations for select to authenticated
using (
  exists (
    select 1 from public.applications application join public.jobs job on job.id = application.job_id
    where application.id = job_execution_cancellations.application_id
      and (application.teen_id = (select auth.uid()) or job.poster_id = (select auth.uid()) or public.is_admin())
  )
);
create policy teen_abandonment_reports_select_owner_admin
on public.teen_abandonment_reports for select to authenticated
using (teen_id = (select auth.uid()) or public.is_admin());
revoke all on public.job_execution_cancellations, public.teen_abandonment_reports from anon, authenticated;
grant select on public.job_execution_cancellations, public.teen_abandonment_reports to authenticated;
grant all on public.job_execution_cancellations, public.teen_abandonment_reports to service_role;

create or replace function private.generate_six_digit_job_pin()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_bytes bytea := extensions.gen_random_bytes(4);
  v_number bigint;
begin
  v_number := (
    get_byte(v_bytes, 0)::bigint * 16777216
    + get_byte(v_bytes, 1)::bigint * 65536
    + get_byte(v_bytes, 2)::bigint * 256
    + get_byte(v_bytes, 3)::bigint
  ) % 1000000;
  return lpad(v_number::text, 6, '0');
end;
$$;
revoke all on function private.generate_six_digit_job_pin() from public, anon, authenticated;
grant execute on function private.generate_six_digit_job_pin() to service_role;

create or replace function private.get_job_execution_gate(p_application_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_contract public.job_contracts%rowtype;
  v_version public.job_contract_versions%rowtype;
  v_safety public.job_safety_agreements%rowtype;
  v_control private.job_execution_runtime_controls%rowtype;
  v_funding private.stripe_job_payment_intents%rowtype;
  v_start_at timestamptz;
begin
  select * into v_control from private.job_execution_runtime_controls where singleton;
  select * into v_application from public.applications where id = p_application_id;
  select * into v_job from public.jobs where id = v_application.job_id;
  select * into v_contract from public.job_contracts where application_id = v_application.id;
  select * into v_version from public.job_contract_versions where id = v_contract.active_version_id;
  select * into v_safety from public.job_safety_agreements where application_id = v_application.id;
  select * into v_funding from private.stripe_job_payment_intents
  where contract_id = v_contract.id and environment = 'test'
  order by operation_version desc limit 1;
  if v_application.id is null then return jsonb_build_object('ok', false, 'code', 'application_not_found'); end if;
  if v_application.status <> 'accepted' then return jsonb_build_object('ok', false, 'code', 'accepted_application_required'); end if;
  if v_job.status not in ('assigned', 'filled') then return jsonb_build_object('ok', false, 'code', 'assigned_job_required'); end if;
  if v_contract.id is null or v_contract.status <> 'active' or v_contract.active_version_id is null or v_version.status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  if (select count(distinct acceptance.party_role) from public.job_contract_acceptances acceptance
      where acceptance.contract_version_id = v_contract.active_version_id
        and acceptance.affirmative_checkbox and acceptance.content_hash = v_version.content_hash) <> 2 then
    return jsonb_build_object('ok', false, 'code', 'current_contract_acceptance_required');
  end if;
  if v_safety.id is null or v_safety.status <> 'confirmed' then
    return jsonb_build_object('ok', false, 'code', 'mutual_safety_agreement_required');
  end if;
  if not exists (select 1 from public.profiles profile where profile.id = v_application.teen_id and profile.role = 'teen' and profile.account_status = 'active')
     or not exists (select 1 from public.profiles profile where profile.id = v_job.poster_id and profile.role = 'adult' and profile.account_status = 'active')
     or not private.has_marketplace_identity(v_application.teen_id)
     or not private.has_marketplace_identity(v_job.poster_id) then
    return jsonb_build_object('ok', false, 'code', 'participant_not_eligible');
  end if;
  if exists (
    select 1 from public.safety_incidents incident
    where (incident.application_id = v_application.id or incident.job_id = v_job.id)
      and incident.status not in ('resolved', 'closed')
  ) then return jsonb_build_object('ok', false, 'code', 'active_safety_incident_blocks_start'); end if;
  v_start_at := coalesce(v_version.start_window, v_job.starts_at);
  if v_start_at is null then return jsonb_build_object('ok', false, 'code', 'start_window_required'); end if;
  if now() < v_start_at - make_interval(mins => v_control.start_window_minutes_before)
     or now() > v_start_at + make_interval(mins => v_control.start_window_minutes_after) then
    return jsonb_build_object('ok', false, 'code', 'outside_start_window');
  end if;
  if v_control.require_funding_for_start and (
    v_funding.id is null or v_funding.status <> 'funded' or v_funding.contract_version_id <> v_contract.active_version_id
  ) then return jsonb_build_object('ok', false, 'code', 'confirmed_job_funding_required'); end if;
  return jsonb_build_object(
    'ok', true, 'application_id', v_application.id, 'job_id', v_job.id,
    'teen_id', v_application.teen_id, 'adult_id', v_job.poster_id,
    'contract_id', v_contract.id, 'contract_version_id', v_contract.active_version_id,
    'review_hours', v_control.completion_review_hours
  );
end;
$$;
revoke all on function private.get_job_execution_gate(uuid) from public, anon, authenticated;
grant execute on function private.get_job_execution_gate(uuid) to service_role;

create or replace function public.generate_job_start_pin(p_application_id uuid, p_client_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_gate jsonb;
  v_control private.job_execution_runtime_controls%rowtype;
  v_handshake public.job_arrival_handshakes%rowtype;
  v_pin text;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  select * into v_control from private.job_execution_runtime_controls where singleton;
  select * into v_handshake from public.job_arrival_handshakes where application_id = p_application_id for update;
  if v_handshake.id is null or v_handshake.adult_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'job_poster_required');
  end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  if v_handshake.start_client_request_id = p_client_request_id and v_handshake.start_pin_expires_at > now() then
    insert into public.job_execution_events(application_id, actor_id, event_type, from_state, to_state, request_id)
    values (p_application_id, auth.uid(), 'start_pin_generation_replayed', v_handshake.execution_state, v_handshake.execution_state, p_client_request_id)
    on conflict do nothing;
    return jsonb_build_object('ok', false, 'code', 'pin_not_repeated_for_replay', 'expires_at', v_handshake.start_pin_expires_at);
  end if;
  if v_handshake.execution_state not in ('awaiting_start', 'start_pin_active') then
    return jsonb_build_object('ok', false, 'code', 'job_not_awaiting_start');
  end if;
  if v_handshake.start_pin_generated_at is not null
     and v_handshake.start_pin_generated_at + make_interval(secs => v_control.pin_generation_cooldown_seconds) > now() then
    return jsonb_build_object('ok', false, 'code', 'pin_generation_rate_limited', 'retry_at', v_handshake.start_pin_generated_at + make_interval(secs => v_control.pin_generation_cooldown_seconds));
  end if;
  v_gate := private.get_job_execution_gate(p_application_id);
  if coalesce((v_gate->>'ok')::boolean, false) is not true then return v_gate; end if;
  v_pin := private.generate_six_digit_job_pin();
  update public.job_arrival_handshakes set
    execution_state = 'start_pin_active',
    start_pin_hash = extensions.crypt(v_pin, extensions.gen_salt('bf', 10)),
    start_pin_generated_at = now(),
    start_pin_expires_at = now() + make_interval(secs => v_control.pin_ttl_seconds),
    start_pin_used_at = null,
    start_pin_attempt_count = 0,
    start_pin_locked_until = null,
    start_contract_version_id = (v_gate->>'contract_version_id')::uuid,
    start_client_request_id = p_client_request_id,
    code_hash = null, code_expires_at = null, code_used_at = null,
    code_generation = code_generation + 1, updated_at = now()
  where id = v_handshake.id returning * into v_handshake;
  insert into public.job_execution_events(application_id, contract_id, contract_version_id, actor_id, event_type, from_state, to_state, request_id)
  values (p_application_id, (v_gate->>'contract_id')::uuid, (v_gate->>'contract_version_id')::uuid, auth.uid(), 'start_pin_generated', 'awaiting_start', 'start_pin_active', p_client_request_id);
  return jsonb_build_object('ok', true, 'start_pin', v_pin, 'expires_at', v_handshake.start_pin_expires_at, 'generation', v_handshake.code_generation);
end;
$$;

create or replace function public.confirm_job_start_pin(
  p_application_id uuid,
  p_pin text,
  p_person_matches_profile boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_contract public.job_contracts%rowtype;
  v_control private.job_execution_runtime_controls%rowtype;
  v_attempts integer;
begin
  select * into v_control from private.job_execution_runtime_controls where singleton;
  select * into v_handshake from public.job_arrival_handshakes where application_id = p_application_id for update;
  if v_handshake.id is null or v_handshake.teen_id <> auth.uid() then return jsonb_build_object('ok', false, 'code', 'assigned_worker_required'); end if;
  if v_handshake.start_client_request_id is not null and v_handshake.start_confirmed_by = auth.uid()
     and v_handshake.execution_state = 'in_progress' then
    return jsonb_build_object('ok', true, 'replayed', true, 'state', v_handshake.execution_state, 'started_at', v_handshake.checkin_at);
  end if;
  if not coalesce(p_person_matches_profile, false) then return public.report_person_mismatch(p_application_id, 'The person at the job did not match the MORT profile.'); end if;
  if p_pin !~ '^[0-9]{6}$' then return jsonb_build_object('ok', false, 'code', 'six_digit_pin_required'); end if;
  if v_handshake.execution_state <> 'start_pin_active' or v_handshake.start_pin_hash is null then return jsonb_build_object('ok', false, 'code', 'start_pin_not_active'); end if;
  if v_handshake.start_pin_used_at is not null then return jsonb_build_object('ok', false, 'code', 'start_pin_already_used'); end if;
  if v_handshake.start_pin_locked_until is not null and v_handshake.start_pin_locked_until > now() then return jsonb_build_object('ok', false, 'code', 'start_pin_locked', 'retry_at', v_handshake.start_pin_locked_until); end if;
  if v_handshake.start_pin_expires_at is null or v_handshake.start_pin_expires_at <= now() then return jsonb_build_object('ok', false, 'code', 'start_pin_expired'); end if;
  if extensions.crypt(p_pin, v_handshake.start_pin_hash) <> v_handshake.start_pin_hash then
    v_attempts := v_handshake.start_pin_attempt_count + 1;
    update public.job_arrival_handshakes set
      start_pin_attempt_count = v_attempts,
      start_pin_locked_until = case when v_attempts >= v_control.maximum_pin_attempts then now() + make_interval(mins => v_control.pin_lock_minutes) else null end,
      updated_at = now()
    where id = v_handshake.id;
    insert into public.job_execution_events(application_id, actor_id, event_type, from_state, to_state, request_id, safe_metadata)
    values (p_application_id, auth.uid(), case when v_attempts >= v_control.maximum_pin_attempts then 'start_pin_locked' else 'start_pin_failed_attempt' end,
      v_handshake.execution_state, v_handshake.execution_state, p_client_request_id, jsonb_build_object('attempt_count', v_attempts));
    return jsonb_build_object('ok', false, 'code', case when v_attempts >= v_control.maximum_pin_attempts then 'start_pin_locked' else 'start_pin_invalid' end, 'attempts_remaining', greatest(0, v_control.maximum_pin_attempts - v_attempts));
  end if;
  select * into v_contract from public.job_contracts where application_id = p_application_id for update;
  if v_contract.active_version_id <> v_handshake.start_contract_version_id or v_contract.status <> 'active' then return jsonb_build_object('ok', false, 'code', 'contract_changed_reconfirmation_required'); end if;
  update public.job_arrival_handshakes set
    execution_state = 'in_progress', start_pin_used_at = now(), start_confirmed_by = auth.uid(),
    checkin_at = now(), teen_identity_match_confirmed = true, adult_identity_match_confirmed = true,
    updated_at = now()
  where id = v_handshake.id returning * into v_handshake;
  update public.applications set status = 'in_progress', updated_at = now() where id = p_application_id and status = 'accepted';
  update public.jobs set status = 'in_progress', updated_at = now() where id = v_handshake.job_id and status in ('assigned', 'filled');
  insert into public.job_checkins(application_id, user_id, checkin_type, completed_at, status)
  values (p_application_id, auth.uid(), 'arrival', now(), 'completed');
  insert into public.job_execution_events(application_id, contract_id, contract_version_id, actor_id, event_type, from_state, to_state, request_id)
  values (p_application_id, v_contract.id, v_handshake.start_contract_version_id, auth.uid(), 'start_confirmed', 'start_pin_active', 'in_progress', p_client_request_id);
  perform public.enqueue_notification(v_handshake.adult_id, 'Job start confirmed', 'The in-person start PIN was confirmed. The job is now in progress.', jsonb_build_object('applicationId', p_application_id, 'route', '/jobs/progress/' || p_application_id::text));
  perform public.enqueue_notification(v_handshake.teen_id, 'Job is in progress', 'Your start confirmation was recorded. Use Safety Center at any time if needed.', jsonb_build_object('applicationId', p_application_id, 'route', '/jobs/progress/' || p_application_id::text));
  return jsonb_build_object('ok', true, 'replayed', false, 'state', v_handshake.execution_state, 'started_at', v_handshake.checkin_at);
end;
$$;

create or replace function public.generate_job_finish_pin(p_application_id uuid, p_client_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_contract public.job_contracts%rowtype;
  v_control private.job_execution_runtime_controls%rowtype;
  v_pin text;
begin
  select * into v_control from private.job_execution_runtime_controls where singleton;
  select * into v_handshake from public.job_arrival_handshakes where application_id = p_application_id for update;
  select * into v_contract from public.job_contracts where application_id = p_application_id for update;
  if v_handshake.id is null or v_handshake.adult_id <> auth.uid() then return jsonb_build_object('ok', false, 'code', 'job_poster_required'); end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  if v_handshake.execution_state not in ('in_progress', 'finish_pin_active') or v_handshake.start_pin_used_at is null then return jsonb_build_object('ok', false, 'code', 'in_progress_start_confirmation_required'); end if;
  if v_contract.status <> 'active' or v_contract.active_version_id <> v_handshake.start_contract_version_id then return jsonb_build_object('ok', false, 'code', 'contract_changed_reconfirmation_required'); end if;
  if exists (select 1 from public.payment_disputes dispute where dispute.contract_id = v_contract.id and dispute.status not like 'resolved%' and dispute.status <> 'closed_confirmed_paid') then return jsonb_build_object('ok', false, 'code', 'active_dispute_blocks_finish_pin'); end if;
  if v_handshake.finish_client_request_id = p_client_request_id and v_handshake.finish_pin_expires_at > now() then
    insert into public.job_execution_events(application_id, actor_id, event_type, from_state, to_state, request_id)
    values (p_application_id, auth.uid(), 'finish_pin_generation_replayed', v_handshake.execution_state, v_handshake.execution_state, p_client_request_id) on conflict do nothing;
    return jsonb_build_object('ok', false, 'code', 'pin_not_repeated_for_replay', 'expires_at', v_handshake.finish_pin_expires_at);
  end if;
  if v_handshake.finish_pin_generated_at is not null and v_handshake.finish_pin_generated_at + make_interval(secs => v_control.pin_generation_cooldown_seconds) > now() then
    return jsonb_build_object('ok', false, 'code', 'pin_generation_rate_limited', 'retry_at', v_handshake.finish_pin_generated_at + make_interval(secs => v_control.pin_generation_cooldown_seconds));
  end if;
  v_pin := private.generate_six_digit_job_pin();
  update public.job_arrival_handshakes set
    execution_state = 'finish_pin_active', finish_pin_hash = extensions.crypt(v_pin, extensions.gen_salt('bf', 10)),
    finish_pin_generation = finish_pin_generation + 1, finish_pin_generated_at = now(),
    finish_pin_expires_at = now() + make_interval(secs => v_control.pin_ttl_seconds),
    finish_pin_used_at = null, finish_pin_attempt_count = 0, finish_pin_locked_until = null,
    finish_contract_version_id = v_contract.active_version_id, finish_requested_by = auth.uid(),
    finish_client_request_id = p_client_request_id, updated_at = now()
  where id = v_handshake.id returning * into v_handshake;
  insert into public.job_execution_events(application_id, contract_id, contract_version_id, actor_id, event_type, from_state, to_state, request_id)
  values (p_application_id, v_contract.id, v_contract.active_version_id, auth.uid(), 'finish_pin_generated', 'in_progress', 'finish_pin_active', p_client_request_id);
  return jsonb_build_object('ok', true, 'finish_pin', v_pin, 'expires_at', v_handshake.finish_pin_expires_at, 'generation', v_handshake.finish_pin_generation);
end;
$$;

create or replace function public.confirm_job_finish_pin(p_application_id uuid, p_pin text, p_client_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_contract public.job_contracts%rowtype;
  v_control private.job_execution_runtime_controls%rowtype;
  v_attempts integer;
begin
  select * into v_control from private.job_execution_runtime_controls where singleton;
  select * into v_handshake from public.job_arrival_handshakes where application_id = p_application_id for update;
  select * into v_contract from public.job_contracts where application_id = p_application_id for update;
  if v_handshake.id is null or v_handshake.teen_id <> auth.uid() then return jsonb_build_object('ok', false, 'code', 'assigned_worker_required'); end if;
  if v_handshake.execution_state = 'completion_pending_release' and v_handshake.finish_confirmed_by = auth.uid() then
    return jsonb_build_object('ok', true, 'replayed', true, 'state', v_handshake.execution_state, 'review_window_ends_at', v_handshake.review_window_ends_at);
  end if;
  if p_pin !~ '^[0-9]{6}$' then return jsonb_build_object('ok', false, 'code', 'six_digit_pin_required'); end if;
  if v_handshake.execution_state <> 'finish_pin_active' or v_handshake.finish_pin_hash is null then return jsonb_build_object('ok', false, 'code', 'finish_pin_not_active'); end if;
  if v_handshake.finish_pin_used_at is not null then return jsonb_build_object('ok', false, 'code', 'finish_pin_already_used'); end if;
  if v_handshake.finish_pin_locked_until is not null and v_handshake.finish_pin_locked_until > now() then return jsonb_build_object('ok', false, 'code', 'finish_pin_locked', 'retry_at', v_handshake.finish_pin_locked_until); end if;
  if v_handshake.finish_pin_expires_at is null or v_handshake.finish_pin_expires_at <= now() then return jsonb_build_object('ok', false, 'code', 'finish_pin_expired'); end if;
  if v_contract.status <> 'active' or v_contract.active_version_id <> v_handshake.finish_contract_version_id or v_handshake.start_contract_version_id <> v_contract.active_version_id then
    return jsonb_build_object('ok', false, 'code', 'contract_changed_reconfirmation_required');
  end if;
  if extensions.crypt(p_pin, v_handshake.finish_pin_hash) <> v_handshake.finish_pin_hash then
    v_attempts := v_handshake.finish_pin_attempt_count + 1;
    update public.job_arrival_handshakes set
      finish_pin_attempt_count = v_attempts,
      finish_pin_locked_until = case when v_attempts >= v_control.maximum_pin_attempts then now() + make_interval(mins => v_control.pin_lock_minutes) else null end,
      updated_at = now()
    where id = v_handshake.id;
    insert into public.job_execution_events(application_id, actor_id, event_type, from_state, to_state, request_id, safe_metadata)
    values (p_application_id, auth.uid(), case when v_attempts >= v_control.maximum_pin_attempts then 'finish_pin_locked' else 'finish_pin_failed_attempt' end,
      v_handshake.execution_state, v_handshake.execution_state, p_client_request_id, jsonb_build_object('attempt_count', v_attempts));
    return jsonb_build_object('ok', false, 'code', case when v_attempts >= v_control.maximum_pin_attempts then 'finish_pin_locked' else 'finish_pin_invalid' end, 'attempts_remaining', greatest(0, v_control.maximum_pin_attempts - v_attempts));
  end if;
  update public.job_arrival_handshakes set
    execution_state = 'completion_pending_release', finish_pin_used_at = now(), finish_confirmed_by = auth.uid(),
    teen_checkout_at = now(), adult_checkout_at = coalesce(adult_checkout_at, finish_pin_generated_at),
    completion_pending_at = now(), review_window_ends_at = now() + make_interval(hours => v_control.completion_review_hours), updated_at = now()
  where id = v_handshake.id returning * into v_handshake;
  if not exists (select 1 from public.job_completion_assertions where contract_id = v_contract.id and asserted_by = v_handshake.teen_id and assertion_type = 'worker_completed') then
    insert into public.job_completion_assertions(contract_id, contract_version_id, asserted_by, assertion_role, assertion_type, start_timestamp, completion_timestamp, approved_scope_confirmation, statement)
    values (v_contract.id, v_contract.active_version_id, v_handshake.teen_id, 'teen', 'worker_completed', v_handshake.checkin_at, now(), true, 'Worker confirmed completion using the in-person finish PIN.');
  end if;
  if not exists (select 1 from public.job_completion_assertions where contract_id = v_contract.id and asserted_by = v_handshake.adult_id and assertion_type = 'adult_acknowledged') then
    insert into public.job_completion_assertions(contract_id, contract_version_id, asserted_by, assertion_role, assertion_type, start_timestamp, completion_timestamp, approved_scope_confirmation, statement)
    values (v_contract.id, v_contract.active_version_id, v_handshake.adult_id, 'adult', 'adult_acknowledged', v_handshake.checkin_at, v_handshake.finish_pin_generated_at, true, 'Adult generated the in-person finish PIN for the current agreed contract.');
  end if;
  update public.applications set status = 'completion_pending_release', updated_at = now() where id = p_application_id and status = 'in_progress';
  update public.jobs set status = 'completion_pending_release', updated_at = now() where id = v_handshake.job_id and status = 'in_progress';
  update public.job_contracts set status = 'completion_pending_release' where id = v_contract.id;
  update public.job_payment_obligations set status = 'pending_release', due_at = v_handshake.review_window_ends_at where contract_id = v_contract.id and contract_version_id = v_contract.active_version_id and status = 'pending_completion';
  update public.job_location_share_sessions set status = 'stopped', stopped_at = now() where application_id = p_application_id and status = 'active';
  update public.job_checkins set status = 'completed', completed_at = coalesce(completed_at, now()) where application_id = p_application_id and checkin_type = 'departure' and status = 'pending';
  insert into public.job_checkins(application_id, user_id, checkin_type, completed_at, status)
  select p_application_id, v_handshake.teen_id, 'departure', now(), 'completed'
  where not exists (select 1 from public.job_checkins where application_id = p_application_id and user_id = v_handshake.teen_id and checkin_type = 'departure' and status = 'completed');
  insert into public.job_execution_events(application_id, contract_id, contract_version_id, actor_id, event_type, from_state, to_state, request_id)
  values (p_application_id, v_contract.id, v_contract.active_version_id, auth.uid(), 'finish_confirmed', 'finish_pin_active', 'completion_pending_release', p_client_request_id);
  insert into public.job_execution_events(application_id, contract_id, contract_version_id, actor_id, event_type, from_state, to_state, safe_metadata)
  values (p_application_id, v_contract.id, v_contract.active_version_id, null, 'completion_review_started', 'completion_pending_release', 'completion_pending_release', jsonb_build_object('review_window_ends_at', v_handshake.review_window_ends_at));
  perform public.enqueue_notification(v_handshake.adult_id, 'Completion review window started', 'The finish PIN was confirmed. Funds remain pending release during the review window.', jsonb_build_object('applicationId', p_application_id, 'route', '/jobs/progress/' || p_application_id::text));
  perform public.enqueue_notification(v_handshake.teen_id, 'Completion recorded', 'Your finish confirmation was recorded. This does not itself guarantee transfer or resolve a dispute.', jsonb_build_object('applicationId', p_application_id, 'route', '/jobs/progress/' || p_application_id::text));
  return jsonb_build_object('ok', true, 'replayed', false, 'state', v_handshake.execution_state, 'review_window_ends_at', v_handshake.review_window_ends_at, 'money_moved', false);
end;
$$;

create or replace function public.get_job_execution_status(p_application_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_contract public.job_contracts%rowtype;
  v_role text;
  v_funding text;
begin
  select * into v_handshake from public.job_arrival_handshakes where application_id = p_application_id;
  select * into v_contract from public.job_contracts where application_id = p_application_id;
  if v_handshake.id is null or auth.uid() not in (v_handshake.teen_id, v_handshake.adult_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  v_role := case when auth.uid() = v_handshake.teen_id then 'teen' else 'adult' end;
  select payment.status into v_funding from private.stripe_job_payment_intents payment
  where payment.contract_id = v_contract.id and payment.environment = 'test'
  order by payment.operation_version desc limit 1;
  return jsonb_build_object(
    'ok', true, 'application_id', p_application_id, 'job_id', v_handshake.job_id,
    'contract_id', v_contract.id, 'role', v_role, 'state', v_handshake.execution_state,
    'start_pin_active', v_handshake.execution_state = 'start_pin_active' and v_handshake.start_pin_expires_at > now(),
    'start_pin_expires_at', v_handshake.start_pin_expires_at,
    'started_at', v_handshake.checkin_at,
    'finish_pin_active', v_handshake.execution_state = 'finish_pin_active' and v_handshake.finish_pin_expires_at > now(),
    'finish_pin_expires_at', v_handshake.finish_pin_expires_at,
    'completion_pending_at', v_handshake.completion_pending_at,
    'review_window_ends_at', v_handshake.review_window_ends_at,
    'funding_status', coalesce(v_funding, 'missing'),
    'live_payment_enabled', false
  );
end;
$$;

create or replace function private.open_execution_review_case(
  p_application_id uuid,
  p_category text,
  p_subject text,
  p_statement text,
  p_source text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract public.job_contracts%rowtype;
  v_obligation public.job_payment_obligations%rowtype;
  v_dispute public.payment_disputes%rowtype;
  v_support jsonb;
begin
  select * into v_contract from public.job_contracts where application_id = p_application_id for update;
  select * into v_obligation from public.job_payment_obligations where contract_id = v_contract.id and contract_version_id = v_contract.active_version_id for update;
  if v_obligation.id is not null then
    insert into public.payment_disputes(obligation_id, contract_id, opened_by, worker_id, poster_id, allegation_type, worker_statement)
    values (v_obligation.id, v_contract.id, auth.uid(), v_contract.teen_id, v_contract.adult_id, p_category, left(btrim(p_statement), 4000))
    on conflict (obligation_id) do update set updated_at = now()
    returning * into v_dispute;
    update public.job_payment_obligations set status = 'disputed', disputed_at = coalesce(disputed_at, now()) where id = v_obligation.id;
    update public.job_contracts set status = 'disputed' where id = v_contract.id;
    insert into public.payment_dispute_timeline(dispute_id, actor_id, event_type, event_summary)
    values (v_dispute.id, auth.uid(), p_category, 'A participant requested private review. This is an allegation, not a finding or automatic payment decision.');
  end if;
  v_support := public.create_support_conversation(
    p_category, p_subject, p_statement, p_source, v_contract.job_id,
    p_application_id, v_contract.id, v_dispute.id, gen_random_uuid()
  );
  return jsonb_build_object('ok', true, 'support', v_support, 'dispute_id', v_dispute.id, 'money_moved', false);
end;
$$;
revoke all on function private.open_execution_review_case(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function private.open_execution_review_case(uuid, text, text, text, text) to service_role;

create or replace function public.report_finish_pin_unavailable(
  p_application_id uuid,
  p_actual_start_at timestamptz,
  p_actual_finish_at timestamptz,
  p_work_completed text,
  p_statement text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_result jsonb;
begin
  select * into v_handshake from public.job_arrival_handshakes where application_id = p_application_id for update;
  if v_handshake.id is null or v_handshake.teen_id <> auth.uid() then return jsonb_build_object('ok', false, 'code', 'assigned_worker_required'); end if;
  if v_handshake.execution_state not in ('in_progress', 'finish_pin_active') or v_handshake.start_pin_used_at is null then return jsonb_build_object('ok', false, 'code', 'in_progress_start_confirmation_required'); end if;
  if p_actual_start_at is null or p_actual_finish_at is null or p_actual_finish_at < p_actual_start_at or p_actual_finish_at > now() + interval '5 minutes' then return jsonb_build_object('ok', false, 'code', 'valid_work_times_required'); end if;
  if char_length(btrim(coalesce(p_work_completed, ''))) not between 10 and 2000 or char_length(btrim(coalesce(p_statement, ''))) not between 10 and 2000 then return jsonb_build_object('ok', false, 'code', 'factual_completion_statement_required'); end if;
  if exists (select 1 from public.job_execution_events where application_id = p_application_id and event_type = 'finish_pin_unavailable_reported' and actor_id = auth.uid() and request_id = p_client_request_id) then
    return jsonb_build_object('ok', true, 'replayed', true, 'money_moved', false);
  end if;
  v_result := private.open_execution_review_case(p_application_id, 'adult_refused_completion', 'Finish PIN unavailable or refused',
    'Actual start: ' || p_actual_start_at::text || E'\nActual finish: ' || p_actual_finish_at::text || E'\nWork completed: ' || btrim(p_work_completed) || E'\nStatement: ' || btrim(p_statement), 'payment_dispute');
  update public.job_arrival_handshakes set execution_state = 'disputed', finish_pin_hash = null, finish_pin_expires_at = null, updated_at = now() where id = v_handshake.id;
  update public.applications set status = 'disputed', updated_at = now() where id = p_application_id;
  insert into public.job_execution_events(application_id, actor_id, event_type, from_state, to_state, request_id)
  values (p_application_id, auth.uid(), 'finish_pin_unavailable_reported', v_handshake.execution_state, 'disputed', p_client_request_id);
  return v_result || jsonb_build_object('replayed', false, 'notice', 'Submission does not guarantee payment. Human review may be required.');
end;
$$;

create or replace function public.request_adult_job_cancellation(
  p_application_id uuid,
  p_reason text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_contract public.job_contracts%rowtype;
  v_obligation public.job_payment_obligations%rowtype;
  v_control private.job_execution_runtime_controls%rowtype;
  v_record public.job_execution_cancellations%rowtype;
  v_stage text;
  v_bps integer;
  v_review jsonb;
begin
  select * into v_control from private.job_execution_runtime_controls where singleton;
  select * into v_handshake from public.job_arrival_handshakes where application_id = p_application_id for update;
  select * into v_contract from public.job_contracts where application_id = p_application_id for update;
  select * into v_obligation from public.job_payment_obligations where contract_id = v_contract.id and contract_version_id = v_contract.active_version_id for update;
  if v_handshake.id is null or v_handshake.adult_id <> auth.uid() then return jsonb_build_object('ok', false, 'code', 'job_poster_required'); end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 3 and 2000 then return jsonb_build_object('ok', false, 'code', 'cancellation_reason_required'); end if;
  select * into v_record from public.job_execution_cancellations where actor_id = auth.uid() and client_request_id = p_client_request_id;
  if v_record.id is not null then return jsonb_build_object('ok', true, 'replayed', true, 'cancellation', to_jsonb(v_record), 'money_moved', false); end if;
  v_stage := case when v_handshake.start_pin_used_at is null then 'before_start' else 'after_start' end;
  v_bps := case when v_stage = 'before_start' then v_control.pre_start_compensation_bps else v_control.post_start_compensation_bps end;
  if v_obligation.id is not null then
    v_review := private.open_execution_review_case(p_application_id, 'job_cancellation', 'Adult job cancellation review', btrim(p_reason), 'payment_dispute');
  else
    v_review := public.create_support_conversation('job_cancellation', 'Adult job cancellation', btrim(p_reason), 'human_support', v_handshake.job_id, p_application_id, v_contract.id, null, gen_random_uuid());
  end if;
  insert into public.job_execution_cancellations(
    application_id, contract_id, actor_id, actor_role, cancellation_stage, reason,
    recommended_compensation_cents, compensation_policy_bps, execution_status,
    support_ticket_id, dispute_id, client_request_id
  ) values (
    p_application_id, v_contract.id, auth.uid(), 'adult', v_stage, btrim(p_reason),
    coalesce(v_obligation.amount_cents, 0) * v_bps / 10000, v_bps,
    'disabled_pending_review',
    coalesce(nullif(v_review#>>'{support,ticket,id}', '')::uuid, nullif(v_review#>>'{ticket,id}', '')::uuid),
    nullif(v_review->>'dispute_id', '')::uuid, p_client_request_id
  ) returning * into v_record;
  update public.job_arrival_handshakes set execution_state = case when v_obligation.id is null then 'cancelled' else 'disputed' end, start_pin_hash = null, finish_pin_hash = null, updated_at = now() where id = v_handshake.id;
  update public.applications set status = case when v_obligation.id is null then 'withdrawn' else 'disputed' end, updated_at = now() where id = p_application_id;
  update public.jobs set status = case when v_obligation.id is null then 'cancelled' else status end, updated_at = now() where id = v_handshake.job_id;
  update public.job_contracts set status = case when v_obligation.id is null then 'cancelled' else 'disputed' end, closed_at = case when v_obligation.id is null then now() else closed_at end where id = v_contract.id;
  insert into public.job_execution_events(application_id, contract_id, contract_version_id, actor_id, event_type, from_state, to_state, request_id, safe_metadata)
  values (p_application_id, v_contract.id, v_contract.active_version_id, auth.uid(), 'adult_cancelled', v_handshake.execution_state,
    case when v_obligation.id is null then 'cancelled' else 'disputed' end, p_client_request_id,
    jsonb_build_object('stage', v_stage, 'compensation_policy_bps', v_bps, 'provider_execution_enabled', v_control.production_compensation_execution_enabled));
  return jsonb_build_object('ok', true, 'replayed', false, 'cancellation', to_jsonb(v_record), 'money_moved', false, 'human_review_required', v_obligation.id is not null);
end;
$$;

create or replace function public.submit_teen_abandonment(
  p_application_id uuid,
  p_statement text,
  p_safety_related boolean,
  p_final_confirmation boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_contract public.job_contracts%rowtype;
  v_control private.job_execution_runtime_controls%rowtype;
  v_report public.teen_abandonment_reports%rowtype;
  v_review jsonb;
  v_cooldown timestamptz;
begin
  select * into v_control from private.job_execution_runtime_controls where singleton;
  select * into v_handshake from public.job_arrival_handshakes where application_id = p_application_id for update;
  select * into v_contract from public.job_contracts where application_id = p_application_id for update;
  if v_handshake.id is null or v_handshake.teen_id <> auth.uid() then return jsonb_build_object('ok', false, 'code', 'assigned_worker_required'); end if;
  if coalesce(p_safety_related, false) then return jsonb_build_object('ok', false, 'code', 'safety_route_required', 'route', '/safety', 'cooldown_applied', false); end if;
  if not coalesce(p_final_confirmation, false) then return jsonb_build_object('ok', false, 'code', 'final_abandonment_confirmation_required'); end if;
  if v_handshake.execution_state not in ('in_progress', 'finish_pin_active') then return jsonb_build_object('ok', false, 'code', 'in_progress_job_required'); end if;
  if char_length(btrim(coalesce(p_statement, ''))) not between 10 and 2000 then return jsonb_build_object('ok', false, 'code', 'abandonment_statement_required'); end if;
  select * into v_report from public.teen_abandonment_reports where teen_id = auth.uid() and client_request_id = p_client_request_id;
  if v_report.id is not null then return jsonb_build_object('ok', true, 'replayed', true, 'report', to_jsonb(v_report), 'money_moved', false); end if;
  v_review := private.open_execution_review_case(p_application_id, 'teen_abandonment', 'Teen abandonment review', btrim(p_statement), 'payment_dispute');
  v_cooldown := case when v_control.closed_test_mode then now() + make_interval(secs => v_control.teen_abandonment_cooldown_seconds) else null end;
  insert into public.teen_abandonment_reports(application_id, contract_id, teen_id, statement, final_non_safety_confirmation, cooldown_until, support_ticket_id, dispute_id, client_request_id)
  values (p_application_id, v_contract.id, auth.uid(), btrim(p_statement), true, v_cooldown,
    nullif(v_review#>>'{support,ticket,id}', '')::uuid, nullif(v_review->>'dispute_id', '')::uuid, p_client_request_id)
  returning * into v_report;
  update public.job_arrival_handshakes set execution_state = 'disputed', finish_pin_hash = null, updated_at = now() where id = v_handshake.id;
  update public.applications set status = 'disputed', updated_at = now() where id = p_application_id;
  insert into public.job_execution_events(application_id, contract_id, contract_version_id, actor_id, event_type, from_state, to_state, request_id, safe_metadata)
  values (p_application_id, v_contract.id, v_contract.active_version_id, auth.uid(), 'teen_abandonment_reported', v_handshake.execution_state, 'disputed', p_client_request_id,
    jsonb_build_object('closed_test_cooldown_until', v_cooldown, 'safety_related', false));
  return jsonb_build_object('ok', true, 'replayed', false, 'report', to_jsonb(v_report), 'money_moved', false, 'support_and_safety_available', true);
end;
$$;

create or replace function private.enforce_teen_abandonment_cooldown()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_until timestamptz;
begin
  if coalesce(auth.jwt()->>'role', '') = 'service_role' then return new; end if;
  select max(report.cooldown_until) into v_until from public.teen_abandonment_reports report where report.teen_id = new.teen_id;
  if v_until is not null and v_until > now() then
    raise exception 'teen_abandonment_cooldown_active' using errcode = 'P0001', detail = v_until::text;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_teen_abandonment_cooldown() from public, anon, authenticated;

drop trigger if exists applications_enforce_abandonment_cooldown on public.applications;
create trigger applications_enforce_abandonment_cooldown
before insert on public.applications
for each row execute function private.enforce_teen_abandonment_cooldown();

-- Preserve callers that still use the 0.9.2 arrival names while routing all
-- state transitions through the hardened start-PIN implementation.
create or replace function public.generate_job_arrival_code(p_application_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_result jsonb;
begin
  v_result := public.generate_job_start_pin(p_application_id, gen_random_uuid());
  if coalesce((v_result->>'ok')::boolean, false) then
    return (v_result - 'start_pin') || jsonb_build_object('arrival_code', v_result->>'start_pin');
  end if;
  return v_result;
end;
$$;

create or replace function public.confirm_job_arrival_code(p_application_id uuid, p_code text, p_person_matches_profile boolean)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select public.confirm_job_start_pin(p_application_id, p_code, p_person_matches_profile, gen_random_uuid())
$$;

do $$
declare signature text;
begin
  foreach signature in array array[
    'public.generate_job_start_pin(uuid,uuid)',
    'public.confirm_job_start_pin(uuid,text,boolean,uuid)',
    'public.generate_job_finish_pin(uuid,uuid)',
    'public.confirm_job_finish_pin(uuid,text,uuid)',
    'public.get_job_execution_status(uuid)',
    'public.report_finish_pin_unavailable(uuid,timestamptz,timestamptz,text,text,uuid)',
    'public.request_adult_job_cancellation(uuid,text,uuid)',
    'public.submit_teen_abandonment(uuid,text,boolean,boolean,uuid)',
    'public.generate_job_arrival_code(uuid)',
    'public.confirm_job_arrival_code(uuid,text,boolean)'
  ] loop
    execute format('revoke all on function %s from public, anon', signature);
    execute format('grant execute on function %s to authenticated, service_role', signature);
  end loop;
end $$;

-- Extend support linking after the new enum value is committed in this release.
create or replace function private.can_link_support_subject(
  p_user_id uuid,
  p_job_id uuid,
  p_application_id uuid,
  p_contract_id uuid,
  p_dispute_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (p_job_id is null or exists (
      select 1 from public.jobs job
      where job.id = p_job_id and (
        job.poster_id = p_user_id or exists (
          select 1 from public.applications application
          where application.job_id = job.id and application.teen_id = p_user_id
            and application.status in ('accepted', 'in_progress', 'proof_submitted', 'completion_pending_release', 'completed', 'disputed')
        )
      )
    ))
    and (p_application_id is null or exists (
      select 1 from public.applications application join public.jobs job on job.id = application.job_id
      where application.id = p_application_id and p_user_id in (application.teen_id, job.poster_id)
    ))
    and (p_contract_id is null or exists (
      select 1 from public.job_contracts contract where contract.id = p_contract_id and p_user_id in (contract.teen_id, contract.adult_id)
    ))
    and (p_dispute_id is null or exists (
      select 1 from public.payment_disputes dispute where dispute.id = p_dispute_id and p_user_id in (dispute.worker_id, dispute.poster_id)
    ))
$$;
