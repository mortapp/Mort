-- Execution PINs are private, short-lived handoff controls on the live
-- job_assignments schema. They never verify identity or move money.
create table private.job_execution_sessions (
  assignment_id uuid primary key
    references public.job_assignments(id) on delete restrict,
  application_id uuid not null
    references public.job_applications(id) on delete restrict,
  job_id uuid not null references public.jobs(id) on delete restrict,
  execution_state text not null default 'awaiting_start',
  start_pin_hash text,
  start_pin_generated_at timestamptz,
  start_pin_expires_at timestamptz,
  start_pin_used_at timestamptz,
  start_pin_attempt_count integer not null default 0,
  start_pin_locked_until timestamptz,
  start_client_request_id uuid,
  finish_pin_hash text,
  finish_pin_generated_at timestamptz,
  finish_pin_expires_at timestamptz,
  finish_pin_used_at timestamptz,
  finish_pin_attempt_count integer not null default 0,
  finish_pin_locked_until timestamptz,
  finish_client_request_id uuid,
  completion_pending_at timestamptz,
  review_window_ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_execution_sessions_state_check check (execution_state in (
    'awaiting_start', 'start_pin_active', 'in_progress', 'finish_pin_active',
    'completion_pending_release', 'disputed', 'cancelled', 'completed'
  )),
  constraint job_execution_sessions_attempts_check check (
    start_pin_attempt_count between 0 and 100
    and finish_pin_attempt_count between 0 and 100
  ),
  constraint job_execution_sessions_start_hash_check check (
    start_pin_hash is null or start_pin_hash like '$2%'
  ),
  constraint job_execution_sessions_finish_hash_check check (
    finish_pin_hash is null or finish_pin_hash like '$2%'
  )
);

create unique index job_execution_sessions_application_idx
  on private.job_execution_sessions(application_id);
alter table private.job_execution_sessions enable row level security;
alter table private.job_execution_sessions force row level security;
revoke all on private.job_execution_sessions from public, anon, authenticated;
grant all on private.job_execution_sessions to service_role;

create table private.job_execution_events (
  id bigint generated always as identity primary key,
  assignment_id uuid not null
    references public.job_assignments(id) on delete restrict,
  application_id uuid not null
    references public.job_applications(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  from_state text,
  to_state text,
  request_id uuid,
  safe_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint job_execution_events_type_check check (event_type in (
    'start_pin_generated', 'start_pin_failed_attempt', 'start_pin_locked',
    'start_confirmed', 'finish_pin_generated', 'finish_pin_failed_attempt',
    'finish_pin_locked', 'finish_confirmed',
    'finish_pin_unavailable_reported', 'adult_cancellation_requested',
    'teen_abandonment_reported', 'teen_abandonment_response'
  ))
);
create index job_execution_events_application_idx
  on private.job_execution_events(application_id, created_at desc);
create unique index job_execution_events_request_idx
  on private.job_execution_events(application_id, event_type, actor_id, request_id)
  where request_id is not null;
alter table private.job_execution_events enable row level security;
alter table private.job_execution_events force row level security;
revoke all on private.job_execution_events from public, anon, authenticated;
grant all on private.job_execution_events to service_role;

create table private.job_pin_confirmation_requests (
  actor_id uuid not null references auth.users(id) on delete cascade,
  client_request_id uuid not null,
  application_id uuid not null
    references public.job_applications(id) on delete restrict,
  pin_kind text not null check (pin_kind in ('start', 'finish')),
  pin_hash text not null,
  person_matches_profile boolean,
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor_id, client_request_id),
  constraint job_pin_confirmation_request_hash_check check (pin_hash like '$2%')
);
alter table private.job_pin_confirmation_requests enable row level security;
alter table private.job_pin_confirmation_requests force row level security;
revoke all on private.job_pin_confirmation_requests from public, anon, authenticated;
grant all on private.job_pin_confirmation_requests to service_role;

create or replace function private.job_execution_gate(
  p_application_id uuid,
  p_operation text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_application public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_teen public.profiles%rowtype;
  v_adult public.profiles%rowtype;
  v_contract public.job_contracts%rowtype;
  v_version public.job_contract_versions%rowtype;
  v_safety public.job_safety_agreements%rowtype;
  v_safety_terms jsonb;
  v_acceptances integer;
  v_funded boolean := false;
  v_runtime jsonb;
  v_start_at timestamptz;
begin
  if p_operation is null or p_operation not in ('start', 'finish') then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_execution_operation');
  end if;
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;

  select assignment.* into v_assignment
    from public.job_assignments assignment
   where assignment.application_id = p_application_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if v_user_id not in (v_assignment.teen_user_id, v_assignment.adult_user_id) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if p_operation = 'start' and v_assignment.status <> 'accepted' then
    return jsonb_build_object('ok', false, 'code', 'job_not_awaiting_start');
  end if;
  if p_operation = 'finish' and v_assignment.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'job_not_in_progress');
  end if;

  select application.* into v_application
    from public.job_applications application
   where application.id = v_assignment.application_id
     and application.job_id = v_assignment.job_id;
  if not found or v_application.status <> 'accepted'::public.mort_application_status then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;
  select job.* into v_job
    from public.jobs job
   where job.id = v_assignment.job_id
     and job.poster_id = v_assignment.adult_user_id;
  if not found or (p_operation = 'start' and v_job.status <> 'filled')
     or (p_operation = 'finish' and v_job.status <> 'in_progress') then
    return jsonb_build_object('ok', false, 'code', 'assigned_job_required');
  end if;

  select profile.* into v_teen from public.profiles profile
   where profile.id = v_assignment.teen_user_id;
  select profile.* into v_adult from public.profiles profile
   where profile.id = v_assignment.adult_user_id;
  if v_teen.role <> 'teen' or v_adult.role <> 'adult'
     or v_teen.account_status <> 'active'
     or v_adult.account_status <> 'active'
     or v_teen.verification_status::text <> 'approved'
     or v_adult.verification_status::text <> 'approved' then
    return jsonb_build_object('ok', false, 'code', 'participant_not_eligible');
  end if;

  select contract.* into v_contract from public.job_contracts contract
   where contract.application_id = p_application_id
     and contract.job_id = v_job.id
     and contract.teen_id = v_assignment.teen_user_id
     and contract.adult_id = v_assignment.adult_user_id;
  if not found or v_contract.status <> 'active'
     or v_contract.active_version_id is null then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  select version.* into v_version from public.job_contract_versions version
   where version.id = v_contract.active_version_id
     and version.contract_id = v_contract.id
     and version.status = 'active';
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  select count(distinct acceptance.user_id)::integer into v_acceptances
    from public.job_contract_acceptances acceptance
   where acceptance.contract_id = v_contract.id
     and acceptance.contract_version_id = v_version.id
     and acceptance.content_hash = v_version.content_hash
     and acceptance.affirmative_checkbox
     and ((acceptance.user_id = v_assignment.teen_user_id and acceptance.party_role = 'teen')
       or (acceptance.user_id = v_assignment.adult_user_id and acceptance.party_role = 'adult'));
  if v_acceptances <> 2 then
    return jsonb_build_object('ok', false, 'code', 'current_contract_acceptance_required');
  end if;

  select agreement.* into v_safety from public.job_safety_agreements agreement
   where agreement.application_id = p_application_id
     and agreement.teen_id = v_assignment.teen_user_id
     and agreement.adult_id = v_assignment.adult_user_id;
  if not found or v_safety.status <> 'confirmed'
     or v_safety.teen_confirmed_version <> v_safety.agreement_version
     or v_safety.adult_confirmed_version <> v_safety.agreement_version then
    return jsonb_build_object('ok', false, 'code', 'mutual_safety_agreement_required');
  end if;
  v_safety_terms := private.job_safety_terms(p_application_id);
  if v_safety_terms is null
     or v_safety.material_terms_hash <> encode(extensions.digest(v_safety.terms_snapshot::text, 'sha256'), 'hex')
     or v_safety.material_terms_hash <> encode(extensions.digest(v_safety_terms::text, 'sha256'), 'hex') then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_version_changed');
  end if;
  if not exists (
    select 1 from public.job_safety_plans plan
     where plan.application_id = p_application_id
       and plan.checkin_cadence_minutes between 15 and 240
       and (plan.expected_people is not null or v_job.remote_allowed)
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_required');
  end if;
  if exists (
    select 1 from public.safety_reports report
     where (report.application_id = p_application_id or report.job_id = v_job.id)
       and report.status not in ('resolved', 'dismissed', 'closed')
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_safety_incident_blocks_start');
  end if;
  if exists (
    select 1 from public.disputes dispute
     where dispute.assignment_id = v_assignment.id
       and dispute.status in ('open', 'investigating', 'awaiting_evidence')
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_dispute_blocks_execution');
  end if;

  if p_operation = 'start' then
    v_start_at := coalesce(v_version.start_window, v_job.starts_at);
    if v_start_at is null then
      return jsonb_build_object('ok', false, 'code', 'start_window_required');
    end if;
    if now() < v_start_at - interval '2 hours'
       or now() > v_start_at + interval '4 hours' then
      return jsonb_build_object('ok', false, 'code', 'outside_start_window');
    end if;
    v_runtime := public.get_runtime_feature_status();
    if coalesce((v_runtime->>'payments_disabled')::boolean, true) then
      return jsonb_build_object('ok', false, 'code', 'confirmed_job_funding_required');
    end if;
    select exists (
      select 1 from private.stripe_payment_intents payment
       where payment.assignment_id = v_assignment.id
         and payment.environment = 'live'
         and payment.status in ('succeeded', 'authorized')
    ) into v_funded;
    if not v_funded then
      return jsonb_build_object('ok', false, 'code', 'confirmed_job_funding_required');
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'application_id', p_application_id,
    'assignment_id', v_assignment.id,
    'job_id', v_job.id,
    'teen_id', v_assignment.teen_user_id,
    'adult_id', v_assignment.adult_user_id,
    'contract_id', v_contract.id,
    'contract_version_id', v_version.id,
    'contract_content_hash', v_version.content_hash,
    'safety_agreement_version', v_safety.agreement_version,
    'start_window', coalesce(v_version.start_window, v_job.starts_at)
  );
end;
$function$;
revoke all on function private.job_execution_gate(uuid, text) from public, anon, authenticated;

create or replace function private.generate_job_start_pin_internal(
  p_application_id uuid,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_session private.job_execution_sessions%rowtype;
  v_gate jsonb;
  v_pin text;
  v_random bytea;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id
   for update;
  if not found or v_assignment.adult_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  v_gate := private.job_execution_gate(p_application_id, 'start');
  if coalesce((v_gate->>'ok')::boolean, false) is not true then
    return v_gate;
  end if;

  insert into private.job_execution_sessions(assignment_id, application_id, job_id)
  values (v_assignment.id, v_assignment.application_id, v_assignment.job_id)
  on conflict (assignment_id) do nothing;
  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id = v_assignment.id for update;
  if v_session.start_pin_used_at is not null then
    return jsonb_build_object('ok', false, 'code', 'start_pin_already_used');
  end if;
  if v_session.start_client_request_id = p_client_request_id then
    return jsonb_build_object(
      'ok', false,
      'code', 'pin_generation_replayed',
      'expires_at', v_session.start_pin_expires_at
    );
  end if;
  if v_session.start_pin_generated_at is not null
     and v_session.start_pin_generated_at + interval '60 seconds' > now() then
    return jsonb_build_object(
      'ok', false,
      'code', 'pin_generation_rate_limited',
      'retry_at', v_session.start_pin_generated_at + interval '60 seconds'
    );
  end if;
  v_random := extensions.gen_random_bytes(4);
  v_pin := lpad((mod(
    get_byte(v_random, 0)::bigint * 16777216
      + get_byte(v_random, 1)::bigint * 65536
      + get_byte(v_random, 2)::bigint * 256
      + get_byte(v_random, 3)::bigint,
    1000000
  ))::text, 6, '0');
  update private.job_execution_sessions
     set execution_state = 'start_pin_active',
         start_pin_hash = extensions.crypt(v_pin, extensions.gen_salt('bf', 10)),
         start_pin_generated_at = now(),
         start_pin_expires_at = now() + interval '10 minutes',
         start_pin_used_at = null,
         start_pin_attempt_count = 0,
         start_pin_locked_until = null,
         start_client_request_id = p_client_request_id,
         updated_at = now()
   where assignment_id = v_assignment.id
   returning * into v_session;
  insert into private.job_execution_events(
    assignment_id, application_id, actor_id, event_type,
    from_state, to_state, request_id
  ) values (
    v_assignment.id, p_application_id, v_user_id, 'start_pin_generated',
    'awaiting_start', 'start_pin_active', p_client_request_id
  ) on conflict do nothing;
  return jsonb_build_object(
    'ok', true,
    'start_pin', v_pin,
    'expires_at', v_session.start_pin_expires_at,
    'state', 'start_pin_active'
  );
end;
$function$;

create or replace function private.confirm_job_start_pin_internal(
  p_application_id uuid,
  p_pin text,
  p_person_matches_profile boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_session private.job_execution_sessions%rowtype;
  v_request private.job_pin_confirmation_requests%rowtype;
  v_gate jsonb;
  v_response jsonb;
  v_attempts integer;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text || ':' || p_client_request_id::text, 0)
  );
  select request.* into v_request from private.job_pin_confirmation_requests request
   where request.actor_id = v_user_id and request.client_request_id = p_client_request_id;
  if found then
    if v_request.application_id <> p_application_id
       or v_request.pin_kind <> 'start'
       or v_request.person_matches_profile is distinct from p_person_matches_profile
       or extensions.crypt(coalesce(p_pin, ''), v_request.pin_hash) <> v_request.pin_hash then
      return jsonb_build_object('ok', false, 'code', 'pin_request_payload_mismatch');
    end if;
    return v_request.response || jsonb_build_object('replayed', true);
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id
   for update;
  if not found or v_assignment.teen_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;

  if p_person_matches_profile is null then
    return jsonb_build_object('ok', false, 'code', 'person_match_confirmation_required');
  end if;

  if coalesce(p_person_matches_profile, false) is false then
    if v_assignment.status <> 'accepted' then
      return jsonb_build_object('ok', false, 'code', 'job_not_awaiting_start');
    end if;
    return private.submit_safety_cancellation_internal(
      p_application_id,
      'person_mismatch',
      'The teen reported that the adult present did not match the profile for this job. Do not proceed until reviewed.'
    ) || jsonb_build_object('code', 'person_mismatch_reported');
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'code', 'start_pin_invalid');
  end if;
  v_gate := private.job_execution_gate(p_application_id, 'start');
  if coalesce((v_gate->>'ok')::boolean, false) is not true then
    return v_gate;
  end if;
  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id = v_assignment.id for update;
  if not found or v_session.start_pin_hash is null then
    return jsonb_build_object('ok', false, 'code', 'start_pin_required');
  end if;
  if v_session.start_pin_used_at is not null then
    return jsonb_build_object('ok', false, 'code', 'start_pin_already_used');
  end if;
  if v_session.start_pin_locked_until > now() then
    return jsonb_build_object('ok', false, 'code', 'start_pin_locked');
  end if;
  if v_session.start_pin_expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'start_pin_expired');
  end if;

  if extensions.crypt(p_pin, v_session.start_pin_hash) <> v_session.start_pin_hash then
    v_attempts := v_session.start_pin_attempt_count + 1;
    update private.job_execution_sessions
       set start_pin_attempt_count = v_attempts,
           start_pin_locked_until = case when v_attempts >= 5 then now() + interval '30 minutes' else null end,
           updated_at = now()
     where assignment_id = v_assignment.id;
    insert into private.job_execution_events(
      assignment_id, application_id, actor_id, event_type,
      from_state, to_state, request_id, safe_metadata
    ) values (
      v_assignment.id, p_application_id, v_user_id,
      case when v_attempts >= 5 then 'start_pin_locked' else 'start_pin_failed_attempt' end,
      'start_pin_active', 'start_pin_active', p_client_request_id,
      jsonb_build_object('attempt_count', v_attempts)
    ) on conflict do nothing;
    v_response := jsonb_build_object(
      'ok', false,
      'code', case when v_attempts >= 5 then 'start_pin_locked' else 'start_pin_invalid' end,
      'attempts_remaining', greatest(0, 5 - v_attempts)
    );
  else
    update private.job_execution_sessions
       set execution_state = 'in_progress',
           start_pin_used_at = now(), start_pin_hash = null,
           finish_pin_hash = null,
           updated_at = now()
     where assignment_id = v_assignment.id;
    update public.job_assignments
       set status = 'in_progress', started_at = coalesce(started_at, now())
     where id = v_assignment.id;
    update public.jobs set status = 'in_progress', updated_at = now()
     where id = v_assignment.job_id and status = 'filled';
    insert into private.job_execution_events(
      assignment_id, application_id, actor_id, event_type,
      from_state, to_state, request_id
    ) values (
      v_assignment.id, p_application_id, v_user_id, 'start_confirmed',
      'start_pin_active', 'in_progress', p_client_request_id
    ) on conflict do nothing;
    v_response := jsonb_build_object(
      'ok', true, 'replayed', false, 'state', 'in_progress', 'money_moved', false
    );
  end if;

  insert into private.job_pin_confirmation_requests(
    actor_id, client_request_id, application_id, pin_kind,
    pin_hash, person_matches_profile, response
  ) values (
    v_user_id, p_client_request_id, p_application_id, 'start',
    extensions.crypt(coalesce(p_pin, ''), extensions.gen_salt('bf', 10)),
    p_person_matches_profile, v_response
  ) on conflict (actor_id, client_request_id) do nothing;
  return v_response;
end;
$function$;

create or replace function private.generate_job_finish_pin_internal(
  p_application_id uuid,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_session private.job_execution_sessions%rowtype;
  v_gate jsonb;
  v_pin text;
  v_random bytea;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id
   for update;
  if not found or v_assignment.adult_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  v_gate := private.job_execution_gate(p_application_id, 'finish');
  if coalesce((v_gate->>'ok')::boolean, false) is not true then
    return v_gate;
  end if;
  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id = v_assignment.id for update;
  if not found or v_session.execution_state not in ('in_progress', 'finish_pin_active') then
    return jsonb_build_object('ok', false, 'code', 'job_not_in_progress');
  end if;
  if v_session.finish_client_request_id = p_client_request_id then
    return jsonb_build_object(
      'ok', false,
      'code', 'pin_generation_replayed',
      'expires_at', v_session.finish_pin_expires_at
    );
  end if;
  if v_session.finish_pin_generated_at is not null
     and v_session.finish_pin_generated_at + interval '60 seconds' > now() then
    return jsonb_build_object(
      'ok', false,
      'code', 'pin_generation_rate_limited',
      'retry_at', v_session.finish_pin_generated_at + interval '60 seconds'
    );
  end if;
  v_random := extensions.gen_random_bytes(4);
  v_pin := lpad((mod(
    get_byte(v_random, 0)::bigint * 16777216
      + get_byte(v_random, 1)::bigint * 65536
      + get_byte(v_random, 2)::bigint * 256
      + get_byte(v_random, 3)::bigint,
    1000000
  ))::text, 6, '0');
  update private.job_execution_sessions
     set execution_state = 'finish_pin_active',
         finish_pin_hash = extensions.crypt(v_pin, extensions.gen_salt('bf', 10)),
         finish_pin_generated_at = now(),
         finish_pin_expires_at = now() + interval '10 minutes',
         finish_pin_used_at = null,
         finish_pin_attempt_count = 0,
         finish_pin_locked_until = null,
         finish_client_request_id = p_client_request_id,
         updated_at = now()
   where assignment_id = v_assignment.id
   returning * into v_session;
  update public.job_assignments set completed_by_adult_at = now()
   where id = v_assignment.id;
  insert into private.job_execution_events(
    assignment_id, application_id, actor_id, event_type,
    from_state, to_state, request_id
  ) values (
    v_assignment.id, p_application_id, v_user_id, 'finish_pin_generated',
    'in_progress', 'finish_pin_active', p_client_request_id
  ) on conflict do nothing;
  return jsonb_build_object(
    'ok', true,
    'finish_pin', v_pin,
    'expires_at', v_session.finish_pin_expires_at,
    'state', 'finish_pin_active'
  );
end;
$function$;

create or replace function private.confirm_job_finish_pin_internal(
  p_application_id uuid,
  p_pin text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_session private.job_execution_sessions%rowtype;
  v_request private.job_pin_confirmation_requests%rowtype;
  v_gate jsonb;
  v_response jsonb;
  v_attempts integer;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text || ':' || p_client_request_id::text, 0)
  );
  select request.* into v_request from private.job_pin_confirmation_requests request
   where request.actor_id = v_user_id and request.client_request_id = p_client_request_id;
  if found then
    if v_request.application_id <> p_application_id
       or v_request.pin_kind <> 'finish'
       or extensions.crypt(coalesce(p_pin, ''), v_request.pin_hash) <> v_request.pin_hash then
      return jsonb_build_object('ok', false, 'code', 'pin_request_payload_mismatch');
    end if;
    return v_request.response || jsonb_build_object('replayed', true);
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id
   for update;
  if not found or v_assignment.teen_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'code', 'finish_pin_invalid');
  end if;
  v_gate := private.job_execution_gate(p_application_id, 'finish');
  if coalesce((v_gate->>'ok')::boolean, false) is not true then
    return v_gate;
  end if;
  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id = v_assignment.id for update;
  if not found or v_session.finish_pin_hash is null then
    return jsonb_build_object('ok', false, 'code', 'finish_pin_required');
  end if;
  if v_session.finish_pin_used_at is not null then
    return jsonb_build_object('ok', false, 'code', 'finish_pin_already_used');
  end if;
  if v_session.finish_pin_locked_until > now() then
    return jsonb_build_object('ok', false, 'code', 'finish_pin_locked');
  end if;
  if v_session.finish_pin_expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'finish_pin_expired');
  end if;

  if extensions.crypt(p_pin, v_session.finish_pin_hash) <> v_session.finish_pin_hash then
    v_attempts := v_session.finish_pin_attempt_count + 1;
    update private.job_execution_sessions
       set finish_pin_attempt_count = v_attempts,
           finish_pin_locked_until = case when v_attempts >= 5 then now() + interval '30 minutes' else null end,
           updated_at = now()
     where assignment_id = v_assignment.id;
    insert into private.job_execution_events(
      assignment_id, application_id, actor_id, event_type,
      from_state, to_state, request_id, safe_metadata
    ) values (
      v_assignment.id, p_application_id, v_user_id,
      case when v_attempts >= 5 then 'finish_pin_locked' else 'finish_pin_failed_attempt' end,
      'finish_pin_active', 'finish_pin_active', p_client_request_id,
      jsonb_build_object('attempt_count', v_attempts)
    ) on conflict do nothing;
    v_response := jsonb_build_object(
      'ok', false,
      'code', case when v_attempts >= 5 then 'finish_pin_locked' else 'finish_pin_invalid' end,
      'attempts_remaining', greatest(0, 5 - v_attempts)
    );
  else
    update private.job_execution_sessions
       set execution_state = 'completion_pending_release',
           finish_pin_used_at = now(), finish_pin_hash = null,
           completion_pending_at = now(),
           review_window_ends_at = now() + interval '24 hours',
           updated_at = now()
     where assignment_id = v_assignment.id;
    update public.job_assignments
       set status = 'awaiting_confirmation',
           completed_by_teen_at = coalesce(completed_by_teen_at, now())
     where id = v_assignment.id;
    update public.jobs set status = 'under_review', updated_at = now()
     where id = v_assignment.job_id and status = 'in_progress';
    insert into private.job_execution_events(
      assignment_id, application_id, actor_id, event_type,
      from_state, to_state, request_id
    ) values (
      v_assignment.id, p_application_id, v_user_id, 'finish_confirmed',
      'finish_pin_active', 'completion_pending_release', p_client_request_id
    ) on conflict do nothing;
    v_response := jsonb_build_object(
      'ok', true,
      'replayed', false,
      'state', 'completion_pending_release',
      'review_window_ends_at', now() + interval '24 hours',
      'money_moved', false
    );
  end if;
  insert into private.job_pin_confirmation_requests(
    actor_id, client_request_id, application_id, pin_kind,
    pin_hash, person_matches_profile, response
  ) values (
    v_user_id, p_client_request_id, p_application_id, 'finish',
    extensions.crypt(coalesce(p_pin, ''), extensions.gen_salt('bf', 10)),
    null, v_response
  ) on conflict (actor_id, client_request_id) do nothing;
  return v_response;
end;
$function$;

create or replace function private.get_job_execution_status_internal(p_application_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_contract public.job_contracts%rowtype;
  v_session private.job_execution_sessions%rowtype;
  v_funding_status text;
  v_live_payment_enabled boolean := false;
  v_state text;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id
     and v_user_id in (assignment.teen_user_id, assignment.adult_user_id);
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  select contract.* into v_contract from public.job_contracts contract
   where contract.application_id = p_application_id
     and v_user_id in (contract.teen_id, contract.adult_id);
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_contract_required');
  end if;
  select session.* into v_session from private.job_execution_sessions session
   where session.assignment_id = v_assignment.id;
  select payment.status into v_funding_status
    from public.payment_records payment
   where payment.assignment_id = v_assignment.id
     and v_user_id in (payment.payer_id, payment.payee_id)
   order by payment.updated_at desc, payment.created_at desc limit 1;
  if v_funding_status is null then
    select payment.status into v_funding_status
      from private.stripe_payment_intents payment
     where payment.assignment_id = v_assignment.id
     order by payment.updated_at desc limit 1;
  end if;
  v_live_payment_enabled := coalesce(
    not ((public.get_runtime_feature_status()->>'payments_disabled')::boolean), false
  );
  v_state := case
    when v_assignment.status = 'awaiting_confirmation' then 'completion_pending_release'
    when v_assignment.status = 'completed' then 'completed'
    when v_assignment.status = 'cancelled' then 'cancelled'
    when v_assignment.status = 'disputed' then 'disputed'
    when v_session.finish_pin_hash is not null
      and v_session.finish_pin_expires_at > now() then 'finish_pin_active'
    when v_assignment.status = 'in_progress' then 'in_progress'
    when v_session.start_pin_hash is not null
      and v_session.start_pin_expires_at > now() then 'start_pin_active'
    else 'awaiting_start'
  end;
  return pg_catalog.jsonb_build_object(
    'ok', true,
    'application_id', v_assignment.application_id,
    'job_id', v_assignment.job_id,
    'contract_id', v_contract.id,
    'role', case when v_user_id = v_assignment.teen_user_id then 'teen' else 'adult' end,
    'state', v_state,
    'funding_status', case when v_funding_status in ('succeeded', 'authorized') then 'funded'
                           else coalesce(v_funding_status, 'missing') end,
    'start_pin_active', v_session.start_pin_hash is not null
      and v_session.start_pin_expires_at > now(),
    'finish_pin_active', v_session.finish_pin_hash is not null
      and v_session.finish_pin_expires_at > now(),
    'live_payment_enabled', v_live_payment_enabled,
    'start_pin_expires_at', v_session.start_pin_expires_at,
    'finish_pin_expires_at', v_session.finish_pin_expires_at,
    'started_at', v_assignment.started_at,
    'completion_pending_at', coalesce(v_session.completion_pending_at, v_assignment.completed_by_teen_at),
    'review_window_ends_at', v_session.review_window_ends_at,
    'contract_ready', v_contract.status = 'active' and v_contract.active_version_id is not null,
    'execution_actions_enabled', true,
    'execution_actions_reason', null
  );
end;
$function$;

revoke all on function private.get_job_execution_status_internal(uuid)
  from public, anon;
grant execute on function private.get_job_execution_status_internal(uuid)
  to authenticated;

create or replace function public.generate_job_start_pin(p_application_id uuid, p_client_request_id uuid)
returns jsonb language sql security invoker set search_path = '' as $function$
  select private.generate_job_start_pin_internal(p_application_id, p_client_request_id);
$function$;
create or replace function public.confirm_job_start_pin_v2(
  p_application_id uuid, p_pin text, p_person_matches_profile boolean, p_client_request_id uuid
)
returns jsonb language sql security invoker set search_path = '' as $function$
  select private.confirm_job_start_pin_internal(
    p_application_id, p_pin, p_person_matches_profile, p_client_request_id
  );
$function$;
create or replace function public.generate_job_finish_pin(p_application_id uuid, p_client_request_id uuid)
returns jsonb language sql security invoker set search_path = '' as $function$
  select private.generate_job_finish_pin_internal(p_application_id, p_client_request_id);
$function$;
create or replace function public.confirm_job_finish_pin_v2(
  p_application_id uuid, p_pin text, p_client_request_id uuid
)
returns jsonb language sql security invoker set search_path = '' as $function$
  select private.confirm_job_finish_pin_internal(
    p_application_id, p_pin, p_client_request_id
  );
$function$;
create or replace function public.get_job_execution_status(p_application_id uuid)
returns jsonb language sql stable security invoker set search_path = '' as $function$
  select private.get_job_execution_status_internal(p_application_id);
$function$;

revoke all on function private.generate_job_start_pin_internal(uuid, uuid)
  from public, anon;
grant execute on function private.generate_job_start_pin_internal(uuid, uuid)
  to authenticated;
revoke all on function private.confirm_job_start_pin_internal(uuid, text, boolean, uuid)
  from public, anon;
grant execute on function private.confirm_job_start_pin_internal(uuid, text, boolean, uuid)
  to authenticated;
revoke all on function private.generate_job_finish_pin_internal(uuid, uuid)
  from public, anon;
grant execute on function private.generate_job_finish_pin_internal(uuid, uuid)
  to authenticated;
revoke all on function private.confirm_job_finish_pin_internal(uuid, text, uuid)
  from public, anon;
grant execute on function private.confirm_job_finish_pin_internal(uuid, text, uuid)
  to authenticated;

revoke all on function public.generate_job_start_pin(uuid, uuid) from public, anon;
grant execute on function public.generate_job_start_pin(uuid, uuid) to authenticated;
revoke all on function public.confirm_job_start_pin_v2(uuid, text, boolean, uuid)
  from public, anon;
grant execute on function public.confirm_job_start_pin_v2(uuid, text, boolean, uuid)
  to authenticated;
revoke all on function public.generate_job_finish_pin(uuid, uuid) from public, anon;
grant execute on function public.generate_job_finish_pin(uuid, uuid) to authenticated;
revoke all on function public.confirm_job_finish_pin_v2(uuid, text, uuid)
  from public, anon;
grant execute on function public.confirm_job_finish_pin_v2(uuid, text, uuid)
  to authenticated;
revoke all on function public.get_job_execution_status(uuid) from public, anon;
grant execute on function public.get_job_execution_status(uuid) to authenticated;

-- The Flutter execution UI also exposes cancellation, unavailable-PIN review,
-- and an allegation/response workflow. These actions open human-review disputes;
-- none adjudicates fault, applies a cooldown, or moves money.
create table public.job_execution_review_responses (
  id uuid primary key default extensions.gen_random_uuid(),
  dispute_id uuid not null references public.disputes(id) on delete restrict,
  assignment_id uuid not null references public.job_assignments(id) on delete restrict,
  responded_by uuid not null references public.profiles(id) on delete restrict,
  client_request_id uuid not null,
  statement text not null check (char_length(btrim(statement)) between 10 and 2000),
  safety_related boolean not null,
  created_at timestamptz not null default now(),
  constraint job_execution_review_responses_request_key
    unique (assignment_id, responded_by, client_request_id)
);
alter table public.job_execution_review_responses enable row level security;
revoke all on public.job_execution_review_responses from public, anon;
grant select on public.job_execution_review_responses to authenticated;
create policy job_execution_review_responses_participants_read
  on public.job_execution_review_responses for select to authenticated
  using (
    private.can_access_assignment(assignment_id)
    or private.has_staff_role(array['admin'::public.mort_role, 'moderator'::public.mort_role])
  );

create or replace function private.report_finish_pin_unavailable_internal(
  p_application_id uuid,
  p_actual_start_at timestamptz,
  p_actual_finish_at timestamptz,
  p_work_completed text,
  p_statement text,
  p_client_request_id uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_dispute public.disputes%rowtype;
  v_existing private.job_execution_events%rowtype;
  v_description text;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id for update;
  if not found or v_assignment.teen_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'assigned_worker_required');
  end if;
  select event.* into v_existing from private.job_execution_events event
   where event.application_id = p_application_id and event.actor_id = v_user_id
     and event.event_type = 'finish_pin_unavailable_reported'
     and event.request_id = p_client_request_id;
  if found then
    return jsonb_build_object('ok', true, 'replayed', true,
      'dispute_id', v_existing.safe_metadata->>'dispute_id', 'money_moved', false);
  end if;
  if v_assignment.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'in_progress_start_confirmation_required');
  end if;
  if p_actual_start_at is null or p_actual_finish_at is null
     or p_actual_start_at < now() - interval '7 days'
     or p_actual_finish_at < p_actual_start_at
     or p_actual_finish_at > now() + interval '5 minutes' then
    return jsonb_build_object('ok', false, 'code', 'valid_work_times_required');
  end if;
  if char_length(btrim(coalesce(p_work_completed, ''))) not between 10 and 2000
     or char_length(btrim(coalesce(p_statement, ''))) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'factual_completion_statement_required');
  end if;
  v_description := 'Finish PIN unavailable. Actual start: ' || p_actual_start_at::text
    || E'\nActual finish: ' || p_actual_finish_at::text
    || E'\nWork completed: ' || btrim(p_work_completed)
    || E'\nStatement: ' || btrim(p_statement);
  insert into public.disputes(assignment_id, opened_by, category, description, status)
  values (v_assignment.id, v_user_id, 'other', v_description, 'open')
  returning * into v_dispute;
  update public.job_assignments set status = 'disputed' where id = v_assignment.id;
  update public.jobs set status = 'paused', updated_at = now()
   where id = v_assignment.job_id and status = 'in_progress';
  update public.job_contracts set status = 'disputed'
   where application_id = p_application_id and status = 'active';
  update private.job_execution_sessions set execution_state = 'disputed',
    finish_pin_hash = null, finish_pin_expires_at = null, updated_at = now()
   where assignment_id = v_assignment.id;
  insert into private.job_execution_events(assignment_id, application_id, actor_id,
    event_type, from_state, to_state, request_id, safe_metadata)
  values (v_assignment.id, p_application_id, v_user_id,
    'finish_pin_unavailable_reported', 'in_progress', 'disputed', p_client_request_id,
    jsonb_build_object('dispute_id', v_dispute.id));
  return jsonb_build_object('ok', true, 'replayed', false,
    'dispute_id', v_dispute.id, 'money_moved', false, 'human_review_required', true);
end;
$function$;

create or replace function private.request_adult_job_cancellation_internal(
  p_application_id uuid, p_reason text, p_client_request_id uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_dispute public.disputes%rowtype;
  v_existing private.job_execution_events%rowtype;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id for update;
  if not found or v_assignment.adult_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_poster_required');
  end if;
  select event.* into v_existing from private.job_execution_events event
   where event.application_id = p_application_id and event.actor_id = v_user_id
     and event.event_type = 'adult_cancellation_requested'
     and event.request_id = p_client_request_id;
  if found then
    return jsonb_build_object('ok', true, 'replayed', true,
      'dispute_id', v_existing.safe_metadata->>'dispute_id', 'money_moved', false);
  end if;
  if v_assignment.status not in ('accepted', 'in_progress') then
    return jsonb_build_object('ok', false, 'code', 'job_not_cancellable');
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 3 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'cancellation_reason_required');
  end if;
  insert into public.disputes(assignment_id, opened_by, category, description, status)
  values (v_assignment.id, v_user_id, 'other',
    'Adult requested cancellation. Reason: ' || btrim(p_reason), 'open')
  returning * into v_dispute;
  update public.job_assignments set status = 'disputed' where id = v_assignment.id;
  update public.jobs set status = 'paused', updated_at = now()
   where id = v_assignment.job_id and status in ('filled', 'in_progress');
  update public.job_contracts set status = 'disputed'
   where application_id = p_application_id and status = 'active';
  update private.job_execution_sessions set execution_state = 'disputed',
    start_pin_hash = null, finish_pin_hash = null, updated_at = now()
   where assignment_id = v_assignment.id;
  insert into private.job_execution_events(assignment_id, application_id, actor_id,
    event_type, from_state, to_state, request_id, safe_metadata)
  values (v_assignment.id, p_application_id, v_user_id,
    'adult_cancellation_requested', v_assignment.status, 'disputed', p_client_request_id,
    jsonb_build_object('dispute_id', v_dispute.id));
  return jsonb_build_object('ok', true, 'replayed', false,
    'dispute_id', v_dispute.id, 'money_moved', false, 'human_review_required', true);
end;
$function$;

create or replace function private.report_possible_teen_abandonment_internal(
  p_application_id uuid, p_statement text, p_client_request_id uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_dispute public.disputes%rowtype;
  v_existing private.job_execution_events%rowtype;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id for update;
  if not found or v_assignment.adult_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_poster_required');
  end if;
  select event.* into v_existing from private.job_execution_events event
   where event.application_id = p_application_id and event.actor_id = v_user_id
     and event.event_type = 'teen_abandonment_reported'
     and event.request_id = p_client_request_id;
  if found then
    return jsonb_build_object('ok', true, 'replayed', true,
      'dispute_id', v_existing.safe_metadata->>'dispute_id',
      'cooldown_applied', false, 'money_moved', false);
  end if;
  if v_assignment.status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'code', 'in_progress_start_confirmation_required');
  end if;
  if char_length(btrim(coalesce(p_statement, ''))) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'abandonment_statement_required');
  end if;
  insert into public.disputes(assignment_id, opened_by, category, description, status)
  values (v_assignment.id, v_user_id, 'no_show',
    'Allegation only; no finding or cooldown has been applied. ' || btrim(p_statement), 'open')
  returning * into v_dispute;
  update public.job_assignments set status = 'disputed' where id = v_assignment.id;
  update public.jobs set status = 'paused', updated_at = now()
   where id = v_assignment.job_id and status = 'in_progress';
  update public.job_contracts set status = 'disputed'
   where application_id = p_application_id and status = 'active';
  update private.job_execution_sessions set execution_state = 'disputed',
    finish_pin_hash = null, finish_pin_expires_at = null, updated_at = now()
   where assignment_id = v_assignment.id;
  insert into private.job_execution_events(assignment_id, application_id, actor_id,
    event_type, from_state, to_state, request_id, safe_metadata)
  values (v_assignment.id, p_application_id, v_user_id,
    'teen_abandonment_reported', 'in_progress', 'disputed', p_client_request_id,
    jsonb_build_object('dispute_id', v_dispute.id, 'allegation_only', true));
  return jsonb_build_object('ok', true, 'replayed', false,
    'dispute_id', v_dispute.id, 'cooldown_applied', false,
    'money_moved', false, 'human_review_required', true);
end;
$function$;

create or replace function private.respond_to_teen_abandonment_internal(
  p_application_id uuid, p_statement text, p_safety_related boolean,
  p_client_request_id uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  v_user_id uuid := auth.uid();
  v_assignment public.job_assignments%rowtype;
  v_dispute public.disputes%rowtype;
  v_response public.job_execution_review_responses%rowtype;
begin
  if v_user_id is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_id_required');
  end if;
  select assignment.* into v_assignment from public.job_assignments assignment
   where assignment.application_id = p_application_id for update;
  if not found or v_assignment.teen_user_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'assigned_worker_required');
  end if;
  select response.* into v_response from public.job_execution_review_responses response
   where response.assignment_id = v_assignment.id
     and response.responded_by = v_user_id
     and response.client_request_id = p_client_request_id;
  if found then
    return jsonb_build_object('ok', true, 'replayed', true,
      'dispute_id', v_response.dispute_id,
      'safety_route_recommended', v_response.safety_related,
      'cooldown_applied', false, 'money_moved', false);
  end if;
  if char_length(btrim(coalesce(p_statement, ''))) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'abandonment_statement_required');
  end if;
  if p_safety_related is null then
    return jsonb_build_object('ok', false, 'code', 'safety_response_required');
  end if;
  select dispute.* into v_dispute from public.disputes dispute
   where dispute.assignment_id = v_assignment.id
     and dispute.opened_by = v_assignment.adult_user_id
     and dispute.category = 'no_show'
     and dispute.status in ('open', 'investigating', 'awaiting_evidence')
   order by dispute.created_at desc limit 1 for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'adult_report_required');
  end if;
  insert into public.job_execution_review_responses(
    dispute_id, assignment_id, responded_by, client_request_id, statement, safety_related
  ) values (
    v_dispute.id, v_assignment.id, v_user_id, p_client_request_id,
    btrim(p_statement), p_safety_related
  ) returning * into v_response;
  insert into private.job_execution_events(assignment_id, application_id, actor_id,
    event_type, from_state, to_state, request_id,
    safe_metadata)
  values (v_assignment.id, p_application_id, v_user_id,
    'teen_abandonment_response', 'disputed', 'disputed', p_client_request_id,
    jsonb_build_object('dispute_id', v_dispute.id, 'safety_related', p_safety_related))
  on conflict do nothing;
  return jsonb_build_object('ok', true, 'replayed', false,
    'dispute_id', v_dispute.id,
    'safety_route_recommended', p_safety_related,
    'cooldown_applied', false, 'money_moved', false);
end;
$function$;

create or replace function public.report_finish_pin_unavailable(
  p_application_id uuid, p_actual_start_at timestamptz, p_actual_finish_at timestamptz,
  p_work_completed text, p_statement text, p_client_request_id uuid
)
returns jsonb language sql security invoker set search_path = '' as $function$
  select private.report_finish_pin_unavailable_internal(
    p_application_id, p_actual_start_at, p_actual_finish_at,
    p_work_completed, p_statement, p_client_request_id
  );
$function$;
create or replace function public.request_adult_job_cancellation(
  p_application_id uuid, p_reason text, p_client_request_id uuid
)
returns jsonb language sql security invoker set search_path = '' as $function$
  select private.request_adult_job_cancellation_internal(
    p_application_id, p_reason, p_client_request_id
  );
$function$;
create or replace function public.report_possible_teen_abandonment(
  p_application_id uuid, p_statement text, p_client_request_id uuid
)
returns jsonb language sql security invoker set search_path = '' as $function$
  select private.report_possible_teen_abandonment_internal(
    p_application_id, p_statement, p_client_request_id
  );
$function$;
create or replace function public.respond_to_teen_abandonment(
  p_application_id uuid, p_statement text, p_safety_related boolean,
  p_client_request_id uuid
)
returns jsonb language sql security invoker set search_path = '' as $function$
  select private.respond_to_teen_abandonment_internal(
    p_application_id, p_statement, p_safety_related, p_client_request_id
  );
$function$;

revoke all on function private.report_finish_pin_unavailable_internal(uuid,timestamptz,timestamptz,text,text,uuid) from public, anon;
grant execute on function private.report_finish_pin_unavailable_internal(uuid,timestamptz,timestamptz,text,text,uuid) to authenticated;
revoke all on function private.request_adult_job_cancellation_internal(uuid,text,uuid) from public, anon;
grant execute on function private.request_adult_job_cancellation_internal(uuid,text,uuid) to authenticated;
revoke all on function private.report_possible_teen_abandonment_internal(uuid,text,uuid) from public, anon;
grant execute on function private.report_possible_teen_abandonment_internal(uuid,text,uuid) to authenticated;
revoke all on function private.respond_to_teen_abandonment_internal(uuid,text,boolean,uuid) from public, anon;
grant execute on function private.respond_to_teen_abandonment_internal(uuid,text,boolean,uuid) to authenticated;
revoke all on function public.report_finish_pin_unavailable(uuid,timestamptz,timestamptz,text,text,uuid) from public, anon;
grant execute on function public.report_finish_pin_unavailable(uuid,timestamptz,timestamptz,text,text,uuid) to authenticated;
revoke all on function public.request_adult_job_cancellation(uuid,text,uuid) from public, anon;
grant execute on function public.request_adult_job_cancellation(uuid,text,uuid) to authenticated;
revoke all on function public.report_possible_teen_abandonment(uuid,text,uuid) from public, anon;
grant execute on function public.report_possible_teen_abandonment(uuid,text,uuid) to authenticated;
revoke all on function public.respond_to_teen_abandonment(uuid,text,boolean,uuid) from public, anon;
grant execute on function public.respond_to_teen_abandonment(uuid,text,boolean,uuid) to authenticated;

