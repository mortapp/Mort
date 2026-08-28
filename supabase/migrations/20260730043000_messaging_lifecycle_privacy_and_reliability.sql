-- Phase 6 messaging hardening. Job chat is intentionally text-only. Images and
-- documents belong in the private proof or support-evidence workflows.

alter table public.message_threads
  add column if not exists lifecycle_status text not null default 'active',
  add column if not exists closed_at timestamptz,
  add column if not exists closure_reason text;

alter table public.message_threads
  drop constraint if exists message_threads_lifecycle_status_check;
alter table public.message_threads
  add constraint message_threads_lifecycle_status_check
  check (lifecycle_status in ('active', 'read_only'));

update public.message_threads thread
set lifecycle_status = case
      when application.status in (
        'submitted', 'guardian_pending', 'adult_review', 'viewed', 'accepted',
        'in_progress', 'proof_submitted', 'completion_pending_release'
      ) then 'active'
      else 'read_only'
    end,
    closed_at = case
      when application.status in (
        'submitted', 'guardian_pending', 'adult_review', 'viewed', 'accepted',
        'in_progress', 'proof_submitted', 'completion_pending_release'
      ) then null
      else coalesce(thread.closed_at, now())
    end,
    closure_reason = case
      when application.status in (
        'submitted', 'guardian_pending', 'adult_review', 'viewed', 'accepted',
        'in_progress', 'proof_submitted', 'completion_pending_release'
      ) then null
      else 'application_' || application.status::text
    end
from public.applications application
where application.id = thread.application_id;

create or replace function private.sync_job_message_thread_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active boolean;
begin
  v_active := new.status in (
    'submitted', 'guardian_pending', 'adult_review', 'viewed', 'accepted',
    'in_progress', 'proof_submitted', 'completion_pending_release'
  );

  update public.message_threads
  set lifecycle_status = case when v_active then 'active' else 'read_only' end,
      closed_at = case when v_active then null else coalesce(closed_at, now()) end,
      closure_reason = case when v_active then null else 'application_' || new.status::text end,
      updated_at = now()
  where application_id = new.id;
  return new;
end;
$$;

drop trigger if exists applications_sync_message_thread_lifecycle on public.applications;
create trigger applications_sync_message_thread_lifecycle
after update of status on public.applications
for each row
when (old.status is distinct from new.status)
execute function private.sync_job_message_thread_lifecycle();

revoke all on function private.sync_job_message_thread_lifecycle()
from public, anon, authenticated;
grant execute on function private.sync_job_message_thread_lifecycle() to service_role;

-- Guardian Mode may approve and supervise a job, but it does not grant broad
-- access to teen/adult message content. Moderators use restricted evidence
-- queues instead of browsing ordinary conversations.
create or replace function public.is_thread_participant(p_thread_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.message_threads thread
    where thread.id = p_thread_id
      and (
        (thread.teen_id = auth.uid() and private.has_marketplace_identity(auth.uid()))
        or (thread.adult_id = auth.uid() and private.has_marketplace_identity(auth.uid()))
      )
  );
$$;

revoke all on function public.is_thread_participant(uuid) from public, anon;
grant execute on function public.is_thread_participant(uuid) to authenticated, service_role;

create table if not exists private.message_send_requests (
  sender_id uuid not null references auth.users(id) on delete cascade,
  client_request_id uuid not null,
  thread_id uuid not null references public.message_threads(id) on delete cascade,
  body_sha256 text not null check (body_sha256 ~ '^[0-9a-f]{64}$'),
  message_id uuid not null references public.messages(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (sender_id, client_request_id)
);

alter table private.message_send_requests enable row level security;
alter table private.message_send_requests force row level security;
revoke all on private.message_send_requests from public, anon, authenticated;
grant all on private.message_send_requests to service_role;

create index if not exists messages_thread_created_id_desc_idx
on public.messages(thread_id, created_at desc, id desc);

create or replace function private.classify_message_safety(p_body text)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text := lower(btrim(coalesce(p_body, '')));
begin
  if v_text = '' then
    return jsonb_build_object('blocked', true, 'category', 'harassment', 'severity', 'low', 'reason', 'Message cannot be empty.', 'safer_rewrite', false);
  end if;
  if char_length(v_text) > 2000 then
    return jsonb_build_object('blocked', true, 'category', 'harassment', 'severity', 'low', 'reason', 'Message is too long.', 'safer_rewrite', true);
  end if;
  if v_text ~ '(nude|naked|sexual|sex |send.{0,20}(pic|photo)|hotel room|private bedroom|dating|hook up|touch you|show me your body)' then
    return jsonb_build_object('blocked', true, 'category', 'sexual_conduct', 'severity', 'critical', 'reason', 'Sexual content involving job participants is blocked.', 'safer_rewrite', false);
  end if;
  if v_text ~ '(don''?t tell.{0,30}(parent|guardian|adult)|keep.{0,20}secret|hide this.{0,20}(parent|guardian)|gift.{0,30}secret|pay.{0,30}secret)' then
    return jsonb_build_object('blocked', true, 'category', 'child_safety_concern', 'severity', 'critical', 'reason', 'Secrecy or grooming-style language is blocked.', 'safer_rewrite', false);
  end if;
  if v_text ~ '(i will kill|kill you|hurt you|beat you|weapon|gun|knife|i know where you live|i will find you|watching your house)' then
    return jsonb_build_object('blocked', true, 'category', 'threats', 'severity', 'critical', 'reason', 'Threatening language is blocked and preserved for safety review.', 'safer_rewrite', false);
  end if;
  if v_text ~ '(blackmail|expose you|post your photos|ruin you unless|pay me or|do this or else)' then
    return jsonb_build_object('blocked', true, 'category', 'blackmail', 'severity', 'high', 'reason', 'Blackmail or coercive language is blocked.', 'safer_rewrite', false);
  end if;
  if v_text ~ '(school name|student number|school address|home address|social security|license number|passport number)'
     or v_text ~ '(^|[^0-9])[0-9]{1,6}[[:space:]]+[a-z0-9.''-]+([[:space:]]+[a-z0-9.''-]+){0,4}[[:space:]]+(street|st|avenue|ave|road|rd|drive|dr|lane|ln|court|ct|boulevard|blvd|way|parkway|pkwy|place|pl)([^a-z]|$)' then
    return jsonb_build_object('blocked', true, 'category', 'personal_information_request', 'severity', 'high', 'reason', 'Exact addresses and sensitive identity details are blocked. Use only a general public meeting area.', 'safer_rewrite', true);
  end if;
  if p_body ~* '(https?://|www\.)' then
    return jsonb_build_object('blocked', true, 'category', 'off_platform_pressure', 'severity', 'moderate', 'reason', 'Links are blocked in job chat. Keep scheduling and job details inside MORT.', 'safer_rewrite', true);
  end if;
  if p_body ~* '(\+?1[-.\s]?)?(\(?[0-9]{3}\)?[-.\s]?)?[0-9]{3}[-.\s]?[0-9]{4}'
     or p_body ~* '[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}'
     or v_text ~ '(instagram|snapchat|tiktok|discord|telegram|whatsapp|signal|kik|off app|text me|call me)' then
    return jsonb_build_object('blocked', true, 'category', 'off_platform_pressure', 'severity', 'moderate', 'reason', 'Off-platform contact details or pressure are blocked.', 'safer_rewrite', true);
  end if;
  if v_text ~ '(gift card|crypto payment|deposit first|upfront fee|cashapp|venmo|zelle|paypal|pay or else|withhold pay)' then
    return jsonb_build_object('blocked', true, 'category', 'payment_threat', 'severity', 'high', 'reason', 'Unsafe payment pressure is blocked.', 'safer_rewrite', true);
  end if;
  if v_text ~ '(slur|worthless|stupid kid|stupid adult|hate you|humiliate)' then
    return jsonb_build_object('blocked', false, 'category', 'harassment', 'severity', 'moderate', 'reason', 'Potential harassment was flagged for review.', 'safer_rewrite', true);
  end if;
  return jsonb_build_object('blocked', false, 'category', null, 'severity', null, 'reason', null, 'safer_rewrite', false);
end;
$$;

revoke all on function private.classify_message_safety(text)
from public, anon, authenticated;

create or replace function public.send_safe_message_v2(
  p_thread_id uuid,
  p_body text,
  p_client_request_id uuid
)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sender_id uuid := auth.uid();
  v_body text := btrim(coalesce(p_body, ''));
  v_body_sha256 text;
  v_request private.message_send_requests%rowtype;
  v_message public.messages%rowtype;
  v_thread public.message_threads%rowtype;
begin
  if v_sender_id is null then raise exception 'authentication_required'; end if;
  if p_client_request_id is null then raise exception 'client_request_id_required'; end if;
  v_body_sha256 := encode(extensions.digest(v_body, 'sha256'), 'hex');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_sender_id::text || ':' || p_client_request_id::text, 0)
  );

  select * into v_request
  from private.message_send_requests request
  where request.sender_id = v_sender_id
    and request.client_request_id = p_client_request_id;
  if found then
    if v_request.thread_id <> p_thread_id or v_request.body_sha256 <> v_body_sha256 then
      raise exception 'message_request_payload_mismatch';
    end if;
    select * into v_message from public.messages where id = v_request.message_id;
    return v_message;
  end if;

  select * into v_thread from public.message_threads where id = p_thread_id for update;
  if v_thread.id is null or not public.is_thread_participant(p_thread_id) then
    raise exception 'thread_participant_required';
  end if;
  if v_thread.lifecycle_status <> 'active' then raise exception 'thread_read_only'; end if;
  if not public.check_rate_limit('message_send', 120, 3600) then
    raise exception 'message_rate_limit_reached';
  end if;

  v_message := public.send_safe_message(p_thread_id, v_body);
  insert into private.message_send_requests(
    sender_id, client_request_id, thread_id, body_sha256, message_id
  ) values (
    v_sender_id, p_client_request_id, p_thread_id, v_body_sha256, v_message.id
  );
  perform public.record_rate_limit_event('message_send');
  return v_message;
end;
$$;

revoke all on function public.send_safe_message(uuid,text) from public, anon, authenticated;
grant execute on function public.send_safe_message(uuid,text) to service_role;
revoke all on function public.send_safe_message_v2(uuid,text,uuid) from public, anon;
grant execute on function public.send_safe_message_v2(uuid,text,uuid) to authenticated, service_role;

create or replace function public.list_thread_messages_page(
  p_thread_id uuid,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 40
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_items jsonb;
  v_count integer;
  v_next_created_at timestamptz;
  v_next_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    raise exception 'invalid_message_cursor';
  end if;
  if not public.is_profile_active(auth.uid()) then raise exception 'user_account_restricted'; end if;
  if not public.is_thread_participant(p_thread_id) then raise exception 'thread_participant_required'; end if;

  with candidates as (
    select message.id, message.thread_id, message.sender_id, message.body,
           message.scanner_status, message.scanner_reason,
           message.safety_category, message.safety_severity,
           message.safer_rewrite_available, message.created_at
    from public.messages message
    where message.thread_id = p_thread_id
      and (
        p_cursor_created_at is null
        or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id)
      )
    order by message.created_at desc, message.id desc
    limit v_limit + 1
  ), page as (
    select * from candidates
    order by created_at desc, id desc
    limit v_limit
  )
  select
    coalesce(jsonb_agg(to_jsonb(page) order by page.created_at asc, page.id asc), '[]'::jsonb),
    (select count(*) from candidates),
    (select created_at from page order by created_at asc, id asc limit 1),
    (select id from page order by created_at asc, id asc limit 1)
  into v_items, v_count, v_next_created_at, v_next_id
  from page;

  return jsonb_build_object(
    'items', v_items,
    'has_more', v_count > v_limit,
    'lifecycle_status', (
      select thread.lifecycle_status
      from public.message_threads thread
      where thread.id = p_thread_id
    ),
    'next_cursor', case when v_count > v_limit then jsonb_build_object(
      'created_at', v_next_created_at,
      'id', v_next_id
    ) else null end
  );
end;
$$;

revoke all on function public.list_thread_messages_page(uuid,timestamptz,uuid,integer)
from public, anon;
grant execute on function public.list_thread_messages_page(uuid,timestamptz,uuid,integer)
to authenticated, service_role;

drop function if exists public.get_my_message_threads();
create function public.get_my_message_threads()
returns table (
  id uuid,
  job_id uuid,
  application_id uuid,
  teen_id uuid,
  adult_id uuid,
  guardian_id uuid,
  lifecycle_status text,
  updated_at timestamptz,
  unread_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not public.is_profile_active(auth.uid()) then raise exception 'user_account_restricted'; end if;

  return query
  select thread.id, thread.job_id, thread.application_id, thread.teen_id,
         thread.adult_id, thread.guardian_id, thread.lifecycle_status,
         greatest(thread.updated_at, coalesce(max(message.created_at), thread.updated_at)),
         count(message.id) filter (
           where message.sender_id <> auth.uid()
             and message.created_at > participant.last_read_at
         )::integer
  from public.conversation_participants participant
  join public.conversations conversation on conversation.id = participant.conversation_id
  join public.message_threads thread on thread.id = conversation.legacy_thread_id
  left join public.messages message on message.thread_id = thread.id
  where participant.user_id = auth.uid()
    and participant.role in ('teen', 'adult')
    and public.is_thread_participant(thread.id)
  group by thread.id, participant.last_read_at
  order by greatest(thread.updated_at, coalesce(max(message.created_at), thread.updated_at)) desc;
end;
$$;

create or replace function public.mark_message_thread_read(p_thread_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation_id uuid;
  v_read_at timestamptz := statement_timestamp();
  v_unread_count integer;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not public.is_thread_participant(p_thread_id) then
    return jsonb_build_object('ok', false, 'code', 'thread_participant_required');
  end if;
  select conversation.id into v_conversation_id
  from public.conversations conversation
  join public.conversation_participants participant
    on participant.conversation_id = conversation.id
  where conversation.legacy_thread_id = p_thread_id
    and participant.user_id = auth.uid()
    and participant.role in ('teen', 'adult');
  if v_conversation_id is null then
    return jsonb_build_object('ok', false, 'code', 'thread_participant_required');
  end if;
  update public.conversation_participants
  set last_read_at = v_read_at
  where conversation_id = v_conversation_id and user_id = auth.uid();
  select count(*)::integer into v_unread_count
  from public.messages message
  where message.thread_id = p_thread_id
    and message.sender_id <> auth.uid()
    and message.created_at > v_read_at;
  return jsonb_build_object('ok', true, 'read_at', v_read_at, 'unread_count', v_unread_count);
end;
$$;

revoke all on function public.get_my_message_threads() from public, anon;
grant execute on function public.get_my_message_threads() to authenticated, service_role;
revoke all on function public.mark_message_thread_read(uuid) from public, anon;
grant execute on function public.mark_message_thread_read(uuid) to authenticated, service_role;

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;

comment on table private.message_send_requests is
'Server-only retry ledger. Raw message bodies and PIN values are never stored here.';
comment on function public.list_thread_messages_page(uuid,timestamptz,uuid,integer) is
'Participant-only keyset page. Restricted raw safety evidence is intentionally excluded.';
