-- Provider writes maintain audit caches; caches are not a clock.
-- Read each product's validity independently so delayed webhooks cannot
-- prolong expired Pro/Plus or let a lifetime add-on prolong another product.
create or replace function public.get_my_active_revenuecat_entitlements()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select (select auth.uid()) as user_id
  ), product_history as (
    select state.*
    from public.revenuecat_product_states state
    join me on state.user_id = me.user_id
  ), active_entitlements as (
    select expanded.entitlement
    from product_history state
    cross join lateral unnest(state.entitlements) as expanded(entitlement)
    where state.active
      and (state.active_until is null or state.active_until > now())
    union
    -- Preserve historical cache-only accounts until their provider history
    -- is migrated. A known product history, including revocations, wins.
    select expanded.entitlement
    from public.monetization_entitlements_cache cache
    join me on cache.user_id = me.user_id
    cross join lateral unnest(cache.entitlements) as expanded(entitlement)
    where not exists (select 1 from product_history)
      and (cache.active_until is null or cache.active_until > now())
  )
  select coalesce(
    array_agg(distinct entitlement order by entitlement)
      filter (where entitlement is not null),
    '{}'::text[]
  ) from active_entitlements;
$$;

revoke all on function public.get_my_active_revenuecat_entitlements()
from public, anon;
grant execute on function public.get_my_active_revenuecat_entitlements()
to authenticated, service_role;

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
set search_path = ''
as $$
  with live as (
    select public.get_my_active_revenuecat_entitlements() as entitlements
  )
  select
    live.entitlements && array['mort_pro', 'mort_plus', 'mort_lifetime'],
    live.entitlements && array['mort_ad_free', 'mort_pro', 'mort_plus', 'mort_lifetime'],
    live.entitlements && array['mort_adult_pro', 'mort_pro'],
    'mort_business_boost' = any(live.entitlements),
    'mort_guardian_plus' = any(live.entitlements),
    live.entitlements,
    cache.refreshed_at
  from live
  left join public.monetization_entitlements_cache cache
    on cache.user_id = (select auth.uid());
$$;

revoke all on function public.get_my_entitlements() from public, anon;
grant execute on function public.get_my_entitlements() to authenticated, service_role;


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
    select public.get_my_active_revenuecat_entitlements() && array['mort_pro', 'mort_plus', 'mort_lifetime', 'mort_premium'] as has_plus
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

  select p.username into v_old_username
  from public.profiles p
  where p.id = v_user_id;

  if v_old_username is not distinct from v_new_username then
    raise exception 'That is already your username.';
  end if;

  if exists (
    select 1 from public.profiles p
    where lower(p.username) = v_new_username and p.id <> v_user_id
  ) then
    raise exception 'That username is already taken.';
  end if;

  insert into public.username_change_credits (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select * into v_credits
  from public.username_change_credits c
  where c.user_id = v_user_id
  for update;

  select public.get_my_active_revenuecat_entitlements() && array['mort_pro', 'mort_plus', 'mort_lifetime', 'mort_premium'] into v_has_plus;

  if v_credits.free_changes_used < 3 then
    v_source := 'free';
    update public.username_change_credits c
    set free_changes_used = c.free_changes_used + 1
    where c.user_id = v_user_id
    returning * into v_credits;
  elsif v_has_plus and (v_credits.plus_period_start is null or v_credits.plus_period_start < v_month or v_credits.plus_changes_used < 1) then
    v_source := 'plus_allowance';
    update public.username_change_credits c
    set plus_period_start = v_month,
        plus_changes_used = case when c.plus_period_start is distinct from v_month then 1 else c.plus_changes_used + 1 end
    where c.user_id = v_user_id
    returning * into v_credits;
  elsif v_credits.token_credits > 0 then
    v_source := 'token';
    update public.username_change_credits c
    set token_credits = c.token_credits - 1
    where c.user_id = v_user_id
    returning * into v_credits;
  elsif v_credits.admin_credits > 0 then
    v_source := 'admin_credit';
    update public.username_change_credits c
    set admin_credits = c.admin_credits - 1
    where c.user_id = v_user_id
    returning * into v_credits;
  else
    raise exception 'No username changes are available. Use a token, Plus monthly allowance, or admin-approved credit.';
  end if;

  perform set_config('mort.internal_update', 'true', true);

  update public.profiles p
  set username = v_new_username
  where p.id = v_user_id;

  delete from public.username_reservations r
  where r.user_id = v_user_id or r.username = v_new_username;

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

create or replace function public.get_ad_eligibility(
  p_placement text,
  p_ad_format public.ad_format
)
returns table (
  allowed boolean,
  reason text,
  request_non_personalized boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select p.id, p.role, p.dob
    from public.profiles p
    where p.id = (select auth.uid())
  ), subscription as (
    select public.get_my_active_revenuecat_entitlements() && array['mort_ad_free', 'mort_pro', 'mort_plus', 'mort_lifetime'] as ad_free
  ), prefs as (
    select personalized_ads_allowed, ads_consent_ready, age_restricted_ads
    from public.user_ad_preferences
    where user_id = (select auth.uid())
  ), placement as (
    select (
      (p_placement in ('job_feed', 'adult_dashboard') and p_ad_format = 'banner')
      or (p_placement = 'profile_spark' and p_ad_format = 'rewarded')
    ) as eligible
  )
  select
    case
      when (select id from me) is null then false
      when not (select eligible from placement) then false
      when coalesce((select ad_free from subscription), false) then false
      when not coalesce((select ads_consent_ready from prefs), false) then false
      else true
    end,
    case
      when (select id from me) is null then 'Authentication required.'
      when not (select eligible from placement) then 'Ad placement is not eligible.'
      when coalesce((select ad_free from subscription), false) then 'Ad-free entitlement active.'
      when not coalesce((select ads_consent_ready from prefs), false) then 'Consent and ad preferences are not ready.'
      else 'Eligible.'
    end,
    not (
      coalesce((select role = 'adult' from me), false)
      and coalesce(
        (select date_part('year', age(current_date, dob)) >= 18 from me),
        false
      )
      and not coalesce((select age_restricted_ads from prefs), true)
      and coalesce((select personalized_ads_allowed from prefs), false)
    );
$$;
