-- Store the teen-controlled alert categories used by Guardian Mode.
create table if not exists public.guardian_preferences (
  link_id uuid primary key references public.guardian_links(id) on delete cascade,
  safety_ping_alerts boolean not null default true,
  job_checkin_alerts boolean not null default true,
  accepted_job_summary boolean not null default true,
  safety_warning_alerts boolean not null default true,
  weekly_digest boolean not null default false,
  optional_job_approval_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.guardian_preferences enable row level security;
revoke all on public.guardian_preferences from public, anon, authenticated;
grant select on public.guardian_preferences to authenticated;

drop policy if exists guardian_preferences_select_participants
  on public.guardian_preferences;
create policy guardian_preferences_select_participants
  on public.guardian_preferences
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.guardian_links link
      where link.id = guardian_preferences.link_id
        and link.status = 'active'
        and (link.teen_user_id = (select auth.uid())
          or link.guardian_user_id = (select auth.uid()))
    )
  );

create or replace function public.set_guardian_alert_preferences(
  p_link_id uuid,
  p_safety_ping_alerts boolean,
  p_job_checkin_alerts boolean,
  p_accepted_job_summary boolean,
  p_safety_warning_alerts boolean,
  p_weekly_digest boolean,
  p_optional_job_approval_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  user_id uuid := auth.uid();
begin
  if user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_link_id is null
    or p_safety_ping_alerts is null
    or p_job_checkin_alerts is null
    or p_accepted_job_summary is null
    or p_safety_warning_alerts is null
    or p_weekly_digest is null
    or p_optional_job_approval_enabled is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_preferences_required');
  end if;

  if not exists (
    select 1
    from public.guardian_links link
    where link.id = p_link_id
      and link.teen_user_id = user_id
      and link.status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_guardian_link_not_found');
  end if;

  insert into public.guardian_preferences (
    link_id,
    safety_ping_alerts,
    job_checkin_alerts,
    accepted_job_summary,
    safety_warning_alerts,
    weekly_digest,
    optional_job_approval_enabled
  ) values (
    p_link_id,
    p_safety_ping_alerts,
    p_job_checkin_alerts,
    p_accepted_job_summary,
    p_safety_warning_alerts,
    p_weekly_digest,
    p_optional_job_approval_enabled
  )
  on conflict (link_id) do update set
    safety_ping_alerts = excluded.safety_ping_alerts,
    job_checkin_alerts = excluded.job_checkin_alerts,
    accepted_job_summary = excluded.accepted_job_summary,
    safety_warning_alerts = excluded.safety_warning_alerts,
    weekly_digest = excluded.weekly_digest,
    optional_job_approval_enabled = excluded.optional_job_approval_enabled,
    updated_at = now();

  return jsonb_build_object('ok', true, 'link_id', p_link_id);
end;
$function$;

revoke all on function public.set_guardian_alert_preferences(
  uuid, boolean, boolean, boolean, boolean, boolean, boolean
) from public, anon, authenticated;
grant execute on function public.set_guardian_alert_preferences(
  uuid, boolean, boolean, boolean, boolean, boolean, boolean
) to authenticated;

