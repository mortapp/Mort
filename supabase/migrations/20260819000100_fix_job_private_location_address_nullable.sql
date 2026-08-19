-- Fix a real bug found by the adversarial test for the previous migration:
-- save_job_private_location inserted '' (empty string) for exact_address
-- when only coordinates were given, but the pre-existing
-- job_private_address_length constraint requires char_length(exact_address)
-- BETWEEN 5 AND 500 whenever a value is present (NULL is exempt, since a
-- NULL comparison is not FALSE in a CHECK). Use NULL, not '', when no
-- address text was provided.

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
    left(v_address, 500),
    nullif(left(btrim(coalesce(p_arrival_instructions, '')), 2000), ''),
    nullif(left(btrim(coalesce(p_access_notes, '')), 1000), ''),
    p_latitude, p_longitude, v_source, p_location_accuracy_meters, now()
  )
  on conflict (job_id) do update
  set exact_address = coalesce(left(v_address, 500), public.job_private_locations.exact_address),
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
