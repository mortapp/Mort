create or replace function public.get_guardian_teen_summary_v1(
  p_teen_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  guardian uuid := auth.uid();
  teen public.profiles%rowtype;
  active_jobs integer := 0;
  upcoming_title text;
  checkin public.job_checkins%rowtype;
  checkin_state text := 'notStarted';
  checkin_text text := '';
  earnings_visible boolean := false;
  earnings_this_month bigint := 0;
  safety_alerts integer := 0;
begin
  if guardian is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not public.is_profile_active(guardian) then
    raise exception 'user_account_restricted' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.guardian_connections link
    where link.guardian_id = guardian
      and link.teen_id = p_teen_id
      and link.status = 'active'
  ) then
    raise exception 'active_guardian_link_required' using errcode = '42501';
  end if;

  select * into teen
  from public.profiles
  where id = p_teen_id
    and role = 'teen';

  if teen.id is null then
    return null;
  end if;

  select count(*)::integer
  into active_jobs
  from public.applications application
  where application.teen_id = teen.id
    and application.status::text in (
      'accepted',
      'in_progress',
      'proof_submitted',
      'completion_pending_release'
    );

  select job.title
  into upcoming_title
  from public.applications application
  join public.jobs job on job.id = application.job_id
  where application.teen_id = teen.id
    and application.status::text in (
      'accepted',
      'in_progress',
      'proof_submitted',
      'completion_pending_release'
    )
    and job.starts_at is not null
    and job.starts_at >= statement_timestamp()
  order by job.starts_at, job.id
  limit 1;

  select checkin_row.*
  into checkin
  from public.job_checkins checkin_row
  where checkin_row.user_id = teen.id
  order by coalesce(checkin_row.completed_at, checkin_row.expected_at, checkin_row.created_at) desc,
           checkin_row.id desc
  limit 1;

  if checkin.id is not null then
    checkin_state := case
      when checkin.completed_at is not null or checkin.status = 'completed' then 'confirmed'
      when checkin.status = 'missed' then 'overdue'
      when checkin.status = 'skipped' then 'skipped'
      when checkin.status = 'pending'
        and checkin.expected_at is not null
        and checkin.expected_at < statement_timestamp() then 'overdue'
      when checkin.status = 'pending' then 'dueSoon'
      else 'notStarted'
    end;

    checkin_text := case
      when checkin.completed_at is not null
        then 'Checked in ' || to_char(checkin.completed_at at time zone 'UTC', 'Mon DD, YYYY HH24:MI "UTC"')
      when checkin.expected_at is not null
        then 'Scheduled ' || to_char(checkin.expected_at at time zone 'UTC', 'Mon DD, YYYY HH24:MI "UTC"')
      else ''
    end;
  end if;

  select coalesce(pref.guardian_financial_visibility, false)
  into earnings_visible
  from public.financial_preferences pref
  where pref.user_id = teen.id;

  if earnings_visible then
    select coalesce(sum(job.pay_amount_cents), 0)::bigint
    into earnings_this_month
    from public.applications application
    join public.jobs job on job.id = application.job_id
    where application.teen_id = teen.id
      and application.status::text = 'completed'
      and application.updated_at >= date_trunc('month', statement_timestamp())
      and application.updated_at < date_trunc('month', statement_timestamp()) + interval '1 month';
  end if;

  select count(*)::integer
  into safety_alerts
  from public.safety_incidents incident
  where incident.subject_user_id = teen.id
    and incident.status::text not in ('closed', 'resolved');

  return jsonb_build_object(
    'ok', true,
    'teen_id', teen.id,
    'teen_handle', case
      when nullif(btrim(coalesce(teen.username, '')), '') is null then ''
      else '@' || ltrim(btrim(teen.username), '@')
    end,
    'teen_display_name', coalesce(nullif(btrim(teen.display_name), ''), 'MORT teen'),
    'active_job_count', active_jobs,
    'upcoming_job_title', upcoming_title,
    'last_check_in_state', checkin_state,
    'last_check_in_text', checkin_text,
    'earnings_this_month_cents', case when earnings_visible then earnings_this_month else 0 end,
    'earnings_visible', earnings_visible,
    'payout_stage', null,
    'safety_alerts_count', safety_alerts,
    'restricted_notice',
      case when earnings_visible
        then 'Messages, exact locations, individual payment details, and payout destination details stay private to your teen.'
        else 'Messages, exact locations, financial totals, individual payment details, and payout destination details stay private to your teen.'
      end
  );
end;
$$;

revoke all on function public.get_guardian_teen_summary_v1(uuid)
  from public, anon;
grant execute on function public.get_guardian_teen_summary_v1(uuid)
  to authenticated;
