-- MORT Guide: deterministic FAQ mode, private history, consent, safety, and
-- provider audit foundations. External AI remains server-controlled and off.

create table public.ai_runtime_controls (
  id boolean primary key default true check (id),
  mode text not null default 'faq_only'
    check (mode in ('disabled', 'faq_only', 'sandbox', 'production')),
  external_provider_enabled boolean not null default false,
  provider_circuit_open boolean not null default false,
  retention_days integer not null default 30 check (retention_days between 1 and 90),
  daily_user_requests integer not null default 20 check (daily_user_requests between 1 and 100),
  monthly_user_requests integer not null default 300 check (monthly_user_requests between 1 and 2000),
  global_daily_budget_usd numeric(10, 4) not null default 0
    check (global_daily_budget_usd >= 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

insert into public.ai_runtime_controls (id)
values (true)
on conflict (id) do nothing;

create table public.ai_processing_consents (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  status text not null default 'not_requested'
    check (status in (
      'not_applicable', 'not_requested', 'pending', 'approved', 'declined',
      'expired', 'provider_not_available'
    )),
  requested_at timestamptz,
  decided_at timestamptz,
  expires_at timestamptz,
  withdrawn_at timestamptz,
  decision_source text,
  updated_at timestamptz not null default now()
);

create table public.ai_knowledge_sources (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]{3,80}$'),
  title text not null check (char_length(title) between 3 and 120),
  source_url text not null check (source_url ~ '^https://'),
  source_type text not null check (source_type in ('help', 'policy', 'safety', 'legal_summary', 'resource')),
  version text not null,
  effective_date date not null,
  audience text[] not null default array['all']::text[],
  jurisdiction text not null default 'US-general',
  approval_status text not null default 'approved'
    check (approval_status in ('draft', 'approved', 'retired')),
  review_due_at date not null,
  keywords text[] not null default '{}'::text[],
  answer_text text not null check (char_length(answer_text) between 20 and 2000),
  navigation_route text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default 'MORT Guide conversation'
    check (char_length(title) between 3 and 120),
  mode text not null check (mode in ('faq_only', 'sandbox', 'production')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  retention_until timestamptz not null default (now() + interval '30 days')
);

create table public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (char_length(content) between 1 and 4000),
  source_id uuid references public.ai_knowledge_sources(id) on delete set null,
  provider_generated boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  conversation_id uuid references public.ai_conversations(id) on delete set null,
  client_request_id uuid not null,
  mode text not null check (mode in ('faq_only', 'sandbox', 'production')),
  input_characters integer not null default 0 check (input_characters >= 0),
  input_tokens integer check (input_tokens is null or input_tokens >= 0),
  output_tokens integer check (output_tokens is null or output_tokens >= 0),
  estimated_cost_usd numeric(10, 6) check (estimated_cost_usd is null or estimated_cost_usd >= 0),
  provider_called boolean not null default false,
  outcome text not null,
  created_at timestamptz not null default now(),
  unique (user_id, client_request_id)
);

create table public.ai_safety_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  conversation_id uuid references public.ai_conversations(id) on delete set null,
  direction text not null check (direction in ('input', 'output')),
  category text not null,
  action text not null check (action in ('allowed', 'faq_redirect', 'blocked', 'safety_escalation')),
  scanner text not null,
  requires_adult_review boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.ai_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  message_id uuid not null references public.ai_messages(id) on delete cascade,
  rating text not null check (rating in ('helpful', 'not_helpful', 'unsafe')),
  comment text check (comment is null or char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  unique (user_id, message_id)
);

create table public.ai_provider_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  conversation_id uuid references public.ai_conversations(id) on delete set null,
  provider text not null,
  model text,
  request_hash text,
  response_hash text,
  provider_request_id text,
  store_disabled boolean not null default true,
  moderation_input_passed boolean not null default false,
  moderation_output_passed boolean not null default false,
  outcome text not null,
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  created_at timestamptz not null default now()
);

create table public.ai_human_review_escalations (
  id uuid primary key default gen_random_uuid(),
  safety_event_id uuid not null references public.ai_safety_events(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'reviewing', 'resolved', 'dismissed')),
  assigned_to uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index ai_conversations_user_updated_idx on public.ai_conversations(user_id, updated_at desc);
create index ai_messages_conversation_created_idx on public.ai_messages(conversation_id, created_at);
create index ai_usage_user_created_idx on public.ai_usage_events(user_id, created_at desc);
create index ai_safety_review_idx on public.ai_safety_events(requires_adult_review, created_at desc)
where requires_adult_review;
create index ai_provider_created_idx on public.ai_provider_events(created_at desc);

alter table public.ai_runtime_controls enable row level security;
alter table public.ai_processing_consents enable row level security;
alter table public.ai_knowledge_sources enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_usage_events enable row level security;
alter table public.ai_safety_events enable row level security;
alter table public.ai_feedback enable row level security;
alter table public.ai_provider_events enable row level security;
alter table public.ai_human_review_escalations enable row level security;

alter table public.ai_runtime_controls force row level security;
alter table public.ai_processing_consents force row level security;
alter table public.ai_knowledge_sources force row level security;
alter table public.ai_conversations force row level security;
alter table public.ai_messages force row level security;
alter table public.ai_usage_events force row level security;
alter table public.ai_safety_events force row level security;
alter table public.ai_feedback force row level security;
alter table public.ai_provider_events force row level security;
alter table public.ai_human_review_escalations force row level security;

create policy ai_processing_consents_read_own on public.ai_processing_consents
for select to authenticated using (user_id = (select auth.uid()));
create policy ai_conversations_read_own on public.ai_conversations
for select to authenticated using (user_id = (select auth.uid()));
create policy ai_messages_read_own on public.ai_messages
for select to authenticated using (user_id = (select auth.uid()));
create policy ai_feedback_read_own on public.ai_feedback
for select to authenticated using (user_id = (select auth.uid()));

revoke all on public.ai_runtime_controls from public, anon, authenticated;
revoke all on public.ai_processing_consents from public, anon, authenticated;
revoke all on public.ai_knowledge_sources from public, anon, authenticated;
revoke all on public.ai_conversations from public, anon, authenticated;
revoke all on public.ai_messages from public, anon, authenticated;
revoke all on public.ai_usage_events from public, anon, authenticated;
revoke all on public.ai_safety_events from public, anon, authenticated;
revoke all on public.ai_feedback from public, anon, authenticated;
revoke all on public.ai_provider_events from public, anon, authenticated;
revoke all on public.ai_human_review_escalations from public, anon, authenticated;

grant select on public.ai_processing_consents, public.ai_conversations,
  public.ai_messages, public.ai_feedback to authenticated;
grant all on public.ai_runtime_controls, public.ai_processing_consents,
  public.ai_knowledge_sources, public.ai_conversations, public.ai_messages,
  public.ai_usage_events, public.ai_safety_events, public.ai_feedback,
  public.ai_provider_events, public.ai_human_review_escalations to service_role;

insert into public.ai_knowledge_sources (
  slug, title, source_url, source_type, version, effective_date, audience,
  jurisdiction, approval_status, review_due_at, keywords, answer_text,
  navigation_route
) values
  ('getting-started', 'Getting started with MORT', 'https://mort.app/help/getting-started', 'help', '1.0', current_date, array['all'], 'US-general', 'approved', current_date + 90, array['start','how','mort','role','account'], 'MORT helps teens find approved local opportunities and lets adults post and review jobs. Your account role and age eligibility are server-controlled. Start with onboarding, then use the job feed or job-posting tools available to your role.', '/home'),
  ('jobs-applications', 'Jobs and applications', 'https://mort.app/help/jobs-and-applications', 'help', '1.0', current_date, array['teen','adult'], 'US-general', 'approved', current_date + 90, array['job','apply','application','hire','applicant'], 'Teens can browse eligible pilot jobs and apply without paying. Adults review applications and make their own hiring decisions. MORT Guide does not rank applicants or decide who gets a job.', '/jobs'),
  ('contracts-completion', 'Contracts and completion checks', 'https://mort.app/help/contracts-and-completion', 'help', '1.0', current_date, array['teen','adult'], 'US-general', 'approved', current_date + 90, array['contract','start','complete','proof','finish'], 'Review the job terms before accepting. Start and completion checks record each participant action separately. Proof uploads should contain only the requested work result and must not include unrelated personal information.', '/contracts'),
  ('payment-status', 'Job payment status and disputes', 'https://mort.app/help/payments', 'policy', '1.0', current_date, array['teen','adult'], 'US-general', 'approved', current_date + 60, array['payment','paid','money','refund','dispute','cash'], 'Job payment status comes from the server and payment provider, not from a client confirmation screen. MORT does not guarantee payment. Use the contract payment timeline and dispute route when a payment is missing or incorrect.', '/contracts'),
  ('reports-blocking', 'Reports, blocking, and Safety Center', 'https://mort.app/help/safety', 'safety', '1.0', current_date, array['all'], 'US-general', 'approved', current_date + 30, array['report','block','unsafe','safety','harass','threat'], 'Reporting, blocking, and Safety Ping remain free. Blocking limits contact in MORT; a report sends the concern for human review. For immediate danger, contact local emergency services. MORT Guide cannot dispatch help.', '/safety'),
  ('account-deletion', 'Delete your MORT account', 'https://mort.app/help/account-deletion', 'help', '1.0', current_date, array['all'], 'US-general', 'approved', current_date + 90, array['delete','close','remove','history','privacy'], 'Open Account settings and choose Delete account. The app explains the request and retention process before submission. You can separately delete one MORT Guide conversation or all MORT Guide history.', '/settings/account'),
  ('mort-plus', 'MORT Plus optional perks', 'https://mort.app/help/mort-plus', 'help', '1.0', current_date, array['all'], 'US-general', 'approved', current_date + 90, array['plus','premium','subscription','theme','price','purchase'], 'MORT Plus is optional and covers cosmetic or convenience perks. Browsing, applying, posting, contracts, messaging, reporting, blocking, Guardian Mode basics, and safety help stay available without a subscription. Store prices must come from Google Play.', '/monetization'),
  ('message-help', 'Writing clear job messages', 'https://mort.app/help/messages', 'help', '1.0', current_date, array['teen','adult'], 'US-general', 'approved', current_date + 90, array['message','write','draft','professional','reply'], 'Keep job messages accurate and specific: confirm the task, public meeting details, timing, supplies, and payment terms. Do not claim experience you do not have, move conversations off-platform to bypass safety controls, or share passwords and exact home addresses.', '/messages'),
  ('emergency-guidance', 'Immediate safety guidance', 'https://mort.app/help/immediate-safety', 'safety', '1.0', current_date, array['all'], 'US-general', 'approved', current_date + 30, array['emergency','danger','suicide','kidnap','weapon','violence'], 'If you or someone else may be in immediate danger, stop the job or conversation, move to a safer place when you can, and contact local emergency services. Use MORT Safety Center to report or block. MORT has not dispatched help and cannot replace emergency services.', '/safety')
on conflict (slug) do update set
  title = excluded.title,
  source_url = excluded.source_url,
  version = excluded.version,
  effective_date = excluded.effective_date,
  audience = excluded.audience,
  jurisdiction = excluded.jurisdiction,
  approval_status = excluded.approval_status,
  review_due_at = excluded.review_due_at,
  keywords = excluded.keywords,
  answer_text = excluded.answer_text,
  navigation_route = excluded.navigation_route,
  updated_at = now();

create or replace function public.get_mort_guide_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_control public.ai_runtime_controls%rowtype;
  v_consent text;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_control from public.ai_runtime_controls where id;
  select status into v_consent from public.ai_processing_consents where user_id = auth.uid();
  return jsonb_build_object(
    'ok', true,
    'mode', v_control.mode,
    'external_provider_available', v_control.external_provider_enabled and not v_control.provider_circuit_open,
    'consent_status', coalesce(v_consent, case when public.current_profile_role() = 'teen' then 'not_requested' else 'not_applicable' end),
    'retention_days', v_control.retention_days,
    'daily_request_limit', v_control.daily_user_requests,
    'privacy_warning', 'Do not share IDs, passwords, exact addresses, or emergency evidence.'
  );
end;
$$;

create or replace function public.update_my_ai_consent(p_action text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_status text;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_action not in ('request', 'decline', 'withdraw') then
    return jsonb_build_object('ok', false, 'code', 'invalid_action');
  end if;
  v_status := case when p_action = 'request' then 'pending' else 'declined' end;
  insert into public.ai_processing_consents (
    user_id, status, requested_at, decided_at, withdrawn_at, decision_source
  ) values (
    auth.uid(), v_status,
    case when p_action = 'request' then now() else null end,
    case when p_action = 'decline' then now() else null end,
    case when p_action = 'withdraw' then now() else null end,
    'user'
  )
  on conflict (user_id) do update set
    status = excluded.status,
    requested_at = coalesce(excluded.requested_at, ai_processing_consents.requested_at),
    decided_at = excluded.decided_at,
    withdrawn_at = excluded.withdrawn_at,
    decision_source = excluded.decision_source,
    updated_at = now();
  return jsonb_build_object('ok', true, 'status', v_status);
end;
$$;

create or replace function public.ask_mort_guide_faq(
  p_question text,
  p_conversation_id uuid default null,
  p_client_request_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_question text := btrim(coalesce(p_question, ''));
  v_control public.ai_runtime_controls%rowtype;
  v_conversation public.ai_conversations%rowtype;
  v_source public.ai_knowledge_sources%rowtype;
  v_answer_message_id uuid;
  v_danger boolean;
  v_sensitive boolean;
  v_high_stakes boolean;
  v_outcome text := 'answered';
  v_existing jsonb;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(v_question) not between 3 and 500 then
    return jsonb_build_object('ok', false, 'code', 'invalid_question');
  end if;
  select jsonb_build_object('ok', true, 'replayed', true, 'conversation_id', u.conversation_id)
    into v_existing
    from public.ai_usage_events u
    where u.user_id = auth.uid() and u.client_request_id = p_client_request_id;
  if v_existing is not null then return v_existing; end if;

  select * into v_control from public.ai_runtime_controls where id;
  if v_control.mode = 'disabled' then
    return jsonb_build_object('ok', false, 'code', 'mort_guide_disabled');
  end if;
  if not public.check_rate_limit('mort_guide_request', v_control.daily_user_requests, 86400) then
    return jsonb_build_object('ok', false, 'code', 'daily_limit_reached');
  end if;
  if (select count(*) from public.ai_usage_events where user_id = auth.uid() and created_at >= date_trunc('month', now())) >= v_control.monthly_user_requests then
    return jsonb_build_object('ok', false, 'code', 'monthly_limit_reached');
  end if;

  if p_conversation_id is null then
    insert into public.ai_conversations (user_id, mode, retention_until)
    values (auth.uid(), 'faq_only', now() + make_interval(days => v_control.retention_days))
    returning * into v_conversation;
  else
    select * into v_conversation from public.ai_conversations
      where id = p_conversation_id and user_id = auth.uid();
    if not found then return jsonb_build_object('ok', false, 'code', 'conversation_not_found'); end if;
  end if;

  v_danger := v_question ~* '(suicid|kill myself|kill someone|kidnap|immediate danger|weapon|gun|being followed|traffick)';
  v_sensitive := v_question ~* '(password|social security|ssn|passport|driver.?s license|exact address|auth token|card number|cvc)';
  v_high_stakes := v_question ~* '(who should i hire|rank (the )?applicants|approve (my )?id|decide (the )?dispute|is this person dangerous|medical diagnosis|legal representation)';

  select * into v_source
  from public.ai_knowledge_sources source
  where source.approval_status = 'approved'
    and source.effective_date <= current_date
    and source.review_due_at >= current_date
    and (
      (v_danger and source.slug = 'emergency-guidance')
      or (v_high_stakes and source.slug = 'getting-started')
      or exists (
        select 1 from unnest(source.keywords) keyword
        where lower(v_question) like '%' || lower(keyword) || '%'
      )
    )
  order by
    case when v_danger and source.slug = 'emergency-guidance' then 0
         when v_high_stakes and source.slug = 'getting-started' then 0 else 1 end,
    source.slug
  limit 1;
  if not found then
    select * into v_source from public.ai_knowledge_sources where slug = 'getting-started';
  end if;

  if v_sensitive then
    v_source.answer_text := 'Please do not send IDs, passwords, exact addresses, payment credentials, authentication tokens, or emergency evidence to MORT Guide. Remove that information and ask a general navigation question instead.';
    v_outcome := 'sensitive_data_redirect';
  elsif v_high_stakes then
    v_source.answer_text := 'MORT Guide cannot rank applicants, approve identity, decide moderation or payment disputes, determine that someone is dangerous, or provide legal or medical decisions. Use the relevant human review or support route.';
    v_outcome := 'high_stakes_redirect';
  elsif v_danger then
    v_outcome := 'safety_escalation';
  end if;

  insert into public.ai_messages (conversation_id, user_id, role, content)
  values (v_conversation.id, auth.uid(), 'user', v_question);
  insert into public.ai_messages (conversation_id, user_id, role, content, source_id)
  values (v_conversation.id, auth.uid(), 'assistant', v_source.answer_text, v_source.id)
  returning id into v_answer_message_id;

  insert into public.ai_safety_events (
    user_id, conversation_id, direction, category, action, scanner, requires_adult_review
  ) values (
    auth.uid(), v_conversation.id, 'input',
    case when v_danger then 'immediate_danger' when v_sensitive then 'sensitive_data' when v_high_stakes then 'high_stakes_decision' else 'none' end,
    case when v_danger then 'safety_escalation' when v_sensitive or v_high_stakes then 'faq_redirect' else 'allowed' end,
    'mort_deterministic_v1', v_danger
  );
  if v_danger and public.current_profile_role() <> 'teen' then
    insert into public.ai_human_review_escalations (safety_event_id)
    select id from public.ai_safety_events
    where user_id = auth.uid() and conversation_id = v_conversation.id
    order by created_at desc limit 1;
  end if;
  insert into public.ai_usage_events (
    user_id, conversation_id, client_request_id, mode, input_characters,
    provider_called, outcome
  ) values (
    auth.uid(), v_conversation.id, p_client_request_id, 'faq_only',
    char_length(v_question), false, v_outcome
  );
  perform public.record_rate_limit_event('mort_guide_request');
  update public.ai_conversations set updated_at = now() where id = v_conversation.id;

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'mode', 'faq_only',
    'conversation_id', v_conversation.id,
    'message_id', v_answer_message_id,
    'answer', v_source.answer_text,
    'source', jsonb_build_object(
      'title', v_source.title, 'url', v_source.source_url,
      'version', v_source.version, 'route', v_source.navigation_route
    ),
    'safety_escalation', v_danger,
    'warning', 'AI may make mistakes. MORT Guide is not emergency, legal, or medical assistance.'
  );
end;
$$;

create or replace function public.list_my_mort_guide_conversations()
returns table (id uuid, title text, mode text, created_at timestamptz, updated_at timestamptz)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select c.id, c.title, c.mode, c.created_at, c.updated_at
  from public.ai_conversations c
  where c.user_id = auth.uid()
  order by c.updated_at desc;
$$;

create or replace function public.get_my_mort_guide_messages(p_conversation_id uuid)
returns table (
  id uuid, role text, content text, provider_generated boolean,
  created_at timestamptz, source_title text, source_url text, source_route text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select m.id, m.role, m.content, m.provider_generated, m.created_at,
         source.title, source.source_url, source.navigation_route
  from public.ai_messages m
  left join public.ai_knowledge_sources source on source.id = m.source_id
  where m.conversation_id = p_conversation_id and m.user_id = auth.uid()
  order by m.created_at;
$$;

create or replace function public.delete_my_mort_guide_conversation(p_conversation_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.ai_conversations where id = p_conversation_id and user_id = auth.uid();
  return found;
end;
$$;

create or replace function public.delete_all_my_mort_guide_history()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_count integer;
begin
  delete from public.ai_conversations where user_id = auth.uid();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.export_my_mort_guide_history()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'conversation_id', c.id,
    'title', c.title,
    'mode', c.mode,
    'created_at', c.created_at,
    'messages', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'role', m.role, 'content', m.content, 'created_at', m.created_at
      ) order by m.created_at), '[]'::jsonb)
      from public.ai_messages m where m.conversation_id = c.id
    )
  ) order by c.created_at), '[]'::jsonb)
  from public.ai_conversations c where c.user_id = auth.uid();
$$;

create or replace function public.submit_mort_guide_feedback(
  p_message_id uuid,
  p_rating text,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_rating not in ('helpful', 'not_helpful', 'unsafe') then
    return jsonb_build_object('ok', false, 'code', 'invalid_rating');
  end if;
  if not exists (
    select 1 from public.ai_messages where id = p_message_id and user_id = auth.uid() and role = 'assistant'
  ) then
    return jsonb_build_object('ok', false, 'code', 'message_not_found');
  end if;
  insert into public.ai_feedback (user_id, message_id, rating, comment)
  values (auth.uid(), p_message_id, p_rating, nullif(btrim(p_comment), ''))
  on conflict (user_id, message_id) do update
  set rating = excluded.rating, comment = excluded.comment, created_at = now();
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.expire_mort_guide_history()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_count integer;
begin
  delete from public.ai_conversations where retention_until <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.get_mort_guide_config() from public, anon;
revoke execute on function public.update_my_ai_consent(text) from public, anon;
revoke execute on function public.ask_mort_guide_faq(text, uuid, uuid) from public, anon;
revoke execute on function public.list_my_mort_guide_conversations() from public, anon;
revoke execute on function public.get_my_mort_guide_messages(uuid) from public, anon;
revoke execute on function public.delete_my_mort_guide_conversation(uuid) from public, anon;
revoke execute on function public.delete_all_my_mort_guide_history() from public, anon;
revoke execute on function public.export_my_mort_guide_history() from public, anon;
revoke execute on function public.submit_mort_guide_feedback(uuid, text, text) from public, anon;
revoke execute on function public.expire_mort_guide_history() from public, anon, authenticated;

grant execute on function public.get_mort_guide_config() to authenticated, service_role;
grant execute on function public.update_my_ai_consent(text) to authenticated, service_role;
grant execute on function public.ask_mort_guide_faq(text, uuid, uuid) to authenticated, service_role;
grant execute on function public.list_my_mort_guide_conversations() to authenticated, service_role;
grant execute on function public.get_my_mort_guide_messages(uuid) to authenticated, service_role;
grant execute on function public.delete_my_mort_guide_conversation(uuid) to authenticated, service_role;
grant execute on function public.delete_all_my_mort_guide_history() to authenticated, service_role;
grant execute on function public.export_my_mort_guide_history() to authenticated, service_role;
grant execute on function public.submit_mort_guide_feedback(uuid, text, text) to authenticated, service_role;
grant execute on function public.expire_mort_guide_history() to service_role;
