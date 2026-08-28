-- MORT monetization additive schema.
-- RevenueCat remains the source of truth for purchases. This schema stores
-- optional app-facing cache/audit/analytics records only; it never stores
-- payment cards, processes payments, or creates marketplace escrow.

create type public.monetization_event_source as enum ('revenuecat', 'app', 'admin', 'admob');
create type public.ad_format as enum ('banner', 'interstitial', 'rewarded', 'native', 'app_open');
create type public.boost_status as enum ('pending', 'active', 'expired', 'rejected', 'cancelled');
create type public.paywall_event_type as enum ('viewed', 'package_selected', 'purchase_started', 'purchase_cancelled', 'purchase_failed', 'purchase_completed', 'restore_started', 'restore_completed');

create table public.monetization_entitlements_cache (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  entitlements text[] not null default '{}',
  active_until timestamptz,
  source public.monetization_event_source not null default 'revenuecat',
  last_revenuecat_event_id text,
  refreshed_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint monetization_entitlements_no_blank check (array_position(entitlements, '') is null)
);

create table public.revenuecat_events (
  id uuid primary key default gen_random_uuid(),
  revenuecat_event_id text unique,
  app_user_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  product_id text,
  entitlement_ids text[] not null default '{}',
  raw_event jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_error text
);

create table public.user_subscription_status (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  premium_active boolean not null default false,
  ad_free_active boolean not null default false,
  adult_pro_active boolean not null default false,
  business_boost_active boolean not null default false,
  guardian_plus_active boolean not null default false,
  current_product_id text,
  current_period_ends_at timestamptz,
  source public.monetization_event_source not null default 'revenuecat',
  updated_at timestamptz not null default now()
);

create table public.user_ad_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  personalized_ads_allowed boolean not null default false,
  ads_consent_ready boolean not null default false,
  age_restricted_ads boolean not null default true,
  last_prompted_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.ad_impressions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  placement text not null,
  ad_format public.ad_format not null,
  ad_unit_id text,
  request_non_personalized boolean not null default true,
  revenue_micros integer,
  currency text,
  created_at timestamptz not null default now()
);

create table public.ad_click_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  impression_id uuid references public.ad_impressions(id) on delete set null,
  placement text not null,
  ad_format public.ad_format not null,
  created_at timestamptz not null default now()
);

create table public.ad_frequency_caps (
  user_id uuid not null references public.profiles(id) on delete cascade,
  placement text not null,
  ad_format public.ad_format not null,
  shown_count integer not null default 0,
  last_shown_at timestamptz,
  session_key text,
  updated_at timestamptz not null default now(),
  primary key (user_id, placement, ad_format)
);

create table public.purchase_audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  source public.monetization_event_source not null default 'revenuecat',
  action text not null,
  product_id text,
  entitlement_id text,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table public.premium_feature_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  feature_key text not null,
  entitlement_required text,
  allowed boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.boosted_jobs (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  purchaser_id uuid not null references public.profiles(id) on delete cascade,
  revenuecat_product_id text,
  status public.boost_status not null default 'pending',
  starts_at timestamptz,
  ends_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint boosted_jobs_window check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create table public.boost_impressions (
  id uuid primary key default gen_random_uuid(),
  boost_id uuid not null references public.boosted_jobs(id) on delete cascade,
  viewer_id uuid references public.profiles(id) on delete set null,
  placement text not null,
  created_at timestamptz not null default now()
);

create table public.monetization_experiments (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  description text not null,
  active boolean not null default false,
  audience text not null default 'all',
  payload jsonb not null default '{}',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.paywall_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  event_type public.paywall_event_type not null,
  placement text not null,
  offering_id text,
  package_id text,
  product_id text,
  error_message text,
  created_at timestamptz not null default now()
);

create index monetization_entitlements_cache_refreshed_idx on public.monetization_entitlements_cache(refreshed_at desc);
create index revenuecat_events_app_user_idx on public.revenuecat_events(app_user_id, received_at desc);
create index ad_impressions_user_idx on public.ad_impressions(user_id, created_at desc);
create index ad_click_events_user_idx on public.ad_click_events(user_id, created_at desc);
create index purchase_audit_logs_user_idx on public.purchase_audit_logs(user_id, created_at desc);
create index premium_feature_usage_user_idx on public.premium_feature_usage(user_id, created_at desc);
create index boosted_jobs_job_idx on public.boosted_jobs(job_id, status);
create index boosted_jobs_active_idx on public.boosted_jobs(status, starts_at, ends_at);
create index boost_impressions_boost_idx on public.boost_impressions(boost_id, created_at desc);
create index paywall_events_user_idx on public.paywall_events(user_id, created_at desc);

create trigger monetization_entitlements_cache_set_updated_at before update on public.monetization_entitlements_cache
for each row execute function public.set_updated_at();

create trigger user_subscription_status_set_updated_at before update on public.user_subscription_status
for each row execute function public.set_updated_at();

create trigger user_ad_preferences_set_updated_at before update on public.user_ad_preferences
for each row execute function public.set_updated_at();

create trigger ad_frequency_caps_set_updated_at before update on public.ad_frequency_caps
for each row execute function public.set_updated_at();

create trigger boosted_jobs_set_updated_at before update on public.boosted_jobs
for each row execute function public.set_updated_at();

create trigger monetization_experiments_set_updated_at before update on public.monetization_experiments
for each row execute function public.set_updated_at();

alter table public.monetization_entitlements_cache enable row level security;
alter table public.revenuecat_events enable row level security;
alter table public.user_subscription_status enable row level security;
alter table public.ad_impressions enable row level security;
alter table public.ad_click_events enable row level security;
alter table public.ad_frequency_caps enable row level security;
alter table public.user_ad_preferences enable row level security;
alter table public.purchase_audit_logs enable row level security;
alter table public.premium_feature_usage enable row level security;
alter table public.boosted_jobs enable row level security;
alter table public.boost_impressions enable row level security;
alter table public.monetization_experiments enable row level security;
alter table public.paywall_events enable row level security;

create policy monetization_entitlements_cache_select on public.monetization_entitlements_cache
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy revenuecat_events_select_admin on public.revenuecat_events
for select to authenticated
using (public.is_admin());

create policy user_subscription_status_select on public.user_subscription_status
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy user_ad_preferences_select on public.user_ad_preferences
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy user_ad_preferences_insert_self on public.user_ad_preferences
for insert to authenticated
with check (user_id = (select auth.uid()));

create policy user_ad_preferences_update_self on public.user_ad_preferences
for update to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());

create policy ad_impressions_insert_self on public.ad_impressions
for insert to authenticated
with check (user_id = (select auth.uid()));

create policy ad_impressions_select_self_or_admin on public.ad_impressions
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy ad_click_events_insert_self on public.ad_click_events
for insert to authenticated
with check (user_id = (select auth.uid()));

create policy ad_click_events_select_self_or_admin on public.ad_click_events
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy ad_frequency_caps_select_self_or_admin on public.ad_frequency_caps
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy ad_frequency_caps_upsert_self on public.ad_frequency_caps
for insert to authenticated
with check (user_id = (select auth.uid()));

create policy ad_frequency_caps_update_self on public.ad_frequency_caps
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy purchase_audit_logs_select_self_or_admin on public.purchase_audit_logs
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy premium_feature_usage_insert_self on public.premium_feature_usage
for insert to authenticated
with check (user_id = (select auth.uid()));

create policy premium_feature_usage_select_self_or_admin on public.premium_feature_usage
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy boosted_jobs_select_visible on public.boosted_jobs
for select to authenticated
using (
  public.is_admin()
  or purchaser_id = (select auth.uid())
  or (
    status = 'active'
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at > now())
  )
);

create policy boosted_jobs_insert_job_owner on public.boosted_jobs
for insert to authenticated
with check (
  purchaser_id = (select auth.uid())
  and exists (
    select 1 from public.jobs j
    where j.id = job_id
      and j.poster_id = (select auth.uid())
  )
);

create policy boosted_jobs_update_owner_pending_or_admin on public.boosted_jobs
for update to authenticated
using (public.is_admin() or (purchaser_id = (select auth.uid()) and status = 'pending'))
with check (public.is_admin() or (purchaser_id = (select auth.uid()) and status in ('pending', 'cancelled')));

create policy boost_impressions_insert_authenticated on public.boost_impressions
for insert to authenticated
with check (viewer_id = (select auth.uid()));

create policy boost_impressions_select_owner_or_admin on public.boost_impressions
for select to authenticated
using (
  public.is_admin()
  or viewer_id = (select auth.uid())
  or exists (
    select 1 from public.boosted_jobs bj
    where bj.id = boost_id
      and bj.purchaser_id = (select auth.uid())
  )
);

create policy monetization_experiments_select_active_or_admin on public.monetization_experiments
for select to authenticated
using (active or public.is_admin());

create policy monetization_experiments_write_admin on public.monetization_experiments
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy paywall_events_insert_self on public.paywall_events
for insert to authenticated
with check (user_id = (select auth.uid()));

create policy paywall_events_select_self_or_admin on public.paywall_events
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create or replace function public.get_my_entitlements()
returns table (
  premium_active boolean,
  ad_free_active boolean,
  adult_pro_active boolean,
  business_boost_active boolean,
  guardian_plus_active boolean,
  entitlements text[],
  refreshed_at timestamptz
)
language sql
stable
as $$
  select
    coalesce(uss.premium_active, false),
    coalesce(uss.ad_free_active, false),
    coalesce(uss.adult_pro_active, false),
    coalesce(uss.business_boost_active, false),
    coalesce(uss.guardian_plus_active, false),
    coalesce(mec.entitlements, '{}'),
    mec.refreshed_at
  from (select (select auth.uid()) as user_id) me
  left join public.user_subscription_status uss on uss.user_id = me.user_id
  left join public.monetization_entitlements_cache mec on mec.user_id = me.user_id;
$$;

create or replace function public.record_paywall_event(
  p_event_type public.paywall_event_type,
  p_placement text,
  p_offering_id text default null,
  p_package_id text default null,
  p_product_id text default null,
  p_error_message text default null
)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required.';
  end if;

  insert into public.paywall_events (user_id, event_type, placement, offering_id, package_id, product_id, error_message)
  values ((select auth.uid()), p_event_type, trim(p_placement), p_offering_id, p_package_id, p_product_id, p_error_message)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.record_ad_impression(
  p_placement text,
  p_ad_format public.ad_format,
  p_ad_unit_id text default null,
  p_request_non_personalized boolean default true
)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required.';
  end if;

  insert into public.ad_impressions (user_id, placement, ad_format, ad_unit_id, request_non_personalized)
  values ((select auth.uid()), trim(p_placement), p_ad_format, p_ad_unit_id, p_request_non_personalized)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.get_ad_eligibility(p_placement text, p_ad_format public.ad_format)
returns table (
  allowed boolean,
  reason text,
  request_non_personalized boolean
)
language sql
stable
as $$
  with me as (
    select p.id, p.role, p.dob
    from public.profiles p
    where p.id = (select auth.uid())
  ), subscription as (
    select coalesce(ad_free_active or premium_active, false) as ad_free
    from public.user_subscription_status
    where user_id = (select auth.uid())
  ), prefs as (
    select personalized_ads_allowed, ads_consent_ready, age_restricted_ads
    from public.user_ad_preferences
    where user_id = (select auth.uid())
  )
  select
    case
      when (select id from me) is null then false
      when p_placement = any(array['chat','safety','report','proof','verification','guardian-approval','admin','payment','paywall']) then false
      when coalesce((select ad_free from subscription), false) then false
      when not coalesce((select ads_consent_ready from prefs), false) then false
      else true
    end as allowed,
    case
      when (select id from me) is null then 'Authentication required.'
      when p_placement = any(array['chat','safety','report','proof','verification','guardian-approval','admin','payment','paywall']) then 'Ads disabled on safety-sensitive screens.'
      when coalesce((select ad_free from subscription), false) then 'Ad-free entitlement active.'
      when not coalesce((select ads_consent_ready from prefs), false) then 'Consent and ad preferences are not ready.'
      else 'Eligible.'
    end as reason,
    (
      coalesce((select role = 'teen' from me), true)
      or coalesce((select age_restricted_ads from prefs), true)
      or not coalesce((select personalized_ads_allowed from prefs), false)
    ) as request_non_personalized;
$$;

create or replace function public.get_boosted_jobs()
returns setof public.jobs
language sql
stable
as $$
  select distinct j.*
  from public.jobs j
  join public.boosted_jobs bj on bj.job_id = j.id
  where bj.status = 'active'
    and (bj.starts_at is null or bj.starts_at <= now())
    and (bj.ends_at is null or bj.ends_at > now())
    and j.status = 'open'
  order by j.created_at desc;
$$;

create or replace function public.admin_monetization_overview()
returns table (
  active_subscriptions bigint,
  ad_free_users bigint,
  pending_boosts bigint,
  open_paywall_events bigint,
  ad_impressions_7d bigint
)
language plpgsql
stable
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin role required.';
  end if;

  return query
  select
    (select count(*) from public.user_subscription_status where premium_active or adult_pro_active or guardian_plus_active),
    (select count(*) from public.user_subscription_status where ad_free_active),
    (select count(*) from public.boosted_jobs where status = 'pending'),
    (select count(*) from public.paywall_events where created_at >= now() - interval '7 days'),
    (select count(*) from public.ad_impressions where created_at >= now() - interval '7 days');
end;
$$;

grant select, insert, update on
  public.user_ad_preferences,
  public.ad_frequency_caps
to authenticated;

grant select, insert on
  public.ad_impressions,
  public.ad_click_events,
  public.premium_feature_usage,
  public.boost_impressions,
  public.paywall_events
to authenticated;

grant select on
  public.monetization_entitlements_cache,
  public.user_subscription_status,
  public.revenuecat_events,
  public.purchase_audit_logs,
  public.boosted_jobs,
  public.monetization_experiments
to authenticated;

grant insert, update on public.boosted_jobs to authenticated;

grant execute on function public.get_my_entitlements() to authenticated;
grant execute on function public.record_paywall_event(public.paywall_event_type, text, text, text, text, text) to authenticated;
grant execute on function public.record_ad_impression(text, public.ad_format, text, boolean) to authenticated;
grant execute on function public.get_ad_eligibility(text, public.ad_format) to authenticated;
grant execute on function public.get_boosted_jobs() to authenticated;
grant execute on function public.admin_monetization_overview() to authenticated;
