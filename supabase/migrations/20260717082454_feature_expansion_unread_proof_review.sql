-- Wave 0 completion: accurate participant unread state and auditable proof review.
-- All changes are additive and preserve existing jobs, applications, messages, and proof rows.

alter table public.conversation_participants
  add column if not exists last_read_at timestamptz;

insert into public.conversations (legacy_thread_id, job_id, application_id)
select thread.id, thread.job_id, thread.application_id
from public.message_threads thread
on conflict (legacy_thread_id) do update
set job_id = excluded.job_id,
    application_id = excluded.application_id;

insert into public.conversation_participants (conversation_id, user_id, role)
select conversation.id, participant.user_id, participant.role
from public.conversations conversation
join public.message_threads thread on thread.id = conversation.legacy_thread_id
cross join lateral (
  values
    (thread.teen_id, 'teen'::public.user_role),
    (thread.adult_id, 'adult'::public.user_role),
    (thread.guardian_id, 'guardian'::public.user_role)
) participant(user_id, role)
where participant.user_id is not null
on conflict (conversation_id, user_id) do nothing;

-- Existing conversations start without a surprise historical unread backlog.
update public.conversation_participants
set last_read_at = now()
where last_read_at is null;

alter table public.conversation_participants
  alter column last_read_at set default '-infinity'::timestamptz,
  alter column last_read_at set not null;

create index if not exists conversation_participants_user_read_idx
on public.conversation_participants(user_id, conversation_id, last_read_at);

create index if not exists messages_thread_sender_created_idx
on public.messages(thread_id, sender_id, created_at desc);

create or replace function public.touch_message_thread_after_message()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.message_threads
  set updated_at = greatest(updated_at, new.created_at)
  where id = new.thread_id;

  update public.conversation_participants participant
  set last_read_at = greatest(participant.last_read_at, new.created_at)
  from public.conversations conversation
  where conversation.id = participant.conversation_id
    and conversation.legacy_thread_id = new.thread_id
    and participant.user_id = new.sender_id;

  return new;
end;
$$;

drop trigger if exists messages_touch_thread on public.messages;
create trigger messages_touch_thread
after insert on public.messages
for each row execute function public.touch_message_thread_after_message();

create or replace function public.get_my_message_threads()
returns table (
  id uuid,
  job_id uuid,
  application_id uuid,
  teen_id uuid,
  adult_id uuid,
  guardian_id uuid,
  updated_at timestamptz,
  unread_count integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  if not public.is_profile_active(auth.uid()) then
    raise exception 'user_account_restricted';
  end if;

  return query
  select
    thread.id,
    thread.job_id,
    thread.application_id,
    thread.teen_id,
    thread.adult_id,
    thread.guardian_id,
    greatest(thread.updated_at, coalesce(max(message.created_at), thread.updated_at)) as updated_at,
    count(message.id) filter (
      where message.sender_id <> auth.uid()
        and message.created_at > participant.last_read_at
    )::integer as unread_count
  from public.conversation_participants participant
  join public.conversations conversation on conversation.id = participant.conversation_id
  join public.message_threads thread on thread.id = conversation.legacy_thread_id
  left join public.messages message on message.thread_id = thread.id
  where participant.user_id = auth.uid()
  group by thread.id, participant.last_read_at
  order by greatest(thread.updated_at, coalesce(max(message.created_at), thread.updated_at)) desc;
end;
$$;

create or replace function public.mark_message_thread_read(p_thread_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_conversation_id uuid;
  v_read_at timestamptz := statement_timestamp();
  v_unread_count integer;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select conversation.id
  into v_conversation_id
  from public.conversations conversation
  join public.conversation_participants participant
    on participant.conversation_id = conversation.id
  where conversation.legacy_thread_id = p_thread_id
    and participant.user_id = auth.uid();

  if v_conversation_id is null then
    return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
  end if;

  update public.conversation_participants
  set last_read_at = greatest(last_read_at, v_read_at)
  where conversation_id = v_conversation_id
    and user_id = auth.uid();

  select count(*)::integer
  into v_unread_count
  from public.messages message
  where message.thread_id = p_thread_id
    and message.sender_id <> auth.uid()
    and message.created_at > v_read_at;

  return jsonb_build_object(
    'ok', true,
    'thread_id', p_thread_id,
    'read_at', v_read_at,
    'unread_count', v_unread_count
  );
end;
$$;

alter table public.proof_uploads
  add column if not exists status text not null default 'submitted',
  add column if not exists reviewed_by uuid references public.profiles(id) on delete set null,
  add column if not exists review_note text,
  add column if not exists reviewed_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.proof_uploads'::regclass
      and conname = 'proof_uploads_status_check'
  ) then
    alter table public.proof_uploads
      add constraint proof_uploads_status_check
      check (status in ('submitted', 'approved', 'resubmission_requested', 'rejected'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.proof_uploads'::regclass
      and conname = 'proof_uploads_review_note_length_check'
  ) then
    alter table public.proof_uploads
      add constraint proof_uploads_review_note_length_check
      check (review_note is null or char_length(review_note) <= 500);
  end if;
end;
$$;

create index if not exists proof_uploads_application_status_created_idx
on public.proof_uploads(application_id, status, created_at desc);

drop trigger if exists proof_uploads_set_updated_at on public.proof_uploads;
create trigger proof_uploads_set_updated_at
before update on public.proof_uploads
for each row execute function public.set_updated_at();

create table if not exists public.proof_review_events (
  id uuid primary key default gen_random_uuid(),
  proof_id uuid not null references public.proof_uploads(id) on delete cascade,
  application_id uuid not null references public.applications(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null check (action in ('approved', 'resubmission_requested', 'rejected')),
  note text check (note is null or char_length(note) <= 500),
  created_at timestamptz not null default now()
);

create index if not exists proof_review_events_application_created_idx
on public.proof_review_events(application_id, created_at desc);

create index if not exists proof_review_events_proof_idx
on public.proof_review_events(proof_id);

create index if not exists proof_review_events_actor_idx
on public.proof_review_events(actor_id)
where actor_id is not null;

alter table public.proof_review_events enable row level security;

drop policy if exists proof_review_events_select_participant on public.proof_review_events;
create policy proof_review_events_select_participant
on public.proof_review_events for select to authenticated
using (public.is_application_participant(application_id));

create or replace function public.review_application_proof(
  p_proof_id uuid,
  p_action text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_proof public.proof_uploads%rowtype;
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_note text := nullif(left(btrim(coalesce(p_note, '')), 500), '');
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  if not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'user_account_restricted');
  end if;

  if v_action not in ('approved', 'resubmission_requested', 'rejected') then
    return jsonb_build_object('ok', false, 'code', 'invalid_proof_review_action');
  end if;

  if v_action in ('resubmission_requested', 'rejected')
     and char_length(coalesce(v_note, '')) < 10 then
    return jsonb_build_object('ok', false, 'code', 'proof_review_note_required');
  end if;

  select * into v_proof
  from public.proof_uploads
  where id = p_proof_id
  for update;

  if v_proof.id is null then
    return jsonb_build_object('ok', false, 'code', 'proof_not_found');
  end if;

  select * into v_application
  from public.applications
  where id = v_proof.application_id
  for update;

  select * into v_job
  from public.jobs
  where id = v_application.job_id
  for update;

  if v_job.poster_id <> auth.uid() and not public.is_admin() then
    return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
  end if;

  if exists (
    select 1
    from public.proof_uploads newer
    where newer.application_id = v_proof.application_id
      and (newer.created_at, newer.id) > (v_proof.created_at, v_proof.id)
  ) then
    return jsonb_build_object('ok', false, 'code', 'stale_proof_submission');
  end if;

  if v_proof.status = v_action then
    return jsonb_build_object(
      'ok', true,
      'idempotent', true,
      'proof', to_jsonb(v_proof),
      'application', to_jsonb(v_application),
      'job', to_jsonb(v_job)
    );
  end if;

  if v_proof.status <> 'submitted' or v_application.status <> 'proof_submitted' then
    return jsonb_build_object('ok', false, 'code', 'invalid_proof_review_state');
  end if;

  update public.proof_uploads
  set status = v_action,
      reviewed_by = auth.uid(),
      review_note = v_note,
      reviewed_at = now()
  where id = v_proof.id
  returning * into v_proof;

  if v_action in ('resubmission_requested', 'rejected') then
    update public.applications
    set status = 'in_progress'
    where id = v_application.id
    returning * into v_application;

    update public.jobs
    set status = 'in_progress'
    where id = v_job.id
    returning * into v_job;
  end if;

  insert into public.proof_review_events (
    proof_id, application_id, actor_id, action, note
  ) values (
    v_proof.id, v_application.id, auth.uid(), v_action, v_note
  );

  return jsonb_build_object(
    'ok', true,
    'idempotent', false,
    'proof', to_jsonb(v_proof),
    'application', to_jsonb(v_application),
    'job', to_jsonb(v_job)
  );
end;
$$;

create or replace function public.require_approved_proof_for_completion()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_proof_expected boolean;
begin
  if new.status = 'completed' and old.status is distinct from new.status then
    select job.proof_expected
    into v_proof_expected
    from public.jobs job
    where job.id = new.job_id;

    if coalesce(v_proof_expected, false)
       and not exists (
         select 1
         from public.proof_uploads proof
         where proof.application_id = new.id
           and proof.status = 'approved'
       ) then
      raise exception 'proof_approval_required';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists applications_require_approved_proof on public.applications;
create trigger applications_require_approved_proof
before update of status on public.applications
for each row execute function public.require_approved_proof_for_completion();

create or replace function public.queue_proof_review_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_teen_id uuid;
  v_title text;
  v_body text;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  select application.teen_id into v_teen_id
  from public.applications application
  where application.id = new.application_id;

  if new.status = 'approved' then
    v_title := 'Proof approved';
    v_body := 'The job poster approved your completion proof.';
  elsif new.status = 'resubmission_requested' then
    v_title := 'Proof update requested';
    v_body := 'The job poster requested a new completion proof. Open the job for details.';
  else
    v_title := 'Proof needs attention';
    v_body := 'The job poster could not approve that proof. Open the job for next steps.';
  end if;

  perform public.enqueue_notification(
    v_teen_id,
    v_title,
    v_body,
    jsonb_build_object(
      'applicationId', new.application_id,
      'proofUploadId', new.id,
      'proofStatus', new.status
    )
  );

  return new;
end;
$$;

drop trigger if exists proof_uploads_queue_review_notification on public.proof_uploads;
create trigger proof_uploads_queue_review_notification
after update of status on public.proof_uploads
for each row execute function public.queue_proof_review_notification();

revoke execute on function public.touch_message_thread_after_message() from public, anon, authenticated;
revoke execute on function public.get_my_message_threads() from public, anon;
revoke execute on function public.mark_message_thread_read(uuid) from public, anon;
revoke execute on function public.review_application_proof(uuid, text, text) from public, anon;
revoke execute on function public.require_approved_proof_for_completion() from public, anon, authenticated;
revoke execute on function public.queue_proof_review_notification() from public, anon, authenticated;

grant execute on function public.get_my_message_threads() to authenticated, service_role;
grant execute on function public.mark_message_thread_read(uuid) to authenticated, service_role;
grant execute on function public.review_application_proof(uuid, text, text) to authenticated, service_role;
grant select on public.proof_review_events to authenticated;
grant all on public.proof_review_events to service_role;

comment on column public.conversation_participants.last_read_at is
  'Server-authoritative participant read cursor. Updated only by trusted message flow or mark_message_thread_read.';
comment on table public.proof_review_events is
  'Append-only audit history for poster/admin proof decisions. Direct authenticated inserts are not granted.';
