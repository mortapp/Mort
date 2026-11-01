-- MORT marketplace safety contracts. Candidate only: local/isolated verification required.
begin;

create table if not exists private.job_locations (
  job_id uuid primary key references public.jobs(id) on delete cascade,
  exact_address text,
  latitude double precision,
  longitude double precision,
  geocode_source text,
  geocoded_at timestamptz,
  updated_at timestamptz not null default now(),
  check (exact_address is null or length(btrim(exact_address)) between 5 and 500),
  check ((latitude is null and longitude is null) or
    (latitude between -90 and 90 and longitude between -180 and 180))
);
create table if not exists private.user_location_origins (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  geocode_source text not null,
  geocoded_at timestamptz not null,
  consent_at timestamptz not null,
  consent_version text not null,
  updated_at timestamptz not null default now()
);
alter table private.job_locations enable row level security;
alter table private.job_locations force row level security;
alter table private.user_location_origins enable row level security;
alter table private.user_location_origins force row level security;
revoke all on private.job_locations, private.user_location_origins from public, anon, authenticated;
grant all on private.job_locations, private.user_location_origins to service_role;

insert into private.job_locations(job_id, exact_address)
select id, exact_address from public.jobs
where exact_address is not null and btrim(exact_address) <> ''
on conflict (job_id) do update
set exact_address = excluded.exact_address, updated_at = now()
where private.job_locations.exact_address is null;
update public.jobs set exact_address = null where exact_address is not null;

do $$
begin
  if not exists (select 1 from pg_constraint
    where conrelid = 'public.jobs'::regclass
      and conname = 'jobs_exact_address_must_be_private') then
    alter table public.jobs add constraint jobs_exact_address_must_be_private
      check (exact_address is null) not valid;
  end if;
end $$;
alter table public.jobs validate constraint jobs_exact_address_must_be_private;

create or replace function private.lock_user_pair(p_left uuid, p_right uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_pair text;
begin
  if p_left is null or p_right is null or p_left = p_right then return; end if;
  v_pair := least(p_left::text, p_right::text) || ':' || greatest(p_left::text, p_right::text);
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_pair, 72190431));
end $$;
revoke all on function private.lock_user_pair(uuid, uuid) from public, anon, authenticated;

create or replace function private.enforce_message_block_contract()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_other uuid;
begin
  if new.sender_id is null then
    raise exception using errcode = '23502', message = 'Message sender is required';
  end if;
  if auth.uid() is not null and new.sender_id <> auth.uid() then
    raise exception using errcode = '42501', message = 'Message sender does not match session';
  end if;
  if not exists (
    select 1 from public.conversations c
    join public.conversation_members cm on cm.conversation_id = c.id
    where c.id = new.conversation_id and c.status = 'active' and cm.user_id = new.sender_id
  ) then
    raise exception using errcode = '42501', message = 'Conversation unavailable';
  end if;
  for v_other in
    select cm.user_id from public.conversation_members cm
    where cm.conversation_id = new.conversation_id and cm.user_id <> new.sender_id
    order by cm.user_id
  loop
    perform private.lock_user_pair(new.sender_id, v_other);
    if exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = new.sender_id and b.blocked_id = v_other)
         or (b.blocker_id = v_other and b.blocked_id = new.sender_id)
    ) then
      raise exception using errcode = '42501', message = 'Messaging is unavailable';
    end if;
  end loop;
  return new;
end $$;
revoke all on function private.enforce_message_block_contract() from public, anon, authenticated;

create or replace function private.serialize_user_block_contract()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform private.lock_user_pair(old.blocker_id, old.blocked_id);
    return old;
  end if;
  perform private.lock_user_pair(new.blocker_id, new.blocked_id);
  if tg_op = 'UPDATE' then perform private.lock_user_pair(old.blocker_id, old.blocked_id); end if;
  return new;
end $$;
revoke all on function private.serialize_user_block_contract() from public, anon, authenticated;

drop trigger if exists messages_enforce_block_contract on public.messages;
create trigger messages_enforce_block_contract before insert on public.messages
for each row execute function private.enforce_message_block_contract();
drop trigger if exists user_blocks_serialize_contract on public.user_blocks;
create trigger user_blocks_serialize_contract before insert or update or delete on public.user_blocks
for each row execute function private.serialize_user_block_contract();

create or replace function public.mort_submit_job_application(
  p_job_id uuid, p_cover_note text default null
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_eligibility jsonb;
  v_application uuid;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;
  if not private.is_active_user() or private.current_role() <> 'teen'::public.mort_role then
    raise exception using errcode = '42501', message = 'An active teen account is required';
  end if;
  if p_cover_note is not null and char_length(p_cover_note) > 1000 then
    raise exception using errcode = '22023', message = 'Cover note exceeds 1000 characters';
  end if;
  select * into v_job from public.jobs where id = p_job_id for update;
  if not found or v_job.status <> 'open'::public.mort_job_status
     or v_job.safety_review_status <> 'approved' or not v_job.applications_open
     or (v_job.expires_at is not null and v_job.expires_at <= now())
     or not exists (select 1 from public.profiles p
                    where p.id = v_job.poster_id and p.account_status = 'active') then
    raise exception using errcode = '42501', message = 'Job is not available';
  end if;
  if v_job.poster_id = v_user then
    raise exception using errcode = '42501', message = 'Cannot apply to your own job';
  end if;
  perform private.lock_user_pair(v_user, v_job.poster_id);
  v_eligibility := public.get_job_application_eligibility(p_job_id);
  if coalesce((v_eligibility ->> 'eligible')::boolean, false) is not true then
    raise exception using errcode = '42501',
      message = coalesce(v_eligibility ->> 'message', 'You are not eligible for this job');
  end if;
  if exists (select 1 from public.job_applications ja
             where ja.job_id = p_job_id and ja.applicant_id = v_user) then
    raise exception using errcode = '23505', message = 'You have already applied to this job';
  end if;
  insert into public.job_applications(job_id, applicant_id, cover_note)
  values (p_job_id, v_user, nullif(btrim(p_cover_note), ''))
  returning id into v_application;
  return v_application;
end $$;

create or replace function public.get_job_private_location(p_job_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare v_user uuid := auth.uid(); v_allowed boolean := false; v_address text;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  select exists (
    select 1 from public.jobs j where j.id = p_job_id and (
      j.poster_id = v_user
      or private.has_staff_role(array['admin'::public.mort_role, 'moderator'::public.mort_role])
      or exists (select 1 from public.job_applications ja
        where ja.job_id = j.id and ja.applicant_id = v_user
          and ja.status = 'accepted'::public.mort_application_status)
    )
  ) into v_allowed;
  if not v_allowed then return jsonb_build_object('ok', false, 'code', 'location_not_available'); end if;
  select jl.exact_address into v_address from private.job_locations jl where jl.job_id = p_job_id;
  if v_address is null then return jsonb_build_object('ok', false, 'code', 'location_not_set'); end if;
  return jsonb_build_object('ok', true, 'job_id', p_job_id, 'exact_address', v_address);
end $$;
revoke all on function public.get_job_private_location(uuid) from public, anon;
grant execute on function public.get_job_private_location(uuid) to authenticated;


create or replace function private.set_job_private_address(p_job_id uuid, p_exact_address text)
returns void language plpgsql security definer set search_path = ''
as $
begin
  if p_job_id is null or p_exact_address is null or length(btrim(p_exact_address)) not between 5 and 500 then
    raise exception using errcode = '22023', message = 'Invalid private job address';
  end if;
  insert into private.job_locations(job_id, exact_address, updated_at)
  values (p_job_id, btrim(p_exact_address), now())
  on conflict (job_id) do update set exact_address = excluded.exact_address, updated_at = now();
end $;
revoke all on function private.set_job_private_address(uuid, text) from public, anon, authenticated;
grant execute on function private.set_job_private_address(uuid, text) to service_role;

create or replace function private.set_job_geocode_result(
  p_job_id uuid, p_latitude double precision, p_longitude double precision, p_source text
) returns void language plpgsql security definer set search_path = ''
as $$
begin
  if p_latitude is null or p_longitude is null or p_latitude < -90 or p_latitude > 90
     or p_longitude < -180 or p_longitude > 180 or p_source is null or length(btrim(p_source)) = 0 then
    raise exception using errcode = '22023', message = 'Invalid geocode result';
  end if;
  insert into private.job_locations(job_id, latitude, longitude, geocode_source, geocoded_at)
  values (p_job_id, p_latitude, p_longitude, p_source, now())
  on conflict (job_id) do update set latitude = excluded.latitude, longitude = excluded.longitude,
    geocode_source = excluded.geocode_source, geocoded_at = excluded.geocoded_at, updated_at = now();
end $$;
revoke all on function private.set_job_geocode_result(uuid, double precision, double precision, text)
  from public, anon, authenticated;
grant execute on function private.set_job_geocode_result(uuid, double precision, double precision, text)
  to service_role;

create or replace function private.set_user_location_origin(
  p_user_id uuid, p_latitude double precision, p_longitude double precision, p_source text,
  p_consent_at timestamptz, p_consent_version text
) returns void language plpgsql security definer set search_path = ''
as $
begin
  if p_user_id is null or p_latitude is null or p_longitude is null
     or p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180
     or p_source is null or length(btrim(p_source)) = 0
     or p_consent_at is null or p_consent_at > now()
     or p_consent_version is null or length(btrim(p_consent_version)) = 0 then
    raise exception using errcode = '22023', message = 'Invalid geocoded origin or missing location consent';
  end if;
  if not exists (select 1 from public.profiles p
    where p.id = p_user_id and p.role = 'teen'::public.mort_role and p.account_status = 'active') then
    raise exception using errcode = '42501', message = 'An active teen account is required';
  end if;
  insert into private.user_location_origins(
    user_id, latitude, longitude, geocode_source, geocoded_at, consent_at, consent_version
  ) values (p_user_id, p_latitude, p_longitude, p_source, now(), p_consent_at, p_consent_version)
  on conflict (user_id) do update set latitude = excluded.latitude, longitude = excluded.longitude,
    geocode_source = excluded.geocode_source, geocoded_at = excluded.geocoded_at,
    consent_at = excluded.consent_at, consent_version = excluded.consent_version, updated_at = now();
end $;
revoke all on function private.set_user_location_origin(uuid, double precision, double precision, text, timestamptz, text)
  from public, anon, authenticated;
grant execute on function private.set_user_location_origin(uuid, double precision, double precision, text, timestamptz, text)
  to service_role;

create or replace function public.get_job_distance_bands(p_job_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_origin record;
  v_result jsonb := '[]'::jsonb;
  v_job record;
  v_distance double precision;
begin
  if v_user is null or not private.is_active_user()
     or private.current_role() <> 'teen'::public.mort_role then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_job_ids is null or cardinality(p_job_ids) = 0 or cardinality(p_job_ids) > 50 then
    return jsonb_build_object('ok', false, 'code', 'job_batch_invalid');
  end if;
  select * into v_origin from private.user_location_origins where user_id = v_user;
  if not found then
    return jsonb_build_object('ok', true, 'distance_status', 'unavailable', 'items', '[]'::jsonb);
  end if;
  for v_job in
    select j.id, jl.latitude, jl.longitude
    from public.jobs j
    join private.job_locations jl on jl.job_id = j.id
    join public.profiles poster on poster.id = j.poster_id
    where j.id = any(p_job_ids) and j.status = 'open'::public.mort_job_status
      and j.safety_review_status = 'approved' and j.applications_open
      and poster.account_status = 'active'
  loop
    if v_job.latitude is null or v_job.longitude is null then
      v_result := v_result || jsonb_build_array(jsonb_build_object(
        'job_id', v_job.id, 'distance_band', 'unavailable'));
    else
      v_distance := 3958.7613 * 2 * asin(sqrt(least(1::double precision,
        power(sin(radians(v_job.latitude - v_origin.latitude) / 2), 2)
        + cos(radians(v_origin.latitude)) * cos(radians(v_job.latitude))
        * power(sin(radians(v_job.longitude - v_origin.longitude) / 2), 2))));
      v_result := v_result || jsonb_build_array(jsonb_build_object(
        'job_id', v_job.id, 'distance_band',
        case when v_distance < 1 then 'under_1_mile'
             when v_distance < 5 then '1_to_5_miles'
             when v_distance < 10 then '5_to_10_miles'
             when v_distance < 25 then '10_to_25_miles'
             else '25_plus_miles' end));
    end if;
  end loop;
  return jsonb_build_object('ok', true, 'distance_status', 'available', 'items', v_result);
end $$;
revoke all on function public.get_job_distance_bands(uuid[]) from public, anon;
grant execute on function public.get_job_distance_bands(uuid[]) to authenticated;

commit;
