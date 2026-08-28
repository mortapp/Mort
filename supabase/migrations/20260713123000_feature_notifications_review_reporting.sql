alter table public.reviews
  alter column moderation_status set default 'pending_review';

alter table public.reports
  add column if not exists target_review_id uuid
    references public.reviews(id) on delete set null;

create index if not exists reports_target_review_idx
on public.reports(target_review_id)
where target_review_id is not null;

create or replace function public.queue_message_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_thread public.message_threads%rowtype;
  v_recipient uuid;
begin
  if new.scanner_status <> 'clean' then
    return new;
  end if;

  select * into v_thread
  from public.message_threads
  where id = new.thread_id;

  foreach v_recipient in array array[
    v_thread.teen_id,
    v_thread.adult_id,
    v_thread.guardian_id
  ] loop
    if v_recipient is not null and v_recipient <> new.sender_id then
      perform public.enqueue_notification(
        v_recipient,
        'New MORT message',
        'You have a new message in an active MORT conversation.',
        jsonb_build_object('threadId', new.thread_id, 'messageId', new.id)
      );
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists messages_queue_notifications on public.messages;
create trigger messages_queue_notifications
after insert on public.messages
for each row execute function public.queue_message_notifications();

create or replace function public.queue_job_change_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_application record;
  v_title text;
  v_body text;
begin
  if old.status is not distinct from new.status
     and old.applications_open is not distinct from new.applications_open then
    return new;
  end if;

  v_title := case new.status
    when 'canceled' then 'Job canceled'
    when 'completed' then 'Job completed'
    when 'paused' then 'Job paused'
    when 'open' then 'Job updated'
    else 'Job status updated'
  end;
  v_body := new.title || ' is now ' || replace(new.status::text, '_', ' ') || '.';

  for v_application in
    select distinct a.teen_id
    from public.applications a
    where a.job_id = new.id
      and a.status not in ('rejected', 'guardian_rejected', 'withdrawn')
  loop
    perform public.enqueue_notification(
      v_application.teen_id,
      v_title,
      v_body,
      jsonb_build_object('jobId', new.id, 'status', new.status)
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists jobs_queue_change_notifications on public.jobs;
create trigger jobs_queue_change_notifications
after update of status, applications_open on public.jobs
for each row execute function public.queue_job_change_notifications();

create or replace function public.queue_guardian_link_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_title text;
  v_body text;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status = 'active' then
    v_title := 'Guardian linked';
    v_body := 'A Guardian Mode connection is now active.';
  elsif new.status in ('revoked', 'canceled', 'expired') then
    v_title := 'Guardian connection ended';
    v_body := 'This Guardian Mode connection will not receive new updates.';
  else
    return new;
  end if;

  perform public.enqueue_notification(
    new.teen_id,
    v_title,
    v_body,
    jsonb_build_object('guardianLinkId', new.id, 'status', new.status)
  );
  if new.guardian_id is not null then
    perform public.enqueue_notification(
      new.guardian_id,
      v_title,
      v_body,
      jsonb_build_object('guardianLinkId', new.id, 'status', new.status)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists guardian_links_queue_notifications
on public.guardian_connections;
create trigger guardian_links_queue_notifications
after update of status on public.guardian_connections
for each row execute function public.queue_guardian_link_notifications();

create or replace function public.queue_review_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.enqueue_notification(
    new.subject_id,
    'Review received',
    'A completed-job review was submitted and is awaiting moderation.',
    jsonb_build_object('reviewId', new.id, 'jobId', new.job_id)
  );
  return new;
end;
$$;

drop trigger if exists reviews_queue_notifications on public.reviews;
create trigger reviews_queue_notifications
after insert on public.reviews
for each row execute function public.queue_review_notifications();

create or replace function public.queue_profile_verification_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.verification_status is distinct from new.verification_status then
    perform public.enqueue_notification(
      new.id,
      'Verification updated',
      'Your MORT profile verification status is now ' ||
        replace(new.verification_status::text, '_', ' ') || '.',
      jsonb_build_object('verificationStatus', new.verification_status)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_queue_verification_notifications
on public.profiles;
create trigger profiles_queue_verification_notifications
after update of verification_status on public.profiles
for each row execute function public.queue_profile_verification_notifications();

create or replace function public.queue_report_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  admin_profile record;
begin
  for admin_profile in
    select id from public.profiles where role = 'admin'
  loop
    perform public.enqueue_notification(
      admin_profile.id,
      'Safety report submitted',
      'A MORT safety report is ready for moderation.',
      jsonb_build_object(
        'reportId', new.id,
        'targetUserId', new.target_user_id,
        'targetJobId', new.target_job_id,
        'targetReviewId', new.target_review_id
      )
    );
  end loop;
  return new;
end;
$$;

revoke execute on function public.queue_message_notifications()
from public, anon, authenticated;
revoke execute on function public.queue_job_change_notifications()
from public, anon, authenticated;
revoke execute on function public.queue_guardian_link_notifications()
from public, anon, authenticated;
revoke execute on function public.queue_review_notifications()
from public, anon, authenticated;
revoke execute on function public.queue_profile_verification_notifications()
from public, anon, authenticated;
revoke execute on function public.queue_report_notifications()
from public, anon, authenticated;

grant select, insert on public.reviews to authenticated;
grant select, insert on public.reports to authenticated;

