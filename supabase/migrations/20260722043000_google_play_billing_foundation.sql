-- Google Play Billing foundation. Purchase verification and entitlement writes
-- are server-only. Closed-test starts in license_test mode but disabled until
-- Play Developer API credentials and Console products are configured.

create table public.play_billing_runtime_controls (
  id boolean primary key default true check (id),
  mode text not null default 'license_test'
    check (mode in ('disabled', 'license_test', 'production')),
  billing_enabled boolean not null default false,
  provider_verification_enabled boolean not null default false,
  rtdn_enabled boolean not null default false,
  production_approved boolean not null default false,
  package_name text not null default 'com.mortapp.mobile'
    check (package_name = 'com.mortapp.mobile'),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

insert into public.play_billing_runtime_controls (id)
values (true)
on conflict (id) do nothing;

create table public.store_products (
  product_id text primary key,
  product_type text not null check (product_type in ('subscription', 'one_time')),
  entitlement_key text not null,
  display_name text not null,
  description text not null,
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (product_id ~ '^mort_[a-z0-9_]+$')
);

create table public.store_product_versions (
  id uuid primary key default gen_random_uuid(),
  product_id text not null references public.store_products(product_id) on delete cascade,
  base_plan_id text,
  version integer not null default 1 check (version > 0),
  benefits jsonb not null default '[]'::jsonb,
  effective_at timestamptz not null default now(),
  retired_at timestamptz,
  unique (product_id, base_plan_id, version)
);

create table public.purchase_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id text not null references public.store_products(product_id),
  base_plan_id text,
  package_name text not null check (package_name = 'com.mortapp.mobile'),
  environment text not null check (environment in ('license_test', 'production')),
  token_hash text not null unique check (char_length(token_hash) = 64),
  client_request_id uuid not null,
  purchase_state text not null
    check (purchase_state in ('pending', 'purchased', 'cancelled', 'expired', 'refunded', 'revoked', 'on_hold', 'grace_period', 'paused')),
  acknowledgement_state text not null default 'pending'
    check (acknowledgement_state in ('pending', 'acknowledged', 'not_required', 'failed')),
  provider_order_hash text,
  purchased_at timestamptz,
  expires_at timestamptz,
  verified_at timestamptz not null default now(),
  raw_payload_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, client_request_id)
);

create table public.purchase_token_hashes (
  token_hash text primary key check (char_length(token_hash) = 64),
  purchase_record_id uuid not null unique references public.purchase_records(id) on delete cascade,
  first_seen_at timestamptz not null default now(),
  last_verified_at timestamptz not null default now(),
  verification_count integer not null default 1 check (verification_count > 0)
);

create table public.subscription_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  entitlement_key text not null,
  product_id text not null references public.store_products(product_id),
  source_purchase_id uuid not null references public.purchase_records(id) on delete cascade,
  status text not null check (status in ('pending', 'active', 'grace_period', 'on_hold', 'paused', 'expired', 'revoked')),
  starts_at timestamptz,
  ends_at timestamptz,
  last_verified_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, entitlement_key, product_id)
);

create table public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  purchase_record_id uuid references public.purchase_records(id) on delete set null,
  event_type text not null,
  previous_status text,
  new_status text,
  provider_event_hash text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.billing_reconciliation_runs (
  id uuid primary key default gen_random_uuid(),
  environment text not null check (environment in ('license_test', 'production')),
  status text not null check (status in ('running', 'completed', 'failed')),
  checked_count integer not null default 0 check (checked_count >= 0),
  mismatch_count integer not null default 0 check (mismatch_count >= 0),
  failure_code text,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

create table public.billing_notification_events (
  id uuid primary key default gen_random_uuid(),
  provider_event_hash text not null unique,
  environment text not null check (environment in ('license_test', 'production')),
  notification_type text not null,
  token_hash text,
  package_name text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_status text not null default 'received'
    check (processing_status in ('received', 'processed', 'ignored', 'failed')),
  failure_code text
);

create table public.review_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  entitlement_key text not null default 'mort_plus',
  review_scope text not null default 'play_review' check (review_scope = 'play_review'),
  synthetic boolean not null default true check (synthetic),
  active boolean not null default true,
  granted_by uuid references public.profiles(id) on delete set null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  notes text,
  unique (user_id, entitlement_key, review_scope)
);

create index purchase_records_user_updated_idx on public.purchase_records(user_id, updated_at desc);
create index purchase_records_state_idx on public.purchase_records(purchase_state, verified_at desc);
create index subscription_entitlements_user_idx on public.subscription_entitlements(user_id, status);
create index subscription_events_purchase_idx on public.subscription_events(purchase_record_id, occurred_at desc);
create index billing_notifications_status_idx on public.billing_notification_events(processing_status, received_at);
create index review_entitlements_user_idx on public.review_entitlements(user_id, active);

alter table public.play_billing_runtime_controls enable row level security;
alter table public.store_products enable row level security;
alter table public.store_product_versions enable row level security;
alter table public.purchase_records enable row level security;
alter table public.purchase_token_hashes enable row level security;
alter table public.subscription_entitlements enable row level security;
alter table public.subscription_events enable row level security;
alter table public.billing_reconciliation_runs enable row level security;
alter table public.billing_notification_events enable row level security;
alter table public.review_entitlements enable row level security;

alter table public.play_billing_runtime_controls force row level security;
alter table public.store_products force row level security;
alter table public.store_product_versions force row level security;
alter table public.purchase_records force row level security;
alter table public.purchase_token_hashes force row level security;
alter table public.subscription_entitlements force row level security;
alter table public.subscription_events force row level security;
alter table public.billing_reconciliation_runs force row level security;
alter table public.billing_notification_events force row level security;
alter table public.review_entitlements force row level security;

create policy store_products_read_active on public.store_products
for select to authenticated using (active);
create policy store_product_versions_read_current on public.store_product_versions
for select to authenticated using (
  retired_at is null and exists (
    select 1 from public.store_products product
    where product.product_id = store_product_versions.product_id and product.active
  )
);
create policy purchase_records_read_own on public.purchase_records
for select to authenticated using (user_id = (select auth.uid()));
create policy subscription_entitlements_read_own on public.subscription_entitlements
for select to authenticated using (user_id = (select auth.uid()));
create policy subscription_events_read_own on public.subscription_events
for select to authenticated using (user_id = (select auth.uid()));
create policy review_entitlements_read_own on public.review_entitlements
for select to authenticated using (user_id = (select auth.uid()));

revoke all on public.play_billing_runtime_controls from public, anon, authenticated;
revoke all on public.store_products from public, anon, authenticated;
revoke all on public.store_product_versions from public, anon, authenticated;
revoke all on public.purchase_records from public, anon, authenticated;
revoke all on public.purchase_token_hashes from public, anon, authenticated;
revoke all on public.subscription_entitlements from public, anon, authenticated;
revoke all on public.subscription_events from public, anon, authenticated;
revoke all on public.billing_reconciliation_runs from public, anon, authenticated;
revoke all on public.billing_notification_events from public, anon, authenticated;
revoke all on public.review_entitlements from public, anon, authenticated;

grant select on public.store_products, public.store_product_versions,
  public.purchase_records, public.subscription_entitlements,
  public.subscription_events, public.review_entitlements to authenticated;
grant all on public.play_billing_runtime_controls, public.store_products,
  public.store_product_versions, public.purchase_records,
  public.purchase_token_hashes, public.subscription_entitlements,
  public.subscription_events, public.billing_reconciliation_runs,
  public.billing_notification_events, public.review_entitlements to service_role;

insert into public.store_products (
  product_id, product_type, entitlement_key, display_name, description, active
) values
  ('mort_plus', 'subscription', 'mort_plus', 'MORT Plus', 'Optional cosmetic and convenience benefits; core work and safety stay free.', false),
  ('mort_theme_neon_pack', 'one_time', 'mort_theme_neon_pack', 'Neon theme pack', 'Optional visual theme.', false),
  ('mort_theme_midnight_pack', 'one_time', 'mort_theme_midnight_pack', 'Midnight theme pack', 'Optional visual theme.', false),
  ('mort_profile_frames_pack_01', 'one_time', 'mort_profile_frames_pack_01', 'Profile frames pack', 'Optional cosmetic profile frames.', false),
  ('mort_portfolio_layouts_pack_01', 'one_time', 'mort_portfolio_layouts_pack_01', 'Portfolio layouts pack', 'Optional portfolio layouts.', false)
on conflict (product_id) do update set
  product_type = excluded.product_type,
  entitlement_key = excluded.entitlement_key,
  display_name = excluded.display_name,
  description = excluded.description,
  updated_at = now();

insert into public.store_product_versions (product_id, base_plan_id, benefits)
values
  ('mort_plus', 'monthly-auto', '["eligible_ad_free","premium_themes","profile_accents","profile_frames","portfolio_layouts","saved_searches","job_alert_presets","earnings_charts"]'::jsonb),
  ('mort_plus', 'annual-auto', '["eligible_ad_free","premium_themes","profile_accents","profile_frames","portfolio_layouts","saved_searches","job_alert_presets","earnings_charts"]'::jsonb),
  ('mort_theme_neon_pack', null, '["neon_theme"]'::jsonb),
  ('mort_theme_midnight_pack', null, '["midnight_theme"]'::jsonb),
  ('mort_profile_frames_pack_01', null, '["profile_frames_pack_01"]'::jsonb),
  ('mort_portfolio_layouts_pack_01', null, '["portfolio_layouts_pack_01"]'::jsonb)
on conflict (product_id, base_plan_id, version) do nothing;

create or replace function public.get_play_billing_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare v_control public.play_billing_runtime_controls%rowtype;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_control from public.play_billing_runtime_controls where id;
  return jsonb_build_object(
    'ok', true,
    'mode', v_control.mode,
    'billing_enabled', v_control.billing_enabled,
    'provider_verification_enabled', v_control.provider_verification_enabled,
    'package_name', v_control.package_name,
    'products', (select coalesce(jsonb_agg(jsonb_build_object(
      'product_id', product.product_id,
      'product_type', product.product_type,
      'display_name', product.display_name,
      'description', product.description
    ) order by product.product_id), '[]'::jsonb) from public.store_products product)
  );
end;
$$;

create or replace function public.get_my_play_entitlements()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'ok', auth.uid() is not null,
    'entitlements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'key', entitlement_key,
        'product_id', product_id,
        'status', status,
        'starts_at', starts_at,
        'ends_at', ends_at,
        'source', 'google_play'
      ) order by entitlement_key)
      from public.subscription_entitlements
      where user_id = auth.uid()
        and status in ('active', 'grace_period')
        and (ends_at is null or ends_at > now())
    ), '[]'::jsonb),
    'review_entitlements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'key', entitlement_key,
        'source', 'synthetic_play_review',
        'synthetic', true
      ) order by entitlement_key)
      from public.review_entitlements
      where user_id = auth.uid() and active and revoked_at is null
    ), '[]'::jsonb)
  );
$$;

create or replace function public.record_google_play_purchase_verification(
  p_user_id uuid,
  p_product_id text,
  p_base_plan_id text,
  p_package_name text,
  p_environment text,
  p_purchase_token text,
  p_client_request_id uuid,
  p_purchase_state text,
  p_acknowledgement_state text,
  p_provider_order_id text default null,
  p_purchased_at timestamptz default null,
  p_expires_at timestamptz default null,
  p_raw_payload text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_control public.play_billing_runtime_controls%rowtype;
  v_product public.store_products%rowtype;
  v_token_hash text;
  v_purchase public.purchase_records%rowtype;
  v_entitlement_status text;
begin
  select * into v_control from public.play_billing_runtime_controls where id;
  if not v_control.billing_enabled or not v_control.provider_verification_enabled then
    return jsonb_build_object('ok', false, 'code', 'provider_verification_disabled');
  end if;
  if p_package_name <> v_control.package_name then
    return jsonb_build_object('ok', false, 'code', 'wrong_package');
  end if;
  if p_environment <> v_control.mode or p_environment not in ('license_test', 'production') then
    return jsonb_build_object('ok', false, 'code', 'wrong_environment');
  end if;
  if v_control.mode = 'production' and not v_control.production_approved then
    return jsonb_build_object('ok', false, 'code', 'production_not_approved');
  end if;
  select * into v_product from public.store_products where product_id = p_product_id and active;
  if not found then return jsonb_build_object('ok', false, 'code', 'wrong_product'); end if;
  if p_purchase_state not in ('pending', 'purchased', 'cancelled', 'expired', 'refunded', 'revoked', 'on_hold', 'grace_period', 'paused') then
    return jsonb_build_object('ok', false, 'code', 'invalid_purchase_state');
  end if;
  if char_length(coalesce(p_purchase_token, '')) < 20 then
    return jsonb_build_object('ok', false, 'code', 'invalid_purchase_token');
  end if;
  v_token_hash := encode(digest(p_purchase_token, 'sha256'), 'hex');
  if exists (select 1 from public.purchase_records where token_hash = v_token_hash and user_id <> p_user_id) then
    return jsonb_build_object('ok', false, 'code', 'purchase_token_replayed');
  end if;

  insert into public.purchase_records (
    user_id, product_id, base_plan_id, package_name, environment, token_hash,
    client_request_id, purchase_state, acknowledgement_state,
    provider_order_hash, purchased_at, expires_at, raw_payload_hash
  ) values (
    p_user_id, p_product_id, nullif(p_base_plan_id, ''), p_package_name,
    p_environment, v_token_hash, p_client_request_id, p_purchase_state,
    p_acknowledgement_state,
    case when p_provider_order_id is null then null else encode(digest(p_provider_order_id, 'sha256'), 'hex') end,
    p_purchased_at, p_expires_at,
    case when p_raw_payload is null then null else encode(digest(p_raw_payload, 'sha256'), 'hex') end
  )
  on conflict (token_hash) do update set
    purchase_state = excluded.purchase_state,
    acknowledgement_state = excluded.acknowledgement_state,
    expires_at = excluded.expires_at,
    verified_at = now(),
    updated_at = now()
  returning * into v_purchase;

  insert into public.purchase_token_hashes (token_hash, purchase_record_id)
  values (v_token_hash, v_purchase.id)
  on conflict (token_hash) do update
  set last_verified_at = now(), verification_count = purchase_token_hashes.verification_count + 1;

  v_entitlement_status := case p_purchase_state
    when 'purchased' then 'active'
    when 'grace_period' then 'grace_period'
    when 'on_hold' then 'on_hold'
    when 'paused' then 'paused'
    when 'pending' then 'pending'
    when 'expired' then 'expired'
    else 'revoked'
  end;
  insert into public.subscription_entitlements (
    user_id, entitlement_key, product_id, source_purchase_id, status,
    starts_at, ends_at
  ) values (
    p_user_id, v_product.entitlement_key, p_product_id, v_purchase.id,
    v_entitlement_status, p_purchased_at, p_expires_at
  )
  on conflict (user_id, entitlement_key, product_id) do update set
    source_purchase_id = excluded.source_purchase_id,
    status = excluded.status,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    last_verified_at = now(),
    updated_at = now();

  insert into public.subscription_events (
    user_id, purchase_record_id, event_type, new_status
  ) values (p_user_id, v_purchase.id, 'provider_verification', v_entitlement_status);
  return jsonb_build_object(
    'ok', true,
    'purchase_record_id', v_purchase.id,
    'entitlement_status', v_entitlement_status
  );
end;
$$;

create or replace function public.grant_play_review_entitlement(
  p_user_id uuid,
  p_entitlement_key text default 'mort_plus',
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not exists (select 1 from public.profiles where id = p_user_id and is_test_account) then
    return jsonb_build_object('ok', false, 'code', 'play_review_test_account_required');
  end if;
  insert into public.review_entitlements (
    user_id, entitlement_key, synthetic, active, notes
  ) values (p_user_id, p_entitlement_key, true, true, nullif(btrim(p_notes), ''))
  on conflict (user_id, entitlement_key, review_scope) do update
  set active = true, revoked_at = null, notes = excluded.notes, granted_at = now()
  returning id into v_id;
  return jsonb_build_object('ok', true, 'review_entitlement_id', v_id, 'synthetic', true);
end;
$$;

create or replace function public.revoke_play_review_entitlement(
  p_user_id uuid,
  p_entitlement_key text default 'mort_plus'
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.review_entitlements
  set active = false, revoked_at = now()
  where user_id = p_user_id and entitlement_key = p_entitlement_key
    and review_scope = 'play_review';
  return found;
end;
$$;

revoke execute on function public.get_play_billing_config() from public, anon;
revoke execute on function public.get_my_play_entitlements() from public, anon;
revoke execute on function public.record_google_play_purchase_verification(uuid, text, text, text, text, text, uuid, text, text, text, timestamptz, timestamptz, text) from public, anon, authenticated;
revoke execute on function public.grant_play_review_entitlement(uuid, text, text) from public, anon, authenticated;
revoke execute on function public.revoke_play_review_entitlement(uuid, text) from public, anon, authenticated;

grant execute on function public.get_play_billing_config() to authenticated, service_role;
grant execute on function public.get_my_play_entitlements() to authenticated, service_role;
grant execute on function public.record_google_play_purchase_verification(uuid, text, text, text, text, text, uuid, text, text, text, timestamptz, timestamptz, text) to service_role;
grant execute on function public.grant_play_review_entitlement(uuid, text, text) to service_role;
grant execute on function public.revoke_play_review_entitlement(uuid, text) to service_role;
