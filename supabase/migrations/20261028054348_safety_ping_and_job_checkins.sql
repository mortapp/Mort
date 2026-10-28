create table if not exists public.safety_pings (
  id uuid primary key default extensions.gen_random_uuid(),
  teen_id uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'needs_help'
    check (status in ('needs_help', 'safe')),
  note text,
  job_id uuid references public.jobs(id) on delete set null,
  immediate_danger boolean not null default false,
  client_request_id uuid not null,
  created_at timestamptz not null default now(),
  constraint safety_pings_note_length
    check (note is null or char_length(note) <= 500),
  constraint safety_pings_teen_request_unique
    unique (teen_id, client_request_id)
);

create index if not exists safety_pings_teen_created_idx
  on public.safety_pings (teen_id, created_at desc);
create index if not exists safety_pings_job_idx
  on public.safety_pings (job_id)
  where job_id is not null;

alter table public.safety_pings enable row level security;
revoke all on public.safety_pings from public, anon, authenticated;
grant select on public.safety_pings to authenticated;

drop policy if exists safety_pings_select_authorized_parties
  on public.safety_pings;
create policy safety_pings_select_authorized_parties
  on public.safety_pings
  for select
  to authenticated
  using (
    teen_id = (select auth.uid())
    or exists (
      select 1
      from public.guardian_links link
      left join public.guardian_preferences preferences
        on preferences.link_id = link.id
      where link.teen_user_id = safety_pings.teen_id
        and link.guardian_user_id = (select auth.uid())
        and link.status = 'active'
        and coalesce(preferences.safety_ping_alerts, true)
    )
    or private.has_staff_role(array['admin'::public.mort_role, 'moderator'::public.mort_role])
  );

create table if not exists public.job_safety_checkins (
  id uuid primary key default extensions.gen_random_uuid(),
  application_id uuid not null references public.job_applications(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  teen_user_id uuid not null references public.profiles(id) on delete cascade,
  adult_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'completed', 'cancelled')),
  expected_at timestamptz not null,
  completed_at timestamptz,
  client_request_id uuid not null,
  created_at timestamptz not null default now(),
  constraint job_safety_checkins_teen_request_unique
    unique (teen_user_id, client_request_id)
);

create index if not exists job_safety_checkins_teen_due_idx
  on public.job_safety_checkins (teen_user_id, expected_at)
  where status = 'scheduled';
create index if not exists job_safety_checkins_application_idx
  on public.job_safety_checkins (application_id);
create index if not exists job_safety_checkins_job_idx
  on public.job_safety_checkins (job_id);
create index if not exists job_safety_checkins_adult_idx
  on public.job_safety_checkins (adult_user_id);

alter table public.job_safety_checkins enable row level security;
revoke all on public.job_safety_checkins from public, anon, authenticated;
grant select on public.job_safety_checkins to authenticated;

drop policy if exists job_safety_checkins_select_parties
  on public.job_safety_checkins;
create policy job_safety_checkins_select_parties
  on public.job_safety_checkins
  for select
  to authenticated
  using (
    teen_user_id = (select auth.uid())
    or adult_user_id = (select auth.uid())
    or private.has_staff_role(array['admin'::public.mort_role, 'moderator'::public.mort_role])
  );

create or replace function private.notify_guardians_of_safety_ping()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  insert into public.notifications (
    user_id, notification_type, title, body, data
  )
  select
    link.guardian_user_id,
    'safety_ping',
    case when new.immediate_danger then 'Urgent Safety Ping' else 'Safety Ping' end,
    'A linked teen sent a Safety Ping. Open MORT to review it.',
    jsonb_build_object(
      'safety_ping_id', new.id,
      'teen_id', new.teen_id,
      'immediate_danger', new.immediate_danger
    )
  from public.guardian_links link
  left join public.guardian_preferences guardian_preferences
    on guardian_preferences.link_id = link.id
  left join public.notification_preferences notification_preferences
    on notification_preferences.user_id = link.guardian_user_id
  where link.teen_user_id = new.teen_id
    and link.guardian_user_id is not null
    and link.status = 'active'
    and coalesce(guardian_preferences.safety_ping_alerts, true)
    and coalesce(notification_preferences.safety_alerts, true);
  return new;
end;
$function$;

revoke all on function private.notify_guardians_of_safety_ping()
  from public, anon, authenticated;

drop trigger if exists safety_pings_notify_guardians on public.safety_pings;
create trigger safety_pings_notify_guardians
  after insert on public.safety_pings
  for each row execute function private.notify_guardians_of_safety_ping();

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
set search_path to ''
as $function$
declare
  user_id uuid := auth.uid();
  ping_id uuid;
  guardian_count integer;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;
  if p_status is distinct from 'needs_help' then
    return jsonb_build_object('ok', false, 'code', 'safety_ping_status_invalid');
  end if;
  if char_length(coalesce(p_note, '')) > 500 then
    return jsonb_build_object('ok', false, 'code', 'safety_ping_note_too_long');
  end if;
  if p_job_id is not null and not exists (
    select 1
    from public.job_assignments assignment
    where assignment.teen_user_id = user_id
      and assignment.job_id = p_job_id
      and assignment.status in ('accepted', 'in_progress')
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_job_required');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(user_id::text, 0)
  );
  select id into ping_id
  from public.safety_pings
  where teen_id = user_id and client_request_id = p_client_request_id;
  if ping_id is null and exists (
    select 1 from public.safety_pings
    where teen_id = user_id and created_at > now() - interval '30 seconds'
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_ping_rate_limited');
  end if;

  if ping_id is null then
    insert into public.safety_pings (
      teen_id, status, note, job_id, immediate_danger, client_request_id
    ) values (
      user_id, 'needs_help', nullif(btrim(coalesce(p_note, '')), ''),
      p_job_id, coalesce(p_immediate_danger, false), p_client_request_id
    )
    on conflict (teen_id, client_request_id) do nothing
    returning id into ping_id;
  end if;

  if ping_id is null then
    select id into ping_id from public.safety_pings
    where teen_id = user_id and client_request_id = p_client_request_id;
  end if;

  select count(*) into guardian_count
  from public.notifications notification
  where notification.user_id in (
    select link.guardian_user_id
    from public.guardian_links link
    left join public.guardian_preferences preferences on preferences.link_id = link.id
    where link.teen_user_id = user_id
      and link.guardian_user_id is not null
      and link.status = 'active'
      and coalesce(preferences.safety_ping_alerts, true)
  )
  and notification.notification_type = 'safety_ping'
  and notification.data ->> 'safety_ping_id' = ping_id::text;

  return jsonb_build_object(
    'ok', true,
    'ping_id', ping_id,
    'immediate_danger', coalesce(p_immediate_danger, false),
    'guardian_notified', guardian_count > 0,
    'delivery', 'in_app_only'
  );
end;
$function$;

revoke all on function public.create_safety_ping_v2(text, text, uuid, boolean, uuid)
  from public, anon, authenticated;
grant execute on function public.create_safety_ping_v2(text, text, uuid, boolean, uuid)
  to authenticated;

create or replace function public.get_my_active_job_checkins()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $function$
  select coalesce(jsonb_agg(to_jsonb(checkins) order by checkins.expected_at nulls last), '[]'::jsonb)
  from (
    select
      assignment.application_id,
      assignment.job_id,
      job.title as job_title,
      checkin.id as checkin_id,
      coalesce(checkin.status, 'not_scheduled') as status,
      checkin.expected_at
    from public.job_assignments assignment
    join public.jobs job on job.id = assignment.job_id
    left join lateral (
      select c.id, c.status, c.expected_at
      from public.job_safety_checkins c
      where c.application_id = assignment.application_id
        and c.teen_user_id = (select auth.uid())
        and c.status = 'scheduled'
      order by c.expected_at asc
      limit 1
    ) checkin on true
    where assignment.teen_user_id = (select auth.uid())
      and assignment.status in ('accepted', 'in_progress')
  ) checkins
$function$;

revoke all on function public.get_my_active_job_checkins()
  from public, anon, authenticated;
grant execute on function public.get_my_active_job_checkins() to authenticated;

create or replace function public.schedule_active_job_checkin(
  p_application_id uuid,
  p_minutes_from_now integer,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  user_id uuid := auth.uid();
  assignment public.job_assignments%rowtype;
  checkin_id uuid;
  expected_at_value timestamptz;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;
  if p_minutes_from_now is null or p_minutes_from_now not between 5 and 240 then
    return jsonb_build_object('ok', false, 'code', 'checkin_interval_invalid');
  end if;

  select * into assignment
  from public.job_assignments
  where application_id = p_application_id
    and teen_user_id = user_id
    and status in ('accepted', 'in_progress');
  if not found then
    return jsonb_build_object('ok', false, 'code', 'active_assignment_required');
  end if;

  expected_at_value := now() + make_interval(mins => p_minutes_from_now);
  insert into public.job_safety_checkins (
    application_id, job_id, teen_user_id, adult_user_id,
    expected_at, client_request_id
  ) values (
    assignment.application_id, assignment.job_id, assignment.teen_user_id,
    assignment.adult_user_id, expected_at_value, p_client_request_id
  )
  on conflict (teen_user_id, client_request_id) do nothing
  returning id, expected_at into checkin_id, expected_at_value;

  if checkin_id is null then
    select id, expected_at into checkin_id, expected_at_value
    from public.job_safety_checkins
    where teen_user_id = user_id and client_request_id = p_client_request_id;
  end if;
  return jsonb_build_object(
    'ok', true, 'checkin_id', checkin_id, 'expected_at', expected_at_value
  );
end;
$function$;

revoke all on function public.schedule_active_job_checkin(uuid, integer, uuid)
  from public, anon, authenticated;
grant execute on function public.schedule_active_job_checkin(uuid, integer, uuid)
  to authenticated;

create or replace function public.complete_active_job_checkin(
  p_checkin_id uuid,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  user_id uuid := auth.uid();
  completed_id uuid;
  completed_at_value timestamptz;
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if private.current_role() <> 'teen'::public.mort_role or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_teen_account_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;

  update public.job_safety_checkins
  set status = 'completed', completed_at = now()
  where id = p_checkin_id
    and teen_user_id = user_id
    and status = 'scheduled'
  returning id, completed_at into completed_id, completed_at_value;

  if completed_id is null then
    select id, completed_at into completed_id, completed_at_value
    from public.job_safety_checkins
    where id = p_checkin_id and teen_user_id = user_id and status = 'completed';
  end if;
  if completed_id is null then
    return jsonb_build_object('ok', false, 'code', 'active_checkin_not_found');
  end if;
  return jsonb_build_object(
    'ok', true, 'checkin_id', completed_id, 'completed_at', completed_at_value
  );
end;
$function$;

revoke all on function public.complete_active_job_checkin(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.complete_active_job_checkin(uuid, uuid)
  to authenticated;
