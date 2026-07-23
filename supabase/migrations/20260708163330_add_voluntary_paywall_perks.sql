-- MORT voluntary paywall perks additive schema.
-- Adds username credits, profile style unlocks, saved job folders, and related RPCs.
-- No drops, resets, or destructive changes.

alter table public.profiles add column if not exists username text;

create unique index if not exists profiles_username_lower_unique_idx
on public.profiles (lower(username))
where username is not null;

create table if not exists public.username_change_credits (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  free_changes_used integer not null default 0 check (free_changes_used between 0 and 3),
  token_credits integer not null default 0 check (token_credits >= 0),
  admin_credits integer not null default 0 check (admin_credits >= 0),
  plus_period_start date,
  plus_changes_used integer not null default 0 check (plus_changes_used >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.username_change_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  old_username text,
  new_username text not null,
  source text not null check (source in ('free', 'plus_allowance', 'token', 'admin_credit', 'admin_override')),
  status text not null default 'completed' check (status in ('completed', 'rejected', 'flagged', 'reverted')),
  moderation_reason text,
  created_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz
);

create table if not exists public.username_reservations (
  username text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reserved_at timestamptz not null default now(),
  released_at timestamptz
);

create table if not exists public.username_moderation_flags (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.username_change_events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  flag_type text not null,
  flagged_text text not null,
  resolved boolean not null default false,
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.profile_theme_unlocks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  theme_key text not null,
  source text not null default 'revenuecat',
  created_at timestamptz not null default now(),
  primary key (user_id, theme_key)
);

create table if not exists public.user_profile_theme_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  theme_key text,
  border_style text,
  accent_color text,
  background_pattern text,
  updated_at timestamptz not null default now()
);

create table if not exists public.user_saved_job_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  color text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_saved_job_folders_name_length check (char_length(btrim(name)) between 1 and 60)
);

create table if not exists public.saved_job_folder_items (
  folder_id uuid not null references public.user_saved_job_folders(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (folder_id, job_id)
);

create index if not exists username_change_events_user_idx on public.username_change_events(user_id, created_at desc);
create index if not exists username_moderation_flags_user_idx on public.username_moderation_flags(user_id, created_at desc);
create index if not exists username_moderation_flags_open_idx on public.username_moderation_flags(resolved, created_at desc);
create index if not exists profile_theme_unlocks_user_idx on public.profile_theme_unlocks(user_id, created_at desc);
create index if not exists user_saved_job_folders_user_idx on public.user_saved_job_folders(user_id, created_at desc);
create index if not exists saved_job_folder_items_user_idx on public.saved_job_folder_items(user_id, created_at desc);
create index if not exists saved_job_folder_items_job_idx on public.saved_job_folder_items(job_id);

create trigger username_change_credits_set_updated_at before update on public.username_change_credits
for each row execute function public.set_updated_at();

create trigger user_profile_theme_settings_set_updated_at before update on public.user_profile_theme_settings
for each row execute function public.set_updated_at();

create trigger user_saved_job_folders_set_updated_at before update on public.user_saved_job_folders
for each row execute function public.set_updated_at();

create or replace function public.protect_direct_username_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  internal_update text := current_setting('mort.internal_update', true);
begin
  if tg_op = 'UPDATE' and old.username is distinct from new.username then
    if public.is_admin() or internal_update = 'true' then
      return new;
    end if;

    raise exception 'Username changes must use the username change flow.';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_protect_direct_username on public.profiles;
create trigger profiles_protect_direct_username
before update of username on public.profiles
for each row execute function public.protect_direct_username_update();

alter table public.username_change_credits enable row level security;
alter table public.username_change_events enable row level security;
alter table public.username_reservations enable row level security;
alter table public.username_moderation_flags enable row level security;
alter table public.profile_theme_unlocks enable row level security;
alter table public.user_profile_theme_settings enable row level security;
alter table public.user_saved_job_folders enable row level security;
alter table public.saved_job_folder_items enable row level security;

create policy username_change_credits_select_own_or_admin on public.username_change_credits
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy username_change_credits_admin_write on public.username_change_credits
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy username_change_events_select_own_or_admin on public.username_change_events
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy username_change_events_admin_update on public.username_change_events
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy username_reservations_select_own_or_admin on public.username_reservations
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy username_reservations_admin_write on public.username_reservations
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy username_moderation_flags_select_own_or_admin on public.username_moderation_flags
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy username_moderation_flags_admin_update on public.username_moderation_flags
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy profile_theme_unlocks_select_own_or_admin on public.profile_theme_unlocks
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy profile_theme_unlocks_admin_write on public.profile_theme_unlocks
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy user_profile_theme_settings_select_own_or_admin on public.user_profile_theme_settings
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy user_profile_theme_settings_upsert_own on public.user_profile_theme_settings
for all to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());

create policy user_saved_job_folders_select_own_or_admin on public.user_saved_job_folders
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy user_saved_job_folders_write_own on public.user_saved_job_folders
for all to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());

create policy saved_job_folder_items_select_own_or_admin on public.saved_job_folder_items
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy saved_job_folder_items_write_own on public.saved_job_folder_items
for all to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.user_saved_job_folders f
    where f.id = folder_id and f.user_id = (select auth.uid())
  )
  or public.is_admin()
)
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.user_saved_job_folders f
    where f.id = folder_id and f.user_id = (select auth.uid())
  )
  or public.is_admin()
);

create or replace function public.normalize_username(p_username text)
returns text
language sql
immutable
as $$
  select lower(regexp_replace(btrim(coalesce(p_username, '')), '\s+', '_', 'g'));
$$;

create or replace function public.validate_username(p_username text)
returns text
language plpgsql
immutable
as $$
declare
  cleaned text := public.normalize_username(p_username);
begin
  if cleaned is null or cleaned = '' then
    return 'Username is required.';
  end if;

  if char_length(cleaned) < 3 or char_length(cleaned) > 24 then
    return 'Username must be 3 to 24 characters.';
  end if;

  if cleaned !~ '^[a-z0-9_]+$' then
    return 'Username can use lowercase letters, numbers, and underscores only.';
  end if;

  if cleaned ~ '(^|_)(admin|administrator|mod|moderator|support|staff|mort|official|safety|help)(_|$)' then
    return 'Username cannot impersonate MORT staff or support.';
  end if;

  if cleaned ~ '(fuck|shit|bitch|asshole|slur|nazi|kill|suicide|sex|porn)' then
    return 'Username is not allowed by the safety scanner.';
  end if;

  if cleaned ~ '[0-9]{7,}' then
    return 'Username cannot include phone-number-like contact info.';
  end if;

  if cleaned ~ '(@|gmail|yahoo|icloud|outlook|hotmail|cashapp|venmo|snap|instagram|insta|tiktok|discord)' then
    return 'Username cannot include contact handles or payment handles.';
  end if;

  if cleaned like '$%' then
    return 'Username cannot include a payment tag.';
  end if;

  return null;
end;
$$;

create or replace function public.get_username_change_status()
returns table (
  current_username text,
  free_changes_used integer,
  free_changes_remaining integer,
  token_credits integer,
  admin_credits integer,
  plus_allowance_available boolean,
  plus_changes_used integer,
  plus_period_start date
)
language sql
security definer
set search_path = public
stable
as $$
  with me as (
    select p.id, p.username
    from public.profiles p
    where p.id = (select auth.uid())
  ), credits as (
    select c.*
    from public.username_change_credits c
    join me on me.id = c.user_id
  ), entitlement_state as (
    select exists (
      select 1
      from public.monetization_entitlements_cache mec
      join me on me.id = mec.user_id
      where mec.entitlements && array['mort_plus', 'mort_lifetime', 'mort_premium']
    ) as has_plus
  )
  select
    me.username,
    coalesce(credits.free_changes_used, 0),
    greatest(0, 3 - coalesce(credits.free_changes_used, 0)),
    coalesce(credits.token_credits, 0),
    coalesce(credits.admin_credits, 0),
    (
      (select has_plus from entitlement_state)
      and (
        credits.plus_period_start is null
        or credits.plus_period_start < date_trunc('month', now())::date
        or coalesce(credits.plus_changes_used, 0) < 1
      )
    ) as plus_allowance_available,
    coalesce(credits.plus_changes_used, 0),
    credits.plus_period_start
  from me
  left join credits on credits.user_id = me.id;
$$;

create or replace function public.request_username_change(p_new_username text)
returns table (
  username text,
  source text,
  free_changes_remaining integer,
  token_credits integer,
  admin_credits integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_new_username text := public.normalize_username(p_new_username);
  v_old_username text;
  v_reason text;
  v_credits public.username_change_credits%rowtype;
  v_source text;
  v_has_plus boolean := false;
  v_month date := date_trunc('month', now())::date;
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;

  v_reason := public.validate_username(v_new_username);
  if v_reason is not null then
    raise exception '%', v_reason;
  end if;

  select username into v_old_username from public.profiles where id = v_user_id;
  if v_old_username is not distinct from v_new_username then
    raise exception 'That is already your username.';
  end if;

  if exists (
    select 1 from public.profiles
    where lower(username) = v_new_username and id <> v_user_id
  ) then
    raise exception 'That username is already taken.';
  end if;

  insert into public.username_change_credits (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select * into v_credits
  from public.username_change_credits
  where user_id = v_user_id
  for update;

  select exists (
    select 1
    from public.monetization_entitlements_cache
    where user_id = v_user_id
      and entitlements && array['mort_plus', 'mort_lifetime', 'mort_premium']
  ) into v_has_plus;

  if v_credits.free_changes_used < 3 then
    v_source := 'free';
    update public.username_change_credits
    set free_changes_used = free_changes_used + 1
    where user_id = v_user_id
    returning * into v_credits;
  elsif v_has_plus and (v_credits.plus_period_start is null or v_credits.plus_period_start < v_month or v_credits.plus_changes_used < 1) then
    v_source := 'plus_allowance';
    update public.username_change_credits
    set plus_period_start = v_month,
        plus_changes_used = case when plus_period_start is distinct from v_month then 1 else plus_changes_used + 1 end
    where user_id = v_user_id
    returning * into v_credits;
  elsif v_credits.token_credits > 0 then
    v_source := 'token';
    update public.username_change_credits
    set token_credits = token_credits - 1
    where user_id = v_user_id
    returning * into v_credits;
  elsif v_credits.admin_credits > 0 then
    v_source := 'admin_credit';
    update public.username_change_credits
    set admin_credits = admin_credits - 1
    where user_id = v_user_id
    returning * into v_credits;
  else
    raise exception 'No username changes are available. Use a token, Plus monthly allowance, or admin-approved credit.';
  end if;

  perform set_config('mort.internal_update', 'true', true);

  update public.profiles
  set username = v_new_username
  where id = v_user_id;

  delete from public.username_reservations
  where user_id = v_user_id or username = v_new_username;

  insert into public.username_reservations (username, user_id)
  values (v_new_username, v_user_id);

  perform set_config('mort.internal_update', '', true);

  insert into public.username_change_events (user_id, old_username, new_username, source)
  values (v_user_id, v_old_username, v_new_username, v_source);

  return query
  select
    v_new_username,
    v_source,
    greatest(0, 3 - v_credits.free_changes_used),
    v_credits.token_credits,
    v_credits.admin_credits;
exception
  when others then
    perform set_config('mort.internal_update', '', true);
    raise;
end;
$$;

create or replace function public.consume_username_change_credit()
returns table (
  token_credits integer,
  admin_credits integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_credits public.username_change_credits%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;

  insert into public.username_change_credits (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select * into v_credits
  from public.username_change_credits
  where user_id = v_user_id
  for update;

  if v_credits.token_credits > 0 then
    update public.username_change_credits
    set token_credits = token_credits - 1
    where user_id = v_user_id
    returning * into v_credits;
  elsif v_credits.admin_credits > 0 then
    update public.username_change_credits
    set admin_credits = admin_credits - 1
    where user_id = v_user_id
    returning * into v_credits;
  else
    raise exception 'No username change credits available.';
  end if;

  return query select v_credits.token_credits, v_credits.admin_credits;
end;
$$;

create or replace function public.admin_grant_username_change_credit(
  p_user_id uuid,
  p_credit_count integer default 1,
  p_reason text default null
)
returns public.username_change_credits
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.username_change_credits%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;

  if p_user_id is null or p_credit_count is null or p_credit_count < 1 or p_credit_count > 20 then
    raise exception 'Credit count must be between 1 and 20.';
  end if;

  insert into public.username_change_credits (user_id, admin_credits)
  values (p_user_id, p_credit_count)
  on conflict (user_id) do update
  set admin_credits = public.username_change_credits.admin_credits + excluded.admin_credits
  returning * into v_row;

  insert into public.admin_action_logs (admin_id, action, target_table, target_id, details)
  values (
    (select auth.uid()),
    'grant_username_change_credit',
    'username_change_credits',
    p_user_id,
    jsonb_build_object('credit_count', p_credit_count, 'reason', p_reason)
  );

  return v_row;
end;
$$;

create or replace function public.record_feature_usage(
  p_feature_key text,
  p_entitlement_required text default null,
  p_allowed boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required.';
  end if;

  insert into public.premium_feature_usage (user_id, feature_key, entitlement_required, allowed)
  values ((select auth.uid()), left(btrim(p_feature_key), 80), nullif(left(btrim(coalesce(p_entitlement_required, '')), 80), ''), p_allowed)
  returning id into v_id;

  return v_id;
end;
$$;

grant select on
  public.username_change_credits,
  public.username_change_events,
  public.username_reservations,
  public.username_moderation_flags,
  public.profile_theme_unlocks,
  public.user_profile_theme_settings,
  public.user_saved_job_folders,
  public.saved_job_folder_items
to authenticated;

grant insert, update, delete on
  public.user_profile_theme_settings,
  public.user_saved_job_folders,
  public.saved_job_folder_items
to authenticated;

grant select, insert, update, delete on
  public.username_change_credits,
  public.username_change_events,
  public.username_reservations,
  public.username_moderation_flags,
  public.profile_theme_unlocks,
  public.user_profile_theme_settings,
  public.user_saved_job_folders,
  public.saved_job_folder_items
to service_role;

grant execute on function public.normalize_username(text) to authenticated, service_role;
grant execute on function public.validate_username(text) to authenticated, service_role;
grant execute on function public.get_username_change_status() to authenticated, service_role;
grant execute on function public.request_username_change(text) to authenticated, service_role;
grant execute on function public.consume_username_change_credit() to authenticated, service_role;
grant execute on function public.admin_grant_username_change_credit(uuid, integer, text) to authenticated, service_role;
grant execute on function public.record_feature_usage(text, text, boolean) to authenticated, service_role;
