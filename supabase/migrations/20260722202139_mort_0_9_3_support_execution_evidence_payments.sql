-- MORT 0.9.3 support conversations, private support evidence, and avatar cleanup.
-- This migration extends the existing support and profile systems. It does not
-- create a parallel ticket or profile write path.

create table if not exists public.avatar_orphan_cleanup_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  object_path text not null,
  reason_code text not null,
  status text not null default 'pending',
  attempt_count integer not null default 0,
  last_failure_code text,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint avatar_orphan_owner_path_check check (
    object_path ~ ('^' || owner_id::text || '/[0-9a-f-]{36}\\.jpg$')
  ),
  constraint avatar_orphan_reason_check check (
    reason_code in ('replaced_avatar_delete_failed', 'removed_avatar_delete_failed', 'profile_update_compensation_failed')
  ),
  constraint avatar_orphan_status_check check (status in ('pending', 'retrying', 'resolved', 'retained')),
  unique (owner_id, object_path)
);

alter table public.avatar_orphan_cleanup_events enable row level security;
alter table public.avatar_orphan_cleanup_events force row level security;

create policy avatar_orphan_cleanup_select_own
on public.avatar_orphan_cleanup_events for select to authenticated
using ((select auth.uid()) = owner_id);

revoke all on public.avatar_orphan_cleanup_events from anon, authenticated;
grant select on public.avatar_orphan_cleanup_events to authenticated;
grant all on public.avatar_orphan_cleanup_events to service_role;

create or replace function public.record_avatar_orphan_cleanup(
  p_object_path text,
  p_reason_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_current_path text;
  v_event public.avatar_orphan_cleanup_events%rowtype;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_object_path is null
     or p_object_path !~ ('^' || v_user_id::text || '/[0-9a-f-]{36}\\.jpg$') then
    return jsonb_build_object('ok', false, 'code', 'invalid_avatar_path');
  end if;
  if p_reason_code not in (
    'replaced_avatar_delete_failed',
    'removed_avatar_delete_failed',
    'profile_update_compensation_failed'
  ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_cleanup_reason');
  end if;
  select avatar_path into v_current_path
  from public.profiles
  where id = v_user_id;
  if v_current_path = p_object_path then
    return jsonb_build_object('ok', false, 'code', 'active_avatar_cannot_be_orphaned');
  end if;
  insert into public.avatar_orphan_cleanup_events (owner_id, object_path, reason_code)
  values (v_user_id, p_object_path, p_reason_code)
  on conflict (owner_id, object_path) do update
    set reason_code = excluded.reason_code,
        status = 'pending',
        updated_at = now()
  returning * into v_event;
  return jsonb_build_object('ok', true, 'cleanup_event_id', v_event.id, 'status', v_event.status);
end;
$$;

revoke all on function public.record_avatar_orphan_cleanup(text, text) from public, anon;
grant execute on function public.record_avatar_orphan_cleanup(text, text) to authenticated, service_role;

update storage.buckets
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg']
where id = 'profile-avatars';

drop policy if exists storage_profile_avatars_insert_own on storage.objects;
create policy storage_profile_avatars_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'profile-avatars'
  and name ~ ('^' || (select auth.uid())::text || '/[0-9a-f-]{36}\\.jpg$')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Support staff permissions are explicit and expiring. No user is seeded here.
create table if not exists private.support_staff_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role_key text not null,
  assigned_by uuid not null references auth.users(id) on delete restrict,
  reason text not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint support_staff_role_check check (role_key in ('support_agent', 'support_manager', 'safety_reviewer')),
  constraint support_staff_reason_check check (char_length(btrim(reason)) between 8 and 500),
  constraint support_staff_expiry_check check (expires_at > created_at)
);

alter table private.support_staff_assignments enable row level security;
alter table private.support_staff_assignments force row level security;
revoke all on private.support_staff_assignments from public, anon, authenticated;
grant all on private.support_staff_assignments to service_role;

create index if not exists support_staff_active_idx
on private.support_staff_assignments(user_id, role_key, expires_at)
where revoked_at is null;

create or replace function private.has_support_role(p_user_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and (
    exists (
      select 1 from public.profiles profile
      where profile.id = p_user_id and profile.role = 'admin' and profile.account_status = 'active'
    )
    or exists (
      select 1 from private.support_staff_assignments assignment
      where assignment.user_id = p_user_id
        and assignment.role_key = any(p_roles)
        and assignment.revoked_at is null
        and assignment.expires_at > now()
    )
  )
$$;

revoke all on function private.has_support_role(uuid, text[]) from public, anon, authenticated;
grant execute on function private.has_support_role(uuid, text[]) to service_role;

alter table public.support_tickets
  add column if not exists case_number text,
  add column if not exists category text not null default 'other',
  add column if not exists priority text not null default 'normal',
  add column if not exists source text not null default 'human_support',
  add column if not exists related_job_id uuid references public.jobs(id) on delete set null,
  add column if not exists related_application_id uuid references public.applications(id) on delete set null,
  add column if not exists related_contract_id uuid references public.job_contracts(id) on delete set null,
  add column if not exists related_dispute_id uuid references public.payment_disputes(id) on delete set null,
  add column if not exists assigned_support_user_id uuid references public.profiles(id) on delete set null,
  add column if not exists last_user_message_at timestamptz,
  add column if not exists last_staff_message_at timestamptz,
  add column if not exists waiting_on_party text not null default 'staff',
  add column if not exists resolution_code text,
  add column if not exists closed_reason text,
  add column if not exists ai_assisted boolean not null default false,
  add column if not exists human_reviewed boolean not null default false,
  add column if not exists safe_attachment_count integer not null default 0,
  add column if not exists human_review_requested_at timestamptz,
  add column if not exists reopened_at timestamptz,
  add column if not exists closed_at timestamptz;

update public.support_tickets
set case_number = 'MORT-' || upper(substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 12))
where case_number is null;

alter table public.support_tickets alter column case_number set not null;
create unique index if not exists support_tickets_case_number_idx on public.support_tickets(case_number);
create index if not exists support_tickets_queue_v2_idx
on public.support_tickets(status, priority, last_user_message_at desc nulls last, created_at);

alter table public.support_tickets drop constraint if exists support_tickets_status;
alter table public.support_tickets add constraint support_tickets_status check (
  status in ('open', 'waiting', 'waiting_on_user', 'waiting_on_staff', 'under_review', 'resolved', 'closed')
);
alter table public.support_tickets add constraint support_tickets_category_check check (
  category in (
    'account_sign_in', 'profile_avatar', 'verification', 'job_application',
    'start_finish_pin', 'job_cancellation', 'payment_compensation',
    'adult_refused_completion', 'teen_abandonment', 'evidence_submission',
    'report_block', 'privacy_deletion', 'mort_plus_play_billing', 'other'
  )
);
alter table public.support_tickets add constraint support_tickets_priority_check
  check (priority in ('low', 'normal', 'high', 'urgent_safety'));
alter table public.support_tickets add constraint support_tickets_source_check
  check (source in ('faq', 'automated_support', 'human_support', 'email_fallback', 'payment_dispute'));
alter table public.support_tickets add constraint support_tickets_waiting_check
  check (waiting_on_party in ('user', 'staff', 'none'));
alter table public.support_tickets add constraint support_tickets_attachment_count_check
  check (safe_attachment_count between 0 and 8);

alter table public.support_ticket_messages
  alter column sender_id drop not null,
  add column if not exists sender_kind text not null default 'user',
  add column if not exists message_source text not null default 'human_support',
  add column if not exists client_request_id uuid,
  add column if not exists safe_attachment_count integer not null default 0,
  add column if not exists staff_visible_only boolean not null default false,
  add column if not exists edited_at timestamptz;

alter table public.support_ticket_messages add constraint support_ticket_message_sender_kind_check
  check (sender_kind in ('user', 'automated_support', 'support_staff', 'system'));
alter table public.support_ticket_messages add constraint support_ticket_message_source_check
  check (message_source in ('faq', 'automated_support', 'human_support', 'email_fallback', 'payment_dispute'));
alter table public.support_ticket_messages add constraint support_ticket_message_sender_check
  check ((sender_kind in ('automated_support', 'system')) or sender_id is not null);
alter table public.support_ticket_messages add constraint support_ticket_message_attachment_count_check
  check (safe_attachment_count between 0 and 8);
create unique index if not exists support_ticket_message_request_idx
on public.support_ticket_messages(ticket_id, sender_id, client_request_id)
where client_request_id is not null;

create table if not exists public.support_ticket_audit_events (
  id bigint generated always as identity primary key,
  ticket_id uuid not null references public.support_tickets(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  from_status text,
  to_status text,
  safe_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint support_audit_event_type_check check (char_length(event_type) between 3 and 80)
);

alter table public.support_ticket_audit_events enable row level security;
alter table public.support_ticket_audit_events force row level security;
revoke all on public.support_ticket_audit_events from anon, authenticated;
grant all on public.support_ticket_audit_events to service_role;

create or replace function private.can_access_support_ticket(p_ticket_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.support_tickets ticket
    where ticket.id = p_ticket_id
      and (
        ticket.requester_id = p_user_id
        or (
          private.has_support_role(p_user_id, array['support_agent', 'support_manager', 'safety_reviewer'])
          and (ticket.assigned_support_user_id is null or ticket.assigned_support_user_id = p_user_id
               or private.has_support_role(p_user_id, array['support_manager']))
        )
      )
  )
$$;

revoke all on function private.can_access_support_ticket(uuid, uuid) from public, anon, authenticated;
grant execute on function private.can_access_support_ticket(uuid, uuid) to service_role;

create or replace function private.can_link_support_subject(
  p_user_id uuid,
  p_job_id uuid,
  p_application_id uuid,
  p_contract_id uuid,
  p_dispute_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (p_job_id is null or exists (
      select 1 from public.jobs job
      where job.id = p_job_id and (
        job.poster_id = p_user_id or exists (
          select 1 from public.applications application
          where application.job_id = job.id and application.teen_id = p_user_id
            and application.status in ('accepted', 'in_progress', 'proof_submitted', 'completed', 'disputed')
        )
      )
    ))
    and (p_application_id is null or exists (
      select 1 from public.applications application
      join public.jobs job on job.id = application.job_id
      where application.id = p_application_id
        and p_user_id in (application.teen_id, job.poster_id)
    ))
    and (p_contract_id is null or exists (
      select 1 from public.job_contracts contract
      where contract.id = p_contract_id and p_user_id in (contract.teen_id, contract.adult_id)
    ))
    and (p_dispute_id is null or exists (
      select 1 from public.payment_disputes dispute
      where dispute.id = p_dispute_id and p_user_id in (dispute.worker_id, dispute.poster_id)
    ))
$$;

revoke all on function private.can_link_support_subject(uuid, uuid, uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function private.can_link_support_subject(uuid, uuid, uuid, uuid, uuid) to service_role;

drop policy if exists support_tickets_insert_self on public.support_tickets;
drop policy if exists support_tickets_select_owner_or_admin on public.support_tickets;
drop policy if exists support_tickets_update_admin on public.support_tickets;
drop policy if exists support_tickets_update_owner_or_admin on public.support_tickets;
create policy support_tickets_select_authorized
on public.support_tickets for select to authenticated
using (private.can_access_support_ticket(id, (select auth.uid())));

drop policy if exists support_ticket_messages_insert_participant on public.support_ticket_messages;
drop policy if exists support_ticket_messages_select_participant on public.support_ticket_messages;
create policy support_ticket_messages_select_authorized
on public.support_ticket_messages for select to authenticated
using (
  private.can_access_support_ticket(ticket_id, (select auth.uid()))
  and (not staff_visible_only or private.has_support_role((select auth.uid()), array['support_agent', 'support_manager', 'safety_reviewer']))
);

revoke insert, update, delete on public.support_tickets from authenticated;
revoke insert, update, delete on public.support_ticket_messages from authenticated;
grant select on public.support_tickets, public.support_ticket_messages to authenticated;

create or replace function public.create_support_conversation(
  p_category text,
  p_subject text,
  p_message text,
  p_source text default 'automated_support',
  p_related_job_id uuid default null,
  p_related_application_id uuid default null,
  p_related_contract_id uuid default null,
  p_related_dispute_id uuid default null,
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
  v_subject text := btrim(coalesce(p_subject, ''));
  v_message text := btrim(coalesce(p_message, ''));
  v_priority text := case when p_category in ('adult_refused_completion', 'teen_abandonment') then 'high' else 'normal' end;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_category not in (
    'account_sign_in', 'profile_avatar', 'verification', 'job_application',
    'start_finish_pin', 'job_cancellation', 'payment_compensation',
    'adult_refused_completion', 'teen_abandonment', 'evidence_submission',
    'report_block', 'privacy_deletion', 'mort_plus_play_billing', 'other'
  ) or p_source not in ('faq', 'automated_support', 'human_support', 'email_fallback', 'payment_dispute') then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_category_or_source');
  end if;
  if char_length(v_subject) not between 4 and 120 or char_length(v_message) not between 3 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_ticket');
  end if;
  if not private.can_link_support_subject(v_user_id, p_related_job_id, p_related_application_id, p_related_contract_id, p_related_dispute_id) then
    return jsonb_build_object('ok', false, 'code', 'support_subject_not_authorized');
  end if;
  if not public.check_rate_limit('support_conversation_create', 8, 86400) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_limit_reached');
  end if;
  if p_client_request_id is not null then
    select ticket.* into v_ticket
    from public.support_tickets ticket
    join public.support_ticket_messages message on message.ticket_id = ticket.id
    where ticket.requester_id = v_user_id and message.client_request_id = p_client_request_id
    order by ticket.created_at desc limit 1;
    if v_ticket.id is not null then
      return jsonb_build_object('ok', true, 'replayed', true, 'ticket', to_jsonb(v_ticket));
    end if;
  end if;
  insert into public.support_tickets (
    requester_id, subject, category, priority, source,
    related_job_id, related_application_id, related_contract_id, related_dispute_id,
    last_user_message_at, waiting_on_party, ai_assisted
  ) values (
    v_user_id, v_subject, p_category, v_priority, p_source,
    p_related_job_id, p_related_application_id, p_related_contract_id, p_related_dispute_id,
    now(), 'staff', p_source = 'automated_support'
  ) returning * into v_ticket;
  insert into public.support_ticket_messages (
    ticket_id, sender_id, body, sender_kind, message_source, client_request_id
  ) values (v_ticket.id, v_user_id, v_message, 'user', p_source, p_client_request_id);
  insert into public.support_ticket_audit_events (ticket_id, actor_id, event_type, to_status)
  values (v_ticket.id, v_user_id, 'conversation_created', v_ticket.status);
  perform public.record_rate_limit_event('support_conversation_create');
  return jsonb_build_object('ok', true, 'replayed', false, 'ticket', to_jsonb(v_ticket));
end;
$$;

create or replace function public.create_support_ticket(p_subject text, p_message text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select public.create_support_conversation('other', p_subject, p_message, 'human_support', null, null, null, null, gen_random_uuid())
$$;

create or replace function public.post_support_ticket_message(
  p_ticket_id uuid,
  p_message text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
  v_message public.support_ticket_messages%rowtype;
  v_body text := btrim(coalesce(p_message, ''));
begin
  select * into v_ticket from public.support_tickets where id = p_ticket_id for update;
  if v_user_id is null or v_ticket.id is null or v_ticket.requester_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  if v_ticket.status = 'closed' then
    return jsonb_build_object('ok', false, 'code', 'closed_ticket_must_be_reopened');
  end if;
  if char_length(v_body) not between 1 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_message');
  end if;
  if not public.check_rate_limit('support_message_post', 40, 3600) then
    return jsonb_build_object('ok', false, 'code', 'support_message_limit_reached');
  end if;
  insert into public.support_ticket_messages (ticket_id, sender_id, body, sender_kind, message_source, client_request_id)
  values (v_ticket.id, v_user_id, v_body, 'user', v_ticket.source, p_client_request_id)
  on conflict (ticket_id, sender_id, client_request_id) where client_request_id is not null do nothing
  returning * into v_message;
  if v_message.id is null then
    select * into v_message from public.support_ticket_messages
    where ticket_id = v_ticket.id and sender_id = v_user_id and client_request_id = p_client_request_id;
  else
    update public.support_tickets
    set status = case when status in ('resolved', 'waiting_on_user') then 'open' else status end,
        waiting_on_party = 'staff', last_user_message_at = now()
    where id = v_ticket.id;
    insert into public.support_ticket_audit_events (ticket_id, actor_id, event_type)
    values (v_ticket.id, v_user_id, 'user_message_posted');
    perform public.record_rate_limit_event('support_message_post');
  end if;
  return jsonb_build_object('ok', true, 'message', to_jsonb(v_message));
end;
$$;

create or replace function public.list_my_support_tickets()
returns setof public.support_tickets
language sql
stable
security definer
set search_path = ''
as $$
  select ticket.* from public.support_tickets ticket
  where ticket.requester_id = auth.uid()
  order by coalesce(ticket.last_staff_message_at, ticket.last_user_message_at, ticket.created_at) desc
  limit 50
$$;

create or replace function public.get_my_support_ticket_thread(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ticket public.support_tickets%rowtype;
  v_messages jsonb;
begin
  select * into v_ticket from public.support_tickets
  where id = p_ticket_id and requester_id = auth.uid();
  if v_ticket.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  select coalesce(jsonb_agg(to_jsonb(message) order by message.created_at), '[]'::jsonb)
  into v_messages
  from public.support_ticket_messages message
  where message.ticket_id = v_ticket.id and not message.staff_visible_only;
  return jsonb_build_object('ok', true, 'ticket', to_jsonb(v_ticket), 'messages', v_messages);
end;
$$;

create or replace function public.link_my_support_ticket(
  p_ticket_id uuid,
  p_job_id uuid default null,
  p_application_id uuid default null,
  p_contract_id uuid default null,
  p_dispute_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
begin
  select * into v_ticket from public.support_tickets where id = p_ticket_id for update;
  if v_ticket.id is null or v_ticket.requester_id <> v_user_id then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  if not private.can_link_support_subject(v_user_id, p_job_id, p_application_id, p_contract_id, p_dispute_id) then
    return jsonb_build_object('ok', false, 'code', 'support_subject_not_authorized');
  end if;
  update public.support_tickets set
    related_job_id = coalesce(p_job_id, related_job_id),
    related_application_id = coalesce(p_application_id, related_application_id),
    related_contract_id = coalesce(p_contract_id, related_contract_id),
    related_dispute_id = coalesce(p_dispute_id, related_dispute_id)
  where id = v_ticket.id returning * into v_ticket;
  insert into public.support_ticket_audit_events (ticket_id, actor_id, event_type)
  values (v_ticket.id, v_user_id, 'authorized_subject_linked');
  return jsonb_build_object('ok', true, 'ticket', to_jsonb(v_ticket));
end;
$$;

create or replace function public.request_support_human_review(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ticket public.support_tickets%rowtype;
begin
  select * into v_ticket from public.support_tickets where id = p_ticket_id for update;
  if v_ticket.id is null or v_ticket.requester_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  if v_ticket.status = 'closed' then
    return jsonb_build_object('ok', false, 'code', 'closed_ticket_must_be_reopened');
  end if;
  update public.support_tickets
  set human_review_requested_at = coalesce(human_review_requested_at, now()),
      status = 'waiting_on_staff', waiting_on_party = 'staff'
  where id = v_ticket.id returning * into v_ticket;
  insert into public.support_ticket_audit_events (ticket_id, actor_id, event_type, to_status)
  values (v_ticket.id, auth.uid(), 'human_review_requested', v_ticket.status);
  return jsonb_build_object('ok', true, 'ticket', to_jsonb(v_ticket), 'human_has_reviewed', false);
end;
$$;

create or replace function public.reopen_my_support_ticket(p_ticket_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ticket public.support_tickets%rowtype;
begin
  select * into v_ticket from public.support_tickets where id = p_ticket_id for update;
  if v_ticket.id is null or v_ticket.requester_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  if v_ticket.status not in ('resolved', 'closed') or char_length(btrim(coalesce(p_reason, ''))) not between 3 and 500 then
    return jsonb_build_object('ok', false, 'code', 'ticket_not_reopenable');
  end if;
  update public.support_tickets
  set status = 'waiting_on_staff', waiting_on_party = 'staff', reopened_at = now(), closed_at = null, closed_reason = null
  where id = v_ticket.id returning * into v_ticket;
  insert into public.support_ticket_messages (ticket_id, sender_id, body, sender_kind, message_source)
  values (v_ticket.id, auth.uid(), left(btrim(p_reason), 500), 'user', 'human_support');
  insert into public.support_ticket_audit_events (ticket_id, actor_id, event_type, from_status, to_status)
  values (v_ticket.id, auth.uid(), 'ticket_reopened', 'closed', v_ticket.status);
  return jsonb_build_object('ok', true, 'ticket', to_jsonb(v_ticket));
end;
$$;

create or replace function public.support_staff_post_reply(
  p_ticket_id uuid,
  p_message text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
  v_message public.support_ticket_messages%rowtype;
begin
  if not private.has_support_role(v_actor, array['support_agent', 'support_manager', 'safety_reviewer']) then
    return jsonb_build_object('ok', false, 'code', 'support_staff_role_required');
  end if;
  select * into v_ticket from public.support_tickets where id = p_ticket_id for update;
  if v_ticket.id is null or not private.can_access_support_ticket(v_ticket.id, v_actor) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 1 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_message');
  end if;
  insert into public.support_ticket_messages (ticket_id, sender_id, body, sender_kind, message_source, client_request_id)
  values (v_ticket.id, v_actor, btrim(p_message), 'support_staff', 'human_support', p_client_request_id)
  on conflict (ticket_id, sender_id, client_request_id) where client_request_id is not null do nothing
  returning * into v_message;
  update public.support_tickets set
    assigned_support_user_id = coalesce(assigned_support_user_id, v_actor),
    status = 'waiting_on_user', waiting_on_party = 'user',
    last_staff_message_at = now(), human_reviewed = true
  where id = v_ticket.id;
  insert into public.support_ticket_audit_events (ticket_id, actor_id, event_type, to_status)
  values (v_ticket.id, v_actor, 'staff_reply_posted', 'waiting_on_user');
  return jsonb_build_object('ok', true, 'message', to_jsonb(v_message));
end;
$$;

create or replace function public.support_staff_change_status(
  p_ticket_id uuid,
  p_status text,
  p_resolution_code text default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
  v_old_status text;
begin
  if not private.has_support_role(v_actor, array['support_agent', 'support_manager']) then
    return jsonb_build_object('ok', false, 'code', 'support_staff_role_required');
  end if;
  if p_status not in ('open', 'waiting_on_user', 'waiting_on_staff', 'under_review', 'resolved', 'closed') then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_status');
  end if;
  select * into v_ticket from public.support_tickets where id = p_ticket_id for update;
  if v_ticket.id is null or not private.can_access_support_ticket(v_ticket.id, v_actor) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  if p_status in ('resolved', 'closed') and char_length(btrim(coalesce(p_reason, ''))) < 3 then
    return jsonb_build_object('ok', false, 'code', 'closure_reason_required');
  end if;
  v_old_status := v_ticket.status;
  update public.support_tickets set
    status = p_status,
    waiting_on_party = case p_status when 'waiting_on_user' then 'user' when 'waiting_on_staff' then 'staff' else 'none' end,
    resolution_code = case when p_status in ('resolved', 'closed') then left(p_resolution_code, 80) else resolution_code end,
    closed_reason = case when p_status = 'closed' then left(btrim(p_reason), 500) else closed_reason end,
    closed_at = case when p_status = 'closed' then now() else null end,
    human_reviewed = true,
    assigned_support_user_id = coalesce(assigned_support_user_id, v_actor)
  where id = v_ticket.id returning * into v_ticket;
  insert into public.support_ticket_audit_events (ticket_id, actor_id, event_type, from_status, to_status, safe_metadata)
  values (v_ticket.id, v_actor, 'status_changed', v_old_status, v_ticket.status, jsonb_build_object('resolution_code', v_ticket.resolution_code));
  return jsonb_build_object('ok', true, 'ticket', to_jsonb(v_ticket));
end;
$$;

-- Support evidence is private and image-only. Paths never contain source names.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('support-evidence', 'support-evidence', false, 4194304, array['image/jpeg'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.support_evidence_attachments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  ticket_id uuid references public.support_tickets(id) on delete restrict,
  dispute_id uuid references public.payment_disputes(id) on delete restrict,
  bucket_id text not null default 'support-evidence',
  object_path text not null unique,
  evidence_category text not null,
  statement text,
  content_type text not null default 'image/jpeg',
  processed_byte_size integer not null,
  sha256 text not null,
  status text not null default 'draft',
  review_status text not null default 'not_reviewed',
  retention_delete_at timestamptz not null default (now() + interval '180 days'),
  preservation_hold boolean not null default false,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_evidence_subject_check check (ticket_id is not null or dispute_id is not null),
  constraint support_evidence_bucket_check check (bucket_id = 'support-evidence'),
  constraint support_evidence_path_check check (object_path ~ ('^' || owner_id::text || '/[0-9a-f-]{36}\\.jpg$')),
  constraint support_evidence_category_check check (evidence_category in ('before_photo', 'after_photo', 'work_result', 'mort_message_screenshot', 'time_note_attachment')),
  constraint support_evidence_content_check check (content_type = 'image/jpeg' and processed_byte_size between 1 and 4194304),
  constraint support_evidence_hash_check check (sha256 ~ '^[a-f0-9]{64}$'),
  constraint support_evidence_status_check check (status in ('draft', 'submitted', 'under_review', 'preserved', 'deleted')),
  constraint support_evidence_review_check check (review_status in ('not_reviewed', 'queued', 'viewed', 'accepted_for_review', 'rejected_type'))
);

create index if not exists support_evidence_ticket_idx on public.support_evidence_attachments(ticket_id, created_at);
create index if not exists support_evidence_dispute_idx on public.support_evidence_attachments(dispute_id, created_at);
create index if not exists support_evidence_retention_idx on public.support_evidence_attachments(retention_delete_at) where preservation_hold = false;

create table if not exists public.support_evidence_access_events (
  id bigint generated always as identity primary key,
  evidence_id uuid not null references public.support_evidence_attachments(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  access_type text not null,
  authorization_basis text not null,
  created_at timestamptz not null default now(),
  constraint support_evidence_access_type_check check (access_type in ('signed_url_created', 'review_opened', 'metadata_read'))
);

alter table public.support_evidence_attachments enable row level security;
alter table public.support_evidence_attachments force row level security;
alter table public.support_evidence_access_events enable row level security;
alter table public.support_evidence_access_events force row level security;

create or replace function private.can_access_support_evidence(p_evidence_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.support_evidence_attachments evidence
    where evidence.id = p_evidence_id and evidence.status <> 'deleted' and (
      evidence.owner_id = p_user_id
      or (evidence.ticket_id is not null and private.can_access_support_ticket(evidence.ticket_id, p_user_id))
      or (evidence.dispute_id is not null and exists (
        select 1 from public.payment_disputes dispute
        where dispute.id = evidence.dispute_id and p_user_id in (dispute.worker_id, dispute.poster_id)
      ))
      or private.has_support_role(p_user_id, array['support_manager', 'safety_reviewer'])
    )
  )
$$;

revoke all on function private.can_access_support_evidence(uuid, uuid) from public, anon, authenticated;
grant execute on function private.can_access_support_evidence(uuid, uuid) to service_role;

create policy support_evidence_select_authorized
on public.support_evidence_attachments for select to authenticated
using (private.can_access_support_evidence(id, (select auth.uid())));

revoke all on public.support_evidence_attachments, public.support_evidence_access_events from anon, authenticated;
grant select on public.support_evidence_attachments to authenticated;
grant all on public.support_evidence_attachments, public.support_evidence_access_events to service_role;

drop policy if exists storage_support_evidence_insert_own on storage.objects;
create policy storage_support_evidence_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'support-evidence'
  and name ~ ('^' || (select auth.uid())::text || '/[0-9a-f-]{36}\\.jpg$')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
drop policy if exists storage_support_evidence_select_own on storage.objects;
create policy storage_support_evidence_select_own
on storage.objects for select to authenticated
using (
  bucket_id = 'support-evidence'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
drop policy if exists storage_support_evidence_delete_draft_own on storage.objects;
create policy storage_support_evidence_delete_draft_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'support-evidence'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (
    select 1 from public.support_evidence_attachments evidence
    where evidence.object_path = name and evidence.status <> 'draft'
  )
);

create or replace function public.register_support_evidence(
  p_ticket_id uuid,
  p_dispute_id uuid,
  p_evidence_category text,
  p_object_path text,
  p_sha256 text,
  p_processed_byte_size integer,
  p_statement text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_evidence public.support_evidence_attachments%rowtype;
  v_count integer;
  v_mime text;
  v_size integer;
begin
  if v_user_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_ticket_id is null and p_dispute_id is null then return jsonb_build_object('ok', false, 'code', 'evidence_subject_required'); end if;
  if p_object_path !~ ('^' || v_user_id::text || '/[0-9a-f-]{36}\\.jpg$')
     or p_sha256 !~ '^[a-f0-9]{64}$'
     or p_processed_byte_size not between 1 and 4194304 then
    return jsonb_build_object('ok', false, 'code', 'invalid_evidence_manifest');
  end if;
  if p_evidence_category not in ('before_photo', 'after_photo', 'work_result', 'mort_message_screenshot', 'time_note_attachment') then
    return jsonb_build_object('ok', false, 'code', 'invalid_evidence_category');
  end if;
  if p_ticket_id is not null and not exists (
    select 1 from public.support_tickets where id = p_ticket_id and requester_id = v_user_id
  ) then return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized'); end if;
  if p_dispute_id is not null and not exists (
    select 1 from public.payment_disputes where id = p_dispute_id and v_user_id in (worker_id, poster_id)
  ) then return jsonb_build_object('ok', false, 'code', 'payment_dispute_not_authorized'); end if;
  if p_ticket_id is not null and p_dispute_id is not null and not exists (
    select 1 from public.support_tickets where id = p_ticket_id and related_dispute_id = p_dispute_id
  ) then return jsonb_build_object('ok', false, 'code', 'ticket_dispute_link_required'); end if;
  select coalesce((metadata->>'mimetype')::text, ''), coalesce((metadata->>'size')::integer, 0)
  into v_mime, v_size
  from storage.objects where bucket_id = 'support-evidence' and name = p_object_path;
  if v_mime <> 'image/jpeg' or v_size <> p_processed_byte_size then
    return jsonb_build_object('ok', false, 'code', 'storage_manifest_mismatch');
  end if;
  select count(*) into v_count from public.support_evidence_attachments
  where owner_id = v_user_id and status <> 'deleted'
    and ((p_ticket_id is not null and ticket_id = p_ticket_id) or (p_dispute_id is not null and dispute_id = p_dispute_id));
  if v_count >= 8 then return jsonb_build_object('ok', false, 'code', 'evidence_attachment_limit_reached'); end if;
  insert into public.support_evidence_attachments (
    owner_id, ticket_id, dispute_id, object_path, evidence_category,
    statement, processed_byte_size, sha256, preservation_hold
  ) values (
    v_user_id, p_ticket_id, p_dispute_id, p_object_path, p_evidence_category,
    nullif(left(btrim(coalesce(p_statement, '')), 2000), ''), p_processed_byte_size, lower(p_sha256), p_dispute_id is not null
  )
  on conflict (object_path) do nothing
  returning * into v_evidence;
  if v_evidence.id is null then
    select * into v_evidence from public.support_evidence_attachments
    where object_path = p_object_path and owner_id = v_user_id;
  end if;
  return jsonb_build_object('ok', true, 'evidence', to_jsonb(v_evidence));
end;
$$;

create or replace function public.submit_support_evidence(p_evidence_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evidence public.support_evidence_attachments%rowtype;
begin
  select * into v_evidence from public.support_evidence_attachments where id = p_evidence_id for update;
  if v_evidence.id is null or v_evidence.owner_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'evidence_not_authorized');
  end if;
  if v_evidence.status <> 'draft' then
    return jsonb_build_object('ok', true, 'replayed', true, 'evidence', to_jsonb(v_evidence));
  end if;
  update public.support_evidence_attachments set
    status = 'submitted', review_status = 'queued', submitted_at = now(),
    preservation_hold = dispute_id is not null, updated_at = now()
  where id = v_evidence.id returning * into v_evidence;
  if v_evidence.ticket_id is not null then
    update public.support_tickets set safe_attachment_count = least(8, safe_attachment_count + 1)
    where id = v_evidence.ticket_id;
    insert into public.support_ticket_audit_events (ticket_id, actor_id, event_type, safe_metadata)
    values (v_evidence.ticket_id, auth.uid(), 'evidence_submitted', jsonb_build_object('evidence_id', v_evidence.id));
  end if;
  return jsonb_build_object('ok', true, 'replayed', false, 'evidence', to_jsonb(v_evidence));
end;
$$;

create or replace function public.remove_draft_support_evidence(p_evidence_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evidence public.support_evidence_attachments%rowtype;
begin
  select * into v_evidence from public.support_evidence_attachments where id = p_evidence_id for update;
  if v_evidence.id is null or v_evidence.owner_id <> auth.uid() then
    return jsonb_build_object('ok', false, 'code', 'evidence_not_authorized');
  end if;
  if v_evidence.status <> 'draft' or v_evidence.preservation_hold then
    return jsonb_build_object('ok', false, 'code', 'submitted_evidence_is_preserved');
  end if;
  update public.support_evidence_attachments set status = 'deleted', updated_at = now()
  where id = v_evidence.id;
  return jsonb_build_object('ok', true, 'object_path', v_evidence.object_path, 'storage_delete_allowed', true);
end;
$$;

create or replace function public.authorize_support_evidence_url(p_evidence_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evidence public.support_evidence_attachments%rowtype;
  v_basis text;
begin
  if auth.uid() is null or not private.can_access_support_evidence(p_evidence_id, auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'evidence_not_authorized');
  end if;
  select * into v_evidence from public.support_evidence_attachments where id = p_evidence_id;
  v_basis := case when v_evidence.owner_id = auth.uid() then 'owner'
    when private.has_support_role(auth.uid(), array['support_manager', 'safety_reviewer']) then 'assigned_review'
    else 'authorized_case_participant' end;
  insert into public.support_evidence_access_events (evidence_id, actor_id, access_type, authorization_basis)
  values (v_evidence.id, auth.uid(), 'signed_url_created', v_basis);
  return jsonb_build_object('ok', true, 'bucket_id', v_evidence.bucket_id, 'object_path', v_evidence.object_path, 'authorization_basis', v_basis);
end;
$$;

do $$
declare
  signature text;
begin
  foreach signature in array array[
    'public.create_support_conversation(text,text,text,text,uuid,uuid,uuid,uuid,uuid)',
    'public.post_support_ticket_message(uuid,text,uuid)',
    'public.list_my_support_tickets()',
    'public.get_my_support_ticket_thread(uuid)',
    'public.link_my_support_ticket(uuid,uuid,uuid,uuid,uuid)',
    'public.request_support_human_review(uuid)',
    'public.reopen_my_support_ticket(uuid,text)',
    'public.support_staff_post_reply(uuid,text,uuid)',
    'public.support_staff_change_status(uuid,text,text,text)',
    'public.register_support_evidence(uuid,uuid,text,text,text,integer,text,uuid)',
    'public.submit_support_evidence(uuid)',
    'public.remove_draft_support_evidence(uuid)',
    'public.authorize_support_evidence_url(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', signature);
    execute format('grant execute on function %s to authenticated, service_role', signature);
  end loop;
end $$;

revoke all on function public.create_support_ticket(text, text) from public, anon;
grant execute on function public.create_support_ticket(text, text) to authenticated, service_role;

-- Enum values are committed in this migration so the next forward migration
-- can safely use them in constraints and transition functions.
alter type public.application_status add value if not exists 'completion_pending_release';
alter type public.job_status add value if not exists 'completion_pending_release';
alter type public.job_status add value if not exists 'cancelled';
