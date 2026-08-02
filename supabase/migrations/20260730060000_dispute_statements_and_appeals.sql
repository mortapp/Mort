-- Preserve party statements as append-only history and provide a real,
-- human-reviewed payment-dispute appeal. These functions make platform
-- recommendations only and never execute, release, refund, or transfer money.

create table if not exists public.payment_dispute_statements (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  author_id uuid not null references public.profiles(id) on delete restrict,
  author_role text not null check (author_role in ('worker', 'poster')),
  statement text not null check (char_length(btrim(statement)) between 10 and 4000),
  client_request_id uuid not null,
  created_at timestamptz not null default now(),
  unique (author_id, client_request_id)
);

create table if not exists public.payment_dispute_appeals (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  challenged_decision_id uuid not null references public.payment_dispute_decisions(id) on delete restrict,
  appellant_id uuid not null references public.profiles(id) on delete restrict,
  prior_dispute_status text not null,
  reason text not null check (char_length(btrim(reason)) between 20 and 4000),
  status text not null default 'pending'
    check (status in ('pending', 'under_review', 'upheld', 'modified', 'overturned')),
  reviewed_by uuid references public.profiles(id) on delete restrict,
  review_rationale text check (
    review_rationale is null or char_length(btrim(review_rationale)) between 20 and 4000
  ),
  client_request_id uuid not null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  unique (appellant_id, client_request_id),
  unique (dispute_id, appellant_id)
);

create index if not exists payment_dispute_statements_dispute_created_idx
on public.payment_dispute_statements(dispute_id, created_at, id);
create index if not exists payment_dispute_appeals_dispute_status_idx
on public.payment_dispute_appeals(dispute_id, status, created_at);

insert into public.payment_dispute_statements(
  dispute_id, author_id, author_role, statement, client_request_id, created_at
)
select dispute.id, dispute.worker_id, 'worker', dispute.worker_statement,
       gen_random_uuid(), dispute.opened_at
from public.payment_disputes dispute
where not exists (
  select 1 from public.payment_dispute_statements statement
  where statement.dispute_id = dispute.id and statement.author_role = 'worker'
);

insert into public.payment_dispute_statements(
  dispute_id, author_id, author_role, statement, client_request_id, created_at
)
select dispute.id, dispute.poster_id, 'poster', dispute.poster_statement,
       gen_random_uuid(), coalesce(dispute.updated_at, dispute.opened_at)
from public.payment_disputes dispute
where dispute.poster_statement is not null
  and not exists (
    select 1 from public.payment_dispute_statements statement
    where statement.dispute_id = dispute.id and statement.author_role = 'poster'
  );

alter table public.payment_dispute_statements enable row level security;
alter table public.payment_dispute_statements force row level security;
alter table public.payment_dispute_appeals enable row level security;
alter table public.payment_dispute_appeals force row level security;

create policy payment_dispute_statements_participant_or_assigned_select
on public.payment_dispute_statements for select to authenticated
using (
  exists (
    select 1 from public.payment_disputes dispute
    where dispute.id = payment_dispute_statements.dispute_id
      and (
        auth.uid() in (dispute.worker_id, dispute.poster_id)
        or private.is_assigned_payment_dispute_reviewer(dispute.id, auth.uid())
      )
  )
);

create policy payment_dispute_appeals_participant_or_assigned_select
on public.payment_dispute_appeals for select to authenticated
using (
  exists (
    select 1 from public.payment_disputes dispute
    where dispute.id = payment_dispute_appeals.dispute_id
      and (
        auth.uid() in (dispute.worker_id, dispute.poster_id)
        or private.is_assigned_payment_dispute_reviewer(dispute.id, auth.uid())
      )
  )
);

revoke all on public.payment_dispute_statements, public.payment_dispute_appeals
from public, anon, authenticated;
grant select on public.payment_dispute_statements, public.payment_dispute_appeals
to authenticated;
grant all on public.payment_dispute_statements, public.payment_dispute_appeals
to service_role;

create or replace function private.prevent_dispute_history_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(current_setting('mort.internal_update', true), '') = 'true' then
    return old;
  end if;
  raise exception 'immutable_dispute_history';
end;
$$;

drop trigger if exists payment_dispute_statements_immutable on public.payment_dispute_statements;
create trigger payment_dispute_statements_immutable
before update or delete on public.payment_dispute_statements
for each row execute function private.prevent_dispute_history_mutation();
drop trigger if exists payment_dispute_timeline_immutable on public.payment_dispute_timeline;
create trigger payment_dispute_timeline_immutable
before update or delete on public.payment_dispute_timeline
for each row execute function private.prevent_dispute_history_mutation();
drop trigger if exists payment_dispute_decisions_immutable on public.payment_dispute_decisions;
create trigger payment_dispute_decisions_immutable
before update or delete on public.payment_dispute_decisions
for each row execute function private.prevent_dispute_history_mutation();

revoke all on function private.prevent_dispute_history_mutation()
from public, anon, authenticated;
grant execute on function private.prevent_dispute_history_mutation() to service_role;

create or replace function public.submit_payment_dispute_statement_v2(
  p_dispute_id uuid,
  p_statement text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dispute public.payment_disputes%rowtype;
  v_existing public.payment_dispute_statements%rowtype;
  v_statement public.payment_dispute_statements%rowtype;
  v_role text;
  v_other_party uuid;
  v_text text := btrim(coalesce(p_statement, ''));
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  if char_length(v_text) not between 10 and 4000 then
    return jsonb_build_object('ok', false, 'code', 'statement_required');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text || ':' || p_client_request_id::text, 0)
  );
  select * into v_existing
  from public.payment_dispute_statements statement
  where statement.author_id = auth.uid()
    and statement.client_request_id = p_client_request_id;
  if found then
    if v_existing.dispute_id <> p_dispute_id or v_existing.statement <> v_text then
      return jsonb_build_object('ok', false, 'code', 'dispute_statement_request_mismatch');
    end if;
    return jsonb_build_object('ok', true, 'replayed', true, 'statement_id', v_existing.id);
  end if;
  select * into v_dispute from public.payment_disputes where id = p_dispute_id for update;
  if v_dispute.id is null or auth.uid() not in (v_dispute.worker_id, v_dispute.poster_id) then
    return jsonb_build_object('ok', false, 'code', 'dispute_party_required');
  end if;
  v_role := case when auth.uid() = v_dispute.worker_id then 'worker' else 'poster' end;
  v_other_party := case when v_role = 'worker' then v_dispute.poster_id else v_dispute.worker_id end;
  insert into public.payment_dispute_statements(
    dispute_id, author_id, author_role, statement, client_request_id
  ) values (
    v_dispute.id, auth.uid(), v_role, v_text, p_client_request_id
  ) returning * into v_statement;
  if v_role = 'worker' then
    update public.payment_disputes
    set worker_statement = v_text, status = case
      when status = 'resolved_more_evidence' then 'mediation_review'
      else 'awaiting_poster'
    end, updated_at = now()
    where id = v_dispute.id;
  else
    update public.payment_disputes
    set poster_statement = v_text, status = 'mediation_review', updated_at = now()
    where id = v_dispute.id;
  end if;
  insert into public.payment_dispute_timeline(
    dispute_id, actor_id, event_type, event_summary, private_metadata
  ) values (
    v_dispute.id, auth.uid(), 'party_statement_submitted',
    'A contract party submitted a private factual statement for human review.',
    jsonb_build_object('statement_id', v_statement.id, 'author_role', v_role)
  );
  perform public.enqueue_notification(
    v_other_party,
    'A statement was added to a private job dispute',
    'Review the dispute timeline in MORT. No platform or payment decision was made by this update.',
    jsonb_build_object('route', '/disputes/' || v_dispute.id::text, 'disputeId', v_dispute.id)
  );
  return jsonb_build_object('ok', true, 'replayed', false, 'statement_id', v_statement.id);
end;
$$;

create or replace function public.submit_payment_dispute_appeal(
  p_dispute_id uuid,
  p_reason text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dispute public.payment_disputes%rowtype;
  v_decision public.payment_dispute_decisions%rowtype;
  v_appeal public.payment_dispute_appeals%rowtype;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_other_party uuid;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  if char_length(v_reason) not between 20 and 4000 then
    return jsonb_build_object('ok', false, 'code', 'appeal_reason_required');
  end if;
  select * into v_appeal
  from public.payment_dispute_appeals appeal
  where appeal.appellant_id = auth.uid()
    and appeal.client_request_id = p_client_request_id;
  if found then
    if v_appeal.dispute_id <> p_dispute_id or v_appeal.reason <> v_reason then
      return jsonb_build_object('ok', false, 'code', 'dispute_appeal_request_mismatch');
    end if;
    return jsonb_build_object('ok', true, 'replayed', true, 'appeal_id', v_appeal.id, 'status', v_appeal.status, 'money_moved', false);
  end if;
  select * into v_dispute from public.payment_disputes where id = p_dispute_id for update;
  if v_dispute.id is null or auth.uid() not in (v_dispute.worker_id, v_dispute.poster_id) then
    return jsonb_build_object('ok', false, 'code', 'dispute_party_required');
  end if;
  if v_dispute.status not in (
    'resolved_payment_recommended', 'resolved_partial_payment_recommended',
    'resolved_more_evidence', 'resolved_no_platform_determination',
    'closed_confirmed_paid'
  ) then return jsonb_build_object('ok', false, 'code', 'appeal_not_available'); end if;
  select * into v_decision
  from public.payment_dispute_decisions decision
  where decision.dispute_id = v_dispute.id and decision.appeal_available
  order by decision.decided_at desc limit 1;
  if v_decision.id is null then return jsonb_build_object('ok', false, 'code', 'appealable_decision_required'); end if;
  if exists (
    select 1 from public.payment_dispute_appeals appeal
    where appeal.dispute_id = v_dispute.id and appeal.appellant_id = auth.uid()
  ) then return jsonb_build_object('ok', false, 'code', 'appeal_already_submitted'); end if;
  insert into public.payment_dispute_appeals(
    dispute_id, challenged_decision_id, appellant_id, prior_dispute_status,
    reason, client_request_id
  ) values (
    v_dispute.id, v_decision.id, auth.uid(), v_dispute.status,
    v_reason, p_client_request_id
  ) returning * into v_appeal;
  update public.payment_disputes
  set status = 'appeal_pending', closed_at = null, updated_at = now()
  where id = v_dispute.id;
  insert into public.payment_dispute_timeline(
    dispute_id, actor_id, event_type, event_summary, private_metadata
  ) values (
    v_dispute.id, auth.uid(), 'appeal_submitted',
    'A contract party requested a separate human appeal review. No payment action occurred.',
    jsonb_build_object('appeal_id', v_appeal.id)
  );
  v_other_party := case when auth.uid() = v_dispute.worker_id then v_dispute.poster_id else v_dispute.worker_id end;
  perform public.enqueue_notification(
    v_other_party,
    'A private dispute appeal was submitted',
    'A separate human review is pending. No payment action occurred.',
    jsonb_build_object('route', '/disputes/' || v_dispute.id::text, 'disputeId', v_dispute.id)
  );
  return jsonb_build_object('ok', true, 'replayed', false, 'appeal_id', v_appeal.id, 'status', v_appeal.status, 'money_moved', false);
end;
$$;

create or replace function public.review_payment_dispute_appeal(
  p_appeal_id uuid,
  p_outcome text,
  p_rationale text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appeal public.payment_dispute_appeals%rowtype;
  v_dispute public.payment_disputes%rowtype;
  v_status text;
begin
  select * into v_appeal
  from public.payment_dispute_appeals where id = p_appeal_id for update;
  if v_appeal.id is null then return jsonb_build_object('ok', false, 'code', 'payment_dispute_appeal_not_found'); end if;
  select * into v_dispute from public.payment_disputes where id = v_appeal.dispute_id for update;
  if not private.is_assigned_payment_dispute_reviewer(v_dispute.id, auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'assigned_ready_reviewer_required');
  end if;
  if exists (
    select 1 from public.payment_dispute_decisions decision
    where decision.id = v_appeal.challenged_decision_id
      and decision.reviewer_id = auth.uid()
  ) then return jsonb_build_object('ok', false, 'code', 'independent_appeal_reviewer_required'); end if;
  if v_appeal.status not in ('pending', 'under_review') then
    return jsonb_build_object('ok', false, 'code', 'appeal_already_reviewed');
  end if;
  if p_outcome not in ('upheld', 'modified', 'overturned') then
    return jsonb_build_object('ok', false, 'code', 'unsupported_appeal_outcome');
  end if;
  if char_length(btrim(coalesce(p_rationale, ''))) not between 20 and 4000 then
    return jsonb_build_object('ok', false, 'code', 'substantive_rationale_required');
  end if;
  v_status := case p_outcome
    when 'upheld' then v_appeal.prior_dispute_status
    when 'modified' then 'resolved_more_evidence'
    else 'resolved_no_platform_determination'
  end;
  update public.payment_dispute_appeals
  set status = p_outcome, reviewed_by = auth.uid(),
      review_rationale = btrim(p_rationale), reviewed_at = now()
  where id = v_appeal.id;
  update public.payment_disputes
  set status = v_status,
      closed_at = case when v_status = 'resolved_more_evidence' then null else now() end,
      updated_at = now()
  where id = v_dispute.id;
  if p_outcome = 'overturned' then
    update public.poster_payment_restrictions
    set status = 'overturned', appeal_status = 'overturned',
        lifted_by = auth.uid(), lifted_at = now()
    where dispute_id = v_dispute.id and status = 'active';
  elsif p_outcome = 'upheld' then
    update public.poster_payment_restrictions
    set appeal_status = 'upheld'
    where dispute_id = v_dispute.id and status = 'active';
  end if;
  insert into public.payment_dispute_timeline(
    dispute_id, actor_id, event_type, event_summary, private_metadata
  ) values (
    v_dispute.id, auth.uid(), 'appeal_reviewed',
    'An independent assigned reviewer completed the private appeal. This is not a court judgment or criminal finding.',
    jsonb_build_object('appeal_id', v_appeal.id, 'outcome', p_outcome)
  );
  perform public.enqueue_notification(
    v_dispute.worker_id,
    'Private dispute appeal updated',
    'The appeal review is complete. Open the private timeline for the platform outcome.',
    jsonb_build_object('route', '/disputes/' || v_dispute.id::text, 'disputeId', v_dispute.id)
  );
  perform public.enqueue_notification(
    v_dispute.poster_id,
    'Private dispute appeal updated',
    'The appeal review is complete. Open the private timeline for the platform outcome.',
    jsonb_build_object('route', '/disputes/' || v_dispute.id::text, 'disputeId', v_dispute.id)
  );
  return jsonb_build_object(
    'ok', true, 'appeal_id', v_appeal.id, 'appeal_status', p_outcome,
    'dispute_status', v_status, 'money_moved', false,
    'court_judgment', false, 'criminal_finding', false
  );
end;
$$;

revoke all on function public.submit_payment_dispute_statement(uuid,text)
from public, anon, authenticated;
grant execute on function public.submit_payment_dispute_statement(uuid,text) to service_role;
revoke all on function public.submit_payment_dispute_statement_v2(uuid,text,uuid)
from public, anon;
grant execute on function public.submit_payment_dispute_statement_v2(uuid,text,uuid)
to authenticated, service_role;
revoke all on function public.submit_payment_dispute_appeal(uuid,text,uuid)
from public, anon;
grant execute on function public.submit_payment_dispute_appeal(uuid,text,uuid)
to authenticated, service_role;
revoke all on function public.review_payment_dispute_appeal(uuid,text,text)
from public, anon;
grant execute on function public.review_payment_dispute_appeal(uuid,text,text)
to authenticated, service_role;

comment on table public.payment_dispute_statements is
'Append-only party statement history. Current snapshot columns remain for compact UI summaries.';
comment on table public.payment_dispute_appeals is
'Human-reviewed appeal records. Appeal functions never execute a payment operation.';
