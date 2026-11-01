-- PROPOSAL ONLY. No matching isolated database was available, so this file has
-- not been executed or added to the migration chain. It uses private storage,
-- explicit SECURITY DEFINER authorization, location-version consent, and
-- server-only coarse distance output. Review and test on the exact production
-- migration set before any migration approval.

create table private.job_private_locations (
  job_id uuid primary key references public.jobs(id) on delete restrict,
  owner_id uuid not null references auth.users(id) on delete restrict,
  exact_address text not null check (char_length(btrim(exact_address)) between 5 and 500),
  -- Coordinates are populated only by the trusted geocoding contract below.
  -- They are never accepted from the mobile/web client or returned to callers.
  latitude double precision,
  longitude double precision,
  geocoded_by text,
  location_version integer not null default 1 check (location_version > 0),
  address_fingerprint text not null,
  updated_at timestamptz not null default now(),
  check (
    (latitude is null and longitude is null)
    or (latitude is not null and longitude is not null
      and latitude between -90 and 90
      and longitude between -180 and 180)
  )
);

create table private.job_private_location_requests (
  actor_id uuid not null references auth.users(id) on delete restrict,
  client_request_id uuid not null,
  job_id uuid not null references public.jobs(id) on delete restrict,
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor_id, client_request_id)
);

create table private.job_private_location_history (
  history_id bigint generated always as identity primary key,
  job_id uuid not null,
  owner_id uuid not null,
  exact_address text not null,
  latitude double precision,
  longitude double precision,
  geocoded_by text,
  location_version integer not null,
  address_fingerprint text not null,
  original_updated_at timestamptz not null,
  archived_at timestamptz not null default now()
);

create table private.job_location_access_events (
  id bigint generated always as identity primary key,
  actor_id uuid not null references auth.users(id) on delete restrict,
  assignment_id uuid not null references public.job_assignments(id) on delete restrict,
  action text not null check (action in ('location_read_allowed', 'location_read_denied')),
  reason_code text not null,
  location_version integer,
  created_at timestamptz not null default now()
);

-- Preserve legacy addresses before removing their public-row copies. This is
-- deliberately fail-closed: a conflicting private value is never overwritten,
-- and the public value is cleared only after every row has been verified.
insert into private.job_private_locations (
  job_id, owner_id, exact_address, address_fingerprint
)
select job.id,
       job.poster_id,
       btrim(job.exact_address),
       encode(extensions.digest(btrim(job.exact_address), 'sha256'), 'hex')
from public.jobs job
where nullif(btrim(job.exact_address), '') is not null
on conflict (job_id) do nothing;

do $address_migration$
begin
  if exists (
    select 1
    from public.jobs job
    left join private.job_private_locations location on location.job_id = job.id
    where nullif(btrim(job.exact_address), '') is not null
      and (location.job_id is null
        or location.owner_id <> job.poster_id
        or location.exact_address <> btrim(job.exact_address)
        or location.address_fingerprint <> encode(
          extensions.digest(btrim(job.exact_address), 'sha256'), 'hex'
        ))
  ) then
    raise exception 'legacy_job_address_copy_mismatch';
  end if;

  update public.jobs job
  set exact_address = null
  where nullif(btrim(job.exact_address), '') is not null
    and exists (
      select 1 from private.job_private_locations location
      where location.job_id = job.id
        and location.owner_id = job.poster_id
        and location.exact_address = btrim(job.exact_address)
    );
end;
$address_migration$;

-- Location-area centroids use only normalized city/region values from an
-- approved, licensed data source. Empty means distance remains unavailable.
create table private.location_area_centroids (
  city_key text not null,
  region_key text not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  source text not null,
  updated_at timestamptz not null default now(),
  primary key (city_key, region_key)
);

alter table private.job_private_locations enable row level security;
alter table private.job_private_locations force row level security;
alter table private.job_private_location_requests enable row level security;
alter table private.job_private_location_requests force row level security;
alter table private.job_private_location_history enable row level security;
alter table private.job_private_location_history force row level security;
alter table private.job_location_access_events enable row level security;
alter table private.job_location_access_events force row level security;
alter table private.location_area_centroids enable row level security;
alter table private.location_area_centroids force row level security;
revoke all on private.job_private_locations from public, anon, authenticated, service_role;
revoke all on private.job_private_location_requests from public, anon, authenticated, service_role;
revoke all on private.job_private_location_history from public, anon, authenticated, service_role;
revoke all on private.job_location_access_events from public, anon, authenticated, service_role;
revoke all on private.location_area_centroids from public, anon, authenticated, service_role;

alter table public.job_safety_agreements
  add column if not exists private_location_version integer not null default 0;

-- Keep every prior safety-agreement state and snapshot before version refreshes
-- or participant confirmations update the current row. This archive has no API
-- grants and no client write path.
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
  private_location_version integer not null,
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
as $function$
begin
  insert into private.job_safety_agreement_history (
    agreement_id, application_id, job_id, teen_id, adult_id,
    agreement_version, terms_snapshot, material_terms_hash, status,
    teen_confirmed_at, adult_confirmed_at,
    teen_confirmed_version, adult_confirmed_version,
    private_location_version, original_created_at, original_updated_at
  ) values (
    old.id, old.application_id, old.job_id, old.teen_id, old.adult_id,
    old.agreement_version, old.terms_snapshot, old.material_terms_hash, old.status,
    old.teen_confirmed_at, old.adult_confirmed_at,
    old.teen_confirmed_version, old.adult_confirmed_version,
    old.private_location_version, old.created_at, old.updated_at
  );
  return new;
end;
$function$;
revoke all on function private.archive_job_safety_agreement_before_update()
  from public, anon, authenticated;
create trigger job_safety_agreements_archive_before_update
  before update on public.job_safety_agreements
  for each row execute function private.archive_job_safety_agreement_before_update();

-- Add only coarse location version/availability to the mutual-consent snapshot;
-- exact address, coordinates, arrival instructions, and access notes stay out.
create or replace function private.job_safety_terms(p_application_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
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
      'The exact address stays private until assignment and mutual confirmation of the current location terms.',
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
$function$;
revoke all on function private.job_safety_terms(uuid) from public, anon, authenticated;

create or replace function private.sync_safety_agreement_location_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  select coalesce(location.location_version, 0)
    into new.private_location_version
  from (select 1) seed
  left join private.job_private_locations location on location.job_id = new.job_id;
  return new;
end;
$function$;
revoke all on function private.sync_safety_agreement_location_version() from public, anon, authenticated;
create trigger job_safety_agreements_sync_location_version
  before insert or update on public.job_safety_agreements
  for each row execute function private.sync_safety_agreement_location_version();

create or replace function private.archive_job_private_location_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  insert into private.job_private_location_history (
    job_id, owner_id, exact_address, latitude, longitude, geocoded_by,
    location_version, address_fingerprint, original_updated_at
  ) values (
    old.job_id, old.owner_id, old.exact_address, old.latitude, old.longitude,
    old.geocoded_by, old.location_version, old.address_fingerprint, old.updated_at
  );
  return new;
end;
$function$;
revoke all on function private.archive_job_private_location_before_update()
  from public, anon, authenticated;
create trigger job_private_locations_archive_before_update
  before update on private.job_private_locations
  for each row execute function private.archive_job_private_location_before_update();

create or replace function public.save_job_private_location_v1(
  p_job_id uuid,
  p_exact_address text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_location private.job_private_locations%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_previous_job_id uuid;
  v_terms jsonb;
  v_payload_sha256 text;
  v_previous_sha256 text;
  v_prior_response jsonb;
  v_response jsonb;
  v_next_version integer;
begin
  if v_actor is null or not private.is_active_user()
    or private.current_role() <> 'adult'::public.mort_role then
    return jsonb_build_object('ok', false, 'code', 'active_job_owner_required');
  end if;
  if p_job_id is null or p_client_request_id is null
    or p_exact_address is null
    or char_length(btrim(p_exact_address)) not between 5 and 500 then
    return jsonb_build_object('ok', false, 'code', 'job_location_request_invalid');
  end if;

  v_payload_sha256 := encode(extensions.digest(btrim(p_exact_address), 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'job_location:' || v_actor::text || ':' || p_client_request_id::text, 0
  ));
  select request.payload_sha256, request.response, request.job_id
    into v_previous_sha256, v_prior_response, v_previous_job_id
  from private.job_private_location_requests request
  where request.actor_id = v_actor
    and request.client_request_id = p_client_request_id
  for update;
  if found then
    if v_previous_sha256 <> v_payload_sha256 or v_previous_job_id <> p_job_id then
      return jsonb_build_object('ok', false, 'code', 'idempotency_key_reused');
    end if;
    return v_prior_response || jsonb_build_object('replayed', true);
  end if;

  select * into v_job from public.jobs where id = p_job_id for update;
  if not found or v_job.poster_id <> v_actor
    or v_job.status::text not in ('draft', 'under_review', 'open', 'paused') then
    return jsonb_build_object('ok', false, 'code', 'job_location_write_not_allowed');
  end if;

  select * into v_location
  from private.job_private_locations
  where job_id = p_job_id
  for update;
  if found and v_location.address_fingerprint = v_payload_sha256 then
    v_next_version := v_location.location_version;
  else
    v_next_version := coalesce(v_location.location_version, 0) + 1;
    insert into private.job_private_locations (
      job_id, owner_id, exact_address, location_version, address_fingerprint
    ) values (
      p_job_id, v_actor, btrim(p_exact_address), v_next_version, v_payload_sha256
    )
    on conflict (job_id) do update
    set exact_address = excluded.exact_address,
        latitude = null,
        longitude = null,
        geocoded_by = null,
        location_version = excluded.location_version,
        address_fingerprint = excluded.address_fingerprint,
        updated_at = now()
    returning * into v_location;

    for v_agreement in
      select agreement_row.*
      from public.job_safety_agreements agreement_row
      where agreement_row.job_id = p_job_id
      order by agreement_row.id
      for update
    loop
      v_terms := private.job_safety_terms(v_agreement.application_id);
      update public.job_safety_agreements agreement
      set agreement_version = agreement.agreement_version + 1,
          terms_snapshot = v_terms,
          material_terms_hash = encode(extensions.digest(v_terms::text, 'sha256'), 'hex'),
          status = 'reconfirmation_required',
          teen_confirmed_at = null,
          adult_confirmed_at = null,
          teen_confirmed_version = null,
          adult_confirmed_version = null,
          updated_at = now()
      where agreement.id = v_agreement.id;
    end loop;
  end if;

  v_response := jsonb_build_object(
    'ok', true,
    'job_id', p_job_id,
    'location_version', v_next_version,
    'public_job_address_written', false,
    'replayed', false
  );
  insert into private.job_private_location_requests (
    actor_id, client_request_id, job_id, payload_sha256, response
  ) values (v_actor, p_client_request_id, p_job_id, v_payload_sha256, v_response);
  return v_response;
end;
$function$;
revoke all on function public.save_job_private_location_v1(uuid, text, uuid) from public, anon;
grant execute on function public.save_job_private_location_v1(uuid, text, uuid) to authenticated;

-- Trusted server-only geocoder callback. Clients never submit coordinates and
-- this RPC returns no coordinate values. Only the current address version may
-- receive a result, so delayed geocoder responses cannot overwrite newer terms.
create or replace function public.record_job_location_geocode_v1(
  p_job_id uuid,
  p_location_version integer,
  p_latitude double precision,
  p_longitude double precision,
  p_geocoder_name text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if coalesce(auth.role(), '') <> 'service_role'
    or p_latitude is null or p_latitude not between -90 and 90
    or p_longitude is null or p_longitude not between -180 and 180
    or nullif(btrim(p_geocoder_name), '') is null then
    raise exception using errcode = '42501', message = 'trusted_geocoder_required';
  end if;
  update private.job_private_locations
  set latitude = p_latitude,
      longitude = p_longitude,
      geocoded_by = left(btrim(p_geocoder_name), 80),
      updated_at = now()
  where job_id = p_job_id and location_version = p_location_version;
  return jsonb_build_object('ok', found);
end;
$function$;
revoke all on function public.record_job_location_geocode_v1(uuid, integer, double precision, double precision, text) from public, anon, authenticated;
grant execute on function public.record_job_location_geocode_v1(uuid, integer, double precision, double precision, text) to service_role;

create or replace function public.get_released_job_location_v1(p_assignment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_job_id uuid;
  v_assignment public.job_assignments%rowtype;
  v_application public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_location private.job_private_locations%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_teen_profile public.profiles%rowtype;
  v_adult_profile public.profiles%rowtype;
  v_guardian_id uuid;
  v_reason text := 'job_location_not_released';
begin
  if v_actor is null or not private.is_active_user()
    or private.current_role() not in (
      'adult'::public.mort_role,
      'teen'::public.mort_role
    ) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select assignment.job_id into v_job_id
  from public.job_assignments assignment
  where assignment.id = p_assignment_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', v_reason);
  end if;

  -- Shared lock order: job, private location, assignment, application,
  -- agreement, then canonical participant pair lock.
  select * into v_job from public.jobs where id = v_job_id for share;
  select * into v_location from private.job_private_locations where job_id = v_job_id for share;
  select * into v_assignment from public.job_assignments
  where id = p_assignment_id for share;
  select * into v_application from public.job_applications
  where id = v_assignment.application_id for share;
  select * into v_agreement from public.job_safety_agreements
  where application_id = v_assignment.application_id for share;
  perform profile.id
  from public.profiles profile
  where profile.id in (v_assignment.teen_user_id, v_assignment.adult_user_id)
  order by profile.id
  for share;
  select * into v_teen_profile from public.profiles
  where id = v_assignment.teen_user_id;
  select * into v_adult_profile from public.profiles
  where id = v_assignment.adult_user_id;

  if v_job.id is null or v_location.job_id is null or v_assignment.id is null
    or v_application.id is null or v_agreement.id is null
    or v_assignment.job_id <> v_job.id
    or v_application.job_id <> v_job.id
    or v_job.poster_id <> v_assignment.adult_user_id
    or v_application.applicant_id <> v_assignment.teen_user_id
    or v_teen_profile.role is distinct from 'teen'::public.mort_role
    or v_teen_profile.account_status is distinct from 'active'
    or v_adult_profile.role is distinct from 'adult'::public.mort_role
    or v_adult_profile.account_status is distinct from 'active'
    or v_assignment.status::text not in ('accepted', 'in_progress', 'awaiting_confirmation')
    or v_job.status::text in ('cancelled', 'completed')
    or v_agreement.status <> 'confirmed'
    or v_agreement.teen_confirmed_version <> v_agreement.agreement_version
    or v_agreement.adult_confirmed_version <> v_agreement.agreement_version
    or v_agreement.private_location_version <> v_location.location_version then
    insert into private.job_location_access_events(actor_id, assignment_id, action, reason_code, location_version)
    values (v_actor, p_assignment_id, 'location_read_denied', v_reason, v_location.location_version);
    return jsonb_build_object('ok', false, 'code', v_reason);
  end if;
  if v_actor not in (v_assignment.adult_user_id, v_assignment.teen_user_id) then
    insert into private.job_location_access_events(actor_id, assignment_id, action, reason_code, location_version)
    values (v_actor, p_assignment_id, 'location_read_denied', 'job_participant_required', v_location.location_version);
    return jsonb_build_object('ok', false, 'code', v_reason);
  end if;

  perform private.lock_user_pair(v_assignment.teen_user_id, v_assignment.adult_user_id);
  if exists (
    select 1 from public.user_blocks block_row
    where (block_row.blocker_id = v_assignment.teen_user_id and block_row.blocked_id = v_assignment.adult_user_id)
       or (block_row.blocker_id = v_assignment.adult_user_id and block_row.blocked_id = v_assignment.teen_user_id)
  ) then
    insert into private.job_location_access_events(actor_id, assignment_id, action, reason_code, location_version)
    values (v_actor, p_assignment_id, 'location_read_denied', 'participant_blocked', v_location.location_version);
    return jsonb_build_object('ok', false, 'code', v_reason);
  end if;

  if v_job.requires_guardian_approval then
    select link.guardian_user_id into v_guardian_id
    from public.guardian_links link
    join public.profiles guardian_profile on guardian_profile.id = link.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id = link.guardian_user_id
    where link.teen_user_id = v_assignment.teen_user_id
      and link.status = 'active'
      and link.teen_consent_at is not null
      and link.guardian_consent_at is not null
      and (v_application.guardian_id is null or link.guardian_user_id = v_application.guardian_id)
      and guardian_profile.role = 'guardian'::public.mort_role
      and guardian_profile.account_status = 'active'
      and guardian_profile.date_of_birth is not null
      and extract(year from age(current_date, guardian_profile.date_of_birth)) >= 18
      and guardian_auth.email_confirmed_at is not null
    order by link.id
    limit 1
    for share of link, guardian_profile, guardian_auth;
    if v_guardian_id is null then
      insert into private.job_location_access_events(actor_id, assignment_id, action, reason_code, location_version)
      values (v_actor, p_assignment_id, 'location_read_denied', 'guardian_consent_unavailable', v_location.location_version);
      return jsonb_build_object('ok', false, 'code', v_reason);
    end if;
  end if;

  insert into private.job_location_access_events(actor_id, assignment_id, action, reason_code, location_version)
  values (v_actor, p_assignment_id, 'location_read_allowed', 'assignment_and_consent_current', v_location.location_version);
  return jsonb_build_object(
    'ok', true,
    'assignment_id', p_assignment_id,
    'exact_address', v_location.exact_address,
    'location_version', v_location.location_version
  );
end;
$function$;
revoke all on function public.get_released_job_location_v1(uuid) from public, anon;
grant execute on function public.get_released_job_location_v1(uuid) to authenticated;

-- Distance is calculated only inside the database from a private job geocode
-- and a city/region centroid. Only the coarse band is returned. This function
-- never accepts client coordinates, exact address, or caller-supplied origin.
create or replace function public.get_my_eligible_job_distance_bands_v1(p_job_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_origin record;
  v_job_id uuid;
  v_eligibility jsonb;
  v_job_point record;
  v_miles double precision;
  v_items jsonb := '[]'::jsonb;
begin
  if v_actor is null or not private.is_active_user()
    or private.current_role() <> 'teen'::public.mort_role then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_job_ids is null or cardinality(p_job_ids) < 1 or cardinality(p_job_ids) > 50 then
    return jsonb_build_object('ok', false, 'code', 'job_distance_batch_invalid');
  end if;
  select * into v_profile from public.profiles where id = v_actor;
  select centroid.latitude, centroid.longitude into v_origin
  from private.location_area_centroids centroid
  where centroid.city_key = lower(btrim(v_profile.city))
    and centroid.region_key = upper(btrim(v_profile.region));

  for v_job_id in
    select distinct requested.job_id
    from unnest(p_job_ids) as requested(job_id)
    order by requested.job_id
  loop
    v_eligibility := public.get_job_application_eligibility(v_job_id);
    if v_eligibility->>'eligible' is distinct from 'true' then continue; end if;
    select location.latitude, location.longitude into v_job_point
    from private.job_private_locations location
    where location.job_id = v_job_id;
    if not found or v_origin.latitude is null or v_job_point.latitude is null then
      v_items := v_items || jsonb_build_array(jsonb_build_object('job_id', v_job_id, 'distance_band', null));
      continue;
    end if;
    v_miles := 3958.7613 * acos(least(1.0, greatest(-1.0,
      sin(radians(v_origin.latitude)) * sin(radians(v_job_point.latitude))
      + cos(radians(v_origin.latitude)) * cos(radians(v_job_point.latitude))
      * cos(radians(v_job_point.longitude - v_origin.longitude))
    )));
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'job_id', v_job_id,
      'distance_band', case
        when v_miles < 3 then 'under_3_miles'
        when v_miles < 10 then '3_to_10_miles'
        else '10_plus_miles'
      end
    ));
  end loop;
  return jsonb_build_object('ok', true, 'items', v_items);
end;
$function$;
revoke all on function public.get_my_eligible_job_distance_bands_v1(uuid[]) from public, anon;
grant execute on function public.get_my_eligible_job_distance_bands_v1(uuid[]) to authenticated;
