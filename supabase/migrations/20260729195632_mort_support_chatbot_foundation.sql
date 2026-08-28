-- MORT Support Assistant foundation.
-- Additive only: the existing human support ticket and evidence systems remain
-- authoritative. Provider secrets and system prompts never live in Postgres.

create table public.support_conversations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  ticket_id uuid references public.support_tickets(id) on delete set null,
  title text not null default 'MORT Support conversation',
  status text not null default 'active',
  channel text not null default 'assistant',
  response_mode text not null default 'deterministic',
  highest_safety_level smallint not null default 0,
  client_request_id uuid not null,
  last_message_at timestamptz not null default now(),
  retention_until timestamptz not null default (now() + interval '30 days'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_conversations_title_check
    check (char_length(btrim(title)) between 3 and 120),
  constraint support_conversations_status_check
    check (status in ('active', 'handed_off', 'closed', 'deleted')),
  constraint support_conversations_channel_check
    check (channel in ('assistant', 'human_support')),
  constraint support_conversations_mode_check
    check (response_mode in ('deterministic', 'anthropic', 'disabled', 'staff')),
  constraint support_conversations_safety_check
    check (highest_safety_level between 0 and 3),
  unique (owner_id, client_request_id)
);

create table public.support_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.support_conversations(id) on delete cascade,
  author_id uuid references public.profiles(id) on delete set null,
  role text not null,
  content text not null,
  intent text not null default 'general_support',
  safety_level smallint not null default 0,
  response_mode text not null default 'deterministic',
  cited_document_ids uuid[] not null default '{}'::uuid[],
  client_request_id uuid,
  staff_visible_only boolean not null default false,
  created_at timestamptz not null default now(),
  constraint support_messages_role_check
    check (role in ('user', 'assistant', 'system', 'support_staff', 'tool')),
  constraint support_messages_content_check
    check (char_length(content) between 1 and 4000),
  constraint support_messages_intent_check
    check (char_length(intent) between 3 and 80),
  constraint support_messages_safety_check
    check (safety_level between 0 and 3),
  constraint support_messages_mode_check
    check (response_mode in ('deterministic', 'anthropic', 'disabled', 'staff')),
  constraint support_messages_author_check
    check ((role in ('assistant', 'system', 'tool')) or author_id is not null)
);

create unique index support_messages_request_idx
on public.support_messages(conversation_id, author_id, client_request_id)
where client_request_id is not null;
create unique index support_messages_assistant_request_idx
on public.support_messages(conversation_id, client_request_id)
where client_request_id is not null and role = 'assistant';

create table public.support_ticket_events (
  id bigint generated always as identity primary key,
  ticket_id uuid not null references public.support_tickets(id) on delete restrict,
  conversation_id uuid references public.support_conversations(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  correlation_id uuid not null,
  safe_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint support_ticket_events_type_check
    check (char_length(event_type) between 3 and 80),
  constraint support_ticket_events_metadata_check
    check (jsonb_typeof(safe_metadata) = 'object')
);

create table public.support_attachments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  conversation_id uuid references public.support_conversations(id) on delete restrict,
  ticket_id uuid references public.support_tickets(id) on delete restrict,
  bucket_id text not null default 'support-attachments',
  object_path text not null unique,
  original_extension text not null,
  content_type text not null,
  byte_size integer not null,
  sha256 text not null,
  purpose text not null,
  status text not null default 'authorized',
  scan_status text not null default 'pending',
  client_request_id uuid not null,
  upload_authorization_expires_at timestamptz not null default (now() + interval '15 minutes'),
  retention_delete_at timestamptz not null default (now() + interval '90 days'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_attachments_subject_check
    check (conversation_id is not null or ticket_id is not null),
  constraint support_attachments_bucket_check
    check (bucket_id = 'support-attachments'),
  constraint support_attachments_extension_check
    check (original_extension in ('jpg', 'jpeg', 'png', 'webp', 'pdf')),
  constraint support_attachments_content_type_check
    check (content_type in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
  constraint support_attachments_size_check
    check (byte_size between 1 and 5242880),
  constraint support_attachments_sha_check
    check (sha256 ~ '^[a-f0-9]{64}$'),
  constraint support_attachments_purpose_check
    check (char_length(btrim(purpose)) between 3 and 160),
  constraint support_attachments_status_check
    check (status in ('authorized', 'uploaded', 'submitted', 'quarantined', 'rejected', 'deleted')),
  constraint support_attachments_scan_check
    check (scan_status in ('pending', 'metadata_passed', 'rejected', 'not_available')),
  unique (owner_id, client_request_id)
);

create table public.support_kb_documents (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  summary text not null,
  content text not null,
  source_url text,
  navigation_route text,
  document_type text not null default 'help',
  status text not null default 'draft',
  audience text[] not null default array['all']::text[],
  version text not null,
  effective_at date not null default current_date,
  review_due_at date not null,
  approved_by uuid references public.profiles(id) on delete set null,
  approved_at timestamptz,
  checksum_sha256 text,
  search_vector tsvector generated always as (
    to_tsvector('english'::regconfig,
      coalesce(title, '') || ' ' || coalesce(summary, '') || ' ' || coalesce(content, ''))
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_kb_documents_slug_check
    check (slug ~ '^[a-z0-9][a-z0-9-]{2,79}$'),
  constraint support_kb_documents_title_check
    check (char_length(btrim(title)) between 3 and 160),
  constraint support_kb_documents_summary_check
    check (char_length(btrim(summary)) between 10 and 500),
  constraint support_kb_documents_content_check
    check (char_length(btrim(content)) between 20 and 12000),
  constraint support_kb_documents_source_check
    check (source_url is null or source_url ~ '^https://'),
  constraint support_kb_documents_route_check
    check (navigation_route is null or navigation_route ~ '^/'),
  constraint support_kb_documents_type_check
    check (document_type in ('help', 'policy', 'safety', 'privacy', 'account', 'billing')),
  constraint support_kb_documents_status_check
    check (status in ('draft', 'approved', 'published', 'retired')),
  constraint support_kb_documents_approval_check
    check ((status in ('draft', 'retired')) or approved_at is not null),
  constraint support_kb_documents_checksum_check
    check (checksum_sha256 is null or checksum_sha256 ~ '^[a-f0-9]{64}$')
);

create table public.support_kb_chunks (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.support_kb_documents(id) on delete cascade,
  chunk_index integer not null,
  content text not null,
  token_estimate integer not null default 0,
  search_vector tsvector generated always as (
    to_tsvector('english'::regconfig, coalesce(content, ''))
  ) stored,
  created_at timestamptz not null default now(),
  constraint support_kb_chunks_index_check check (chunk_index between 0 and 999),
  constraint support_kb_chunks_content_check check (char_length(content) between 20 and 4000),
  constraint support_kb_chunks_token_check check (token_estimate between 0 and 2000),
  unique (document_id, chunk_index)
);

create table public.support_ai_feedback (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  conversation_id uuid not null references public.support_conversations(id) on delete cascade,
  message_id uuid not null references public.support_messages(id) on delete cascade,
  rating text not null,
  comment text,
  created_at timestamptz not null default now(),
  constraint support_ai_feedback_rating_check
    check (rating in ('helpful', 'not_helpful', 'unsafe')),
  constraint support_ai_feedback_comment_check
    check (comment is null or char_length(btrim(comment)) between 3 and 500),
  unique (owner_id, message_id)
);

create table public.support_ai_incidents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  conversation_id uuid references public.support_conversations(id) on delete set null,
  message_id uuid references public.support_messages(id) on delete set null,
  category text not null,
  severity smallint not null,
  status text not null default 'open',
  requires_human_review boolean not null default true,
  redacted_excerpt text,
  correlation_id uuid not null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  constraint support_ai_incidents_category_check
    check (char_length(category) between 3 and 80),
  constraint support_ai_incidents_severity_check check (severity between 1 and 3),
  constraint support_ai_incidents_status_check
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  constraint support_ai_incidents_excerpt_check
    check (redacted_excerpt is null or char_length(redacted_excerpt) <= 240)
);

create table public.support_ai_evaluations (
  id bigint generated always as identity primary key,
  run_id uuid not null,
  case_key text not null,
  suite text not null,
  provider_mode text not null,
  expected_outcome text not null,
  actual_outcome text not null,
  passed boolean not null,
  score numeric(5,4),
  safe_details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint support_ai_eval_case_check check (case_key ~ '^[a-z0-9][a-z0-9_-]{2,79}$'),
  constraint support_ai_eval_provider_check
    check (provider_mode in ('deterministic', 'anthropic', 'disabled', 'mock')),
  constraint support_ai_eval_score_check check (score is null or score between 0 and 1),
  constraint support_ai_eval_details_check check (jsonb_typeof(safe_details) = 'object'),
  unique (run_id, case_key)
);

create table public.support_action_audit (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  conversation_id uuid references public.support_conversations(id) on delete set null,
  ticket_id uuid references public.support_tickets(id) on delete set null,
  action text not null,
  authorization_basis text not null,
  target_type text,
  target_id uuid,
  correlation_id uuid not null,
  safe_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint support_action_audit_action_check check (char_length(action) between 3 and 100),
  constraint support_action_audit_basis_check check (char_length(authorization_basis) between 3 and 80),
  constraint support_action_audit_metadata_check check (jsonb_typeof(safe_metadata) = 'object')
);

create table public.support_rate_limits (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  scope text not null,
  window_started_at timestamptz not null,
  window_seconds integer not null,
  request_count integer not null default 1,
  expires_at timestamptz not null,
  constraint support_rate_limits_scope_check check (scope ~ '^[a-z0-9_.-]{3,80}$'),
  constraint support_rate_limits_window_check check (window_seconds between 10 and 86400),
  constraint support_rate_limits_count_check check (request_count between 1 and 100000),
  unique (user_id, scope, window_started_at)
);

create table public.support_escalation_rules (
  id uuid primary key default gen_random_uuid(),
  rule_key text not null unique,
  priority integer not null default 100,
  enabled boolean not null default true,
  intent text,
  minimum_safety_level smallint not null default 0,
  match_pattern text,
  action text not null,
  queue text not null,
  user_message text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_escalation_rule_key_check check (rule_key ~ '^[a-z0-9][a-z0-9_-]{2,79}$'),
  constraint support_escalation_priority_check check (priority between 1 and 10000),
  constraint support_escalation_safety_check check (minimum_safety_level between 0 and 3),
  constraint support_escalation_pattern_check check (match_pattern is null or char_length(match_pattern) <= 500),
  constraint support_escalation_action_check check (action in ('answer', 'offer_handoff', 'required_handoff', 'safety_center')),
  constraint support_escalation_queue_check check (queue in ('support', 'trust_safety', 'privacy', 'billing')),
  constraint support_escalation_message_check check (char_length(user_message) between 10 and 1000)
);

create table public.support_macros (
  id uuid primary key default gen_random_uuid(),
  macro_key text not null unique,
  title text not null,
  body text not null,
  audience text[] not null default array['all']::text[],
  navigation_route text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_macros_key_check check (macro_key ~ '^[a-z0-9][a-z0-9_-]{2,79}$'),
  constraint support_macros_title_check check (char_length(title) between 3 and 120),
  constraint support_macros_body_check check (char_length(body) between 10 and 2000),
  constraint support_macros_route_check check (navigation_route is null or navigation_route ~ '^/'),
  constraint support_macros_status_check check (status in ('active', 'retired'))
);

create table public.support_retention_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null,
  status text not null default 'queued',
  scheduled_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  row_count integer not null default 0,
  cursor_state jsonb not null default '{}'::jsonb,
  safe_error_code text,
  created_at timestamptz not null default now(),
  constraint support_retention_jobs_type_check
    check (job_type in ('conversation_expiry', 'attachment_expiry', 'audit_pruning')),
  constraint support_retention_jobs_status_check
    check (status in ('queued', 'running', 'completed', 'failed')),
  constraint support_retention_jobs_count_check check (row_count >= 0),
  constraint support_retention_jobs_cursor_check check (jsonb_typeof(cursor_state) = 'object')
);

create table public.support_user_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  assistant_enabled boolean not null default true,
  save_history boolean not null default true,
  share_diagnostics boolean not null default false,
  email_ticket_updates boolean not null default true,
  retention_days integer not null default 30,
  updated_at timestamptz not null default now(),
  constraint support_user_preferences_retention_check check (retention_days between 1 and 90)
);

create index support_conversations_owner_updated_idx
on public.support_conversations(owner_id, updated_at desc);
create index support_conversations_ticket_idx
on public.support_conversations(ticket_id) where ticket_id is not null;
create index support_conversations_retention_idx
on public.support_conversations(retention_until) where status <> 'deleted';
create index support_messages_conversation_created_idx
on public.support_messages(conversation_id, created_at);
create index support_ticket_events_ticket_created_idx
on public.support_ticket_events(ticket_id, created_at desc);
create index support_attachments_owner_created_idx
on public.support_attachments(owner_id, created_at desc);
create index support_attachments_conversation_idx
on public.support_attachments(conversation_id) where conversation_id is not null;
create index support_attachments_ticket_idx
on public.support_attachments(ticket_id) where ticket_id is not null;
create index support_attachments_retention_idx
on public.support_attachments(retention_delete_at) where status <> 'deleted';
create index support_kb_documents_search_idx
on public.support_kb_documents using gin(search_vector);
create index support_kb_chunks_search_idx
on public.support_kb_chunks using gin(search_vector);
create index support_kb_chunks_document_idx
on public.support_kb_chunks(document_id, chunk_index);
create index support_ai_incidents_queue_idx
on public.support_ai_incidents(status, severity desc, created_at)
where requires_human_review;
create index support_ai_evaluations_run_idx
on public.support_ai_evaluations(run_id, passed);
create index support_action_audit_actor_idx
on public.support_action_audit(actor_id, created_at desc);
create index support_action_audit_ticket_idx
on public.support_action_audit(ticket_id, created_at desc) where ticket_id is not null;
create index support_rate_limits_expiry_idx
on public.support_rate_limits(expires_at);
create index support_retention_jobs_queue_idx
on public.support_retention_jobs(status, scheduled_at);

-- Private storage is authorized by an opaque, short-lived database manifest.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'support-attachments',
  'support-attachments',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.support_conversations enable row level security;
alter table public.support_messages enable row level security;
alter table public.support_ticket_events enable row level security;
alter table public.support_attachments enable row level security;
alter table public.support_kb_documents enable row level security;
alter table public.support_kb_chunks enable row level security;
alter table public.support_ai_feedback enable row level security;
alter table public.support_ai_incidents enable row level security;
alter table public.support_ai_evaluations enable row level security;
alter table public.support_action_audit enable row level security;
alter table public.support_rate_limits enable row level security;
alter table public.support_escalation_rules enable row level security;
alter table public.support_macros enable row level security;
alter table public.support_retention_jobs enable row level security;
alter table public.support_user_preferences enable row level security;

alter table public.support_conversations force row level security;
alter table public.support_messages force row level security;
alter table public.support_ticket_events force row level security;
alter table public.support_attachments force row level security;
alter table public.support_kb_documents force row level security;
alter table public.support_kb_chunks force row level security;
alter table public.support_ai_feedback force row level security;
alter table public.support_ai_incidents force row level security;
alter table public.support_ai_evaluations force row level security;
alter table public.support_action_audit force row level security;
alter table public.support_rate_limits force row level security;
alter table public.support_escalation_rules force row level security;
alter table public.support_macros force row level security;
alter table public.support_retention_jobs force row level security;
alter table public.support_user_preferences force row level security;

create policy support_conversations_read_own
on public.support_conversations for select to authenticated
using ((select auth.uid()) is not null and owner_id = (select auth.uid()));

create policy support_messages_read_own
on public.support_messages for select to authenticated
using (
  (select auth.uid()) is not null
  and exists (
    select 1
    from public.support_conversations conversation
    where conversation.id = support_messages.conversation_id
      and conversation.owner_id = (select auth.uid())
  )
  and not staff_visible_only
);

create policy support_attachments_read_own
on public.support_attachments for select to authenticated
using ((select auth.uid()) is not null and owner_id = (select auth.uid()));

create policy support_ai_feedback_read_own
on public.support_ai_feedback for select to authenticated
using ((select auth.uid()) is not null and owner_id = (select auth.uid()));

create policy support_user_preferences_read_own
on public.support_user_preferences for select to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));
create policy support_user_preferences_insert_own
on public.support_user_preferences for insert to authenticated
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));
create policy support_user_preferences_update_own
on public.support_user_preferences for update to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()))
with check ((select auth.uid()) is not null and user_id = (select auth.uid()));

-- Existing support staff must continue to use audited SECURITY DEFINER RPCs.
-- Direct table reads are owner-only; guardian connections confer no chat access.
drop policy if exists support_tickets_select_authorized on public.support_tickets;
create policy support_tickets_select_authorized
on public.support_tickets for select to authenticated
using ((select auth.uid()) is not null and requester_id = (select auth.uid()));

drop policy if exists support_ticket_messages_select_authorized on public.support_ticket_messages;
create policy support_ticket_messages_select_authorized
on public.support_ticket_messages for select to authenticated
using (
  (select auth.uid()) is not null
  and not staff_visible_only
  and exists (
    select 1 from public.support_tickets ticket
    where ticket.id = support_ticket_messages.ticket_id
      and ticket.requester_id = (select auth.uid())
  )
);

drop policy if exists support_evidence_select_authorized on public.support_evidence_attachments;
create policy support_evidence_select_authorized
on public.support_evidence_attachments for select to authenticated
using ((select auth.uid()) is not null and owner_id = (select auth.uid()));

revoke all on public.support_conversations, public.support_messages,
  public.support_ticket_events, public.support_attachments,
  public.support_kb_documents, public.support_kb_chunks,
  public.support_ai_feedback, public.support_ai_incidents,
  public.support_ai_evaluations, public.support_action_audit,
  public.support_rate_limits, public.support_escalation_rules,
  public.support_macros, public.support_retention_jobs,
  public.support_user_preferences from public, anon, authenticated;

grant select on public.support_conversations, public.support_messages,
  public.support_attachments, public.support_ai_feedback,
  public.support_user_preferences to authenticated;
grant insert, update on public.support_user_preferences to authenticated;
grant all on public.support_conversations, public.support_messages,
  public.support_ticket_events, public.support_attachments,
  public.support_kb_documents, public.support_kb_chunks,
  public.support_ai_feedback, public.support_ai_incidents,
  public.support_ai_evaluations, public.support_action_audit,
  public.support_rate_limits, public.support_escalation_rules,
  public.support_macros, public.support_retention_jobs,
  public.support_user_preferences to service_role;

drop policy if exists storage_support_attachments_insert_authorized on storage.objects;
create policy storage_support_attachments_insert_authorized
on storage.objects for insert to authenticated
with check (
  bucket_id = 'support-attachments'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1
    from public.support_attachments attachment
    where attachment.owner_id = (select auth.uid())
      and attachment.object_path = name
      and attachment.status = 'authorized'
      and attachment.upload_authorization_expires_at > now()
  )
);

drop policy if exists storage_support_attachments_delete_draft on storage.objects;
create policy storage_support_attachments_delete_draft
on storage.objects for delete to authenticated
using (
  bucket_id = 'support-attachments'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1
    from public.support_attachments attachment
    where attachment.owner_id = (select auth.uid())
      and attachment.object_path = name
      and attachment.status = 'authorized'
  )
);

create or replace function private.support_touch_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger support_conversations_touch_updated_at
before update on public.support_conversations
for each row execute function private.support_touch_updated_at();
create trigger support_attachments_touch_updated_at
before update on public.support_attachments
for each row execute function private.support_touch_updated_at();
create trigger support_kb_documents_touch_updated_at
before update on public.support_kb_documents
for each row execute function private.support_touch_updated_at();
create trigger support_escalation_rules_touch_updated_at
before update on public.support_escalation_rules
for each row execute function private.support_touch_updated_at();
create trigger support_macros_touch_updated_at
before update on public.support_macros
for each row execute function private.support_touch_updated_at();
create trigger support_user_preferences_touch_updated_at
before update on public.support_user_preferences
for each row execute function private.support_touch_updated_at();

revoke all on function private.support_touch_updated_at() from public, anon, authenticated;

create or replace function private.support_take_rate_limit(
  p_user_id uuid,
  p_scope text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window timestamptz;
  v_count integer;
begin
  if p_user_id is null
    or p_scope !~ '^[a-z0-9_.-]{3,80}$'
    or p_limit not between 1 and 10000
    or p_window_seconds not between 10 and 86400 then
    return false;
  end if;

  v_window := to_timestamp(
    floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds
  );

  insert into public.support_rate_limits (
    user_id, scope, window_started_at, window_seconds, request_count, expires_at
  ) values (
    p_user_id, p_scope, v_window, p_window_seconds, 1,
    v_window + make_interval(secs => p_window_seconds)
  )
  on conflict (user_id, scope, window_started_at) do update
  set request_count = public.support_rate_limits.request_count + 1
  returning request_count into v_count;

  return v_count <= p_limit;
end;
$$;

create or replace function private.support_classify_message(p_message text)
returns jsonb
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  v_message text := lower(btrim(coalesce(p_message, '')));
  v_level smallint := 0;
  v_category text := 'general';
  v_intent text := 'general_support';
  v_action text := 'answer';
begin
  if v_message ~ '(suicid|kill myself|hurt myself|kill (him|her|them|someone)|kidnap|abduct|traffick|weapon|gun|knife|immediate danger|being followed right now|sexual assault|rape)' then
    v_level := 3;
    v_category := 'immediate_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  elsif v_message ~ '(threat|stalk|harass|blackmail|extort|nude|sexual message|meet.*alone|off.platform|cashapp|gift card|verification code|password|social security|ssn|passport|driver.?s license|card number|cvc|exact (home )?address)' then
    v_level := 2;
    v_category := 'trust_safety';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_message ~ '(report|block|unsafe|scam|fraud|privacy|delete.*account|payment|paid|refund|dispute|identity|verify|login|sign.?in|account|application|job|guardian)' then
    v_level := 1;
    v_category := case
      when v_message ~ '(report|block|unsafe|scam|fraud)' then 'trust_safety'
      when v_message ~ '(privacy|delete.*account)' then 'privacy'
      when v_message ~ '(payment|paid|refund|dispute)' then 'billing'
      when v_message ~ '(login|sign.?in|account|identity|verify)' then 'account'
      else 'marketplace'
    end;
    v_intent := case
      when v_category = 'trust_safety' then 'report_or_block'
      when v_category = 'privacy' then 'privacy_or_deletion'
      when v_category = 'billing' then 'payment_or_dispute'
      when v_category = 'account' then 'account_access'
      else 'jobs_or_applications'
    end;
    v_action := 'offer_handoff';
  end if;

  return jsonb_build_object(
    'level', v_level,
    'category', v_category,
    'intent', v_intent,
    'action', v_action,
    'provider_allowed', v_level < 2
  );
end;
$$;

revoke all on function private.support_take_rate_limit(uuid, text, integer, integer)
from public, anon, authenticated;
revoke all on function private.support_classify_message(text)
from public, anon, authenticated;
grant execute on function private.support_take_rate_limit(uuid, text, integer, integer)
to service_role;
grant execute on function private.support_classify_message(text)
to service_role;

create or replace function public.support_get_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_preferences public.support_user_preferences%rowtype;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_preferences
  from public.support_user_preferences preference
  where preference.user_id = auth.uid();

  return jsonb_build_object(
    'ok', true,
    'assistant_enabled', coalesce(v_preferences.assistant_enabled, true),
    'save_history', coalesce(v_preferences.save_history, true),
    'retention_days', coalesce(v_preferences.retention_days, 30),
    'human_support_available', true,
    'guardian_chat_access', false,
    'warning', 'Do not share passwords, verification codes, payment credentials, government IDs, exact home addresses, or emergency evidence.'
  );
end;
$$;

create or replace function public.support_classify_intent(p_message text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 3 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_message');
  end if;
  if not private.support_take_rate_limit(auth.uid(), 'intent', 60, 600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;
  return jsonb_build_object('ok', true, 'classification', private.support_classify_message(p_message));
end;
$$;

create or replace function public.support_begin_chat(
  p_message text,
  p_conversation_id uuid default null,
  p_client_request_id uuid default gen_random_uuid(),
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_message_text text := btrim(coalesce(p_message, ''));
  v_conversation public.support_conversations%rowtype;
  v_message public.support_messages%rowtype;
  v_classification jsonb;
  v_preferences public.support_user_preferences%rowtype;
  v_existing public.support_messages%rowtype;
  v_retention integer := 30;
begin
  if v_user_id is null or not public.is_profile_active(v_user_id) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(v_message_text) not between 3 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_message');
  end if;
  if p_client_request_id is null or p_correlation_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_identifiers_required');
  end if;
  if not private.support_take_rate_limit(v_user_id, 'chat', 30, 600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;

  select message.* into v_existing
  from public.support_messages message
  join public.support_conversations conversation on conversation.id = message.conversation_id
  where conversation.owner_id = v_user_id
    and message.author_id = v_user_id
    and message.client_request_id = p_client_request_id
  limit 1;
  if v_existing.id is not null then
    return jsonb_build_object(
      'ok', true,
      'replayed', true,
      'conversation_id', v_existing.conversation_id,
      'message_id', v_existing.id
    );
  end if;

  select * into v_preferences
  from public.support_user_preferences preference
  where preference.user_id = v_user_id;
  if found then v_retention := v_preferences.retention_days; end if;

  if p_conversation_id is null then
    insert into public.support_conversations (
      owner_id, client_request_id, title, response_mode, retention_until
    ) values (
      v_user_id,
      p_client_request_id,
      left(v_message_text, 80),
      case when coalesce(v_preferences.assistant_enabled, true) then 'deterministic' else 'disabled' end,
      now() + make_interval(days => v_retention)
    ) returning * into v_conversation;
  else
    select * into v_conversation
    from public.support_conversations conversation
    where conversation.id = p_conversation_id
      and conversation.owner_id = v_user_id
      and conversation.status = 'active'
    for update;
    if v_conversation.id is null then
      return jsonb_build_object('ok', false, 'code', 'support_conversation_not_found');
    end if;
  end if;

  v_classification := private.support_classify_message(v_message_text);
  insert into public.support_messages (
    conversation_id, author_id, role, content, intent, safety_level,
    response_mode, client_request_id
  ) values (
    v_conversation.id, v_user_id, 'user', v_message_text,
    v_classification->>'intent', (v_classification->>'level')::smallint,
    v_conversation.response_mode, p_client_request_id
  ) returning * into v_message;

  update public.support_conversations
  set last_message_at = now(),
      highest_safety_level = greatest(highest_safety_level, v_message.safety_level),
      retention_until = now() + make_interval(days => v_retention)
  where id = v_conversation.id
  returning * into v_conversation;

  if v_message.safety_level >= 2 then
    insert into public.support_ai_incidents (
      owner_id, conversation_id, message_id, category, severity,
      requires_human_review, redacted_excerpt, correlation_id
    ) values (
      v_user_id, v_conversation.id, v_message.id,
      v_classification->>'category', v_message.safety_level, true,
      '[content withheld; review the authorized conversation]', p_correlation_id
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'conversation', to_jsonb(v_conversation),
    'message', to_jsonb(v_message),
    'classification', v_classification,
    'assistant_enabled', coalesce(v_preferences.assistant_enabled, true)
  );
end;
$$;

create or replace function public.support_server_record_assistant(
  p_owner_id uuid,
  p_conversation_id uuid,
  p_content text,
  p_intent text,
  p_safety_level smallint,
  p_response_mode text,
  p_cited_document_ids uuid[] default '{}'::uuid[],
  p_client_request_id uuid default gen_random_uuid(),
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation public.support_conversations%rowtype;
  v_message public.support_messages%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  if char_length(btrim(coalesce(p_content, ''))) not between 1 and 4000
    or char_length(btrim(coalesce(p_intent, ''))) not between 3 and 80
    or p_safety_level not between 0 and 3
    or p_response_mode not in ('deterministic', 'anthropic', 'disabled', 'staff')
    or cardinality(coalesce(p_cited_document_ids, '{}'::uuid[])) > 8 then
    return jsonb_build_object('ok', false, 'code', 'invalid_assistant_response');
  end if;

  select * into v_conversation
  from public.support_conversations conversation
  where conversation.id = p_conversation_id
    and conversation.owner_id = p_owner_id
    and conversation.status <> 'deleted'
  for update;
  if v_conversation.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_conversation_not_found');
  end if;

  insert into public.support_messages (
    conversation_id, role, content, intent, safety_level, response_mode,
    cited_document_ids, client_request_id
  ) values (
    v_conversation.id, 'assistant', btrim(p_content), btrim(p_intent),
    p_safety_level, p_response_mode, coalesce(p_cited_document_ids, '{}'::uuid[]),
    p_client_request_id
  ) returning * into v_message;

  update public.support_conversations
  set response_mode = p_response_mode,
      highest_safety_level = greatest(highest_safety_level, p_safety_level),
      last_message_at = now()
  where id = v_conversation.id;

  insert into public.support_action_audit (
    actor_id, conversation_id, action, authorization_basis,
    target_type, target_id, correlation_id, safe_metadata
  ) values (
    null, v_conversation.id, 'assistant_response_recorded', 'edge_service',
    'support_message', v_message.id, p_correlation_id,
    jsonb_build_object('mode', p_response_mode, 'safety_level', p_safety_level,
      'citation_count', cardinality(coalesce(p_cited_document_ids, '{}'::uuid[])))
  );

  return jsonb_build_object('ok', true, 'message', to_jsonb(v_message));
end;
$$;

create or replace function public.support_search_kb(
  p_query text,
  p_limit integer default 5
)
returns table (
  id uuid,
  title text,
  excerpt text,
  source_url text,
  navigation_route text,
  rank real
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_query tsquery;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return;
  end if;
  if char_length(btrim(coalesce(p_query, ''))) not between 2 and 500 then
    return;
  end if;
  v_role := public.current_profile_role()::text;
  v_query := websearch_to_tsquery('english'::regconfig, left(btrim(p_query), 500));

  return query
  select document.id,
    document.title,
    left(document.content, 700),
    document.source_url,
    document.navigation_route,
    ts_rank(document.search_vector, v_query)
  from public.support_kb_documents document
  where document.status = 'published'
    and document.review_due_at >= current_date
    and ('all' = any(document.audience) or v_role = any(document.audience))
    and document.search_vector @@ v_query
  order by ts_rank(document.search_vector, v_query) desc, document.title
  limit least(greatest(coalesce(p_limit, 5), 1), 8);
end;
$$;

create or replace function public.support_list_my_conversations()
returns setof public.support_conversations
language sql
stable
security invoker
set search_path = ''
as $$
  select conversation.*
  from public.support_conversations conversation
  where conversation.owner_id = auth.uid()
    and conversation.status <> 'deleted'
  order by conversation.updated_at desc
  limit 100
$$;

create or replace function public.support_get_my_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_conversation public.support_conversations%rowtype;
  v_messages jsonb;
  v_citations jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_conversation
  from public.support_conversations conversation
  where conversation.id = p_conversation_id
    and conversation.owner_id = auth.uid()
    and conversation.status <> 'deleted';
  if v_conversation.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_conversation_not_found');
  end if;

  select coalesce(jsonb_agg(to_jsonb(message) order by message.created_at), '[]'::jsonb)
  into v_messages
  from public.support_messages message
  where message.conversation_id = v_conversation.id
    and not message.staff_visible_only;

  select coalesce(jsonb_agg(distinct jsonb_build_object(
    'id', document.id,
    'title', document.title,
    'source_url', document.source_url,
    'navigation_route', document.navigation_route
  )), '[]'::jsonb)
  into v_citations
  from public.support_messages message
  cross join lateral unnest(message.cited_document_ids) as citation(document_id)
  join public.support_kb_documents document on document.id = citation.document_id
  where message.conversation_id = v_conversation.id
    and document.status = 'published';

  return jsonb_build_object(
    'ok', true,
    'conversation', to_jsonb(v_conversation),
    'messages', v_messages,
    'citations', v_citations
  );
end;
$$;

create or replace function public.support_delete_my_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if exists (
    select 1 from public.support_attachments attachment
    where attachment.conversation_id = p_conversation_id
      and attachment.owner_id = auth.uid()
      and attachment.status not in ('rejected', 'deleted')
  ) then
    return jsonb_build_object('ok', false, 'code', 'attachment_cleanup_required');
  end if;
  delete from public.support_conversations conversation
  where conversation.id = p_conversation_id
    and conversation.owner_id = auth.uid()
    and conversation.ticket_id is null;
  get diagnostics v_count = row_count;
  return jsonb_build_object(
    'ok', v_count = 1,
    'code', case when v_count = 1 then 'deleted' else 'conversation_not_deletable' end
  );
end;
$$;

create or replace function public.support_submit_feedback(
  p_message_id uuid,
  p_rating text,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation_id uuid;
begin
  if auth.uid() is null or p_rating not in ('helpful', 'not_helpful', 'unsafe') then
    return jsonb_build_object('ok', false, 'code', 'invalid_feedback');
  end if;
  if p_comment is not null and char_length(btrim(p_comment)) not between 3 and 500 then
    return jsonb_build_object('ok', false, 'code', 'invalid_feedback_comment');
  end if;
  select conversation.id into v_conversation_id
  from public.support_messages message
  join public.support_conversations conversation on conversation.id = message.conversation_id
  where message.id = p_message_id
    and message.role = 'assistant'
    and conversation.owner_id = auth.uid();
  if v_conversation_id is null then
    return jsonb_build_object('ok', false, 'code', 'support_message_not_found');
  end if;

  insert into public.support_ai_feedback (
    owner_id, conversation_id, message_id, rating, comment
  ) values (
    auth.uid(), v_conversation_id, p_message_id, p_rating,
    nullif(btrim(coalesce(p_comment, '')), '')
  ) on conflict (owner_id, message_id) do update
  set rating = excluded.rating, comment = excluded.comment, created_at = now();

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.support_report_ai_response(
  p_message_id uuid,
  p_category text,
  p_comment text default null,
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation_id uuid;
  v_incident_id uuid;
begin
  if auth.uid() is null
    or p_category not in ('unsafe', 'incorrect', 'privacy', 'bias', 'other')
    or (p_comment is not null and char_length(btrim(p_comment)) > 500) then
    return jsonb_build_object('ok', false, 'code', 'invalid_ai_report');
  end if;
  if not private.support_take_rate_limit(auth.uid(), 'ai_report', 10, 3600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;
  select conversation.id into v_conversation_id
  from public.support_messages message
  join public.support_conversations conversation on conversation.id = message.conversation_id
  where message.id = p_message_id
    and message.role = 'assistant'
    and conversation.owner_id = auth.uid();
  if v_conversation_id is null then
    return jsonb_build_object('ok', false, 'code', 'support_message_not_found');
  end if;

  insert into public.support_ai_incidents (
    owner_id, conversation_id, message_id, category, severity,
    requires_human_review, redacted_excerpt, correlation_id
  ) values (
    auth.uid(), v_conversation_id, p_message_id, p_category,
    case when p_category in ('unsafe', 'privacy') then 2 else 1 end,
    true,
    case when p_comment is null then null else '[user supplied report comment withheld]' end,
    p_correlation_id
  ) returning id into v_incident_id;

  return jsonb_build_object('ok', true, 'incident_id', v_incident_id);
end;
$$;

create or replace function public.support_escalate_conversation(
  p_conversation_id uuid,
  p_subject text,
  p_category text default 'other',
  p_summary text default 'User requested human support.',
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation public.support_conversations%rowtype;
  v_ticket_result jsonb;
  v_ticket_id uuid;
  v_priority text := 'normal';
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(btrim(coalesce(p_subject, ''))) not between 3 and 120
    or char_length(btrim(coalesce(p_summary, ''))) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_handoff_request');
  end if;
  select * into v_conversation
  from public.support_conversations conversation
  where conversation.id = p_conversation_id
    and conversation.owner_id = auth.uid()
    and conversation.status <> 'deleted'
  for update;
  if v_conversation.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_conversation_not_found');
  end if;
  if v_conversation.ticket_id is not null then
    return jsonb_build_object(
      'ok', true, 'replayed', true,
      'conversation_id', v_conversation.id,
      'ticket_id', v_conversation.ticket_id
    );
  end if;
  if not private.support_take_rate_limit(auth.uid(), 'handoff', 5, 3600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;

  if v_conversation.highest_safety_level >= 3 then v_priority := 'urgent_safety';
  elsif v_conversation.highest_safety_level = 2 then v_priority := 'high';
  end if;

  v_ticket_result := public.create_support_conversation(
    p_category,
    btrim(p_subject),
    btrim(p_summary),
    'automated_support',
    null, null, null, null,
    p_correlation_id
  );
  if coalesce((v_ticket_result->>'ok')::boolean, false) is not true then
    return v_ticket_result;
  end if;
  v_ticket_id := (v_ticket_result->'ticket'->>'id')::uuid;

  update public.support_tickets
  set priority = v_priority,
      ai_assisted = true,
      human_review_requested_at = now(),
      waiting_on_party = 'staff'
  where id = v_ticket_id;
  update public.support_conversations
  set ticket_id = v_ticket_id, status = 'handed_off', channel = 'human_support'
  where id = v_conversation.id;

  insert into public.support_ticket_events (
    ticket_id, conversation_id, actor_id, event_type, correlation_id, safe_metadata
  ) values (
    v_ticket_id, v_conversation.id, auth.uid(), 'assistant_handoff_created',
    p_correlation_id,
    jsonb_build_object('priority', v_priority,
      'highest_safety_level', v_conversation.highest_safety_level)
  );
  insert into public.support_action_audit (
    actor_id, conversation_id, ticket_id, action, authorization_basis,
    target_type, target_id, correlation_id
  ) values (
    auth.uid(), v_conversation.id, v_ticket_id, 'human_handoff_created',
    'conversation_owner', 'support_ticket', v_ticket_id, p_correlation_id
  );

  return jsonb_build_object(
    'ok', true, 'replayed', false,
    'conversation_id', v_conversation.id,
    'ticket_id', v_ticket_id,
    'priority', v_priority
  );
end;
$$;

create or replace function public.support_authorize_attachment_upload(
  p_conversation_id uuid,
  p_ticket_id uuid,
  p_original_name text,
  p_content_type text,
  p_byte_size integer,
  p_sha256 text,
  p_purpose text,
  p_client_request_id uuid default gen_random_uuid(),
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_extension text;
  v_expected_type text;
  v_attachment public.support_attachments%rowtype;
  v_name text := lower(btrim(coalesce(p_original_name, '')));
  v_purpose text := btrim(coalesce(p_purpose, ''));
begin
  if v_user_id is null or not public.is_profile_active(v_user_id) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_conversation_id is null and p_ticket_id is null then
    return jsonb_build_object('ok', false, 'code', 'attachment_subject_required');
  end if;
  if p_conversation_id is not null and not exists (
    select 1 from public.support_conversations conversation
    where conversation.id = p_conversation_id and conversation.owner_id = v_user_id
  ) then return jsonb_build_object('ok', false, 'code', 'attachment_not_authorized'); end if;
  if p_ticket_id is not null and not exists (
    select 1 from public.support_tickets ticket
    where ticket.id = p_ticket_id and ticket.requester_id = v_user_id
  ) then return jsonb_build_object('ok', false, 'code', 'attachment_not_authorized'); end if;
  if p_byte_size not between 1 and 5242880
    or p_sha256 !~ '^[a-f0-9]{64}$'
    or char_length(v_purpose) not between 3 and 160 then
    return jsonb_build_object('ok', false, 'code', 'invalid_attachment_metadata');
  end if;
  if v_name ~ '(\.exe|\.dll|\.dmg|\.apk|\.aab|\.ipa|\.zip|\.rar|\.7z|\.tar|\.gz|\.pem|\.key|id_rsa|keystore|client_secret)($|\.)'
    or lower(v_purpose) ~ '(full card|card number|cvc|cvv|social security|ssn|passport|driver.?s license|government id|password|secret key|auth token)' then
    return jsonb_build_object('ok', false, 'code', 'prohibited_attachment');
  end if;

  v_extension := lower(substring(v_name from '\.([a-z0-9]+)$'));
  v_expected_type := case
    when v_extension in ('jpg', 'jpeg') then 'image/jpeg'
    when v_extension = 'png' then 'image/png'
    when v_extension = 'webp' then 'image/webp'
    when v_extension = 'pdf' then 'application/pdf'
    else null
  end;
  if v_expected_type is null or p_content_type <> v_expected_type then
    return jsonb_build_object('ok', false, 'code', 'unsupported_attachment_type');
  end if;
  if not private.support_take_rate_limit(v_user_id, 'attachment', 8, 3600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;

  insert into public.support_attachments (
    owner_id, conversation_id, ticket_id, object_path, original_extension,
    content_type, byte_size, sha256, purpose, scan_status,
    client_request_id, upload_authorization_expires_at
  ) values (
    v_user_id, p_conversation_id, p_ticket_id,
    v_user_id::text || '/' || gen_random_uuid()::text || '.' || v_extension,
    v_extension, p_content_type, p_byte_size, p_sha256, v_purpose,
    'metadata_passed', p_client_request_id, now() + interval '15 minutes'
  )
  on conflict (owner_id, client_request_id) do update
  set updated_at = now()
  returning * into v_attachment;

  insert into public.support_action_audit (
    actor_id, conversation_id, ticket_id, action, authorization_basis,
    target_type, target_id, correlation_id, safe_metadata
  ) values (
    v_user_id, p_conversation_id, p_ticket_id, 'attachment_upload_authorized',
    'subject_owner', 'support_attachment', v_attachment.id, p_correlation_id,
    jsonb_build_object('content_type', p_content_type, 'byte_size', p_byte_size)
  );

  return jsonb_build_object(
    'ok', true,
    'attachment_id', v_attachment.id,
    'bucket_id', v_attachment.bucket_id,
    'object_path', v_attachment.object_path,
    'expires_at', v_attachment.upload_authorization_expires_at
  );
end;
$$;

create or replace function public.support_submit_attachment(p_attachment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attachment public.support_attachments%rowtype;
  v_storage storage.objects%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_attachment from public.support_attachments attachment
  where attachment.id = p_attachment_id
    and attachment.owner_id = auth.uid()
    and attachment.status = 'authorized'
    and attachment.upload_authorization_expires_at > now()
  for update;
  if v_attachment.id is null then
    return jsonb_build_object('ok', false, 'code', 'attachment_not_authorized');
  end if;
  select * into v_storage from storage.objects object
  where object.bucket_id = v_attachment.bucket_id
    and object.name = v_attachment.object_path;
  if v_storage.id is null
    or coalesce((v_storage.metadata->>'size')::integer, -1) <> v_attachment.byte_size
    or coalesce(v_storage.metadata->>'mimetype', '') <> v_attachment.content_type then
    return jsonb_build_object('ok', false, 'code', 'attachment_manifest_mismatch');
  end if;
  update public.support_attachments
  set status = 'submitted', scan_status = 'metadata_passed'
  where id = v_attachment.id;
  return jsonb_build_object('ok', true, 'attachment_id', v_attachment.id);
end;
$$;

create or replace function public.support_authorize_attachment_url(
  p_attachment_id uuid,
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attachment public.support_attachments%rowtype;
  v_basis text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_attachment
  from public.support_attachments attachment
  where attachment.id = p_attachment_id and attachment.status = 'submitted';
  if v_attachment.id is null then
    return jsonb_build_object('ok', false, 'code', 'attachment_not_found');
  end if;
  if v_attachment.owner_id = auth.uid() then
    v_basis := 'owner';
  elsif private.has_support_role(auth.uid(), array['support_agent', 'support_manager', 'safety_reviewer'])
    and v_attachment.ticket_id is not null
    and private.can_access_support_ticket(v_attachment.ticket_id, auth.uid()) then
    v_basis := 'audited_staff_access';
  else
    return jsonb_build_object('ok', false, 'code', 'attachment_not_authorized');
  end if;
  if not private.support_take_rate_limit(auth.uid(), 'attachment_url', 30, 300) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;
  insert into public.support_action_audit (
    actor_id, conversation_id, ticket_id, action, authorization_basis,
    target_type, target_id, correlation_id
  ) values (
    auth.uid(), v_attachment.conversation_id, v_attachment.ticket_id,
    'attachment_signed_url_authorized', v_basis,
    'support_attachment', v_attachment.id, p_correlation_id
  );
  return jsonb_build_object(
    'ok', true,
    'bucket_id', v_attachment.bucket_id,
    'object_path', v_attachment.object_path,
    'expires_in_seconds', 300
  );
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
  v_actor uuid := auth.uid();
begin
  if not private.has_support_role(
    v_actor, array['support_agent', 'support_manager', 'safety_reviewer']
  ) then return; end if;
  insert into public.support_action_audit (
    actor_id, action, authorization_basis, correlation_id, safe_metadata
  ) values (
    v_actor, 'staff_ticket_queue_read', 'active_support_assignment',
    gen_random_uuid(),
    jsonb_build_object('status_filter', p_status,
      'unassigned_only', coalesce(p_unassigned_only, false),
      'limit', least(greatest(coalesce(p_limit, 50), 1), 100))
  );
  return query
  select ticket.*
  from public.support_tickets ticket
  where private.can_access_support_ticket(ticket.id, v_actor)
    and (p_status is null or ticket.status = p_status)
    and (not coalesce(p_unassigned_only, false) or ticket.assigned_support_user_id is null)
  order by
    case ticket.priority when 'urgent_safety' then 0 when 'high' then 1 when 'normal' then 2 else 3 end,
    coalesce(ticket.last_user_message_at, ticket.created_at) asc
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
  v_actor uuid := auth.uid();
  v_ticket public.support_tickets%rowtype;
  v_messages jsonb;
  v_evidence jsonb;
  v_attachments jsonb;
  v_correlation_id uuid := gen_random_uuid();
begin
  if not private.has_support_role(
    v_actor, array['support_agent', 'support_manager', 'safety_reviewer']
  ) then return jsonb_build_object('ok', false, 'code', 'support_staff_role_required'); end if;
  select * into v_ticket from public.support_tickets ticket where ticket.id = p_ticket_id;
  if v_ticket.id is null or not private.can_access_support_ticket(v_ticket.id, v_actor) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  select coalesce(jsonb_agg(to_jsonb(message) order by message.created_at), '[]'::jsonb)
  into v_messages from public.support_ticket_messages message
  where message.ticket_id = v_ticket.id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', evidence.id,
    'category', evidence.evidence_category,
    'status', evidence.status,
    'processed_byte_size', evidence.processed_byte_size,
    'created_at', evidence.created_at,
    'retention_delete_at', evidence.retention_delete_at,
    'preservation_hold', evidence.preservation_hold,
    'review_status', evidence.review_status
  ) order by evidence.created_at), '[]'::jsonb)
  into v_evidence from public.support_evidence_attachments evidence
  where evidence.ticket_id = v_ticket.id and evidence.status <> 'deleted';
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', attachment.id,
    'content_type', attachment.content_type,
    'byte_size', attachment.byte_size,
    'status', attachment.status,
    'created_at', attachment.created_at
  ) order by attachment.created_at), '[]'::jsonb)
  into v_attachments from public.support_attachments attachment
  where attachment.ticket_id = v_ticket.id and attachment.status <> 'deleted';

  insert into public.support_action_audit (
    actor_id, ticket_id, action, authorization_basis,
    target_type, target_id, correlation_id
  ) values (
    v_actor, v_ticket.id, 'staff_ticket_thread_read', 'active_support_assignment',
    'support_ticket', v_ticket.id, v_correlation_id
  );
  insert into public.support_ticket_audit_events (
    ticket_id, actor_id, event_type, safe_metadata
  ) values (
    v_ticket.id, v_actor, 'staff_thread_read',
    jsonb_build_object('correlation_id', v_correlation_id)
  );

  return jsonb_build_object(
    'ok', true,
    'ticket', to_jsonb(v_ticket),
    'messages', v_messages,
    'evidence', v_evidence,
    'attachments', v_attachments
  );
end;
$$;

create or replace function public.support_staff_list_conversations(
  p_minimum_safety_level smallint default 0,
  p_limit integer default 50
)
returns setof public.support_conversations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if not private.has_support_role(
    v_actor, array['support_manager', 'safety_reviewer']
  ) then return; end if;
  insert into public.support_action_audit (
    actor_id, action, authorization_basis, correlation_id, safe_metadata
  ) values (
    v_actor, 'staff_assistant_queue_read', 'active_support_assignment',
    gen_random_uuid(), jsonb_build_object(
      'minimum_safety_level', least(greatest(coalesce(p_minimum_safety_level, 0), 0), 3),
      'limit', least(greatest(coalesce(p_limit, 50), 1), 100))
  );
  return query
  select conversation.*
  from public.support_conversations conversation
  where conversation.highest_safety_level >= least(greatest(coalesce(p_minimum_safety_level, 0), 0), 3)
    and conversation.status <> 'deleted'
  order by conversation.highest_safety_level desc, conversation.updated_at
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
end;
$$;

create or replace function public.support_staff_get_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_conversation public.support_conversations%rowtype;
  v_messages jsonb;
  v_correlation_id uuid := gen_random_uuid();
begin
  if not private.has_support_role(
    v_actor, array['support_manager', 'safety_reviewer']
  ) then return jsonb_build_object('ok', false, 'code', 'support_staff_role_required'); end if;
  select * into v_conversation
  from public.support_conversations conversation
  where conversation.id = p_conversation_id and conversation.status <> 'deleted';
  if v_conversation.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_conversation_not_found');
  end if;
  select coalesce(jsonb_agg(to_jsonb(message) order by message.created_at), '[]'::jsonb)
  into v_messages
  from public.support_messages message
  where message.conversation_id = v_conversation.id;
  insert into public.support_action_audit (
    actor_id, conversation_id, ticket_id, action, authorization_basis,
    target_type, target_id, correlation_id
  ) values (
    v_actor, v_conversation.id, v_conversation.ticket_id,
    'staff_assistant_conversation_read', 'active_support_assignment',
    'support_conversation', v_conversation.id, v_correlation_id
  );
  return jsonb_build_object(
    'ok', true,
    'conversation', to_jsonb(v_conversation),
    'messages', v_messages
  );
end;
$$;

create or replace function public.support_run_retention_cleanup(p_limit integer default 100)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job_id uuid;
  v_conversations integer := 0;
  v_limits integer := 0;
begin
  if auth.role() is distinct from 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  insert into public.support_retention_jobs (job_type, status, started_at)
  values ('conversation_expiry', 'running', now()) returning id into v_job_id;

  with expired as (
    select conversation.id
    from public.support_conversations conversation
    where conversation.retention_until <= now()
      and conversation.status <> 'deleted'
      and conversation.ticket_id is null
      and not exists (
        select 1 from public.support_attachments attachment
        where attachment.conversation_id = conversation.id
          and attachment.status not in ('rejected', 'deleted')
      )
    order by conversation.retention_until
    limit least(greatest(coalesce(p_limit, 100), 1), 500)
  )
  delete from public.support_conversations conversation
  using expired where conversation.id = expired.id;
  get diagnostics v_conversations = row_count;

  delete from public.support_rate_limits rate_limit where rate_limit.expires_at < now();
  get diagnostics v_limits = row_count;
  update public.support_retention_jobs
  set status = 'completed', completed_at = now(),
      row_count = v_conversations + v_limits,
      cursor_state = jsonb_build_object(
        'conversations_deleted', v_conversations,
        'rate_windows_deleted', v_limits)
  where id = v_job_id;
  return jsonb_build_object(
    'ok', true, 'job_id', v_job_id,
    'conversations_deleted', v_conversations,
    'rate_windows_deleted', v_limits
  );
end;
$$;

create or replace function public.support_record_evaluation(
  p_run_id uuid,
  p_case_key text,
  p_suite text,
  p_provider_mode text,
  p_expected_outcome text,
  p_actual_outcome text,
  p_passed boolean,
  p_score numeric default null,
  p_safe_details jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() is distinct from 'service_role' then return false; end if;
  insert into public.support_ai_evaluations (
    run_id, case_key, suite, provider_mode, expected_outcome,
    actual_outcome, passed, score, safe_details
  ) values (
    p_run_id, p_case_key, left(p_suite, 80), p_provider_mode,
    left(p_expected_outcome, 160), left(p_actual_outcome, 160),
    p_passed, p_score, coalesce(p_safe_details, '{}'::jsonb)
  ) on conflict (run_id, case_key) do update set
    actual_outcome = excluded.actual_outcome,
    passed = excluded.passed,
    score = excluded.score,
    safe_details = excluded.safe_details;
  return true;
end;
$$;

insert into public.support_kb_documents (
  slug, title, summary, content, source_url, navigation_route,
  document_type, status, audience, version, effective_at,
  review_due_at, approved_at
)
select
  source.slug,
  source.title,
  left(source.answer_text, 500),
  source.answer_text,
  source.source_url,
  source.navigation_route,
  case source.source_type
    when 'safety' then 'safety'
    when 'policy' then 'policy'
    else 'help'
  end,
  'published',
  source.audience,
  source.version,
  source.effective_date,
  source.review_due_at,
  now()
from public.ai_knowledge_sources source
where source.approval_status = 'approved'
on conflict (slug) do update set
  title = excluded.title,
  summary = excluded.summary,
  content = excluded.content,
  source_url = excluded.source_url,
  navigation_route = excluded.navigation_route,
  document_type = excluded.document_type,
  status = excluded.status,
  audience = excluded.audience,
  version = excluded.version,
  effective_at = excluded.effective_at,
  review_due_at = excluded.review_due_at,
  approved_at = excluded.approved_at,
  updated_at = now();

insert into public.support_kb_chunks (
  document_id, chunk_index, content, token_estimate
)
select document.id, 0, document.content,
  greatest(1, ceil(char_length(document.content)::numeric / 4)::integer)
from public.support_kb_documents document
where document.status = 'published'
on conflict (document_id, chunk_index) do update set
  content = excluded.content,
  token_estimate = excluded.token_estimate;

insert into public.support_escalation_rules (
  rule_key, priority, enabled, intent, minimum_safety_level,
  action, queue, user_message
) values
  (
    'immediate-safety', 10, true, 'safety_emergency', 3,
    'safety_center', 'trust_safety',
    'MORT cannot dispatch emergency help. Move to a safer place if you can, contact local emergency services, and use Safety Center to report or block.'
  ),
  (
    'trust-safety-review', 20, true, 'report_or_privacy', 2,
    'required_handoff', 'trust_safety',
    'This needs a trained human safety review. Do not upload IDs, payment credentials, exact addresses, or emergency evidence here.'
  ),
  (
    'payment-dispute-handoff', 100, true, 'payment_or_dispute', 1,
    'offer_handoff', 'billing',
    'I can show the payment help steps or open a human support case. MORT Support does not make the payment decision.'
  ),
  (
    'privacy-handoff', 90, true, 'privacy_or_deletion', 1,
    'offer_handoff', 'privacy',
    'I can show the account privacy controls or open a human support case for a privacy request.'
  )
on conflict (rule_key) do update set
  priority = excluded.priority,
  enabled = excluded.enabled,
  intent = excluded.intent,
  minimum_safety_level = excluded.minimum_safety_level,
  action = excluded.action,
  queue = excluded.queue,
  user_message = excluded.user_message,
  updated_at = now();

insert into public.support_macros (
  macro_key, title, body, audience, navigation_route
) values
  (
    'assistant-disabled', 'Human support remains available',
    'The optional Support Assistant is off. You can still search MORT Help, open Safety Center, or create a human support case.',
    array['all'], '/support'
  ),
  (
    'immediate-safety', 'Immediate safety',
    'MORT cannot dispatch emergency help. If anyone may be in immediate danger, move to a safer place when possible and contact local emergency services. Report or block in Safety Center when safe to do so.',
    array['all'], '/safety'
  ),
  (
    'no-sensitive-data', 'Keep sensitive data out of chat',
    'Do not send passwords, verification codes, payment credentials, government IDs, exact home addresses, or unrelated private messages.',
    array['all'], '/support'
  ),
  (
    'human-handoff', 'Human support handoff',
    'A human support case can preserve the issue summary and case number. A trained person, not the assistant, reviews the request.',
    array['all'], '/support'
  )
on conflict (macro_key) do update set
  title = excluded.title,
  body = excluded.body,
  audience = excluded.audience,
  navigation_route = excluded.navigation_route,
  status = 'active',
  updated_at = now();

do $$
declare
  signature text;
begin
  foreach signature in array array[
    'public.support_get_config()',
    'public.support_classify_intent(text)',
    'public.support_begin_chat(text,uuid,uuid,uuid)',
    'public.support_search_kb(text,integer)',
    'public.support_list_my_conversations()',
    'public.support_get_my_conversation(uuid)',
    'public.support_delete_my_conversation(uuid)',
    'public.support_submit_feedback(uuid,text,text)',
    'public.support_report_ai_response(uuid,text,text,uuid)',
    'public.support_escalate_conversation(uuid,text,text,text,uuid)',
    'public.support_authorize_attachment_upload(uuid,uuid,text,text,integer,text,text,uuid,uuid)',
    'public.support_submit_attachment(uuid)',
    'public.support_authorize_attachment_url(uuid,uuid)',
    'public.support_staff_list_queue(text,boolean,integer)',
    'public.support_staff_get_ticket_thread(uuid)',
    'public.support_staff_list_conversations(smallint,integer)',
    'public.support_staff_get_conversation(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', signature);
    execute format('grant execute on function %s to authenticated, service_role', signature);
  end loop;
end $$;

revoke all on function public.support_server_record_assistant(
  uuid, uuid, text, text, smallint, text, uuid[], uuid, uuid
) from public, anon, authenticated;
grant execute on function public.support_server_record_assistant(
  uuid, uuid, text, text, smallint, text, uuid[], uuid, uuid
) to service_role;

revoke all on function public.support_run_retention_cleanup(integer)
from public, anon, authenticated;
grant execute on function public.support_run_retention_cleanup(integer)
to service_role;
revoke all on function public.support_record_evaluation(
  uuid, text, text, text, text, text, boolean, numeric, jsonb
) from public, anon, authenticated;
grant execute on function public.support_record_evaluation(
  uuid, text, text, text, text, text, boolean, numeric, jsonb
) to service_role;

-- The service role may use generated identity sequences; clients never can.
grant usage, select on sequence public.support_ticket_events_id_seq,
  public.support_ai_evaluations_id_seq, public.support_action_audit_id_seq,
  public.support_rate_limits_id_seq to service_role;
