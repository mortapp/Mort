-- Safety contracts for the hosted job_applications/job_assignments schema.
-- This migration is a draft until it is replayed in an isolated Supabase
-- environment. It must not be applied directly to the hosted main project.

begin;

create table if not exists public.job_private_locations (
  job_id uuid primary key references public.jobs(id) on delete cascade,
  poster_id uuid not null references public.profiles(id) on delete cascade,
  exact_address text,
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
    check (exact_address is null or char_length(exact_address) between 5 and 500),
  constraint job_private_locations_coordinates_valid
    check ((latitude is null and longitude is null)
      or (latitude between -90 and 90 and longitude between -180 and 180)),
  constraint job_private_locations_source_check
    check (location_source in ('address_text', 'precise_gps'))
);

create index if not exists job_private_locations_poster_idx
  on public.job_private_locations(poster_id);

alter table public.job_private_locations enable row level security;
alter table public.job_private_locations force row level security;
revoke all on public.job_private_locations from public, anon, authenticated;
grant all on public.job_private_locations to service_role;

create table if not exists public.private_data_access_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  resource_type text not null,
  resource_id uuid not null,
  action text not null,
  reason text not null,
  created_at timestamptz not null default now()
);
alter table public.private_data_access_events enable row level security;
alter table public.private_data_access_events force row level security;
revoke all on public.private_data_access_events from public, anon, authenticated;
grant all on public.private_data_access_events to service_role;

alter table public.job_safety_agreements
  add column if not exists location_version integer not null default 0;

create or replace function public.sync_safety_agreement_location_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select location.location_version
    into new.location_version
  from public.job_private_locations location
  where location.job_id = new.job_id;
  new.location_version := coalesce(new.location_version, 0);
  return new;
end;
$$;

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

create or replace function public.save_job_private_location(
  p_job_id uuid,
  p_exact_address text default null,
  p_arrival_instructions text default null,
  p_access_notes text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_location_accuracy_meters double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_address text := nullif(btrim(coalesce(p_exact_address, '')), '');
  v_source text;
  v_location public.job_private_locations%rowtype;
  v_application_id uuid;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  select * into v_job from public.jobs job where job.id = p_job_id;
  if not found or v_job.poster_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'job_not_found');
  end if;
  if p_latitude is not null or p_longitude is not null then
    if p_latitude is null or p_longitude is null
       or p_latitude not between -90 and 90
       or p_longitude not between -180 and 180 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_site_coordinates');
    end if;
    v_source := 'precise_gps';
  elsif v_address is not null and char_length(v_address) between 5 and 500 then
    v_source := 'address_text';
  else
    return jsonb_build_object('ok', false, 'code', 'job_site_location_required');
  end if;
  insert into public.job_private_locations(
    job_id, poster_id, exact_address, arrival_instructions, access_notes,
    latitude, longitude, location_source, location_accuracy_meters,
  location_version, captured_at, updated_at
  ) values (
    p_job_id, v_user_id, v_address,
    nullif(left(btrim(coalesce(p_arrival_instructions, '')), 2000), ''),
    nullif(left(btrim(coalesce(p_access_notes, '')), 1000), ''),
    p_latitude, p_longitude, v_source, p_location_accuracy_meters,
    1, now(), now()
  )
  on conflict (job_id) do update set
    exact_address = excluded.exact_address,
    arrival_instructions = excluded.arrival_instructions,
    access_notes = excluded.access_notes,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    location_source = excluded.location_source,
    location_accuracy_meters = excluded.location_accuracy_meters,
    location_version = public.job_private_locations.location_version + 1,
    verified_for_job = false,
    captured_at = excluded.captured_at,
    updated_at = now()
  returning * into v_location;
  update public.job_safety_agreements agreement
  set location_version = v_location.location_version
  where agreement.job_id = p_job_id;
  for v_application_id in
    select agreement.application_id
    from public.job_safety_agreements agreement
    where agreement.job_id = p_job_id
  loop
    perform private.refresh_job_safety_agreement(v_application_id);
  end loop;
  insert into public.private_data_access_events(actor_id, resource_type, resource_id, action, reason)
  values (v_user_id, 'job_private_location', p_job_id, 'write', 'Job poster saved the restricted job location.');
  return jsonb_build_object(
    'ok', true,
    'job_id', p_job_id,
    'location_version', v_location.location_version,
    'public_feed_contains_exact_address', false,
    'public_feed_contains_coordinates', false
  );
end;
$$;

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
  v_location public.job_private_locations%rowtype;
  v_allowed boolean := false;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_application from public.job_applications application where application.id = p_application_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'application_not_found');
  end if;
  select * into v_job from public.jobs job where job.id = v_application.job_id;
  select * into v_location from public.job_private_locations location where location.job_id = v_job.id;
  if exists (
    select 1 from public.user_blocks block
    where (block.blocker_id = v_user_id and block.blocked_id = v_job.poster_id)
       or (block.blocker_id = v_job.poster_id and block.blocked_id = v_user_id)
  ) then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;
  if v_job.id is null or v_location.job_id is null then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_configured');
  elsif v_job.poster_id = v_user_id then
    v_allowed := true;
  else
    select * into v_assignment
    from public.job_assignments assignment
    where assignment.application_id = p_application_id;
    select * into v_agreement
    from public.job_safety_agreements agreement
    where agreement.application_id = p_application_id;
    v_allowed := coalesce(
      v_application.applicant_id = v_user_id
      and v_assignment.id is not null
      and v_assignment.job_id = v_job.id
      and v_assignment.teen_user_id = v_user_id
      and v_assignment.status = 'in_progress'
      and v_job.status = 'in_progress'
      and v_agreement.id is not null
      and v_agreement.status = 'confirmed'
      and v_agreement.location_version = v_location.location_version
      and v_agreement.teen_confirmed_version = v_agreement.agreement_version
      and v_agreement.adult_confirmed_version = v_agreement.agreement_version,
      false
    );
  end if;
  if coalesce(v_allowed, false) is not true then
    return jsonb_build_object(
      'ok', false,
      'code', 'exact_location_not_released',
      'public_location', jsonb_build_object(
        'area', v_job.location_text, 'city', v_job.city,
        'region', v_job.region, 'location_type', v_job.location_type
      )
    );
  end if;
  insert into public.private_data_access_events(actor_id, resource_type, resource_id, action, reason)
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

revoke all on function public.save_job_private_location(uuid,text,text,text,double precision,double precision,double precision) from public, anon;
grant execute on function public.save_job_private_location(uuid,text,text,text,double precision,double precision,double precision) to authenticated, service_role;
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
