-- Safety contracts for the hosted job_applications/job_assignments schema.
-- This migration is a draft until it is replayed in an isolated Supabase
-- environment. It must not be applied directly to the hosted main project.

begin;

-- Fail closed if legacy public rows contain exact addresses. This migration
-- never copies, clears, or overwrites legacy address data; that would require
-- a separately reviewed preservation plan.
do $$
begin
  if exists (
    select 1 from public.jobs job
    where job.exact_address is not null
  ) then
    raise exception 'private_job_location_requires_legacy_address_review';
  end if;
end;
$$;

create table private.job_private_locations (
  job_id uuid primary key references public.jobs(id) on delete cascade,
  poster_id uuid not null references public.profiles(id) on delete cascade,
  exact_address text not null,
  address_fingerprint text not null check (address_fingerprint ~ '^[0-9a-f]{64}$'),
  arrival_instructions text,
  access_notes text,
  latitude double precision,
  longitude double precision,
  location_source text not null default 'address_text',
  location_accuracy_meters double precision,
  location_version integer not null default 1,
  verified_for_job boolean not null default false,
  captured_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_private_locations_address_length
    check (char_length(btrim(exact_address)) between 5 and 500),
  constraint job_private_locations_coordinates_valid
    check ((latitude is null) = (longitude is null)
      and (latitude is null or (latitude between -90 and 90 and longitude between -180 and 180))),
  constraint job_private_locations_accuracy_valid
    check (location_accuracy_meters is null or location_accuracy_meters between 0 and 50000),
  constraint job_private_locations_source_check
    check (location_source in ('address_text', 'precise_gps'))
);

create index if not exists job_private_locations_poster_idx
  on private.job_private_locations(poster_id);

alter table private.job_private_locations enable row level security;
alter table private.job_private_locations force row level security;
revoke all on private.job_private_locations from public, anon, authenticated;
grant all on private.job_private_locations to service_role;

create table private.job_private_location_requests (
  actor_id uuid not null,
  client_request_id uuid not null,
  job_id uuid not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor_id, client_request_id)
);
alter table private.job_private_location_requests enable row level security;
alter table private.job_private_location_requests force row level security;
revoke all on private.job_private_location_requests from public, anon, authenticated, service_role;

create table private.job_private_location_history (
  history_id bigint generated always as identity primary key,
  job_id uuid not null,
  poster_id uuid not null,
  exact_address text not null,
  address_fingerprint text not null,
  arrival_instructions text,
  access_notes text,
  location_version integer not null,
  original_updated_at timestamptz not null,
  archived_at timestamptz not null default now()
);
alter table private.job_private_location_history enable row level security;
alter table private.job_private_location_history force row level security;
revoke all on private.job_private_location_history from public, anon, authenticated, service_role;

create table private.job_private_location_access_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  resource_type text not null,
  resource_id uuid not null,
  action text not null,
  reason text not null,
  created_at timestamptz not null default now()
);
alter table private.job_private_location_access_events enable row level security;
alter table private.job_private_location_access_events force row level security;
revoke all on private.job_private_location_access_events from public, anon, authenticated;
grant all on private.job_private_location_access_events to service_role;

alter table public.job_safety_agreements
  add column if not exists location_version integer not null default 0;

-- Make the consent snapshot explicitly say when a private job location exists
-- and bind consent to its version without embedding an address or coordinates.
create or replace function private.job_safety_terms(p_application_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'job_id', job.id,
    'job_title', job.title,
    'scope', coalesce(nullif(job.summary, ''), job.description),
    'approximate_area', jsonb_build_object(
      'city', job.city,
      'region', job.region,
      'remote', job.remote_allowed
    ),
    'private_location_version', coalesce(location.location_version, 0),
    'private_location_available', location.job_id is not null,
    'who_will_be_present', coalesce(
      nullif(plan.expected_people, ''),
      case when job.adult_supervision_present
        then 'The job poster reports adult supervision will be present.'
        else 'Presence details must be agreed before the job starts.'
      end
    ),
    'physical_requirements', to_jsonb(job.physical_requirements),
    'hazards', job.safety_notes,
    'equipment', jsonb_build_object(
      'provided', job.equipment_provided,
      'worker_brings', job.equipment_worker_brings
    ),
    'payment', jsonb_build_object(
      'amount_cents', job.pay_amount_cents,
      'type', job.payment_type,
      'method_preference', job.payment_method,
      'timing', job.payment_timing
    ),
    'proof_expected', job.proof_expected,
    'safety_plan', jsonb_build_object(
      'public_or_visible_meeting', plan.public_or_visible_meeting,
      'daylight_preferred', plan.daylight_preferred,
      'transportation_plan', plan.transportation_plan,
      'checkin_cadence_minutes', plan.checkin_cadence_minutes
    ),
    'contract', (
      select jsonb_build_object(
        'contract_id', contract.id,
        'version_id', coalesce(contract.active_version_id, latest.id),
        'content_hash', latest.content_hash,
        'status', contract.status
      )
      from public.job_contracts contract
      left join lateral (
        select version.id, version.content_hash
        from public.job_contract_versions version
        where version.contract_id = contract.id
        order by version.version_number desc
        limit 1
      ) latest on true
      where contract.application_id = application.id
    ),
    'exact_location_policy',
      'The exact address stays private until the authorized job stage.',
    'communication_boundaries', jsonb_build_array(
      'Keep job communication in MORT.',
      'No harassment, sexual behavior, threats, weapons, alcohol, or drugs.',
      'No forced off-platform contact or unapproved work changes.'
    ),
    'right_to_leave', true,
    'verification_not_safety_guarantee', true
  )
  from public.job_applications application
  join public.jobs job on job.id = application.job_id
  left join public.job_safety_plans plan on plan.application_id = application.id
  left join private.job_private_locations location on location.job_id = job.id
  where application.id = p_application_id;
$$;
revoke all on function private.job_safety_terms(uuid) from public, anon, authenticated;

-- Keep prior consent snapshots and confirmations append-only before any
-- location refresh invalidates the current agreement version.
create table private.job_safety_agreement_history (
  history_id bigint generated always as identity primary key,
  agreement_id uuid not null,
  application_id uuid not null,
  job_id uuid not null,
  teen_id uuid not null,
  adult_id uuid not null,
  agreement_version integer not null,
  terms_snapshot jsonb not null,
  material_terms_hash text not null,
  status text not null,
  teen_confirmed_at timestamptz,
  adult_confirmed_at timestamptz,
  teen_confirmed_version integer,
  adult_confirmed_version integer,
  location_version integer not null,
  original_created_at timestamptz not null,
  original_updated_at timestamptz not null,
  archived_at timestamptz not null default now()
);
alter table private.job_safety_agreement_history enable row level security;
alter table private.job_safety_agreement_history force row level security;
revoke all on private.job_safety_agreement_history from public, anon, authenticated, service_role;

create or replace function private.archive_job_safety_agreement_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.job_safety_agreement_history (
    agreement_id, application_id, job_id, teen_id, adult_id,
    agreement_version, terms_snapshot, material_terms_hash, status,
    teen_confirmed_at, adult_confirmed_at,
    teen_confirmed_version, adult_confirmed_version,
    location_version, original_created_at, original_updated_at
  ) values (
    old.id, old.application_id, old.job_id, old.teen_id, old.adult_id,
    old.agreement_version, old.terms_snapshot, old.material_terms_hash, old.status,
    old.teen_confirmed_at, old.adult_confirmed_at,
    old.teen_confirmed_version, old.adult_confirmed_version,
    old.location_version, old.created_at, old.updated_at
  );
  return new;
end;
$$;
revoke all on function private.archive_job_safety_agreement_before_update() from public, anon, authenticated;

create trigger job_safety_agreements_archive_before_update
  before update on public.job_safety_agreements
  for each row execute function private.archive_job_safety_agreement_before_update();

create or replace function private.archive_job_private_location_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.job_private_location_history (
    job_id, poster_id, exact_address, address_fingerprint,
    arrival_instructions, access_notes,
    location_version, original_updated_at
  ) values (
    old.job_id, old.poster_id, old.exact_address, old.address_fingerprint,
    old.arrival_instructions, old.access_notes,
    old.location_version, old.updated_at
  );
  return new;
end;
$$;
revoke all on function private.archive_job_private_location_before_update() from public, anon, authenticated;

create trigger job_private_locations_archive_before_update
  before update on private.job_private_locations
  for each row execute function private.archive_job_private_location_before_update();

create or replace function public.sync_safety_agreement_location_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select location.location_version
    into new.location_version
  from private.job_private_locations location
  where location.job_id = new.job_id;
  new.location_version := coalesce(new.location_version, 0);
  return new;
end;
$$;

revoke all on function public.sync_safety_agreement_location_version() from public, anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.job_safety_agreements'::regclass
      and tgname = 'job_safety_agreements_location_version_trg'
  ) then
    create trigger job_safety_agreements_location_version_trg
      before insert or update of job_id on public.job_safety_agreements
      for each row execute function public.sync_safety_agreement_location_version();
  end if;
end;
$$;

create or replace function public.save_job_private_location_v1(
  p_job_id uuid,
  p_exact_address text,
  p_arrival_instructions text,
  p_access_notes text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_location private.job_private_locations%rowtype;
  v_application_id uuid;
  v_payload_sha256 text;
  v_prior_sha256 text;
  v_prior_job_id uuid;
  v_prior_response jsonb;
  v_response jsonb;
  v_next_version integer;
  v_location_changed boolean := false;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user()
     or private.current_role() is distinct from 'adult'::public.mort_role then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_job_id is null or p_client_request_id is null
     or p_exact_address is null
     or char_length(btrim(p_exact_address)) not between 5 and 500 then
    return jsonb_build_object('ok', false, 'code', 'job_location_request_invalid');
  end if;
  if char_length(coalesce(p_arrival_instructions, '')) > 1000
     or char_length(coalesce(p_access_notes, '')) > 1000 then
    return jsonb_build_object('ok', false, 'code', 'job_location_notes_too_long');
  end if;
  v_payload_sha256 := encode(extensions.digest(convert_to(
    jsonb_build_object(
      'job_id', p_job_id,
      'exact_address', btrim(p_exact_address),
      'arrival_instructions', nullif(btrim(coalesce(p_arrival_instructions, '')), ''),
      'access_notes', nullif(btrim(coalesce(p_access_notes, '')), '')
    )::text, 'UTF8'), 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('job_location:' || v_user_id::text || ':' || p_client_request_id::text, 0)
  );
  select request.payload_sha256, request.job_id, request.response
  into v_prior_sha256, v_prior_job_id, v_prior_response
  from private.job_private_location_requests request
  where request.actor_id = v_user_id
    and request.client_request_id = p_client_request_id
  for update;
  if found then
    if v_prior_sha256 <> v_payload_sha256 or v_prior_job_id <> p_job_id then
      return jsonb_build_object('ok', false, 'code', 'idempotency_key_reused');
    end if;
    return v_prior_response || jsonb_build_object('replayed', true);
  end if;
  -- A location change before work starts invalidates consent and refreshes the
  -- legal safety snapshot. Moving a job already in progress uses cancellation.
  select * into v_job
  from public.jobs job
  where job.id = p_job_id
  for update;
  if not found or v_job.poster_id <> v_user_id
     or v_job.status::text not in ('draft', 'under_review', 'open', 'paused', 'filled') then
    return jsonb_build_object('ok', false, 'code', 'job_location_write_not_allowed');
  end if;
  perform agreement.id
  from public.job_safety_agreements agreement
  where agreement.job_id = p_job_id
  order by agreement.application_id
  for update;
  select * into v_location
  from private.job_private_locations location
  where location.job_id = p_job_id
  for update;
  if not found then
    v_next_version := 1;
    insert into private.job_private_locations(
      job_id, poster_id, exact_address, address_fingerprint,
      arrival_instructions, access_notes, location_version,
      location_source, verified_for_job, captured_at, updated_at
    ) values (
      p_job_id, v_user_id, btrim(p_exact_address),
      encode(extensions.digest(convert_to(btrim(p_exact_address), 'UTF8'), 'sha256'), 'hex'),
      nullif(btrim(coalesce(p_arrival_instructions, '')), ''),
      nullif(btrim(coalesce(p_access_notes, '')), ''), v_next_version,
      'address_text', false, now(), now()
    ) returning * into v_location;
    v_location_changed := true;
  elsif v_location.address_fingerprint <> encode(
      extensions.digest(convert_to(btrim(p_exact_address), 'UTF8'), 'sha256'), 'hex'
    )
    or v_location.arrival_instructions is distinct from nullif(btrim(coalesce(p_arrival_instructions, '')), '')
    or v_location.access_notes is distinct from nullif(btrim(coalesce(p_access_notes, '')), '') then
    v_next_version := v_location.location_version + 1;
    update private.job_private_locations
    set exact_address = btrim(p_exact_address),
        address_fingerprint = encode(extensions.digest(convert_to(btrim(p_exact_address), 'UTF8'), 'sha256'), 'hex'),
        arrival_instructions = nullif(btrim(coalesce(p_arrival_instructions, '')), ''),
        access_notes = nullif(btrim(coalesce(p_access_notes, '')), ''),
        latitude = null,
        longitude = null,
        location_source = 'address_text',
        location_accuracy_meters = null,
        location_version = v_next_version,
        verified_for_job = false,
        captured_at = now(),
        updated_at = now()
    where job_id = p_job_id
    returning * into v_location;
    v_location_changed := true;
  else
    v_next_version := v_location.location_version;
  end if;
  if v_location_changed then
    update public.job_safety_agreements agreement
    set location_version = v_next_version
    where agreement.job_id = p_job_id;
    for v_application_id in
      select agreement.application_id
      from public.job_safety_agreements agreement
      where agreement.job_id = p_job_id
      order by agreement.application_id
    loop
      perform private.refresh_job_safety_agreement(v_application_id);
    end loop;
  end if;
  insert into private.job_private_location_access_events(actor_id, resource_type, resource_id, action, reason)
  values (v_user_id, 'job_private_location', p_job_id, 'write', 'Job poster saved the restricted job location.');
  v_response := jsonb_build_object(
    'ok', true,
    'job_id', p_job_id,
    'location_version', v_next_version,
    'public_feed_contains_exact_address', false,
    'public_feed_contains_coordinates', false,
    'replayed', false
  );
  insert into private.job_private_location_requests(
    actor_id, client_request_id, job_id, payload_sha256, response
  ) values (v_user_id, p_client_request_id, p_job_id, v_payload_sha256, v_response);
  return v_response;
end;
$$;

revoke all on function public.save_job_private_location_v1(uuid, text, text, text, uuid) from public, anon;
grant execute on function public.save_job_private_location_v1(uuid, text, text, text, uuid) to authenticated, service_role;

create or replace function public.get_released_job_location(p_application_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_application public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_assignment public.job_assignments%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_location private.job_private_locations%rowtype;
  v_allowed boolean := false;
  v_pair_key bigint;
  v_pair_other uuid;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  -- Match the live lifecycle lock order: application, assignment, job,
  -- agreement, location. This avoids assignment/job lock inversion with
  -- start, cancellation, and completion operations.
  select * into v_application
  from public.job_applications application
  where application.id = p_application_id
  for share;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  select * into v_assignment
  from public.job_assignments assignment
  where assignment.application_id = p_application_id
  for share;
  select * into v_job
  from public.jobs job
  where job.id = v_application.job_id
  for share;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  if v_job.status::text in ('cancelled', 'completed')
     or (v_assignment.id is not null and v_assignment.status in ('cancelled', 'completed')) then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  select * into v_location
  from private.job_private_locations location
  where location.job_id = v_job.id
  for share;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_configured');
  end if;
  if v_location.poster_id is distinct from v_job.poster_id then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  if v_job.poster_id = v_user_id then
    v_allowed := true;
    v_pair_other := v_assignment.teen_user_id;
  else
    v_pair_other := v_job.poster_id;
    select * into v_agreement
    from public.job_safety_agreements agreement
    where agreement.application_id = p_application_id
    for share;
    v_allowed := coalesce(
      v_application.applicant_id = v_user_id
      and v_application.status = 'accepted'::public.mort_application_status
      and v_assignment.id is not null
      and v_assignment.job_id = v_job.id
      and v_assignment.teen_user_id = v_user_id
      and v_assignment.adult_user_id = v_job.poster_id
      and v_assignment.status = 'in_progress'
      and v_job.status = 'in_progress'
      and v_agreement.id is not null
      and v_agreement.status = 'confirmed'
      and v_agreement.location_version > 0
      and v_agreement.location_version = v_location.location_version
      and v_agreement.teen_confirmed_version = v_agreement.agreement_version
      and v_agreement.adult_confirmed_version = v_agreement.agreement_version,
      false
    );
  end if;
  if coalesce(v_allowed, false) is not true then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  -- Serialize a release check with concurrent block/unblock. If a block wins
  -- the pair lock, this function observes it before returning exact data.
  if v_pair_other is not null then
    v_pair_key := pg_catalog.hashtextextended(
      least(v_user_id, v_pair_other)::text || ':' || greatest(v_user_id, v_pair_other)::text,
      0
    );
    perform pg_catalog.pg_advisory_xact_lock(v_pair_key);
  end if;
  if v_pair_other is not null and exists (
    select 1 from public.user_blocks block
    where (block.blocker_id = v_user_id and block.blocked_id = v_pair_other)
       or (block.blocker_id = v_pair_other and block.blocked_id = v_user_id)
  ) then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  insert into private.job_private_location_access_events(actor_id, resource_type, resource_id, action, reason)
  values (v_user_id, 'job_private_location', v_job.id, 'read', 'Authorized participant accessed a restricted job location.');
  return jsonb_build_object(
    'ok', true,
    'job_id', v_job.id,
    'exact_address', v_location.exact_address,
    'arrival_instructions', v_location.arrival_instructions,
    'access_notes', v_location.access_notes,
    'latitude', v_location.latitude,
    'longitude', v_location.longitude,
    'location_version', v_location.location_version,
    'release_stage', case when v_job.poster_id = v_user_id then 'poster' else 'active_assignment' end
  );
end;
$$;

create or replace function public.block_user_v2(
  p_blocked_id uuid,
  p_reason text default null,
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_key bigint;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_blocked_id is null or p_blocked_id = v_user_id then
    return jsonb_build_object('ok', false, 'code', 'invalid_block_target');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  v_key := pg_catalog.hashtextextended(least(v_user_id, p_blocked_id)::text || ':' || greatest(v_user_id, p_blocked_id)::text, 0);
  perform pg_catalog.pg_advisory_xact_lock(v_key);
  insert into public.user_blocks(blocker_id, blocked_id, reason)
  values (v_user_id, p_blocked_id, nullif(left(btrim(coalesce(p_reason, '')), 500), ''))
  on conflict (blocker_id, blocked_id) do update set reason = excluded.reason;
  return jsonb_build_object('ok', true, 'blocked_id', p_blocked_id);
end;
$$;

create or replace function public.unblock_user_v2(p_blocked_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_key bigint;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_blocked_id is null or p_blocked_id = v_user_id then
    return jsonb_build_object('ok', false, 'code', 'invalid_block_target');
  end if;
  v_key := pg_catalog.hashtextextended(least(v_user_id, p_blocked_id)::text || ':' || greatest(v_user_id, p_blocked_id)::text, 0);
  perform pg_catalog.pg_advisory_xact_lock(v_key);
  delete from public.user_blocks where blocker_id = v_user_id and blocked_id = p_blocked_id;
  return jsonb_build_object('ok', true, 'blocked_id', p_blocked_id);
end;
$$;

revoke all on function public.get_released_job_location(uuid) from public, anon;
grant execute on function public.get_released_job_location(uuid) to authenticated, service_role;
revoke all on function public.block_user_v2(uuid,text,uuid) from public, anon;
grant execute on function public.block_user_v2(uuid,text,uuid) to authenticated, service_role;
revoke all on function public.unblock_user_v2(uuid) from public, anon;
grant execute on function public.unblock_user_v2(uuid) to authenticated, service_role;
revoke insert, update, delete on public.user_blocks from authenticated;
grant select on public.user_blocks to authenticated;
-- Exact addresses must never enter through the client-facing table policies.
-- The security-definer job RPC remains the only authenticated write path.
revoke insert, update on public.jobs from authenticated;
-- Production grants job writes at column scope, so a table-level REVOKE alone
-- leaves those grants intact. Remove each remaining authenticated column
-- grant while preserving the existing restricted SELECT column grants.
do $$
declare
  v_column_grant record;
begin
  for v_column_grant in
    select distinct column_name, privilege_type
    from information_schema.column_privileges
    where table_schema = 'public'
      and table_name = 'jobs'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE')
  loop
    execute format(
      'revoke %s (%I) on table public.jobs from authenticated',
      v_column_grant.privilege_type,
      v_column_grant.column_name
    );
  end loop;
end;
$$;

-- Use the same deterministic pair lock as block_user_v2. Every participant
-- pair in a conversation is locked before the block check, so a concurrent
-- block and send cannot pass their checks in opposite order.
create or replace function public.mort_send_message(p_conversation_id uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_message uuid;
  v_other_user uuid;
  v_conversation public.conversations%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.is_active_user() then raise exception 'Active account required'; end if;
  if p_body is null or char_length(btrim(p_body)) < 1 or char_length(p_body) > 4000 then
    raise exception 'Message must contain 1 to 4000 characters';
  end if;
  select * into v_conversation
  from public.conversations conversation
  where conversation.id = p_conversation_id
  for update;
  if not found or v_conversation.status <> 'active' or not exists (
    select 1 from public.conversation_members member
    where member.conversation_id = p_conversation_id and member.user_id = v_user
  ) then
    raise exception 'Conversation unavailable';
  end if;
  for v_other_user in
    select member.user_id
    from public.conversation_members member
    where member.conversation_id = p_conversation_id
      and member.user_id <> v_user
    order by member.user_id
  loop
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        least(v_user, v_other_user)::text || ':' || greatest(v_user, v_other_user)::text,
        0
      )
    );
  end loop;
  if exists (
    select 1
    from public.conversation_members mine
    join public.conversation_members theirs
      on theirs.conversation_id = mine.conversation_id
     and theirs.user_id <> v_user
    join public.user_blocks block
      on (block.blocker_id = v_user and block.blocked_id = theirs.user_id)
      or (block.blocker_id = theirs.user_id and block.blocked_id = v_user)
    where mine.conversation_id = p_conversation_id
      and mine.user_id = v_user
  ) then
    raise exception 'Messaging is unavailable';
  end if;
  insert into public.messages(conversation_id, sender_id, body, moderation_status)
  values (p_conversation_id, v_user, btrim(p_body), 'pending')
  returning id into v_message;
  update public.conversations set updated_at = now() where id = p_conversation_id;
  return v_message;
end;
$$;

commit;

