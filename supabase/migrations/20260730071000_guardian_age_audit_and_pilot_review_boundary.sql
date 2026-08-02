-- Guardian Mode remains optional, consent-based, narrow, auditable, and ends
-- automatically when the linked teen reaches 18. It never unlocks support chat
-- or ordinary job-message content.

create or replace function private.is_minor_teen(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles profile
    where profile.id = p_user_id
      and profile.role = 'teen'
      and profile.dob is not null
      and profile.dob > (current_date - interval '18 years')::date
      and profile.dob <= (current_date - interval '13 years')::date
  )
$$;

create table if not exists public.guardian_connection_audit_events (
  id bigint generated always as identity primary key,
  link_id uuid references public.guardian_connections(id) on delete set null,
  teen_id uuid not null references public.profiles(id) on delete cascade,
  guardian_id uuid references public.profiles(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (event_type in (
    'invite_created', 'invite_accepted', 'link_revoked', 'link_expired',
    'link_canceled', 'preferences_updated', 'age_transition_revoked'
  )),
  safe_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists guardian_connection_audit_teen_created_idx
on public.guardian_connection_audit_events(teen_id, created_at desc);
create index if not exists guardian_connection_audit_guardian_created_idx
on public.guardian_connection_audit_events(guardian_id, created_at desc)
where guardian_id is not null;

alter table public.guardian_connection_audit_events enable row level security;
alter table public.guardian_connection_audit_events force row level security;

create policy guardian_connection_audit_participants_select
on public.guardian_connection_audit_events for select to authenticated
using (
  teen_id = (select auth.uid())
  or (
    guardian_id = (select auth.uid())
    and private.is_minor_teen(teen_id)
  )
  or public.is_admin()
);

revoke all on public.guardian_connection_audit_events from public, anon, authenticated;
grant select on public.guardian_connection_audit_events to authenticated;
grant all on public.guardian_connection_audit_events to service_role;

create or replace function private.enforce_guardian_minor_boundary()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('invited', 'active')
     and not private.is_minor_teen(new.teen_id) then
    raise exception 'guardian_mode_age_transition_required';
  end if;
  return new;
end;
$$;

drop trigger if exists guardian_connections_enforce_minor_boundary on public.guardian_connections;
create trigger guardian_connections_enforce_minor_boundary
before insert or update of teen_id, status on public.guardian_connections
for each row execute function private.enforce_guardian_minor_boundary();

create or replace function private.enforce_safety_circle_minor_boundary()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('invited', 'active')
     and not private.is_minor_teen(new.teen_id) then
    raise exception 'safety_circle_age_transition_required';
  end if;
  return new;
end;
$$;

drop trigger if exists safety_circle_enforce_minor_boundary on public.safety_circle_members;
create trigger safety_circle_enforce_minor_boundary
before insert or update of teen_id, status on public.safety_circle_members
for each row execute function private.enforce_safety_circle_minor_boundary();

create or replace function private.audit_guardian_connection_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event text;
begin
  if tg_op = 'INSERT' then
    v_event := 'invite_created';
  elsif old.status is not distinct from new.status then
    return new;
  else
    v_event := case new.status
      when 'active' then 'invite_accepted'
      when 'revoked' then case
        when coalesce(current_setting('mort.guardian_age_transition', true), '') = 'true'
          then 'age_transition_revoked'
        else 'link_revoked'
      end
      when 'expired' then 'link_expired'
      when 'canceled' then 'link_canceled'
      else null
    end;
  end if;
  if v_event is null then return new; end if;
  insert into public.guardian_connection_audit_events(
    link_id, teen_id, guardian_id, actor_id, event_type, safe_metadata
  ) values (
    new.id, new.teen_id, new.guardian_id, auth.uid(), v_event,
    jsonb_build_object(
      'from_status', case when tg_op = 'INSERT' then null else old.status::text end,
      'to_status', new.status::text,
      'guardian_mode_optional', true,
      'message_access_granted', false,
      'support_access_granted', false
    )
  );
  return new;
end;
$$;

drop trigger if exists guardian_connections_audit_change on public.guardian_connections;
create trigger guardian_connections_audit_change
after insert or update of status on public.guardian_connections
for each row execute function private.audit_guardian_connection_change();

create or replace function private.audit_guardian_preference_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_connection public.guardian_connections%rowtype;
begin
  if row(
    old.safety_ping_alerts, old.job_checkin_alerts, old.accepted_job_summary,
    old.safety_warning_alerts, old.weekly_digest,
    old.optional_job_approval_enabled
  ) is not distinct from row(
    new.safety_ping_alerts, new.job_checkin_alerts, new.accepted_job_summary,
    new.safety_warning_alerts, new.weekly_digest,
    new.optional_job_approval_enabled
  ) then return new; end if;
  select * into v_connection from public.guardian_connections where id = new.link_id;
  insert into public.guardian_connection_audit_events(
    link_id, teen_id, guardian_id, actor_id, event_type, safe_metadata
  ) values (
    new.link_id, v_connection.teen_id, v_connection.guardian_id, auth.uid(),
    'preferences_updated',
    jsonb_build_object(
      'safety_ping_alerts', new.safety_ping_alerts,
      'job_checkin_alerts', new.job_checkin_alerts,
      'accepted_job_summary', new.accepted_job_summary,
      'safety_warning_alerts', new.safety_warning_alerts,
      'weekly_digest', new.weekly_digest,
      'optional_job_approval_enabled', new.optional_job_approval_enabled,
      'message_access_granted', false,
      'support_access_granted', false
    )
  );
  return new;
end;
$$;

drop trigger if exists guardian_preferences_audit_change on public.guardian_preferences;
create trigger guardian_preferences_audit_change
after update on public.guardian_preferences
for each row execute function private.audit_guardian_preference_change();

create or replace function public.guardian_is_connected_to_teen(
  p_teen_id uuid,
  p_guardian_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and (
      auth.uid() = p_teen_id
      or auth.uid() = p_guardian_id
      or public.is_admin()
    )
    and private.is_minor_teen(p_teen_id)
    and exists (
      select 1 from public.guardian_connections connection
      where connection.teen_id = p_teen_id
        and connection.guardian_id = p_guardian_id
        and connection.status = 'active'
    )
$$;

create or replace function public.guardian_receives_safety_pings(
  p_teen_id uuid,
  p_guardian_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and (
      auth.uid() = p_teen_id
      or auth.uid() = p_guardian_id
      or public.is_admin()
    )
    and private.is_minor_teen(p_teen_id)
    and exists (
      select 1
      from public.guardian_connections connection
      join public.guardian_preferences preference
        on preference.link_id = connection.id
      where connection.teen_id = p_teen_id
        and connection.guardian_id = p_guardian_id
        and connection.status = 'active'
        and preference.safety_ping_alerts
    )
$$;

alter policy profiles_select_visible on public.profiles
to authenticated
using (
  id = (select auth.uid())
  or public.is_admin()
  or exists (
    select 1
    from public.guardian_connections connection
    join public.profiles teen_profile on teen_profile.id = connection.teen_id
    where connection.status = 'active'
      and private.is_minor_teen(teen_profile.id)
      and (
        (connection.teen_id = profiles.id and connection.guardian_id = (select auth.uid()))
        or (connection.guardian_id = profiles.id and connection.teen_id = (select auth.uid()))
      )
  )
  or exists (
    select 1
    from public.applications application
    join public.jobs job on job.id = application.job_id
    where application.teen_id = profiles.id
      and job.poster_id = (select auth.uid())
  )
);

alter policy guardian_connections_select on public.guardian_connections
to authenticated
using (
  teen_id = (select auth.uid())
  or (guardian_id = (select auth.uid()) and private.is_minor_teen(teen_id))
  or (
    status = 'invited'
    and invited_email is not null
    and private.is_minor_teen(teen_id)
    and lower(invited_email) = lower(coalesce((select auth.jwt())->>'email', ''))
  )
  or public.is_admin()
);

alter policy guardian_preferences_select_participants on public.guardian_preferences
to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.guardian_connections connection
    where connection.id = guardian_preferences.link_id
      and connection.status = 'active'
      and (
        connection.teen_id = (select auth.uid())
        or (
          connection.guardian_id = (select auth.uid())
          and private.is_minor_teen(connection.teen_id)
        )
      )
  )
);

alter policy guardian_preferences_update_teen on public.guardian_preferences
to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.guardian_connections connection
    where connection.id = guardian_preferences.link_id
      and connection.teen_id = (select auth.uid())
      and connection.status = 'active'
      and private.is_minor_teen(connection.teen_id)
  )
)
with check (
  public.is_admin()
  or exists (
    select 1 from public.guardian_connections connection
    where connection.id = guardian_preferences.link_id
      and connection.teen_id = (select auth.uid())
      and connection.status = 'active'
      and private.is_minor_teen(connection.teen_id)
  )
);

drop policy if exists safety_circle_participants_select on public.safety_circle_members;
create policy safety_circle_participants_select
on public.safety_circle_members for select to authenticated
using (
  teen_id = (select auth.uid())
  or (contact_id = (select auth.uid()) and private.is_minor_teen(teen_id))
);

create or replace function public.queue_safety_ping_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guardian record;
  v_guardian_count integer := 0;
  v_admin record;
begin
  if private.is_minor_teen(new.teen_id) then
    for v_guardian in
      select distinct connection.guardian_id
      from public.guardian_connections connection
      join public.guardian_preferences preference on preference.link_id = connection.id
      where connection.teen_id = new.teen_id
        and connection.status = 'active'
        and connection.guardian_id is not null
        and preference.safety_ping_alerts
    loop
      perform public.enqueue_notification(
        v_guardian.guardian_id,
        'Teen safety ping',
        'A linked teen sent a safety ping: ' || replace(new.status::text, '_', ' ') || '.',
        jsonb_build_object('safetyPingId', new.id, 'teenId', new.teen_id, 'status', new.status)
      );
      v_guardian_count := v_guardian_count + 1;
    end loop;
  end if;
  if v_guardian_count = 0 and new.status in ('needs_help', 'missed') then
    for v_admin in
      select distinct assignment.user_id
      from public.admin_role_assignments assignment
      join public.profiles profile on profile.id = assignment.user_id
      where assignment.revoked_at is null
        and profile.account_status = 'active'
        and assignment.role in (
          'senior_safety_moderator', 'child_safety_specialist',
          'incident_manager', 'super_admin'
        )
    loop
      perform public.enqueue_notification(
        v_admin.user_id,
        'Unsupervised safety alert',
        'A help or missed-check-in alert has no enabled Guardian Mode recipient. MORT has not dispatched physical help.',
        jsonb_build_object('safetyPingId', new.id, 'teenId', new.teen_id, 'status', new.status)
      );
    end loop;
  end if;
  return new;
end;
$$;

create or replace function private.notify_safety_circle_ping()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contact record;
begin
  if not private.is_minor_teen(new.teen_id) then return new; end if;
  for v_contact in
    select circle.contact_id
    from public.safety_circle_members circle
    where circle.teen_id = new.teen_id
      and circle.status = 'active'
      and circle.contact_id is not null
      and circle.receive_safety_ping
  loop
    perform public.enqueue_notification(
      v_contact.contact_id,
      case when new.status in ('needs_help', 'missed') then 'Safety Circle help alert' else 'Safety Circle check-in' end,
      case
        when new.status in ('needs_help', 'missed') then 'A Safety Circle member sent a help or missed-check-in alert. Contact emergency services for immediate danger.'
        else 'A Safety Circle member sent a check-in.'
      end,
      jsonb_build_object('safetyPingId', new.id, 'teenId', new.teen_id, 'jobId', new.job_id)
    );
  end loop;
  return new;
end;
$$;

create or replace function private.apply_guardian_age_transitions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guardian_count integer;
  v_circle_count integer;
begin
  perform set_config('mort.guardian_age_transition', 'true', true);
  update public.guardian_connections connection
  set status = 'revoked', unlinked_at = coalesce(unlinked_at, now()), updated_at = now()
  where connection.status in ('invited', 'active')
    and not private.is_minor_teen(connection.teen_id);
  get diagnostics v_guardian_count = row_count;
  update public.safety_circle_members circle
  set status = 'revoked', revoked_at = coalesce(revoked_at, now()), updated_at = now()
  where circle.status in ('invited', 'active')
    and not private.is_minor_teen(circle.teen_id);
  get diagnostics v_circle_count = row_count;
  update public.teen_profiles teen
  set paused_by_guardian = false, pause_reason = null
  where teen.paused_by_guardian
    and not private.is_minor_teen(teen.user_id);
  return jsonb_build_object(
    'guardian_links_revoked', v_guardian_count,
    'safety_circle_links_revoked', v_circle_count
  );
end;
$$;

create or replace function public.run_guardian_age_transitions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  return private.apply_guardian_age_transitions();
end;
$$;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname = 'mort-guardian-age-transitions';
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
  perform cron.schedule(
    'mort-guardian-age-transitions',
    '17 4 * * *',
    'select private.apply_guardian_age_transitions();'
  );
end;
$$;

-- No client reads or writes this server-owned review ledger. The trigger and
-- authorized review RPCs are security-definer paths with their own role checks.
revoke all on public.pilot_job_reviews from public, anon, authenticated;
grant all on public.pilot_job_reviews to service_role;

revoke all on function private.is_minor_teen(uuid),
  private.enforce_guardian_minor_boundary(),
  private.enforce_safety_circle_minor_boundary(),
  private.audit_guardian_connection_change(),
  private.audit_guardian_preference_change(),
  private.apply_guardian_age_transitions()
from public, anon, authenticated;

grant execute on function private.is_minor_teen(uuid),
  private.enforce_guardian_minor_boundary(),
  private.enforce_safety_circle_minor_boundary(),
  private.audit_guardian_connection_change(),
  private.audit_guardian_preference_change(),
  private.apply_guardian_age_transitions()
to service_role;

revoke all on function public.run_guardian_age_transitions()
from public, anon, authenticated;
grant execute on function public.run_guardian_age_transitions() to service_role;

comment on table public.guardian_connection_audit_events is
'Privacy-minimized Guardian Mode consent, preference, revocation, and age-transition history. It never grants message or support-conversation access.';
comment on table public.pilot_job_reviews is
'Server-owned closed-pilot review ledger. No direct authenticated or anonymous privileges; writes occur through trusted triggers or authorized review RPCs.';
