-- Every started teen job gets a safety check-in baseline. A configured cadence
-- wins; otherwise use a bounded 60-minute default rather than scheduling none.
create or replace function private.schedule_job_cadence_checkins()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cadence integer;
  v_duration integer;
begin
  if old.start_pin_used_at is null and new.start_pin_used_at is not null then
    select coalesce(plan.checkin_cadence_minutes, 60),
           greatest(15, least(coalesce(job.estimated_duration_minutes, 120), 1440))
    into v_cadence, v_duration
    from public.job_safety_plans plan
    join public.jobs job on job.id = plan.job_id
    where plan.application_id = new.application_id;

    if v_cadence is null then
      v_cadence := 60;
      select greatest(15, least(coalesce(job.estimated_duration_minutes, 120), 1440))
      into v_duration
      from public.applications application
      join public.jobs job on job.id = application.job_id
      where application.id = new.application_id;
    end if;

    insert into public.job_checkins(
      application_id, user_id, checkin_type, expected_at, status
    )
    select new.application_id, new.teen_id, 'cadence',
           new.start_pin_used_at + make_interval(mins => minute_offset), 'pending'
    from generate_series(
      v_cadence,
      greatest(v_cadence, coalesce(v_duration, 120)),
      v_cadence
    ) minute_offset
    on conflict (application_id, user_id, checkin_type, expected_at)
    where expected_at is not null do nothing;
  end if;

  if old.finish_pin_used_at is null and new.finish_pin_used_at is not null then
    update public.job_checkins
    set status = 'canceled'
    where application_id = new.application_id
      and checkin_type = 'cadence'
      and status = 'pending';
  end if;
  return new;
end;
$$;

revoke all on function private.schedule_job_cadence_checkins()
from public, anon, authenticated;
grant execute on function private.schedule_job_cadence_checkins() to service_role;

comment on function private.schedule_job_cadence_checkins() is
'Schedules configured or default 60-minute active-job check-ins after start PIN confirmation and cancels pending cadence rows after finish.';
