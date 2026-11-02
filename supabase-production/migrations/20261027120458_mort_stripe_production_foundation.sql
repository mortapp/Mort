-- Additive Stripe server ledger for the new MORT Supabase project.
-- No provider credentials, user test accounts, or fabricated payment rows are
-- stored here. All live operations remain disabled until external launch gates
-- and provider credentials are verified.

create table if not exists private.stripe_runtime_controls (
  singleton boolean primary key default true check (singleton),
  mode text not null default 'disabled'
    check (mode in ('disabled', 'sandbox', 'live')),
  currency_code text not null default 'USD'
    check (currency_code ~ '^[A-Z]{3}$'),
  service_fee_cents integer not null default 297
    check (service_fee_cents between 0 and 100000),
  payments_enabled boolean not null default false,
  connected_onboarding_enabled boolean not null default false,
  job_funding_enabled boolean not null default false,
  transfers_enabled boolean not null default false,
  refunds_enabled boolean not null default false,
  live_mode_enabled boolean not null default false,
  live_owner_approved boolean not null default false,
  connected_accounts_approved boolean not null default false,
  payouts_approved boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint stripe_live_mode_requires_approval check (
    mode <> 'live' or (live_mode_enabled and live_owner_approved)
  )
);

insert into private.stripe_runtime_controls (singleton, mode)
values (true, 'disabled')
on conflict (singleton) do nothing;

create table if not exists private.stripe_customers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  provider_customer_id text not null
    check (provider_customer_id ~ '^cus_[A-Za-z0-9]+$'),
  created_at timestamptz not null default now(),
  unique (user_id, environment),
  unique (environment, provider_customer_id)
);

create table if not exists private.stripe_connected_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  provider_account_id text not null
    check (provider_account_id ~ '^acct_[A-Za-z0-9]+$'),
  onboarding_status text not null default 'pending'
    check (onboarding_status in ('pending', 'in_progress', 'complete', 'restricted', 'action_required', 'disconnected')),
  details_submitted boolean not null default false,
  charges_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  transfers_capability_status text not null default 'inactive'
    check (transfers_capability_status in ('inactive', 'pending', 'active', 'restricted')),
  requirements_status text not null default 'unknown'
    check (requirements_status in ('unknown', 'currently_due', 'eventually_due', 'past_due', 'pending_verification', 'satisfied', 'restricted')),
  country text check (country is null or country ~ '^[A-Z]{2}$'),
  default_currency text check (default_currency is null or default_currency ~ '^[A-Z]{3}$'),
  last_synchronized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, environment),
  unique (environment, provider_account_id)
);

create table if not exists private.stripe_payment_intents (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.job_assignments(id) on delete restrict,
  payer_id uuid not null references auth.users(id) on delete restrict,
  payee_id uuid not null references auth.users(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  operation_version integer not null default 1 check (operation_version > 0),
  gross_amount_cents integer not null check (gross_amount_cents >= 1000),
  service_fee_cents integer not null check (service_fee_cents >= 0),
  teen_net_cents integer not null check (
    teen_net_cents = gross_amount_cents - service_fee_cents and teen_net_cents > 0
  ),
  currency_code text not null default 'USD' check (currency_code ~ '^[A-Z]{3}$'),
  provider_customer_id text check (provider_customer_id is null or provider_customer_id ~ '^cus_[A-Za-z0-9]+$'),
  provider_payment_intent_id text check (provider_payment_intent_id is null or provider_payment_intent_id ~ '^pi_[A-Za-z0-9]+$'),
  provider_charge_id text check (provider_charge_id is null or provider_charge_id ~ '^ch_[A-Za-z0-9]+$'),
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 200),
  status text not null default 'prepared'
    check (status in ('prepared', 'requires_payment_method', 'requires_action', 'authorized', 'processing', 'succeeded', 'failed', 'cancelled', 'refunded', 'disputed', 'unknown')),
  safe_failure_code text check (safe_failure_code is null or safe_failure_code ~ '^[a-z0-9_]{1,100}$'),
  last_provider_event_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assignment_id, environment, operation_version),
  unique (environment, provider_payment_intent_id),
  unique (environment, idempotency_key),
  check (payer_id <> payee_id)
);

create table if not exists private.stripe_webhook_events (
  id uuid primary key default gen_random_uuid(),
  environment text not null check (environment in ('test', 'live')),
  provider_event_id text not null check (provider_event_id ~ '^evt_[A-Za-z0-9]+$'),
  event_type text not null check (char_length(event_type) between 3 and 120),
  provider_created_at timestamptz,
  payload_sha256 text not null check (payload_sha256 ~ '^[a-f0-9]{64}$'),
  signature_verified boolean not null default true check (signature_verified),
  processing_status text not null default 'received'
    check (processing_status in ('received', 'processing', 'processed', 'ignored', 'failed')),
  safe_failure_code text check (safe_failure_code is null or safe_failure_code ~ '^[a-z0-9_]{1,100}$'),
  lease_epoch bigint not null default 0 check (lease_epoch >= 0),
  lease_token uuid,
  lease_expires_at timestamptz,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (environment, provider_event_id)
);

create index if not exists stripe_payment_intents_assignment_idx
  on private.stripe_payment_intents (assignment_id, environment, created_at desc);
create index if not exists stripe_webhook_events_retry_idx
  on private.stripe_webhook_events (environment, processing_status, lease_expires_at);
create index if not exists stripe_connected_accounts_user_idx
  on private.stripe_connected_accounts (user_id, environment);

alter table private.stripe_runtime_controls enable row level security;
alter table private.stripe_customers enable row level security;
alter table private.stripe_connected_accounts enable row level security;
alter table private.stripe_payment_intents enable row level security;
alter table private.stripe_webhook_events enable row level security;

revoke all on table private.stripe_runtime_controls from public, anon, authenticated;
revoke all on table private.stripe_customers from public, anon, authenticated;
revoke all on table private.stripe_connected_accounts from public, anon, authenticated;
revoke all on table private.stripe_payment_intents from public, anon, authenticated;
revoke all on table private.stripe_webhook_events from public, anon, authenticated;
grant select, insert, update, delete on table private.stripe_runtime_controls to service_role;
grant select, insert, update, delete on table private.stripe_customers to service_role;
grant select, insert, update, delete on table private.stripe_connected_accounts to service_role;
grant select, insert, update, delete on table private.stripe_payment_intents to service_role;
grant select, insert, update, delete on table private.stripe_webhook_events to service_role;

create or replace function private.require_stripe_service_role()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'stripe_service_role_required' using errcode = '42501';
  end if;
end;
$$;
revoke all on function private.require_stripe_service_role() from public, anon, authenticated;
grant execute on function private.require_stripe_service_role() to service_role;

create or replace function public.get_stripe_runtime_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  controls private.stripe_runtime_controls%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select * into strict controls
  from private.stripe_runtime_controls
  where singleton;
  return jsonb_build_object(
    'mode', controls.mode,
    'environment', case controls.mode when 'sandbox' then 'test' when 'live' then 'live' else null end,
    'currency_code', controls.currency_code,
    'service_fee_cents', controls.service_fee_cents,
    'payments_enabled', controls.payments_enabled,
    'connected_onboarding_enabled', controls.connected_onboarding_enabled,
    'job_funding_enabled', controls.job_funding_enabled,
    'transfers_enabled', controls.transfers_enabled,
    'refunds_enabled', controls.refunds_enabled,
    'live_mode_enabled', controls.live_mode_enabled,
    'configured', false,
    'provider', 'stripe'
  );
end;
$$;
revoke all on function public.get_stripe_runtime_status() from public, anon;
grant execute on function public.get_stripe_runtime_status() to authenticated;

create or replace function public.get_my_stripe_payout_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  controls private.stripe_runtime_controls%rowtype;
  connected private.stripe_connected_accounts%rowtype;
  stripe_environment text;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select * into strict controls from private.stripe_runtime_controls where singleton;
  stripe_environment := case controls.mode when 'sandbox' then 'test' when 'live' then 'live' else null end;
  if stripe_environment is not null then
    select * into connected
    from private.stripe_connected_accounts
    where user_id = auth.uid() and environment = stripe_environment;
  end if;
  return jsonb_build_object(
    'configured', false,
    'enabled', controls.connected_onboarding_enabled and controls.payouts_approved,
    'connected', connected.id is not null,
    'onboarding_status', coalesce(connected.onboarding_status, 'not_started'),
    'details_submitted', coalesce(connected.details_submitted, false),
    'payouts_enabled', coalesce(connected.payouts_enabled, false),
    'transfers_capability_status', coalesce(connected.transfers_capability_status, 'inactive'),
    'requirements_status', coalesce(connected.requirements_status, 'unknown')
  );
end;
$$;
revoke all on function public.get_my_stripe_payout_status() from public, anon;
grant execute on function public.get_my_stripe_payout_status() to authenticated;

create or replace function public.stripe_server_claim_webhook_event(
  p_environment text,
  p_provider_event_id text,
  p_event_type text,
  p_provider_created_at timestamptz,
  p_payload_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  controls private.stripe_runtime_controls%rowtype;
  event_row private.stripe_webhook_events%rowtype;
  lease uuid;
begin
  perform private.require_stripe_service_role();
  if p_environment not in ('test', 'live')
    or p_provider_event_id !~ '^evt_[A-Za-z0-9]+$'
    or p_payload_sha256 !~ '^[a-f0-9]{64}$'
    or char_length(p_event_type) not between 3 and 120 then
    raise exception 'stripe_webhook_envelope_invalid';
  end if;
  select * into strict controls from private.stripe_runtime_controls where singleton;
  if controls.mode = 'disabled'
    or (controls.mode = 'sandbox' and p_environment <> 'test')
    or (controls.mode = 'live' and (p_environment <> 'live' or not controls.live_mode_enabled)) then
    raise exception 'stripe_environment_not_enabled' using errcode = '42501';
  end if;

  insert into private.stripe_webhook_events(
    environment, provider_event_id, event_type, provider_created_at,
    payload_sha256, signature_verified
  ) values (
    p_environment, p_provider_event_id, p_event_type, p_provider_created_at,
    p_payload_sha256, true
  ) on conflict (environment, provider_event_id) do nothing;

  select * into strict event_row
  from private.stripe_webhook_events
  where environment = p_environment and provider_event_id = p_provider_event_id
  for update;

  if event_row.payload_sha256 <> p_payload_sha256
    or event_row.event_type <> p_event_type then
    raise exception 'stripe_webhook_event_conflict';
  end if;
  if event_row.processing_status in ('processed', 'ignored') then
    return jsonb_build_object('claimed', false, 'duplicate', true, 'in_flight', false);
  end if;
  if event_row.processing_status = 'processing'
    and event_row.lease_expires_at > now() then
    return jsonb_build_object('claimed', false, 'duplicate', false, 'in_flight', true);
  end if;

  lease := gen_random_uuid();
  update private.stripe_webhook_events set
    processing_status = 'processing',
    lease_epoch = lease_epoch + 1,
    lease_token = lease,
    lease_expires_at = now() + interval '5 minutes',
    attempt_count = attempt_count + 1,
    safe_failure_code = null
  where id = event_row.id
  returning * into event_row;
  return jsonb_build_object(
    'claimed', true,
    'duplicate', false,
    'in_flight', false,
    'lease_token', event_row.lease_token,
    'lease_epoch', event_row.lease_epoch
  );
end;
$$;
revoke all on function public.stripe_server_claim_webhook_event(text, text, text, timestamptz, text) from public, anon, authenticated;
grant execute on function public.stripe_server_claim_webhook_event(text, text, text, timestamptz, text) to service_role;

create or replace function public.stripe_server_finish_webhook_event(
  p_environment text,
  p_provider_event_id text,
  p_lease_token uuid,
  p_disposition text,
  p_safe_failure_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_status text;
begin
  perform private.require_stripe_service_role();
  if p_disposition not in ('processed', 'ignored', 'failed') then
    raise exception 'stripe_webhook_disposition_invalid';
  end if;
  if p_safe_failure_code is not null and p_safe_failure_code !~ '^[a-z0-9_]{1,100}$' then
    raise exception 'stripe_webhook_failure_code_invalid';
  end if;
  next_status := p_disposition;
  update private.stripe_webhook_events set
    processing_status = next_status,
    safe_failure_code = case when next_status = 'failed' then p_safe_failure_code else null end,
    processed_at = case when next_status in ('processed', 'ignored') then now() else null end,
    lease_token = null,
    lease_expires_at = null
  where environment = p_environment
    and provider_event_id = p_provider_event_id
    and processing_status = 'processing'
    and lease_token = p_lease_token;
  if not found then
    raise exception 'stripe_webhook_lease_lost' using errcode = '40001';
  end if;
  return jsonb_build_object('ok', true, 'status', next_status);
end;
$$;
revoke all on function public.stripe_server_finish_webhook_event(text, text, uuid, text, text) from public, anon, authenticated;
grant execute on function public.stripe_server_finish_webhook_event(text, text, uuid, text, text) to service_role;

comment on table private.stripe_runtime_controls is
  'Server-only Stripe gates. Starts disabled; live mode requires separately reviewed owner approval.';
comment on table private.stripe_payment_intents is
  'Private provider reference and amount ledger. It is not an escrow or a promise of payout.';
comment on table private.stripe_webhook_events is
  'Signature-verified Stripe event deduplication and fenced retry ledger; raw request bodies are never stored.';

