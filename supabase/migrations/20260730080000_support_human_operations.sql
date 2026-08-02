-- Phase 8: human Support operations. This migration preserves the existing
-- chatbot and ticket foundations and adds explicit operational boundaries.

create or replace function private.has_support_role(p_user_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and (
    exists (
      select 1
      from private.support_staff_assignments assignment
      join public.profiles profile on profile.id = assignment.user_id
      where assignment.user_id = p_user_id
        and assignment.role_key = any(p_roles)
        and assignment.revoked_at is null
        and assignment.expires_at > now()
        and profile.account_status = 'active'
    )
    or (
      'support_agent' = any(p_roles)
      and private.has_admin_safety_role(
        p_user_id,
        array['support_agent']::public.admin_safety_role[]
      )
    )
    or (
      'support_manager' = any(p_roles)
      and private.has_admin_safety_role(
        p_user_id,
        array['incident_manager']::public.admin_safety_role[]
      )
    )
    or (
      'safety_reviewer' = any(p_roles)
      and private.has_admin_safety_role(
        p_user_id,
        array[
          'senior_safety_moderator', 'child_safety_specialist', 'incident_manager'
        ]::public.admin_safety_role[]
      )
    )
  )
$$;

revoke all on function private.has_support_role(uuid, text[])
from public, anon, authenticated;
grant execute on function private.has_support_role(uuid, text[]) to service_role;

create table public.support_operation_policies (
  singleton boolean primary key default true,
  staffing_status text not null default 'external_gate_unstaffed',
  timezone text not null default 'America/Indiana/Indianapolis',
  support_hours jsonb not null default '{"display":"Not staffed yet","days":[]}'::jsonb,
  normal_first_response_target_minutes integer not null default 1440,
  high_first_response_target_minutes integer not null default 240,
  urgent_escalation_target_minutes integer not null default 15,
  targets_are_commitments boolean not null default false,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint support_operation_policy_singleton check (singleton),
  constraint support_operation_staffing_check check (
    staffing_status in ('external_gate_unstaffed', 'closed_pilot_staffed', 'production_staffed')
  ),
  constraint support_operation_hours_check check (jsonb_typeof(support_hours) = 'object'),
  constraint support_operation_normal_target_check check (
    normal_first_response_target_minutes between 30 and 10080
  ),
  constraint support_operation_high_target_check check (
    high_first_response_target_minutes between 15 and 2880
  ),
  constraint support_operation_urgent_target_check check (
    urgent_escalation_target_minutes between 5 and 240
  ),
  constraint support_operation_commitment_check check (
    not targets_are_commitments or staffing_status = 'production_staffed'
  )
);

alter table public.support_operation_policies enable row level security;
alter table public.support_operation_policies force row level security;
revoke all on public.support_operation_policies from public, anon, authenticated;
grant all on public.support_operation_policies to service_role;

insert into public.support_operation_policies (singleton)
values (true)
on conflict (singleton) do nothing;

alter table public.support_tickets
  add column if not exists queue_key text not null default 'support',
  add column if not exists case_kind text not null default 'standard',
  add column if not exists appeal_of_ticket_id uuid references public.support_tickets(id) on delete restrict,
  add column if not exists assigned_at timestamptz,
  add column if not exists first_response_due_at timestamptz,
  add column if not exists urgent_escalation_due_at timestamptz,
  add column if not exists first_human_response_at timestamptz,
  add column if not exists escalation_summary jsonb not null default '{}'::jsonb,
  add column if not exists last_aging_evaluated_at timestamptz;

alter table public.support_tickets drop constraint if exists support_ticket_queue_key_check;
alter table public.support_tickets add constraint support_ticket_queue_key_check
  check (queue_key in ('support', 'trust_safety', 'privacy', 'billing'));
alter table public.support_tickets drop constraint if exists support_ticket_case_kind_check;
alter table public.support_tickets add constraint support_ticket_case_kind_check
  check (case_kind in ('standard', 'appeal'));
alter table public.support_tickets drop constraint if exists support_ticket_appeal_shape_check;
alter table public.support_tickets add constraint support_ticket_appeal_shape_check
  check (
    (case_kind = 'standard' and appeal_of_ticket_id is null)
    or (case_kind = 'appeal' and appeal_of_ticket_id is not null)
  );
alter table public.support_tickets drop constraint if exists support_ticket_escalation_summary_check;
alter table public.support_tickets add constraint support_ticket_escalation_summary_check
  check (jsonb_typeof(escalation_summary) = 'object');

create unique index if not exists support_ticket_one_appeal_idx
on public.support_tickets(requester_id, appeal_of_ticket_id)
where case_kind = 'appeal';
create index if not exists support_ticket_response_due_idx
on public.support_tickets(first_response_due_at)
where first_human_response_at is null and status not in ('resolved', 'closed');
create index if not exists support_ticket_assignment_queue_idx
on public.support_tickets(queue_key, assigned_support_user_id, priority, first_response_due_at);

create or replace function private.support_apply_response_targets()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  policy public.support_operation_policies%rowtype;
  target_minutes integer;
begin
  select * into policy
  from public.support_operation_policies
  where singleton = true;

  target_minutes := case
    when new.priority = 'urgent_safety' then policy.urgent_escalation_target_minutes
    when new.priority = 'high' then policy.high_first_response_target_minutes
    else policy.normal_first_response_target_minutes
  end;

  if tg_op = 'INSERT'
     or new.priority is distinct from old.priority
     or new.first_response_due_at is null then
    new.first_response_due_at := coalesce(new.created_at, now())
      + make_interval(mins => target_minutes);
    new.urgent_escalation_due_at := case
      when new.priority = 'urgent_safety' then coalesce(new.created_at, now())
        + make_interval(mins => policy.urgent_escalation_target_minutes)
      else null
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists support_ticket_response_targets on public.support_tickets;
create trigger support_ticket_response_targets
before insert or update of priority, first_response_due_at on public.support_tickets
for each row execute function private.support_apply_response_targets();

update public.support_tickets
set first_response_due_at = null
where first_response_due_at is null;

create table public.support_internal_notes (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete restrict,
  author_id uuid not null references public.profiles(id) on delete restrict,
  note_kind text not null default 'case_note',
  body text not null,
  body_sha256 text not null,
  client_request_id uuid not null,
  created_at timestamptz not null default now(),
  constraint support_internal_note_kind_check check (
    note_kind in ('case_note', 'handoff_summary', 'safety_review', 'appeal_review')
  ),
  constraint support_internal_note_body_check check (
    char_length(btrim(body)) between 3 and 2000
  ),
  constraint support_internal_note_hash_check check (body_sha256 ~ '^[a-f0-9]{64}$'),
  unique (ticket_id, author_id, client_request_id)
);

alter table public.support_internal_notes enable row level security;
alter table public.support_internal_notes force row level security;
revoke all on public.support_internal_notes from public, anon, authenticated;
grant all on public.support_internal_notes to service_role;
create index support_internal_notes_ticket_idx
on public.support_internal_notes(ticket_id, created_at);

create table public.support_ticket_appeals (
  id uuid primary key default gen_random_uuid(),
  original_ticket_id uuid not null references public.support_tickets(id) on delete restrict,
  appeal_ticket_id uuid not null unique references public.support_tickets(id) on delete restrict,
  requester_id uuid not null references public.profiles(id) on delete restrict,
  client_request_id uuid not null,
  reason_sha256 text not null,
  created_at timestamptz not null default now(),
  constraint support_ticket_appeal_hash_check check (reason_sha256 ~ '^[a-f0-9]{64}$'),
  unique (requester_id, client_request_id),
  unique (requester_id, original_ticket_id)
);

alter table public.support_ticket_appeals enable row level security;
alter table public.support_ticket_appeals force row level security;
revoke all on public.support_ticket_appeals from public, anon, authenticated;
grant all on public.support_ticket_appeals to service_role;

create table public.support_backlog_alerts (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete restrict,
  alert_type text not null,
  severity text not null,
  target_at timestamptz not null,
  detected_at timestamptz not null default now(),
  resolved_at timestamptz,
  safe_metadata jsonb not null default '{}'::jsonb,
  constraint support_backlog_alert_type_check check (
    alert_type in ('first_response_overdue', 'urgent_escalation_overdue', 'waiting_staff_24h')
  ),
  constraint support_backlog_alert_severity_check check (
    severity in ('warning', 'high', 'urgent')
  ),
  constraint support_backlog_alert_metadata_check check (jsonb_typeof(safe_metadata) = 'object')
);

alter table public.support_backlog_alerts enable row level security;
alter table public.support_backlog_alerts force row level security;
revoke all on public.support_backlog_alerts from public, anon, authenticated;
grant all on public.support_backlog_alerts to service_role;
create unique index support_backlog_alert_active_idx
on public.support_backlog_alerts(ticket_id, alert_type)
where resolved_at is null;
create index support_backlog_alert_queue_idx
on public.support_backlog_alerts(severity, detected_at)
where resolved_at is null;

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
        or private.has_support_role(p_user_id, array['support_manager'])
        or (
          private.has_support_role(p_user_id, array['support_agent'])
          and ticket.priority <> 'urgent_safety'
          and (
            ticket.assigned_support_user_id is null
            or ticket.assigned_support_user_id = p_user_id
          )
        )
        or (
          private.has_support_role(p_user_id, array['safety_reviewer'])
          and ticket.priority in ('high', 'urgent_safety')
          and (
            ticket.assigned_support_user_id is null
            or ticket.assigned_support_user_id = p_user_id
          )
        )
      )
  )
$$;

revoke all on function private.can_access_support_ticket(uuid, uuid)
from public, anon, authenticated;
grant execute on function private.can_access_support_ticket(uuid, uuid) to service_role;

create or replace function public.support_get_service_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  policy public.support_operation_policies%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into policy from public.support_operation_policies where singleton = true;
  return jsonb_build_object(
    'ok', true,
    'staffing_status', policy.staffing_status,
    'timezone', policy.timezone,
    'support_hours', policy.support_hours,
    'targets_are_commitments', policy.targets_are_commitments,
    'response_message', case
      when policy.targets_are_commitments then 'Published response targets are active.'
      else 'Human staffing and response times are not yet guaranteed.'
    end,
    'emergency_service', false
  );
end;
$$;

create or replace function public.support_staff_claim_ticket(
  p_ticket_id uuid,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  ticket public.support_tickets%rowtype;
  claimed boolean := false;
begin
  if p_client_request_id is null
     or not private.has_support_role(
       actor, array['support_agent', 'support_manager', 'safety_reviewer']
     ) then
    return jsonb_build_object('ok', false, 'code', 'support_staff_role_required');
  end if;
  select * into ticket from public.support_tickets where id = p_ticket_id for update;
  if ticket.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_found');
  end if;
  if ticket.priority = 'urgent_safety'
     and not private.has_support_role(actor, array['support_manager', 'safety_reviewer']) then
    return jsonb_build_object('ok', false, 'code', 'safety_reviewer_required');
  end if;
  if ticket.assigned_support_user_id is not null
     and ticket.assigned_support_user_id <> actor then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_already_assigned');
  end if;
  if ticket.assigned_support_user_id is null then
    update public.support_tickets
    set assigned_support_user_id = actor, assigned_at = now()
    where id = ticket.id
    returning * into ticket;
    claimed := true;
    insert into public.support_ticket_audit_events (
      ticket_id, actor_id, event_type, safe_metadata
    ) values (
      ticket.id, actor, 'ticket_claimed',
      jsonb_build_object('request_id', p_client_request_id)
    );
  end if;
  return jsonb_build_object('ok', true, 'replayed', not claimed, 'ticket', to_jsonb(ticket));
end;
$$;

create or replace function public.support_manager_assign_ticket(
  p_ticket_id uuid,
  p_assignee_id uuid,
  p_reason text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  ticket public.support_tickets%rowtype;
  previous_assignee uuid;
begin
  if not private.has_support_role(actor, array['support_manager']) then
    return jsonb_build_object('ok', false, 'code', 'support_manager_required');
  end if;
  if p_client_request_id is null
     or char_length(btrim(coalesce(p_reason, ''))) not between 8 and 500 then
    return jsonb_build_object('ok', false, 'code', 'assignment_reason_required');
  end if;
  select * into ticket from public.support_tickets where id = p_ticket_id for update;
  if ticket.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_found');
  end if;
  if ticket.priority = 'urgent_safety' then
    if not private.has_support_role(p_assignee_id, array['support_manager', 'safety_reviewer']) then
      return jsonb_build_object('ok', false, 'code', 'safety_reviewer_required');
    end if;
  elsif not private.has_support_role(
    p_assignee_id, array['support_agent', 'support_manager', 'safety_reviewer']
  ) then
    return jsonb_build_object('ok', false, 'code', 'assignee_support_role_required');
  end if;
  previous_assignee := ticket.assigned_support_user_id;
  update public.support_tickets
  set assigned_support_user_id = p_assignee_id, assigned_at = now()
  where id = ticket.id returning * into ticket;
  insert into public.support_ticket_audit_events (
    ticket_id, actor_id, event_type, safe_metadata
  ) values (
    ticket.id, actor, 'ticket_assigned',
    jsonb_build_object(
      'previous_assignee_id', previous_assignee,
      'assignee_id', p_assignee_id,
      'reason_code', 'manager_assignment',
      'request_id', p_client_request_id
    )
  );
  return jsonb_build_object('ok', true, 'ticket', to_jsonb(ticket));
end;
$$;

create or replace function public.support_staff_release_ticket(
  p_ticket_id uuid,
  p_reason text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  ticket public.support_tickets%rowtype;
begin
  if char_length(btrim(coalesce(p_reason, ''))) not between 8 and 500
     or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'release_reason_required');
  end if;
  select * into ticket from public.support_tickets where id = p_ticket_id for update;
  if ticket.id is null or (
    ticket.assigned_support_user_id <> actor
    and not private.has_support_role(actor, array['support_manager'])
  ) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  update public.support_tickets
  set assigned_support_user_id = null, assigned_at = null
  where id = ticket.id returning * into ticket;
  insert into public.support_ticket_audit_events (
    ticket_id, actor_id, event_type, safe_metadata
  ) values (
    ticket.id, actor, 'ticket_released',
    jsonb_build_object('reason_code', 'staff_release', 'request_id', p_client_request_id)
  );
  return jsonb_build_object('ok', true, 'ticket', to_jsonb(ticket));
end;
$$;

create or replace function public.support_staff_add_internal_note(
  p_ticket_id uuid,
  p_note_kind text,
  p_body text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  ticket public.support_tickets%rowtype;
  note public.support_internal_notes%rowtype;
  body_hash text;
begin
  if not private.has_support_role(
    actor, array['support_agent', 'support_manager', 'safety_reviewer']
  ) then
    return jsonb_build_object('ok', false, 'code', 'support_staff_role_required');
  end if;
  if p_note_kind not in ('case_note', 'handoff_summary', 'safety_review', 'appeal_review')
     or char_length(btrim(coalesce(p_body, ''))) not between 3 and 2000
     or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_internal_note');
  end if;
  select * into ticket from public.support_tickets where id = p_ticket_id;
  if ticket.id is null or not private.can_access_support_ticket(ticket.id, actor)
     or (
       ticket.assigned_support_user_id <> actor
       and not private.has_support_role(actor, array['support_manager'])
     ) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  body_hash := encode(extensions.digest(convert_to(btrim(p_body), 'utf8'), 'sha256'), 'hex');
  select * into note
  from public.support_internal_notes existing
  where existing.ticket_id = ticket.id
    and existing.author_id = actor
    and existing.client_request_id = p_client_request_id;
  if note.id is not null then
    if note.body_sha256 <> body_hash or note.note_kind <> p_note_kind then
      return jsonb_build_object('ok', false, 'code', 'request_payload_mismatch');
    end if;
    return jsonb_build_object('ok', true, 'replayed', true, 'note', to_jsonb(note));
  end if;
  insert into public.support_internal_notes (
    ticket_id, author_id, note_kind, body, body_sha256, client_request_id
  ) values (
    ticket.id, actor, p_note_kind, btrim(p_body), body_hash, p_client_request_id
  ) returning * into note;
  insert into public.support_ticket_audit_events (
    ticket_id, actor_id, event_type, safe_metadata
  ) values (
    ticket.id, actor, 'internal_note_added',
    jsonb_build_object('note_id', note.id, 'note_kind', note.note_kind)
  );
  return jsonb_build_object('ok', true, 'replayed', false, 'note', to_jsonb(note));
end;
$$;

create or replace function public.appeal_my_support_ticket(
  p_ticket_id uuid,
  p_reason text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  original public.support_tickets%rowtype;
  appeal public.support_tickets%rowtype;
  request public.support_ticket_appeals%rowtype;
  reason_hash text;
begin
  if actor is null or not public.is_profile_active(actor) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_client_request_id is null
     or char_length(btrim(coalesce(p_reason, ''))) not between 10 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'appeal_reason_required');
  end if;
  reason_hash := encode(extensions.digest(convert_to(btrim(p_reason), 'utf8'), 'sha256'), 'hex');
  select * into request
  from public.support_ticket_appeals existing
  where existing.requester_id = actor
    and existing.client_request_id = p_client_request_id;
  if request.id is not null then
    if request.original_ticket_id <> p_ticket_id or request.reason_sha256 <> reason_hash then
      return jsonb_build_object('ok', false, 'code', 'request_payload_mismatch');
    end if;
    select * into appeal from public.support_tickets where id = request.appeal_ticket_id;
    return jsonb_build_object('ok', true, 'replayed', true, 'ticket', to_jsonb(appeal));
  end if;
  if not private.support_take_rate_limit(actor, 'ticket_appeal', 2, 86400) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;
  select * into original
  from public.support_tickets ticket
  where ticket.id = p_ticket_id and ticket.requester_id = actor
  for update;
  if original.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_found');
  end if;
  if original.status not in ('resolved', 'closed') or original.case_kind = 'appeal' then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_appealable');
  end if;
  if exists (
    select 1 from public.support_ticket_appeals existing
    where existing.requester_id = actor and existing.original_ticket_id = original.id
  ) then
    return jsonb_build_object('ok', false, 'code', 'support_appeal_already_exists');
  end if;
  insert into public.support_tickets (
    requester_id, subject, status, category, priority, source,
    waiting_on_party, last_user_message_at, queue_key, case_kind,
    appeal_of_ticket_id, escalation_summary
  ) values (
    actor, left('Appeal of ' || original.case_number, 120), 'waiting_on_staff',
    original.category,
    case when original.priority = 'urgent_safety' then 'high' else 'normal' end,
    'human_support', 'staff', now(),
    case when original.queue_key = 'trust_safety' then 'trust_safety' else 'support' end,
    'appeal', original.id,
    jsonb_build_object(
      'source', 'user_appeal',
      'original_case_number', original.case_number,
      'requires_independent_review', true
    )
  ) returning * into appeal;
  insert into public.support_ticket_messages (
    ticket_id, sender_id, body, sender_kind, message_source, client_request_id
  ) values (
    appeal.id, actor, btrim(p_reason), 'user', 'human_support', p_client_request_id
  );
  insert into public.support_ticket_appeals (
    original_ticket_id, appeal_ticket_id, requester_id, client_request_id, reason_sha256
  ) values (
    original.id, appeal.id, actor, p_client_request_id, reason_hash
  );
  insert into public.support_ticket_audit_events (
    ticket_id, actor_id, event_type, safe_metadata
  ) values
    (original.id, actor, 'appeal_requested', jsonb_build_object('appeal_ticket_id', appeal.id)),
    (appeal.id, actor, 'appeal_created', jsonb_build_object('original_ticket_id', original.id));
  return jsonb_build_object('ok', true, 'replayed', false, 'ticket', to_jsonb(appeal));
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
  actor uuid := auth.uid();
  ticket public.support_tickets%rowtype;
  message public.support_ticket_messages%rowtype;
begin
  if not private.has_support_role(
    actor, array['support_agent', 'support_manager', 'safety_reviewer']
  ) then
    return jsonb_build_object('ok', false, 'code', 'support_staff_role_required');
  end if;
  select * into ticket from public.support_tickets where id = p_ticket_id for update;
  if ticket.id is null or not private.can_access_support_ticket(ticket.id, actor) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  if ticket.status = 'closed' then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_closed');
  end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 1 and 2000
     or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_message');
  end if;
  insert into public.support_ticket_messages (
    ticket_id, sender_id, body, sender_kind, message_source, client_request_id
  ) values (
    ticket.id, actor, btrim(p_message), 'support_staff', 'human_support', p_client_request_id
  )
  on conflict (ticket_id, sender_id, client_request_id)
  where client_request_id is not null do nothing
  returning * into message;
  if message.id is null then
    select * into message from public.support_ticket_messages existing
    where existing.ticket_id = ticket.id
      and existing.sender_id = actor
      and existing.client_request_id = p_client_request_id;
    if message.body <> btrim(p_message) then
      return jsonb_build_object('ok', false, 'code', 'request_payload_mismatch');
    end if;
    return jsonb_build_object('ok', true, 'replayed', true, 'message', to_jsonb(message));
  end if;
  update public.support_tickets set
    assigned_support_user_id = coalesce(assigned_support_user_id, actor),
    assigned_at = coalesce(assigned_at, now()),
    status = 'waiting_on_user',
    waiting_on_party = 'user',
    last_staff_message_at = now(),
    first_human_response_at = coalesce(first_human_response_at, now()),
    human_reviewed = true
  where id = ticket.id;
  update public.support_backlog_alerts
  set resolved_at = now()
  where ticket_id = ticket.id and resolved_at is null;
  insert into public.support_ticket_audit_events (
    ticket_id, actor_id, event_type, to_status
  ) values (ticket.id, actor, 'staff_reply_posted', 'waiting_on_user');
  return jsonb_build_object('ok', true, 'replayed', false, 'message', to_jsonb(message));
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
  actor uuid := auth.uid();
  ticket public.support_tickets%rowtype;
  old_status text;
begin
  if not private.has_support_role(
    actor, array['support_agent', 'support_manager', 'safety_reviewer']
  ) then
    return jsonb_build_object('ok', false, 'code', 'support_staff_role_required');
  end if;
  if p_status not in (
    'open', 'waiting_on_user', 'waiting_on_staff', 'under_review', 'resolved', 'closed'
  ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_status');
  end if;
  select * into ticket from public.support_tickets where id = p_ticket_id for update;
  if ticket.id is null or not private.can_access_support_ticket(ticket.id, actor)
     or (
       ticket.assigned_support_user_id <> actor
       and not private.has_support_role(actor, array['support_manager'])
     ) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  if p_status in ('resolved', 'closed')
     and char_length(btrim(coalesce(p_reason, ''))) < 8 then
    return jsonb_build_object('ok', false, 'code', 'closure_reason_required');
  end if;
  old_status := ticket.status;
  update public.support_tickets set
    status = p_status,
    waiting_on_party = case p_status
      when 'waiting_on_user' then 'user'
      when 'waiting_on_staff' then 'staff'
      else 'none'
    end,
    resolution_code = case
      when p_status in ('resolved', 'closed') then left(p_resolution_code, 80)
      else resolution_code
    end,
    closed_reason = case
      when p_status = 'closed' then left(btrim(p_reason), 500)
      else closed_reason
    end,
    closed_at = case when p_status = 'closed' then now() else null end,
    human_reviewed = true
  where id = ticket.id returning * into ticket;
  if p_status in ('resolved', 'closed') then
    update public.support_backlog_alerts
    set resolved_at = now()
    where ticket_id = ticket.id and resolved_at is null;
  end if;
  insert into public.support_ticket_audit_events (
    ticket_id, actor_id, event_type, from_status, to_status, safe_metadata
  ) values (
    ticket.id, actor, 'status_changed', old_status, ticket.status,
    jsonb_build_object('resolution_code', ticket.resolution_code)
  );
  return jsonb_build_object('ok', true, 'ticket', to_jsonb(ticket));
end;
$$;

create or replace function public.support_staff_list_queue(
  p_status text default null,
  p_unassigned_only boolean default false,
  p_limit integer default 50
)
returns setof public.support_tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if not private.has_support_role(
    actor, array['support_agent', 'support_manager', 'safety_reviewer']
  ) then return; end if;
  insert into public.support_action_audit (
    actor_id, action, authorization_basis, correlation_id, safe_metadata
  ) values (
    actor, 'staff_ticket_queue_read', 'explicit_support_role', gen_random_uuid(),
    jsonb_build_object(
      'status_filter', p_status,
      'unassigned_only', coalesce(p_unassigned_only, false),
      'limit', least(greatest(coalesce(p_limit, 50), 1), 100)
    )
  );
  return query
  select ticket.*
  from public.support_tickets ticket
  where private.can_access_support_ticket(ticket.id, actor)
    and (p_status is null or ticket.status = p_status)
    and (not coalesce(p_unassigned_only, false) or ticket.assigned_support_user_id is null)
  order by
    case ticket.priority
      when 'urgent_safety' then 0 when 'high' then 1 when 'normal' then 2 else 3
    end,
    ticket.first_response_due_at nulls last,
    coalesce(ticket.last_user_message_at, ticket.created_at)
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
end;
$$;

create or replace function public.support_staff_get_ticket_thread(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  ticket public.support_tickets%rowtype;
  messages jsonb;
  evidence jsonb;
  attachments jsonb;
  notes jsonb;
  audit_history jsonb;
  trace_id uuid := gen_random_uuid();
begin
  if not private.has_support_role(
    actor, array['support_agent', 'support_manager', 'safety_reviewer']
  ) then
    return jsonb_build_object('ok', false, 'code', 'support_staff_role_required');
  end if;
  select * into ticket from public.support_tickets where id = p_ticket_id;
  if ticket.id is null or not private.can_access_support_ticket(ticket.id, actor) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  select coalesce(jsonb_agg(to_jsonb(item) order by item.created_at), '[]'::jsonb)
  into messages from public.support_ticket_messages item where item.ticket_id = ticket.id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', item.id, 'category', item.evidence_category, 'status', item.status,
    'processed_byte_size', item.processed_byte_size, 'created_at', item.created_at,
    'retention_delete_at', item.retention_delete_at,
    'preservation_hold', item.preservation_hold, 'review_status', item.review_status
  ) order by item.created_at), '[]'::jsonb)
  into evidence from public.support_evidence_attachments item
  where item.ticket_id = ticket.id and item.status <> 'deleted';
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', item.id, 'content_type', item.content_type, 'byte_size', item.byte_size,
    'status', item.status, 'created_at', item.created_at
  ) order by item.created_at), '[]'::jsonb)
  into attachments from public.support_attachments item
  where item.ticket_id = ticket.id and item.status <> 'deleted';
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', item.id, 'author_id', item.author_id, 'note_kind', item.note_kind,
    'body', item.body, 'created_at', item.created_at
  ) order by item.created_at), '[]'::jsonb)
  into notes from public.support_internal_notes item where item.ticket_id = ticket.id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', item.id, 'event_type', item.event_type, 'actor_id', item.actor_id,
    'from_status', item.from_status, 'to_status', item.to_status,
    'safe_metadata', item.safe_metadata, 'created_at', item.created_at
  ) order by item.created_at), '[]'::jsonb)
  into audit_history from public.support_ticket_audit_events item
  where item.ticket_id = ticket.id;
  insert into public.support_action_audit (
    actor_id, ticket_id, action, authorization_basis,
    target_type, target_id, correlation_id
  ) values (
    actor, ticket.id, 'staff_ticket_thread_read', 'explicit_support_role',
    'support_ticket', ticket.id, trace_id
  );
  insert into public.support_ticket_audit_events (
    ticket_id, actor_id, event_type, safe_metadata
  ) values (
    ticket.id, actor, 'staff_thread_read', jsonb_build_object('correlation_id', trace_id)
  );
  return jsonb_build_object(
    'ok', true, 'ticket', to_jsonb(ticket), 'messages', messages,
    'evidence', evidence, 'attachments', attachments,
    'internal_notes', notes, 'audit_history', audit_history
  );
end;
$$;

create or replace function public.support_process_backlog_aging(p_limit integer default 500)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  processed integer := 0;
  created integer := 0;
  inserted_count integer := 0;
begin
  if coalesce(auth.role(), '') not in ('service_role')
     and current_user not in ('postgres', 'supabase_admin') then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  with candidates as (
    select ticket.id
    from public.support_tickets ticket
    where ticket.status not in ('resolved', 'closed')
      and ticket.first_human_response_at is null
    order by ticket.first_response_due_at
    limit least(greatest(coalesce(p_limit, 500), 1), 2000)
  )
  update public.support_tickets ticket
  set last_aging_evaluated_at = now()
  from candidates where candidates.id = ticket.id;
  get diagnostics processed = row_count;

  insert into public.support_backlog_alerts (
    ticket_id, alert_type, severity, target_at, safe_metadata
  )
  select ticket.id, 'first_response_overdue',
    case when ticket.priority = 'high' then 'high' else 'warning' end,
    ticket.first_response_due_at,
    jsonb_build_object('priority', ticket.priority, 'queue', ticket.queue_key)
  from public.support_tickets ticket
  where ticket.status not in ('resolved', 'closed')
    and ticket.first_human_response_at is null
    and ticket.first_response_due_at <= now()
  on conflict (ticket_id, alert_type) where resolved_at is null do nothing;
  get diagnostics created = row_count;

  insert into public.support_backlog_alerts (
    ticket_id, alert_type, severity, target_at, safe_metadata
  )
  select ticket.id, 'urgent_escalation_overdue', 'urgent',
    ticket.urgent_escalation_due_at,
    jsonb_build_object('priority', ticket.priority, 'queue', ticket.queue_key)
  from public.support_tickets ticket
  where ticket.status not in ('resolved', 'closed')
    and ticket.first_human_response_at is null
    and ticket.priority = 'urgent_safety'
    and ticket.urgent_escalation_due_at <= now()
  on conflict (ticket_id, alert_type) where resolved_at is null do nothing;
  get diagnostics inserted_count = row_count;
  created := created + inserted_count;

  insert into public.support_backlog_alerts (
    ticket_id, alert_type, severity, target_at, safe_metadata
  )
  select ticket.id, 'waiting_staff_24h', 'high',
    coalesce(ticket.last_user_message_at, ticket.created_at) + interval '24 hours',
    jsonb_build_object('priority', ticket.priority, 'queue', ticket.queue_key)
  from public.support_tickets ticket
  where ticket.status in ('open', 'waiting', 'waiting_on_staff', 'under_review')
    and coalesce(ticket.last_user_message_at, ticket.created_at) <= now() - interval '24 hours'
  on conflict (ticket_id, alert_type) where resolved_at is null do nothing;
  get diagnostics inserted_count = row_count;
  created := created + inserted_count;

  update public.support_backlog_alerts alert
  set resolved_at = now()
  from public.support_tickets ticket
  where ticket.id = alert.ticket_id
    and alert.resolved_at is null
    and (ticket.first_human_response_at is not null or ticket.status in ('resolved', 'closed'));
  return jsonb_build_object('ok', true, 'tickets_evaluated', processed, 'alerts_created', created);
end;
$$;

create or replace function public.support_staff_operations_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  policy jsonb;
  status_counts jsonb;
  priority_counts jsonb;
  active_alerts jsonb;
begin
  if not private.has_support_role(actor, array['support_manager']) then
    return jsonb_build_object('ok', false, 'code', 'support_manager_required');
  end if;
  select to_jsonb(item) - 'updated_by' into policy
  from public.support_operation_policies item where singleton = true;
  select coalesce(jsonb_object_agg(status, count), '{}'::jsonb) into status_counts
  from (select status, count(*)::integer count from public.support_tickets group by status) grouped;
  select coalesce(jsonb_object_agg(priority, count), '{}'::jsonb) into priority_counts
  from (select priority, count(*)::integer count from public.support_tickets group by priority) grouped;
  select coalesce(jsonb_object_agg(severity, count), '{}'::jsonb) into active_alerts
  from (
    select severity, count(*)::integer count
    from public.support_backlog_alerts where resolved_at is null group by severity
  ) grouped;
  insert into public.support_action_audit (
    actor_id, action, authorization_basis, correlation_id
  ) values (actor, 'support_operations_metrics_read', 'support_manager', gen_random_uuid());
  return jsonb_build_object(
    'ok', true, 'privacy_scope', 'aggregate_counts_only',
    'policy', policy, 'status_counts', status_counts,
    'priority_counts', priority_counts, 'active_alerts', active_alerts
  );
end;
$$;

do $$
declare
  existing_job bigint;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    select jobid into existing_job from cron.job
    where jobname = 'mort-support-backlog-aging' limit 1;
    if existing_job is not null then perform cron.unschedule(existing_job); end if;
    perform cron.schedule(
      'mort-support-backlog-aging',
      '*/5 * * * *',
      'select public.support_process_backlog_aging(500);'
    );
  end if;
end;
$$;

do $$
declare
  signature text;
begin
  foreach signature in array array[
    'public.support_get_service_status()',
    'public.support_staff_claim_ticket(uuid,uuid)',
    'public.support_manager_assign_ticket(uuid,uuid,text,uuid)',
    'public.support_staff_release_ticket(uuid,text,uuid)',
    'public.support_staff_add_internal_note(uuid,text,text,uuid)',
    'public.appeal_my_support_ticket(uuid,text,uuid)',
    'public.support_staff_post_reply(uuid,text,uuid)',
    'public.support_staff_change_status(uuid,text,text,text)',
    'public.support_staff_list_queue(text,boolean,integer)',
    'public.support_staff_get_ticket_thread(uuid)',
    'public.support_process_backlog_aging(integer)',
    'public.support_staff_operations_dashboard()'
  ] loop
    execute format('revoke all on function %s from public, anon', signature);
  end loop;
end;
$$;

grant execute on function public.support_get_service_status() to authenticated, service_role;
grant execute on function public.support_staff_claim_ticket(uuid, uuid) to authenticated, service_role;
grant execute on function public.support_manager_assign_ticket(uuid, uuid, text, uuid) to authenticated, service_role;
grant execute on function public.support_staff_release_ticket(uuid, text, uuid) to authenticated, service_role;
grant execute on function public.support_staff_add_internal_note(uuid, text, text, uuid) to authenticated, service_role;
grant execute on function public.appeal_my_support_ticket(uuid, text, uuid) to authenticated, service_role;
grant execute on function public.support_staff_post_reply(uuid, text, uuid) to authenticated, service_role;
grant execute on function public.support_staff_change_status(uuid, text, text, text) to authenticated, service_role;
grant execute on function public.support_staff_list_queue(text, boolean, integer) to authenticated, service_role;
grant execute on function public.support_staff_get_ticket_thread(uuid) to authenticated, service_role;
revoke all on function public.support_process_backlog_aging(integer) from authenticated;
grant execute on function public.support_process_backlog_aging(integer) to service_role;
grant execute on function public.support_staff_operations_dashboard() to authenticated, service_role;
