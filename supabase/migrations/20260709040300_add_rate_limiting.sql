-- MORT rate limiting schema.
create table if not exists public.rate_limit_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  action text not null,
  ip_address text,
  created_at timestamptz not null default now()
);

create table if not exists public.user_action_counters (
  user_id uuid not null references public.profiles(id) on delete cascade,
  action text not null,
  count integer not null default 0,
  last_action_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, action)
);

create table if not exists public.abuse_flags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  reason text not null,
  action text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.moderation_events (
  id uuid primary key default gen_random_uuid(),
  target_user_id uuid references public.profiles(id) on delete set null,
  moderator_id uuid references public.profiles(id) on delete set null,
  action_taken text not null,
  notes text,
  created_at timestamptz not null default now()
);

create index rate_limit_events_action_idx on public.rate_limit_events(user_id, action, created_at desc);

create trigger user_action_counters_set_updated_at before update on public.user_action_counters
for each row execute function public.set_updated_at();

alter table public.rate_limit_events enable row level security;
alter table public.user_action_counters enable row level security;
alter table public.abuse_flags enable row level security;
alter table public.moderation_events enable row level security;

create policy rate_limit_events_admin on public.rate_limit_events
for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy user_action_counters_admin on public.user_action_counters
for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy abuse_flags_admin on public.abuse_flags
for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy moderation_events_admin on public.moderation_events
for all to authenticated using (public.is_admin()) with check (public.is_admin());

create or replace function public.check_rate_limit(p_action text, p_limit integer, p_window_seconds integer)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_count integer;
begin
  if v_user_id is null then return false; end if;
  
  select count(*) into v_count
  from public.rate_limit_events
  where user_id = v_user_id
    and action = p_action
    and created_at >= now() - (p_window_seconds || ' seconds')::interval;
    
  return v_count < p_limit;
end;
$$;

create or replace function public.record_rate_limit_event(p_action text, p_ip_address text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then return; end if;
  
  insert into public.rate_limit_events (user_id, action, ip_address)
  values (v_user_id, p_action, p_ip_address);
  
  insert into public.user_action_counters (user_id, action, count, last_action_at)
  values (v_user_id, p_action, 1, now())
  on conflict (user_id, action) do update
  set count = public.user_action_counters.count + 1,
      last_action_at = now();
end;
$$;

create or replace function public.is_action_allowed(p_action text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer;
  v_window integer;
begin
  case p_action
    when 'username_change' then
      v_limit := 2; v_window := 86400 * 30; -- 2 per 30 days
    when 'job_post_create' then
      v_limit := 10; v_window := 86400; -- 10 per day
    when 'job_application_create' then
      v_limit := 20; v_window := 86400; -- 20 per day
    when 'message_send' then
      v_limit := 500; v_window := 86400; -- 500 per day
    when 'report_create' then
      v_limit := 5; v_window := 3600; -- 5 per hour
    else
      v_limit := 100; v_window := 3600; -- Default fallback
  end case;
  
  return public.check_rate_limit(p_action, v_limit, v_window);
end;
$$;

create or replace function public.admin_rate_limit_overview()
returns table (
  action text,
  total_events bigint,
  unique_users bigint
)
language sql
security definer
set search_path = public
stable
as $$
  select
    action,
    count(*),
    count(distinct user_id)
  from public.rate_limit_events
  where created_at >= now() - interval '24 hours'
  group by action;
$$;

grant execute on function public.check_rate_limit(text, integer, integer) to authenticated;
grant execute on function public.record_rate_limit_event(text, text) to authenticated;
grant execute on function public.is_action_allowed(text) to authenticated;
grant execute on function public.admin_rate_limit_overview() to authenticated;
