-- MORT AI Safety Foundation Schema

create table if not exists public.ai_moderation_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  resource_type text not null,
  resource_id text not null,
  content text,
  detected_flags text[] not null default '{}',
  ai_provider text,
  fallback_used boolean not null default false,
  status text not null default 'pending_review',
  created_at timestamptz not null default now()
);

create table if not exists public.ai_risk_scores (
  user_id uuid not null references public.profiles(id) on delete cascade,
  job_id uuid references public.jobs(id) on delete cascade,
  score numeric not null check (score >= 0.0 and score <= 1.0),
  factors jsonb not null default '{}',
  calculated_at timestamptz not null default now(),
  primary key (user_id, job_id)
);

create table if not exists public.ai_recommendation_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  recommended_job_ids uuid[] not null default '{}',
  generated_at timestamptz not null default now()
);

create table if not exists public.ai_support_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  context jsonb not null default '{}',
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create table if not exists public.ai_model_audit_logs (
  id uuid primary key default gen_random_uuid(),
  model_name text not null,
  input_hash text,
  output_hash text,
  latency_ms integer,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_rule_matches (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.ai_moderation_events(id) on delete cascade,
  rule_name text not null,
  matched_text text,
  created_at timestamptz not null default now()
);

alter table public.ai_moderation_events enable row level security;
alter table public.ai_risk_scores enable row level security;
alter table public.ai_recommendation_events enable row level security;
alter table public.ai_support_sessions enable row level security;
alter table public.ai_model_audit_logs enable row level security;
alter table public.ai_rule_matches enable row level security;

-- RLS: users see only their own allowed AI safety outputs
create policy ai_moderation_events_select_own on public.ai_moderation_events
for select to authenticated using (user_id = (select auth.uid()) or public.is_admin());

create policy ai_risk_scores_select_own on public.ai_risk_scores
for select to authenticated using (user_id = (select auth.uid()) or public.is_admin());

create policy ai_recommendation_events_select_own on public.ai_recommendation_events
for select to authenticated using (user_id = (select auth.uid()) or public.is_admin());

create policy ai_support_sessions_select_own on public.ai_support_sessions
for select to authenticated using (user_id = (select auth.uid()) or public.is_admin());

create policy ai_rule_matches_select_own on public.ai_rule_matches
for select to authenticated using (
  exists (
    select 1 from public.ai_moderation_events ame
    where ame.id = event_id and (ame.user_id = (select auth.uid()) or public.is_admin())
  )
);

create policy ai_model_audit_logs_select_admin on public.ai_model_audit_logs
for select to authenticated using (public.is_admin());

-- Insert policies (usually handled by Edge Functions via service_role, but allow authenticated for client-side triggering)
create policy ai_support_sessions_insert on public.ai_support_sessions
for insert to authenticated with check (user_id = (select auth.uid()));

create policy ai_moderation_events_admin_all on public.ai_moderation_events
for all to authenticated using (public.is_admin()) with check (public.is_admin());
