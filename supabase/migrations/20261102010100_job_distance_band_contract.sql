-- Server-side, coarse job-distance bands. Approximate coordinates are stored
-- only in a private relation and are rounded again on the server. Public job
-- rows, RPC responses, and exact private job addresses never contain them.
begin;

create table if not exists private.job_distance_centers (
  job_id uuid primary key references public.jobs(id) on delete cascade,
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  approx_latitude double precision not null check (approx_latitude between -90 and 90),
  approx_longitude double precision not null check (approx_longitude between -180 and 180),
  updated_at timestamptz not null default now()
);
alter table private.job_distance_centers enable row level security;
alter table private.job_distance_centers force row level security;
revoke all on private.job_distance_centers from public, anon, authenticated;

create or replace function public.set_job_approx_location_v1(
  p_job_id uuid,
  p_latitude double precision,
  p_longitude double precision
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_profile public.profiles%rowtype;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_job_id is null or p_latitude is null or p_longitude is null
     or p_latitude < -90 or p_latitude > 90
     or p_longitude < -180 or p_longitude > 180 then
    return jsonb_build_object('ok', false, 'code', 'job_approx_location_invalid');
  end if;

  select * into v_profile from public.profiles p where p.id = v_user_id for share;
  if not found or v_profile.role <> 'adult'::public.mort_role
     or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'active_adult_account_required');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id for update;
  if not found or v_job.poster_id <> v_user_id
     or v_job.status not in ('draft'::public.mort_job_status, 'open'::public.mort_job_status) then
    return jsonb_build_object('ok', false, 'code', 'job_approx_location_write_not_allowed');
  end if;

  insert into private.job_distance_centers
    (job_id, owner_user_id, approx_latitude, approx_longitude, updated_at)
  values
    (p_job_id, v_user_id,
     round(p_latitude::numeric, 2)::double precision,
     round(p_longitude::numeric, 2)::double precision,
     clock_timestamp())
  on conflict (job_id) do update
    set owner_user_id = excluded.owner_user_id,
        approx_latitude = excluded.approx_latitude,
        approx_longitude = excluded.approx_longitude,
        updated_at = excluded.updated_at;

  return jsonb_build_object('ok', true, 'job_id', p_job_id);
end;
$function$;

create or replace function public.get_job_distance_v1(
  p_job_id uuid,
  p_latitude double precision,
  p_longitude double precision
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_release public.mort_release_control%rowtype;
  v_job public.jobs%rowtype;
  v_center private.job_distance_centers%rowtype;
  v_now timestamptz := clock_timestamp();
  v_age integer;
  v_count integer;
  v_distance_miles double precision;
  v_band text;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_job_id is null or p_latitude is null or p_longitude is null
     or p_latitude < -90 or p_latitude > 90
     or p_longitude < -180 or p_longitude > 180 then
    return jsonb_build_object('ok', false, 'code', 'coordinates_invalid');
  end if;

  select * into v_profile from public.profiles p where p.id = v_user_id;
  if not found or v_profile.role <> 'teen'::public.mort_role
     or v_profile.account_status <> 'active' or v_profile.date_of_birth is null then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  v_age := private.mort_age_years(v_profile.date_of_birth);
  if v_age < 13 or v_age > 17 then
    return jsonb_build_object('ok', false, 'code', 'teen_age_required');
  end if;

  select * into v_release from public.mort_release_control r where r.is_primary for share;
  if not found or v_release.maintenance_mode or not v_release.public_marketplace_enabled then
    return jsonb_build_object('ok', false, 'code', 'public_marketplace_disabled');
  end if;

  select j.* into v_job from public.jobs j
  join public.profiles poster on poster.id = j.poster_id
  where j.id = p_job_id
    and poster.account_status = 'active'
    and j.status = 'open'::public.mort_job_status
    and j.safety_review_status = 'approved'
    and j.applications_open
    and (j.expires_at is null or j.expires_at > v_now)
    and j.age_min <= v_age and j.age_max >= v_age
  for share of j, poster;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_not_visible');
  end if;

  -- Match the shared user-pair lock used by block/message operations so this
  -- read cannot race past a concurrent block for the same poster/teen pair.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      least(v_user_id, v_job.poster_id)::text || ':' || greatest(v_user_id, v_job.poster_id)::text,
      0
    )
  );

  perform vc.id from public.verification_cases vc
  where vc.user_id = v_user_id and vc.verification_type = 'age'
    and vc.status = 'verified'::public.mort_verification_status
  for share;
  if not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = v_user_id and vc.verification_type = 'age'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > v_now)
  ) then
    return jsonb_build_object('ok', false, 'code', 'age_verification_required');
  end if;

  if v_job.requires_guardian_approval then
    perform gl.id
    from public.guardian_links gl
    join public.profiles guardian on guardian.id = gl.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id = gl.guardian_user_id
    where gl.teen_user_id = v_user_id and gl.status = 'active'
      and gl.teen_consent_at is not null and gl.guardian_consent_at is not null
      and guardian.role = 'guardian'::public.mort_role
      and guardian.account_status = 'active'
      and guardian.date_of_birth is not null
      and private.mort_age_years(guardian.date_of_birth) >= 18
      and guardian_auth.email_confirmed_at is not null
    for share of gl, guardian, guardian_auth;
  end if;

  if v_job.requires_guardian_approval and not exists (
    select 1 from public.guardian_links gl
    join public.profiles guardian on guardian.id = gl.guardian_user_id
    join auth.users guardian_auth on guardian_auth.id = gl.guardian_user_id
    where gl.teen_user_id = v_user_id and gl.status = 'active'
      and gl.teen_consent_at is not null and gl.guardian_consent_at is not null
      and guardian.role = 'guardian'::public.mort_role
      and guardian.account_status = 'active'
      and guardian.date_of_birth is not null
      and private.mort_age_years(guardian.date_of_birth) >= 18
      and guardian_auth.email_confirmed_at is not null
  ) then
    return jsonb_build_object('ok', false, 'code', 'guardian_approval_required');
  end if;

  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_user_id and b.blocked_id = v_job.poster_id)
       or (b.blocker_id = v_job.poster_id and b.blocked_id = v_user_id)
  ) then
    return jsonb_build_object('ok', false, 'code', 'interaction_unavailable');
  end if;

  insert into private.mort_edge_action_limits(user_id, action, window_started_at, request_count)
  values (v_user_id, 'job_distance_lookup', date_trunc('minute', v_now), 1)
  on conflict (user_id, action, window_started_at) do update
    set request_count = private.mort_edge_action_limits.request_count + 1
    where private.mort_edge_action_limits.request_count < 30
  returning request_count into v_count;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'job_distance_rate_limit_reached');
  end if;

  select * into v_center from private.job_distance_centers c where c.job_id = p_job_id;
  if not found then
    return jsonb_build_object('ok', true, 'distance_status', 'unavailable');
  end if;

  -- Round both inputs again before distance calculation. Only a broad band is
  -- returned, making the RPC unsuitable for exact-coordinate extraction.
  v_distance_miles := 3959 * acos(least(1.0, greatest(-1.0,
    sin(radians(round(p_latitude::numeric, 2)::double precision))
      * sin(radians(v_center.approx_latitude))
    + cos(radians(round(p_latitude::numeric, 2)::double precision))
      * cos(radians(v_center.approx_latitude))
      * cos(radians(v_center.approx_longitude - round(p_longitude::numeric, 2)::double precision))
  )));
  v_band := case
    when v_distance_miles < 1 then 'under_1_mile'
    when v_distance_miles < 5 then '1_to_5_miles'
    when v_distance_miles < 10 then '5_to_10_miles'
    else 'over_10_miles'
  end;

  return jsonb_build_object('ok', true, 'distance_status', 'available', 'distance_band', v_band);
end;
$function$;

revoke all on function public.set_job_approx_location_v1(uuid,double precision,double precision) from public, anon, authenticated;
revoke all on function public.get_job_distance_v1(uuid,double precision,double precision) from public, anon, authenticated;
grant execute on function public.set_job_approx_location_v1(uuid,double precision,double precision) to authenticated;
grant execute on function public.get_job_distance_v1(uuid,double precision,double precision) to authenticated;

commit;
