-- Corrected location architecture: the job site is captured from the
-- Adult/Business's own precise device location at job-creation time
-- (coordinates), not free-form public address text. Extends the EXISTING
-- canonical private-location table/RPCs rather than creating a second
-- competing system. Exact coordinates remain private -- job_private_locations
-- keeps zero direct RLS policies (RPC-only access, unchanged). Teens get
-- real server-computed distance pre-acceptance (never raw coordinates),
-- and the existing, already-correct lifecycle-gated release RPC
-- (get_released_job_location) is extended to also return coordinates for
-- navigation once genuinely authorized -- its authorization logic already
-- matches the requested ephemeral-access model exactly (only while the
-- application is in an active-execution stage AND the job is AND the
-- mutual safety agreement is confirmed at its current version; any other
-- status -- completed/cancelled/rejected/withdrawn -- already falls
-- through to denied because those statuses are not in the allowed list).
-- This migration adds an explicit block check as defense in depth.

alter table public.job_private_locations
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists location_source text not null default 'address_text',
  add column if not exists location_accuracy_meters double precision,
  add column if not exists captured_at timestamptz;

alter table public.job_private_locations
  drop constraint if exists job_private_locations_coordinates_valid;
alter table public.job_private_locations
  add constraint job_private_locations_coordinates_valid
  check (
    (latitude is null and longitude is null)
    or (latitude between -90 and 90 and longitude between -180 and 180)
  );

alter table public.job_private_locations
  drop constraint if exists job_private_locations_location_source_check;
alter table public.job_private_locations
  add constraint job_private_locations_location_source_check
  check (location_source in ('address_text', 'precise_gps'));

alter table public.job_private_locations
  alter column exact_address drop not null;

-- Job site capture: precise GPS is now the primary path. Free-form
-- address text remains supported (e.g. arrival notes, or a fallback) but
-- is no longer the only way to record a job site.
--
-- Adding parameters changes this function's argument-type signature, so
-- CREATE OR REPLACE would create a second, additional overload rather
-- than truly replacing the old one -- drop the old 4-arg signature first
-- so there is exactly one save_job_private_location, and re-grant
-- explicitly since a differently-signed function does not inherit the
-- old one's grants.
drop function if exists public.save_job_private_location(uuid, text, text, text);

create function public.save_job_private_location(
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
set search_path = 'public', 'pg_temp'
as $$
declare
  v_job public.jobs%rowtype;
  v_location public.job_private_locations%rowtype;
  v_agreement record;
  v_terms jsonb;
  v_address text;
  v_source text;
begin
  if auth.uid() is null or not private.has_marketplace_identity(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'identity_verification_required');
  end if;
  select * into v_job from public.jobs where id = p_job_id;
  if v_job.id is null or (v_job.poster_id <> auth.uid() and not public.is_admin()) then
    return jsonb_build_object('ok', false, 'code', 'job_not_found');
  end if;

  if p_latitude is not null or p_longitude is not null then
    if p_latitude is null or p_longitude is null
       or p_latitude not between -90 and 90
       or p_longitude not between -180 and 180 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_site_coordinates');
    end if;
    v_source := 'precise_gps';
    v_address := nullif(btrim(coalesce(p_exact_address, '')), '');
  elsif char_length(btrim(coalesce(p_exact_address, ''))) >= 5 then
    v_source := 'address_text';
    v_address := btrim(p_exact_address);
  else
    return jsonb_build_object('ok', false, 'code', 'job_site_location_required');
  end if;

  insert into public.job_private_locations (
    job_id, poster_id, exact_address, arrival_instructions, access_notes,
    latitude, longitude, location_source, location_accuracy_meters,
    captured_at
  ) values (
    p_job_id, v_job.poster_id,
    coalesce(left(v_address, 500), ''),
    nullif(left(btrim(coalesce(p_arrival_instructions, '')), 2000), ''),
    nullif(left(btrim(coalesce(p_access_notes, '')), 1000), ''),
    p_latitude, p_longitude, v_source, p_location_accuracy_meters, now()
  )
  on conflict (job_id) do update
  set exact_address = coalesce(left(v_address, 500), public.job_private_locations.exact_address, ''),
      arrival_instructions = nullif(left(btrim(coalesce(p_arrival_instructions, '')), 2000), ''),
      access_notes = nullif(left(btrim(coalesce(p_access_notes, '')), 1000), ''),
      latitude = p_latitude,
      longitude = p_longitude,
      location_source = v_source,
      location_accuracy_meters = p_location_accuracy_meters,
      captured_at = now(),
      location_version = public.job_private_locations.location_version + 1,
      verified_for_job = false,
      updated_at = now()
  returning * into v_location;

  for v_agreement in
    select agreement.id, agreement.application_id
    from public.job_safety_agreements agreement
    where agreement.job_id = p_job_id
      and agreement.status <> 'canceled'
  loop
    v_terms := private.job_safety_terms(v_agreement.application_id);
    update public.job_safety_agreements
    set agreement_version = agreement_version + 1,
        terms_snapshot = v_terms,
        material_terms_hash = encode(extensions.digest(v_terms::text, 'sha256'), 'hex'),
        status = 'reconfirmation_required',
        teen_confirmed_at = null,
        adult_confirmed_at = null,
        teen_confirmed_version = null,
        adult_confirmed_version = null,
        updated_at = now()
    where id = v_agreement.id;
  end loop;

  insert into public.private_data_access_events (
    actor_id, resource_type, resource_id, action, reason
  ) values (
    auth.uid(), 'job_private_location', p_job_id, 'write',
    'Job poster saved or updated the restricted job location.'
  );

  return jsonb_build_object(
    'ok', true,
    'job_id', p_job_id,
    'location_version', v_location.location_version,
    'location_source', v_location.location_source,
    'public_feed_contains_exact_address', false,
    'public_feed_contains_coordinates', false
  );
end;
$$;

revoke all on function public.save_job_private_location(
  uuid, text, text, text, double precision, double precision, double precision
) from public, anon;
grant execute on function public.save_job_private_location(
  uuid, text, text, text, double precision, double precision, double precision
) to authenticated, service_role;

-- Extended: also returns coordinates (for navigation) once authorized,
-- using the SAME already-correct lifecycle gate as before. Adds an
-- explicit block check as defense in depth -- if either party has
-- blocked the other, exact location is withheld even if the status
-- fields haven't caught up yet.
create or replace function public.get_released_job_location(p_application_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_location public.job_private_locations%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_allowed boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_application from public.applications where id = p_application_id;
  if v_application.id is null then
    return jsonb_build_object('ok', false, 'code', 'application_not_found');
  end if;
  select * into v_job from public.jobs where id = v_application.job_id;
  select * into v_location from public.job_private_locations where job_id = v_job.id;
  select * into v_agreement from public.job_safety_agreements where application_id = p_application_id;

  if public.users_are_blocked(v_application.teen_id, v_job.poster_id) then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_released');
  end if;

  if v_job.poster_id = auth.uid() then
    v_allowed := true;
  elsif v_application.teen_id = auth.uid()
    and v_application.status in ('accepted', 'in_progress', 'proof_submitted')
    and v_job.status in ('assigned', 'in_progress', 'proof_submitted')
    and v_agreement.status = 'confirmed'
    and v_agreement.teen_confirmed_version = v_agreement.agreement_version
    and v_agreement.adult_confirmed_version = v_agreement.agreement_version then
    v_allowed := true;
  end if;

  if not v_allowed then
    return jsonb_build_object(
      'ok', false,
      'code', 'exact_location_not_released',
      'public_location', jsonb_build_object('area', v_job.location_text, 'city', v_job.city, 'state', v_job.state, 'location_type', v_job.location_type)
    );
  end if;
  if v_location.job_id is null then
    return jsonb_build_object('ok', false, 'code', 'exact_location_not_configured');
  end if;

  insert into public.private_data_access_events (
    actor_id, resource_type, resource_id, action, reason
  ) values (
    auth.uid(), 'job_private_location', v_job.id, 'read',
    case when v_job.poster_id = auth.uid() then 'Job poster accessed own restricted location.' else 'Accepted verified worker accessed location after mutual confirmation.' end
  );

  return jsonb_build_object(
    'ok', true,
    'job_id', v_job.id,
    'exact_address', v_location.exact_address,
    'arrival_instructions', v_location.arrival_instructions,
    'access_notes', v_location.access_notes,
    'latitude', v_location.latitude,
    'longitude', v_location.longitude,
    'location_version', v_location.location_version,
    'release_stage', case when v_job.poster_id = auth.uid() then 'poster' else 'accepted_confirmed' end
  );
end;
$$;

-- Pre-acceptance distance: computed server-side from the job's private
-- coordinates against the Teen's fresh, on-demand precise location
-- (passed in as an ephemeral request parameter -- never stored). Returns
-- ONLY a rounded distance figure per job, never the job's raw
-- coordinates. Any authenticated teen may call this for any open job --
-- same posture as the existing open job feed (no application/acceptance
-- relationship required, since this is exactly the pre-acceptance
-- "how far is this job" information Section 5 explicitly allows).
create or replace function public.get_nearby_job_distances_v1(
  p_job_ids uuid[],
  p_latitude double precision,
  p_longitude double precision
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_profile public.profiles%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  if p_job_ids is null or cardinality(p_job_ids) = 0 or cardinality(p_job_ids) > 50 then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_ids');
  end if;
  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180 then
    return jsonb_build_object('ok', false, 'code', 'invalid_teen_coordinates');
  end if;

  return jsonb_build_object(
    'ok', true,
    'distances', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'job_id', loc.job_id,
          'distance_miles', round(
            (2 * 3958.8 * asin(sqrt(
              power(sin(radians(p_latitude - loc.latitude) / 2), 2) +
              cos(radians(loc.latitude)) * cos(radians(p_latitude)) *
              power(sin(radians(p_longitude - loc.longitude) / 2), 2)
            )))::numeric,
            1
          )
        )
      )
      from public.job_private_locations loc
      join public.jobs job on job.id = loc.job_id
      where loc.job_id = any(p_job_ids)
        and loc.latitude is not null
        and loc.longitude is not null
        and job.status = 'open'
        and job.applications_open
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_nearby_job_distances_v1(uuid[], double precision, double precision)
from public, anon;
grant execute on function public.get_nearby_job_distances_v1(uuid[], double precision, double precision)
to authenticated;
