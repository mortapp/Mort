-- MORT Stripe Connect sandbox foundation.
-- Provider credentials never enter Postgres or a mobile build. Provider object
-- references live only in the private schema and all provider writes are
-- service-role RPCs reached through authenticated Edge Functions.

create table private.stripe_runtime_controls (
  singleton boolean primary key default true check (singleton),
  mode text not null default 'sandbox' check (mode in ('disabled', 'sandbox', 'live')),
  currency_code text not null default 'USD' check (currency_code ~ '^[A-Z]{3}$'),
  adult_service_fee_bps integer not null default 0 check (adult_service_fee_bps between 0 and 10000),
  adult_service_fee_fixed_cents integer not null default 0 check (adult_service_fee_fixed_cents between 0 and 100000),
  stripe_payments_enabled boolean not null default false,
  stripe_connected_onboarding_enabled boolean not null default false,
  stripe_job_funding_enabled boolean not null default false,
  stripe_transfers_enabled boolean not null default false,
  stripe_refunds_enabled boolean not null default false,
  stripe_live_mode_enabled boolean not null default false,
  live_owner_approved boolean not null default false,
  connected_accounts_approved boolean not null default false,
  payouts_approved boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  check (mode <> 'live' or (stripe_live_mode_enabled and live_owner_approved))
);

insert into private.stripe_runtime_controls (singleton) values (true)
on conflict (singleton) do nothing;

create table private.stripe_connected_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  provider_account_id text not null check (provider_account_id ~ '^acct_[A-Za-z0-9]+$'),
  account_configuration text not null default 'stripe_hosted_connect' check (account_configuration = 'stripe_hosted_connect'),
  onboarding_status text not null default 'pending' check (onboarding_status in ('pending', 'in_progress', 'complete', 'restricted', 'action_required', 'disconnected')),
  details_submitted boolean not null default false,
  charges_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  transfers_capability_status text not null default 'inactive' check (transfers_capability_status in ('inactive', 'pending', 'active', 'restricted')),
  requirements_status text not null default 'unknown' check (requirements_status in ('unknown', 'currently_due', 'eventually_due', 'past_due', 'pending_verification', 'satisfied', 'restricted')),
  guardian_requirement_status text not null default 'provider_managed_unknown' check (guardian_requirement_status in ('provider_managed_unknown', 'provider_managed_required', 'provider_managed_pending', 'provider_managed_satisfied', 'provider_managed_restricted')),
  disabled_reason_code text,
  country text check (country is null or country ~ '^[A-Z]{2}$'),
  default_currency text check (default_currency is null or default_currency ~ '^[A-Z]{3}$'),
  last_synchronized_at timestamptz,
  disconnected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, environment),
  unique (environment, provider_account_id)
);

create table private.stripe_connected_account_requirements (
  id uuid primary key default gen_random_uuid(),
  connected_account_id uuid not null references private.stripe_connected_accounts(id) on delete cascade,
  requirement_category text not null check (requirement_category in ('currently_due', 'eventually_due', 'past_due', 'pending_verification', 'disabled_reason')),
  requirement_code text not null check (char_length(requirement_code) between 1 and 160),
  observed_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (connected_account_id, requirement_category, requirement_code)
);

create table private.stripe_account_onboarding_sessions (
  id uuid primary key default gen_random_uuid(),
  connected_account_id uuid not null references private.stripe_connected_accounts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  provider_account_link_id text check (provider_account_link_id is null or provider_account_link_id ~ '^link_[A-Za-z0-9]+$'),
  return_url_origin text not null check (return_url_origin ~ '^https://'),
  refresh_url_origin text not null check (refresh_url_origin ~ '^https://'),
  status text not null default 'created' check (status in ('created', 'opened', 'returned', 'expired', 'superseded')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  returned_at timestamptz
);

create table private.stripe_customers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  provider_customer_id text not null check (provider_customer_id ~ '^cus_[A-Za-z0-9]+$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, environment),
  unique (environment, provider_customer_id)
);

create table private.stripe_job_payment_intents (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  contract_version_id uuid not null references public.job_contract_versions(id) on delete restrict,
  obligation_id uuid not null references public.job_payment_obligations(id) on delete restrict,
  adult_id uuid not null references auth.users(id) on delete restrict,
  teen_id uuid not null references auth.users(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  operation_version integer not null default 1 check (operation_version > 0),
  earnings_amount_cents integer not null check (earnings_amount_cents > 0),
  service_fee_cents integer not null check (service_fee_cents >= 0),
  total_amount_cents integer not null check (total_amount_cents = earnings_amount_cents + service_fee_cents and total_amount_cents > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  provider_customer_id text check (provider_customer_id is null or provider_customer_id ~ '^cus_[A-Za-z0-9]+$'),
  provider_payment_intent_id text check (provider_payment_intent_id is null or provider_payment_intent_id ~ '^pi_[A-Za-z0-9]+$'),
  provider_charge_id text check (provider_charge_id is null or provider_charge_id ~ '^ch_[A-Za-z0-9]+$'),
  transfer_group text not null check (transfer_group ~ '^MORT_JOB_[A-Fa-f0-9]{32}$'),
  idempotency_key text not null check (char_length(idempotency_key) between 20 and 180),
  status text not null default 'unfunded' check (status in ('unfunded', 'requires_payment_method', 'requires_action', 'processing', 'funded', 'funding_failed', 'canceled', 'transfer_pending', 'transferred', 'transfer_failed', 'refund_pending', 'partially_refunded', 'refunded', 'disputed', 'chargeback', 'closed')),
  last_failure_code text,
  funded_at timestamptz,
  canceled_at timestamptz,
  last_synchronized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (contract_version_id, environment, operation_version),
  unique (environment, provider_payment_intent_id),
  unique (environment, idempotency_key)
);

create table private.stripe_job_payment_attempts (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid not null references private.stripe_job_payment_intents(id) on delete cascade,
  request_id uuid not null,
  initiated_by uuid not null references auth.users(id) on delete restrict,
  outcome text not null check (outcome in ('prepared', 'provider_created', 'client_presented', 'client_canceled', 'provider_processing', 'provider_succeeded', 'provider_failed')),
  safe_failure_code text,
  created_at timestamptz not null default now(),
  unique (payment_intent_id, request_id, outcome)
);

create table private.stripe_job_transfers (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid not null references private.stripe_job_payment_intents(id) on delete restrict,
  connected_account_id uuid not null references private.stripe_connected_accounts(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  amount_cents integer not null check (amount_cents > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  provider_transfer_id text check (provider_transfer_id is null or provider_transfer_id ~ '^tr_[A-Za-z0-9]+$'),
  provider_source_charge_id text not null check (provider_source_charge_id ~ '^ch_[A-Za-z0-9]+$'),
  idempotency_key text not null,
  eligibility_path text not null check (eligibility_path in ('mutual_completion_confirmed', 'completion_confirmed_after_review', 'completion_without_code_approved', 'partial_completion_approved', 'authorized_safety_exit_payment')),
  status text not null default 'pending' check (status in ('pending', 'created', 'paid', 'failed', 'reversed', 'partially_reversed')),
  failure_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  transferred_at timestamptz,
  reversed_at timestamptz,
  unique (payment_intent_id),
  unique (environment, provider_transfer_id),
  unique (environment, idempotency_key)
);

create table private.stripe_job_refunds (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid not null references private.stripe_job_payment_intents(id) on delete restrict,
  requested_by uuid references auth.users(id) on delete set null,
  environment text not null check (environment in ('test', 'live')),
  amount_cents integer not null check (amount_cents > 0),
  provider_refund_id text check (provider_refund_id is null or provider_refund_id ~ '^re_[A-Za-z0-9]+$'),
  idempotency_key text not null,
  reason_code text not null check (char_length(reason_code) between 2 and 100),
  status text not null default 'pending' check (status in ('pending', 'succeeded', 'failed', 'canceled')),
  failure_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (environment, provider_refund_id),
  unique (environment, idempotency_key)
);

create table private.stripe_job_disputes (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid not null references private.stripe_job_payment_intents(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  provider_dispute_id text not null check (provider_dispute_id ~ '^dp_[A-Za-z0-9]+$'),
  amount_cents integer not null check (amount_cents > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  status text not null check (status in ('warning_received', 'needs_response', 'under_review', 'won', 'lost', 'funds_withdrawn', 'funds_reinstated', 'closed')),
  reason_code text,
  evidence_due_at timestamptz,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (environment, provider_dispute_id)
);

create table private.stripe_payout_events (
  id uuid primary key default gen_random_uuid(),
  connected_account_id uuid not null references private.stripe_connected_accounts(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  provider_payout_id text not null check (provider_payout_id ~ '^po_[A-Za-z0-9]+$'),
  amount_cents integer not null check (amount_cents > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  status text not null check (status in ('pending', 'in_transit', 'paid', 'failed', 'canceled')),
  destination_type text check (destination_type in ('bank_account', 'debit_card', 'other', 'unknown')),
  destination_last4 text check (destination_last4 is null or destination_last4 ~ '^[0-9]{4}$'),
  arrival_at timestamptz,
  failure_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (environment, provider_payout_id)
);

create table private.stripe_webhook_events (
  id uuid primary key default gen_random_uuid(),
  environment text not null check (environment in ('test', 'live')),
  provider_event_id text not null check (provider_event_id ~ '^evt_[A-Za-z0-9]+$'),
  event_type text not null check (char_length(event_type) between 3 and 120),
  provider_created_at timestamptz,
  payload_sha256 text not null check (payload_sha256 ~ '^[a-f0-9]{64}$'),
  signature_verified boolean not null check (signature_verified),
  processing_status text not null default 'received' check (processing_status in ('received', 'processed', 'ignored', 'failed')),
  safe_failure_code text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (environment, provider_event_id)
);

create table private.stripe_reconciliation_runs (
  id uuid primary key default gen_random_uuid(),
  environment text not null check (environment in ('test', 'live')),
  scope text not null check (scope in ('payment', 'connected_account', 'payout', 'stale_records')),
  subject_reference uuid,
  status text not null check (status in ('started', 'matched', 'corrected', 'needs_review', 'failed')),
  safe_result_code text,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

create table private.stripe_financial_role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role_key text not null check (role_key in ('payment_support', 'payment_reviewer', 'payment_operations', 'financial_admin', 'super_admin')),
  reason text not null check (char_length(btrim(reason)) between 8 and 500),
  assigned_by uuid not null references auth.users(id) on delete restrict,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

create table private.stripe_financial_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  environment text check (environment in ('test', 'live')),
  event_type text not null check (char_length(event_type) between 3 and 120),
  subject_type text not null check (char_length(subject_type) between 2 and 80),
  subject_id uuid,
  safe_reason_code text,
  field_names text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index stripe_connected_accounts_user_idx on private.stripe_connected_accounts(user_id, environment);
create index stripe_onboarding_sessions_user_idx on private.stripe_account_onboarding_sessions(user_id, created_at desc);
create index stripe_payment_intents_contract_idx on private.stripe_job_payment_intents(contract_id, created_at desc);
create index stripe_payment_intents_adult_idx on private.stripe_job_payment_intents(adult_id, created_at desc);
create index stripe_payment_intents_teen_idx on private.stripe_job_payment_intents(teen_id, created_at desc);
create index stripe_payment_intents_status_idx on private.stripe_job_payment_intents(environment, status, updated_at);
create index stripe_refunds_payment_idx on private.stripe_job_refunds(payment_intent_id, created_at desc);
create index stripe_disputes_payment_idx on private.stripe_job_disputes(payment_intent_id, updated_at desc);
create index stripe_webhooks_status_idx on private.stripe_webhook_events(environment, processing_status, received_at);
create index stripe_payout_account_idx on private.stripe_payout_events(connected_account_id, created_at desc);
create index stripe_roles_user_idx on private.stripe_financial_role_assignments(user_id, expires_at) where revoked_at is null;
create index stripe_audit_subject_idx on private.stripe_financial_audit_events(subject_type, subject_id, created_at desc);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'stripe_runtime_controls', 'stripe_connected_accounts',
    'stripe_connected_account_requirements', 'stripe_account_onboarding_sessions',
    'stripe_customers', 'stripe_job_payment_intents', 'stripe_job_payment_attempts',
    'stripe_job_transfers', 'stripe_job_refunds', 'stripe_job_disputes',
    'stripe_payout_events', 'stripe_webhook_events', 'stripe_reconciliation_runs',
    'stripe_financial_role_assignments', 'stripe_financial_audit_events'
  ] loop
    execute format('alter table private.%I enable row level security', table_name);
    execute format('alter table private.%I force row level security', table_name);
  end loop;
end $$;

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

create or replace function private.stripe_environment_for_mode(p_mode text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_mode when 'sandbox' then 'test' when 'live' then 'live' else null end
$$;

revoke all on function private.stripe_environment_for_mode(text) from public, anon, authenticated;
grant execute on function private.stripe_environment_for_mode(text) to service_role;

create or replace function public.get_stripe_runtime_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  control private.stripe_runtime_controls%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select * into control from private.stripe_runtime_controls where singleton;
  return jsonb_build_object(
    'mode', control.mode,
    'environment', private.stripe_environment_for_mode(control.mode),
    'currency_code', control.currency_code,
    'payments_enabled', control.stripe_payments_enabled,
    'connected_onboarding_enabled', control.stripe_connected_onboarding_enabled,
    'job_funding_enabled', control.stripe_job_funding_enabled,
    'transfers_enabled', control.stripe_transfers_enabled,
    'refunds_enabled', control.stripe_refunds_enabled,
    'live_mode_enabled', control.stripe_live_mode_enabled,
    'configured', false,
    'provider', 'stripe',
    'digital_purchases_provider', 'google_play_billing'
  );
end;
$$;

create or replace function public.get_my_stripe_payout_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  account private.stripe_connected_accounts%rowtype;
  control private.stripe_runtime_controls%rowtype;
  payout jsonb;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  select * into control from private.stripe_runtime_controls where singleton;
  select * into account
  from private.stripe_connected_accounts
  where user_id = auth.uid()
    and environment = private.stripe_environment_for_mode(control.mode);

  if account.id is null then
    return jsonb_build_object('status', 'not_started', 'onboarding_available', control.stripe_connected_onboarding_enabled, 'provider', 'stripe');
  end if;

  select jsonb_build_object(
    'status', event.status,
    'amount_cents', event.amount_cents,
    'currency_code', event.currency_code,
    'destination_type', event.destination_type,
    'destination_last4', event.destination_last4,
    'arrival_at', event.arrival_at,
    'updated_at', event.updated_at
  ) into payout
  from private.stripe_payout_events event
  where event.connected_account_id = account.id
  order by event.created_at desc
  limit 1;

  return jsonb_build_object(
    'status', account.onboarding_status,
    'details_submitted', account.details_submitted,
    'payouts_enabled', account.payouts_enabled,
    'transfers_status', account.transfers_capability_status,
    'requirements_status', account.requirements_status,
    'guardian_requirement_status', account.guardian_requirement_status,
    'disabled_reason_code', account.disabled_reason_code,
    'country', account.country,
    'default_currency', account.default_currency,
    'last_synchronized_at', account.last_synchronized_at,
    'latest_payout', payout,
    'provider', 'stripe'
  );
end;
$$;

create or replace function public.preview_job_funding(p_contract_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  contract public.job_contracts%rowtype;
  obligation public.job_payment_obligations%rowtype;
  control private.stripe_runtime_controls%rowtype;
  fee integer;
  environment text;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  select * into contract from public.job_contracts where id = p_contract_id;
  if contract.id is null or contract.adult_id <> auth.uid() then
    raise exception 'adult_contract_party_required' using errcode = '42501';
  end if;
  if contract.status not in ('active', 'change_pending') or contract.active_version_id is null then
    raise exception 'active_contract_required';
  end if;
  select * into obligation from public.job_payment_obligations
  where contract_id = contract.id and contract_version_id = contract.active_version_id;
  if obligation.id is null or obligation.amount_cents <= 0 then raise exception 'fundable_obligation_required'; end if;
  select * into control from private.stripe_runtime_controls where singleton;
  environment := private.stripe_environment_for_mode(control.mode);
  fee := ceil((obligation.amount_cents::numeric * control.adult_service_fee_bps::numeric) / 10000)::integer
    + control.adult_service_fee_fixed_cents;
  return jsonb_build_object(
    'contract_id', contract.id,
    'contract_version_id', contract.active_version_id,
    'obligation_id', obligation.id,
    'environment', environment,
    'earnings_amount_cents', obligation.amount_cents,
    'service_fee_cents', fee,
    'total_amount_cents', obligation.amount_cents + fee,
    'expected_teen_transfer_cents', obligation.amount_cents,
    'currency_code', obligation.currency_code,
    'funding_enabled', control.stripe_payments_enabled and control.stripe_job_funding_enabled,
    'provider', 'stripe',
    'not_escrow', true
  );
end;
$$;

create or replace function public.get_job_payment_summary(p_contract_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  contract public.job_contracts%rowtype;
  obligation public.job_payment_obligations%rowtype;
  payment private.stripe_job_payment_intents%rowtype;
  transfer private.stripe_job_transfers%rowtype;
  refunded integer;
  has_dispute boolean;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  select * into contract from public.job_contracts where id = p_contract_id;
  if contract.id is null or auth.uid() not in (contract.adult_id, contract.teen_id) then
    raise exception 'contract_party_required' using errcode = '42501';
  end if;
  select * into obligation from public.job_payment_obligations where contract_id = contract.id order by created_at desc limit 1;
  select * into payment from private.stripe_job_payment_intents where contract_id = contract.id order by created_at desc limit 1;
  if payment.id is not null then
    select coalesce(sum(amount_cents) filter (where status = 'succeeded'), 0)::integer into refunded
      from private.stripe_job_refunds where payment_intent_id = payment.id;
    select exists(select 1 from private.stripe_job_disputes where payment_intent_id = payment.id and status not in ('won', 'closed')) into has_dispute;
    select * into transfer from private.stripe_job_transfers where payment_intent_id = payment.id;
  end if;
  return jsonb_build_object(
    'contract_id', contract.id,
    'obligation_status', obligation.status,
    'earnings_amount_cents', obligation.amount_cents,
    'currency_code', obligation.currency_code,
    'funding_status', coalesce(payment.status, 'unfunded'),
    'service_fee_cents', case when auth.uid() = contract.adult_id then payment.service_fee_cents else null end,
    'total_amount_cents', case when auth.uid() = contract.adult_id then payment.total_amount_cents else null end,
    'refunded_amount_cents', coalesce(refunded, 0),
    'transfer_status', coalesce(transfer.status, 'not_started'),
    'dispute_active', coalesce(has_dispute, false),
    'provider', 'stripe',
    'payout_deposit_confirmed', false
  );
end;
$$;

create or replace function public.stripe_server_prepare_connected_account(p_user_id uuid, p_environment text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare profile public.profiles%rowtype; control private.stripe_runtime_controls%rowtype; existing private.stripe_connected_accounts%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into control from private.stripe_runtime_controls where singleton for share;
  if p_environment <> private.stripe_environment_for_mode(control.mode) then raise exception 'stripe_environment_mismatch'; end if;
  if not control.stripe_connected_onboarding_enabled or not control.connected_accounts_approved then raise exception 'stripe_connected_onboarding_disabled'; end if;
  if p_environment = 'live' and (not control.stripe_live_mode_enabled or not control.live_owner_approved) then raise exception 'stripe_live_disabled'; end if;
  select * into profile from public.profiles where id = p_user_id;
  if profile.id is null or profile.role <> 'teen' or profile.account_status <> 'active' then raise exception 'eligible_teen_required'; end if;
  if profile.dob is null or date_part('year', age(current_date, profile.dob)) < 13 or date_part('year', age(current_date, profile.dob)) >= 18 then raise exception 'teen_age_required'; end if;
  if p_environment = 'test' and not profile.is_test_account then raise exception 'sandbox_test_account_required'; end if;
  select * into existing from private.stripe_connected_accounts where user_id = p_user_id and environment = p_environment;
  return jsonb_build_object('ok', true, 'existing', existing.id is not null, 'provider_account_id', existing.provider_account_id, 'role', 'teen', 'age_band', private.current_age_band(profile.dob));
end;
$$;

create or replace function public.stripe_server_record_connected_account(
  p_user_id uuid, p_environment text, p_provider_account_id text,
  p_country text default null, p_default_currency text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare account private.stripe_connected_accounts%rowtype;
begin
  perform public.stripe_server_prepare_connected_account(p_user_id, p_environment);
  insert into private.stripe_connected_accounts(user_id, environment, provider_account_id, country, default_currency)
  values (p_user_id, p_environment, p_provider_account_id, upper(p_country), upper(p_default_currency))
  on conflict (user_id, environment) do update
    set updated_at = now()
    where private.stripe_connected_accounts.provider_account_id = excluded.provider_account_id
  returning * into account;
  if account.id is null then raise exception 'connected_account_reference_conflict'; end if;
  insert into private.stripe_financial_audit_events(actor_id, environment, event_type, subject_type, subject_id, field_names)
  values (p_user_id, p_environment, 'connected_account_recorded', 'connected_account', account.id, array['provider_account_id']);
  return jsonb_build_object('ok', true, 'connected_account_record_id', account.id);
end;
$$;

create or replace function public.stripe_server_record_connected_account_status(
  p_provider_account_id text, p_environment text, p_onboarding_status text,
  p_details_submitted boolean, p_charges_enabled boolean, p_payouts_enabled boolean,
  p_transfers_capability_status text, p_requirements_status text,
  p_guardian_requirement_status text, p_disabled_reason_code text default null,
  p_country text default null, p_default_currency text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare account private.stripe_connected_accounts%rowtype;
begin
  perform private.require_stripe_service_role();
  update private.stripe_connected_accounts set
    onboarding_status = p_onboarding_status,
    details_submitted = p_details_submitted,
    charges_enabled = p_charges_enabled,
    payouts_enabled = p_payouts_enabled,
    transfers_capability_status = p_transfers_capability_status,
    requirements_status = p_requirements_status,
    guardian_requirement_status = p_guardian_requirement_status,
    disabled_reason_code = left(nullif(p_disabled_reason_code, ''), 160),
    country = coalesce(upper(p_country), country),
    default_currency = coalesce(upper(p_default_currency), default_currency),
    last_synchronized_at = now(), updated_at = now()
  where provider_account_id = p_provider_account_id and environment = p_environment
  returning * into account;
  if account.id is null then raise exception 'connected_account_not_found'; end if;
  return jsonb_build_object('ok', true, 'user_id', account.user_id, 'record_id', account.id);
end;
$$;

create or replace function public.stripe_server_record_onboarding_session(
  p_user_id uuid, p_environment text, p_provider_account_link_id text,
  p_return_url_origin text, p_refresh_url_origin text, p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare account private.stripe_connected_accounts%rowtype; session_id uuid;
begin
  perform private.require_stripe_service_role();
  select * into account from private.stripe_connected_accounts where user_id = p_user_id and environment = p_environment;
  if account.id is null then raise exception 'connected_account_not_found'; end if;
  if p_expires_at <= now() or p_expires_at > now() + interval '2 hours' then raise exception 'invalid_onboarding_expiry'; end if;
  if p_return_url_origin !~ '^https://' or p_refresh_url_origin !~ '^https://' then raise exception 'https_redirect_required'; end if;
  update private.stripe_account_onboarding_sessions set status = 'superseded'
    where connected_account_id = account.id and status in ('created', 'opened');
  insert into private.stripe_account_onboarding_sessions(connected_account_id, user_id, environment, provider_account_link_id, return_url_origin, refresh_url_origin, expires_at)
  values (account.id, p_user_id, p_environment, p_provider_account_link_id, p_return_url_origin, p_refresh_url_origin, p_expires_at)
  returning id into session_id;
  return jsonb_build_object('ok', true, 'session_id', session_id);
end;
$$;

create or replace function public.stripe_server_prepare_job_payment(
  p_adult_id uuid, p_contract_id uuid, p_environment text, p_operation_version integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  contract public.job_contracts%rowtype; obligation public.job_payment_obligations%rowtype;
  control private.stripe_runtime_controls%rowtype; adult_profile public.profiles%rowtype; teen_profile public.profiles%rowtype;
  existing private.stripe_job_payment_intents%rowtype; customer private.stripe_customers%rowtype;
  fee integer; transfer_group text; idem text;
begin
  perform private.require_stripe_service_role();
  select * into control from private.stripe_runtime_controls where singleton for share;
  if p_environment <> private.stripe_environment_for_mode(control.mode) then raise exception 'stripe_environment_mismatch'; end if;
  if not control.stripe_payments_enabled or not control.stripe_job_funding_enabled then raise exception 'stripe_job_funding_disabled'; end if;
  if p_environment = 'live' and (not control.stripe_live_mode_enabled or not control.live_owner_approved) then raise exception 'stripe_live_disabled'; end if;
  if p_operation_version < 1 then raise exception 'invalid_operation_version'; end if;
  select * into contract from public.job_contracts where id = p_contract_id for share;
  if contract.id is null or contract.adult_id <> p_adult_id then raise exception 'adult_contract_party_required'; end if;
  if contract.status <> 'active' or contract.active_version_id is null then raise exception 'active_contract_required'; end if;
  select * into adult_profile from public.profiles where id = contract.adult_id;
  select * into teen_profile from public.profiles where id = contract.teen_id;
  if adult_profile.role <> 'adult' or adult_profile.account_status <> 'active' or teen_profile.role <> 'teen' or teen_profile.account_status <> 'active' then raise exception 'eligible_contract_parties_required'; end if;
  if p_environment = 'test' and (not adult_profile.is_test_account or not teen_profile.is_test_account) then raise exception 'sandbox_test_contract_required'; end if;
  select * into obligation from public.job_payment_obligations where contract_id = contract.id and contract_version_id = contract.active_version_id for share;
  if obligation.id is null or obligation.amount_cents <= 0 or obligation.currency_code <> control.currency_code then raise exception 'fundable_obligation_required'; end if;
  fee := ceil((obligation.amount_cents::numeric * control.adult_service_fee_bps::numeric) / 10000)::integer + control.adult_service_fee_fixed_cents;
  if obligation.amount_cents + fee > 100000000 then raise exception 'payment_amount_limit_exceeded'; end if;
  transfer_group := 'MORT_JOB_' || replace(contract.id::text, '-', '');
  idem := p_environment || ':job:' || contract.id::text || ':version:' || contract.active_version_id::text || ':funding:' || p_operation_version::text;
  select * into existing from private.stripe_job_payment_intents
    where contract_version_id = contract.active_version_id and environment = p_environment and operation_version = p_operation_version;
  select * into customer from private.stripe_customers where user_id = p_adult_id and environment = p_environment;
  return jsonb_build_object(
    'ok', true, 'existing', existing.id is not null,
    'record_id', existing.id, 'provider_payment_intent_id', existing.provider_payment_intent_id,
    'provider_customer_id', coalesce(existing.provider_customer_id, customer.provider_customer_id),
    'contract_id', contract.id, 'contract_version_id', contract.active_version_id, 'obligation_id', obligation.id,
    'adult_id', contract.adult_id, 'teen_id', contract.teen_id, 'environment', p_environment,
    'earnings_amount_cents', obligation.amount_cents, 'service_fee_cents', fee,
    'total_amount_cents', obligation.amount_cents + fee, 'currency_code', obligation.currency_code,
    'transfer_group', transfer_group, 'idempotency_key', idem, 'operation_version', p_operation_version
  );
end;
$$;

create or replace function public.stripe_server_record_customer(p_user_id uuid, p_environment text, p_provider_customer_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare customer private.stripe_customers%rowtype;
begin
  perform private.require_stripe_service_role();
  insert into private.stripe_customers(user_id, environment, provider_customer_id)
  values (p_user_id, p_environment, p_provider_customer_id)
  on conflict (user_id, environment) do update set updated_at = now()
    where private.stripe_customers.provider_customer_id = excluded.provider_customer_id
  returning * into customer;
  if customer.id is null then raise exception 'stripe_customer_reference_conflict'; end if;
  return jsonb_build_object('ok', true, 'customer_record_id', customer.id);
end;
$$;

create or replace function public.stripe_server_record_payment_intent(
  p_adult_id uuid, p_contract_id uuid, p_environment text, p_operation_version integer,
  p_provider_customer_id text, p_provider_payment_intent_id text, p_provider_status text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare prepared jsonb; payment private.stripe_job_payment_intents%rowtype; mapped_status text;
begin
  perform private.require_stripe_service_role();
  prepared := public.stripe_server_prepare_job_payment(p_adult_id, p_contract_id, p_environment, p_operation_version);
  mapped_status := case p_provider_status
    when 'requires_payment_method' then 'requires_payment_method'
    when 'requires_action' then 'requires_action'
    when 'processing' then 'processing'
    when 'succeeded' then 'processing'
    when 'canceled' then 'canceled'
    else 'unfunded' end;
  insert into private.stripe_job_payment_intents(
    contract_id, contract_version_id, obligation_id, adult_id, teen_id, environment, operation_version,
    earnings_amount_cents, service_fee_cents, total_amount_cents, currency_code,
    provider_customer_id, provider_payment_intent_id, transfer_group, idempotency_key, status
  ) values (
    (prepared->>'contract_id')::uuid, (prepared->>'contract_version_id')::uuid, (prepared->>'obligation_id')::uuid,
    (prepared->>'adult_id')::uuid, (prepared->>'teen_id')::uuid, p_environment, p_operation_version,
    (prepared->>'earnings_amount_cents')::integer, (prepared->>'service_fee_cents')::integer,
    (prepared->>'total_amount_cents')::integer, prepared->>'currency_code', p_provider_customer_id,
    p_provider_payment_intent_id, prepared->>'transfer_group', prepared->>'idempotency_key', mapped_status
  ) on conflict (contract_version_id, environment, operation_version) do update set
    provider_customer_id = excluded.provider_customer_id,
    provider_payment_intent_id = excluded.provider_payment_intent_id,
    status = excluded.status,
    updated_at = now()
  where private.stripe_job_payment_intents.provider_payment_intent_id is null
     or private.stripe_job_payment_intents.provider_payment_intent_id = excluded.provider_payment_intent_id
  returning * into payment;
  if payment.id is null then raise exception 'payment_intent_reference_conflict'; end if;
  insert into private.stripe_job_payment_attempts(payment_intent_id, request_id, initiated_by, outcome)
  values (payment.id, p_request_id, p_adult_id, 'provider_created') on conflict do nothing;
  return jsonb_build_object('ok', true, 'payment_record_id', payment.id, 'status', payment.status);
end;
$$;

create or replace function public.stripe_server_claim_webhook_event(
  p_environment text, p_provider_event_id text, p_event_type text,
  p_provider_created_at timestamptz, p_payload_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare event private.stripe_webhook_events%rowtype; inserted boolean := false; control private.stripe_runtime_controls%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into control from private.stripe_runtime_controls where singleton;
  if p_environment <> private.stripe_environment_for_mode(control.mode) then raise exception 'stripe_environment_mismatch'; end if;
  insert into private.stripe_webhook_events(environment, provider_event_id, event_type, provider_created_at, payload_sha256, signature_verified)
  values (p_environment, p_provider_event_id, p_event_type, p_provider_created_at, p_payload_sha256, true)
  on conflict (environment, provider_event_id) do nothing returning * into event;
  inserted := event.id is not null;
  if not inserted then select * into event from private.stripe_webhook_events where environment = p_environment and provider_event_id = p_provider_event_id; end if;
  if event.payload_sha256 <> p_payload_sha256 then raise exception 'stripe_webhook_replay_payload_mismatch'; end if;
  return jsonb_build_object('ok', true, 'claimed', inserted, 'event_record_id', event.id, 'processing_status', event.processing_status);
end;
$$;

create or replace function public.stripe_server_apply_payment_event(
  p_environment text, p_provider_event_id text, p_event_type text,
  p_provider_payment_intent_id text, p_provider_charge_id text,
  p_amount_cents integer, p_currency_code text, p_safe_failure_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare payment private.stripe_job_payment_intents%rowtype; next_status text;
begin
  perform private.require_stripe_service_role();
  select * into payment from private.stripe_job_payment_intents
  where environment = p_environment and provider_payment_intent_id = p_provider_payment_intent_id for update;
  if payment.id is null then raise exception 'stripe_payment_intent_not_found'; end if;
  if p_amount_cents is not null and p_amount_cents <> payment.total_amount_cents then raise exception 'stripe_payment_amount_mismatch'; end if;
  if p_currency_code is not null and upper(p_currency_code) <> payment.currency_code then raise exception 'stripe_payment_currency_mismatch'; end if;
  next_status := case p_event_type
    when 'payment_intent.succeeded' then 'funded'
    when 'payment_intent.processing' then 'processing'
    when 'payment_intent.payment_failed' then 'funding_failed'
    when 'payment_intent.canceled' then 'canceled'
    else null end;
  if next_status is null then raise exception 'unsupported_payment_event'; end if;
  update private.stripe_job_payment_intents set
    status = next_status,
    provider_charge_id = coalesce(p_provider_charge_id, provider_charge_id),
    last_failure_code = case when next_status = 'funding_failed' then left(p_safe_failure_code, 120) else null end,
    funded_at = case when next_status = 'funded' then coalesce(funded_at, now()) else funded_at end,
    canceled_at = case when next_status = 'canceled' then coalesce(canceled_at, now()) else canceled_at end,
    last_synchronized_at = now(), updated_at = now()
  where id = payment.id;
  update private.stripe_webhook_events set processing_status = 'processed', processed_at = now()
    where environment = p_environment and provider_event_id = p_provider_event_id;
  return jsonb_build_object('ok', true, 'payment_record_id', payment.id, 'status', next_status);
end;
$$;

create or replace function public.stripe_server_fail_webhook_event(p_environment text, p_provider_event_id text, p_safe_failure_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_stripe_service_role();
  update private.stripe_webhook_events set processing_status = 'failed', safe_failure_code = left(p_safe_failure_code, 120), processed_at = now()
    where environment = p_environment and provider_event_id = p_provider_event_id;
  return jsonb_build_object('ok', found);
end;
$$;

create or replace function public.stripe_server_prepare_transfer(
  p_contract_id uuid, p_environment text, p_eligibility_path text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  control private.stripe_runtime_controls%rowtype;
  contract public.job_contracts%rowtype;
  payment private.stripe_job_payment_intents%rowtype;
  account private.stripe_connected_accounts%rowtype;
  existing private.stripe_job_transfers%rowtype;
  active_dispute boolean;
  active_nonpayment_dispute boolean;
  idem text;
begin
  perform private.require_stripe_service_role();
  select * into control from private.stripe_runtime_controls where singleton for share;
  if p_environment <> private.stripe_environment_for_mode(control.mode) then raise exception 'stripe_environment_mismatch'; end if;
  if not control.stripe_transfers_enabled or not control.payouts_approved then raise exception 'stripe_transfers_disabled'; end if;
  if p_environment = 'live' and (not control.stripe_live_mode_enabled or not control.live_owner_approved) then raise exception 'stripe_live_disabled'; end if;
  if p_eligibility_path not in ('mutual_completion_confirmed', 'completion_confirmed_after_review', 'completion_without_code_approved', 'partial_completion_approved', 'authorized_safety_exit_payment') then raise exception 'invalid_transfer_eligibility_path'; end if;
  select * into contract from public.job_contracts where id = p_contract_id for share;
  if contract.id is null or contract.status <> 'completed' then raise exception 'completed_contract_required'; end if;
  select * into payment from private.stripe_job_payment_intents
    where contract_id = contract.id and environment = p_environment order by created_at desc limit 1 for update;
  if payment.id is null or payment.status <> 'funded' or payment.provider_charge_id is null then raise exception 'funded_payment_required'; end if;
  select * into account from private.stripe_connected_accounts
    where user_id = contract.teen_id and environment = p_environment for share;
  if account.id is null or not account.payouts_enabled or account.transfers_capability_status <> 'active' or account.onboarding_status <> 'complete' then raise exception 'eligible_connected_account_required'; end if;
  select exists(select 1 from private.stripe_job_disputes dispute where dispute.payment_intent_id = payment.id and dispute.status not in ('won', 'closed')) into active_dispute;
  select exists(select 1 from public.payment_disputes dispute where dispute.contract_id = contract.id and dispute.status not in ('resolved', 'closed', 'dismissed')) into active_nonpayment_dispute;
  if active_dispute or active_nonpayment_dispute then raise exception 'active_dispute_blocks_transfer'; end if;
  if exists(select 1 from private.stripe_job_refunds refund where refund.payment_intent_id = payment.id and refund.status = 'succeeded') then raise exception 'refund_blocks_transfer'; end if;
  select * into existing from private.stripe_job_transfers where payment_intent_id = payment.id;
  idem := p_environment || ':job:' || contract.id::text || ':transfer:1';
  return jsonb_build_object(
    'ok', true, 'existing', existing.id is not null, 'transfer_record_id', existing.id,
    'provider_transfer_id', existing.provider_transfer_id,
    'payment_record_id', payment.id, 'provider_source_charge_id', payment.provider_charge_id,
    'provider_connected_account_id', account.provider_account_id,
    'amount_cents', payment.earnings_amount_cents, 'currency_code', payment.currency_code,
    'transfer_group', payment.transfer_group, 'idempotency_key', idem,
    'eligibility_path', p_eligibility_path
  );
end;
$$;

create or replace function public.stripe_server_record_transfer(
  p_contract_id uuid, p_environment text, p_eligibility_path text,
  p_provider_transfer_id text, p_provider_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare prepared jsonb; transfer private.stripe_job_transfers%rowtype; mapped_status text;
begin
  perform private.require_stripe_service_role();
  prepared := public.stripe_server_prepare_transfer(p_contract_id, p_environment, p_eligibility_path);
  mapped_status := case p_provider_status when 'paid' then 'paid' when 'failed' then 'failed' else 'created' end;
  insert into private.stripe_job_transfers(
    payment_intent_id, connected_account_id, environment, amount_cents, currency_code,
    provider_transfer_id, provider_source_charge_id, idempotency_key, eligibility_path, status, transferred_at
  ) values (
    (prepared->>'payment_record_id')::uuid,
    (select id from private.stripe_connected_accounts where environment = p_environment and provider_account_id = prepared->>'provider_connected_account_id'),
    p_environment, (prepared->>'amount_cents')::integer, prepared->>'currency_code', p_provider_transfer_id,
    prepared->>'provider_source_charge_id', prepared->>'idempotency_key', p_eligibility_path, mapped_status,
    case when mapped_status in ('created', 'paid') then now() else null end
  ) on conflict (payment_intent_id) do update set
    provider_transfer_id = excluded.provider_transfer_id,
    status = excluded.status,
    updated_at = now(),
    transferred_at = coalesce(private.stripe_job_transfers.transferred_at, excluded.transferred_at)
  where private.stripe_job_transfers.provider_transfer_id is null
     or private.stripe_job_transfers.provider_transfer_id = excluded.provider_transfer_id
  returning * into transfer;
  if transfer.id is null then raise exception 'stripe_transfer_reference_conflict'; end if;
  update private.stripe_job_payment_intents set status = case when mapped_status = 'failed' then 'transfer_failed' else 'transferred' end, updated_at = now()
    where id = transfer.payment_intent_id;
  return jsonb_build_object('ok', true, 'transfer_record_id', transfer.id, 'status', transfer.status);
end;
$$;

create or replace function public.stripe_server_prepare_refund(
  p_payment_record_id uuid, p_environment text, p_amount_cents integer,
  p_reason_code text, p_requested_by uuid, p_operation_version integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare control private.stripe_runtime_controls%rowtype; payment private.stripe_job_payment_intents%rowtype; refunded integer; existing private.stripe_job_refunds%rowtype; idem text;
begin
  perform private.require_stripe_service_role();
  select * into control from private.stripe_runtime_controls where singleton for share;
  if p_environment <> private.stripe_environment_for_mode(control.mode) then raise exception 'stripe_environment_mismatch'; end if;
  if not control.stripe_refunds_enabled then raise exception 'stripe_refunds_disabled'; end if;
  select * into payment from private.stripe_job_payment_intents where id = p_payment_record_id and environment = p_environment for update;
  if payment.id is null or payment.status not in ('funded', 'transfer_pending', 'transferred', 'disputed', 'partially_refunded') then raise exception 'refundable_payment_required'; end if;
  select coalesce(sum(amount_cents) filter (where status in ('pending', 'succeeded')), 0)::integer into refunded from private.stripe_job_refunds where payment_intent_id = payment.id;
  if p_amount_cents <= 0 or p_amount_cents > payment.total_amount_cents - refunded then raise exception 'invalid_refund_amount'; end if;
  if char_length(coalesce(p_reason_code, '')) < 2 then raise exception 'refund_reason_required'; end if;
  idem := p_environment || ':payment:' || payment.id::text || ':refund:' || p_operation_version::text;
  select * into existing from private.stripe_job_refunds where environment = p_environment and idempotency_key = idem;
  return jsonb_build_object(
    'ok', true, 'existing', existing.id is not null, 'refund_record_id', existing.id,
    'provider_refund_id', existing.provider_refund_id, 'provider_payment_intent_id', payment.provider_payment_intent_id,
    'provider_charge_id', payment.provider_charge_id, 'amount_cents', p_amount_cents,
    'currency_code', payment.currency_code, 'reason_code', left(p_reason_code, 100),
    'requested_by', p_requested_by, 'idempotency_key', idem,
    'transfer_reversal_review_required', exists(select 1 from private.stripe_job_transfers t where t.payment_intent_id = payment.id and t.status in ('created', 'paid'))
  );
end;
$$;

create or replace function public.stripe_server_record_refund(
  p_payment_record_id uuid, p_environment text, p_amount_cents integer,
  p_reason_code text, p_requested_by uuid, p_operation_version integer,
  p_provider_refund_id text, p_provider_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare prepared jsonb; refund private.stripe_job_refunds%rowtype; mapped_status text; total_refunded integer; payment_total integer;
begin
  perform private.require_stripe_service_role();
  prepared := public.stripe_server_prepare_refund(p_payment_record_id, p_environment, p_amount_cents, p_reason_code, p_requested_by, p_operation_version);
  mapped_status := case p_provider_status when 'succeeded' then 'succeeded' when 'failed' then 'failed' when 'canceled' then 'canceled' else 'pending' end;
  insert into private.stripe_job_refunds(payment_intent_id, requested_by, environment, amount_cents, provider_refund_id, idempotency_key, reason_code, status)
  values (p_payment_record_id, p_requested_by, p_environment, p_amount_cents, p_provider_refund_id, prepared->>'idempotency_key', left(p_reason_code, 100), mapped_status)
  on conflict (environment, idempotency_key) do update set
    provider_refund_id = excluded.provider_refund_id, status = excluded.status, updated_at = now()
  where private.stripe_job_refunds.provider_refund_id is null or private.stripe_job_refunds.provider_refund_id = excluded.provider_refund_id
  returning * into refund;
  if refund.id is null then raise exception 'stripe_refund_reference_conflict'; end if;
  select total_amount_cents into payment_total from private.stripe_job_payment_intents where id = p_payment_record_id;
  select coalesce(sum(amount_cents) filter (where status = 'succeeded'), 0)::integer into total_refunded from private.stripe_job_refunds where payment_intent_id = p_payment_record_id;
  update private.stripe_job_payment_intents set
    status = case when mapped_status = 'pending' then 'refund_pending' when mapped_status = 'succeeded' and total_refunded >= payment_total then 'refunded' when mapped_status = 'succeeded' then 'partially_refunded' else status end,
    updated_at = now()
  where id = p_payment_record_id;
  return jsonb_build_object('ok', true, 'refund_record_id', refund.id, 'status', refund.status);
end;
$$;

create or replace function public.stripe_server_apply_dispute_event(
  p_environment text, p_provider_event_id text, p_provider_payment_intent_id text,
  p_provider_dispute_id text, p_amount_cents integer, p_currency_code text,
  p_status text, p_reason_code text default null, p_evidence_due_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare payment private.stripe_job_payment_intents%rowtype; dispute private.stripe_job_disputes%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into payment from private.stripe_job_payment_intents where environment = p_environment and provider_payment_intent_id = p_provider_payment_intent_id for update;
  if payment.id is null then raise exception 'stripe_payment_intent_not_found'; end if;
  if p_amount_cents <= 0 or p_amount_cents > payment.total_amount_cents or upper(p_currency_code) <> payment.currency_code then raise exception 'stripe_dispute_amount_mismatch'; end if;
  insert into private.stripe_job_disputes(payment_intent_id, environment, provider_dispute_id, amount_cents, currency_code, status, reason_code, evidence_due_at, closed_at)
  values (payment.id, p_environment, p_provider_dispute_id, p_amount_cents, upper(p_currency_code), p_status, left(p_reason_code, 120), p_evidence_due_at, case when p_status in ('won', 'lost', 'closed') then now() else null end)
  on conflict (environment, provider_dispute_id) do update set
    status = excluded.status, reason_code = excluded.reason_code, evidence_due_at = excluded.evidence_due_at,
    closed_at = excluded.closed_at, updated_at = now()
  returning * into dispute;
  update private.stripe_job_payment_intents set status = case when p_status in ('won', 'closed') then 'funded' when p_status = 'lost' then 'chargeback' else 'disputed' end, updated_at = now() where id = payment.id;
  update private.stripe_webhook_events set processing_status = 'processed', processed_at = now() where environment = p_environment and provider_event_id = p_provider_event_id;
  return jsonb_build_object('ok', true, 'dispute_record_id', dispute.id, 'status', dispute.status);
end;
$$;

create or replace function public.stripe_server_apply_transfer_event(
  p_environment text, p_provider_event_id text, p_provider_transfer_id text,
  p_status text, p_failure_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare transfer private.stripe_job_transfers%rowtype;
begin
  perform private.require_stripe_service_role();
  update private.stripe_job_transfers set
    status = p_status, failure_code = left(p_failure_code, 120), updated_at = now(),
    reversed_at = case when p_status in ('reversed', 'partially_reversed') then now() else reversed_at end
  where environment = p_environment and provider_transfer_id = p_provider_transfer_id returning * into transfer;
  if transfer.id is null then raise exception 'stripe_transfer_not_found'; end if;
  update private.stripe_job_payment_intents set status = case p_status when 'failed' then 'transfer_failed' when 'reversed' then 'funded' else status end, updated_at = now() where id = transfer.payment_intent_id;
  update private.stripe_webhook_events set processing_status = 'processed', processed_at = now() where environment = p_environment and provider_event_id = p_provider_event_id;
  return jsonb_build_object('ok', true, 'transfer_record_id', transfer.id, 'status', transfer.status);
end;
$$;

create or replace function public.stripe_server_apply_payout_event(
  p_environment text, p_provider_event_id text, p_provider_account_id text,
  p_provider_payout_id text, p_amount_cents integer, p_currency_code text,
  p_status text, p_destination_type text default 'unknown', p_destination_last4 text default null,
  p_arrival_at timestamptz default null, p_failure_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare account private.stripe_connected_accounts%rowtype; payout private.stripe_payout_events%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into account from private.stripe_connected_accounts where environment = p_environment and provider_account_id = p_provider_account_id;
  if account.id is null then raise exception 'stripe_connected_account_not_found'; end if;
  insert into private.stripe_payout_events(connected_account_id, environment, provider_payout_id, amount_cents, currency_code, status, destination_type, destination_last4, arrival_at, failure_code)
  values (account.id, p_environment, p_provider_payout_id, p_amount_cents, upper(p_currency_code), p_status, p_destination_type, p_destination_last4, p_arrival_at, left(p_failure_code, 120))
  on conflict (environment, provider_payout_id) do update set
    status = excluded.status, destination_type = excluded.destination_type, destination_last4 = excluded.destination_last4,
    arrival_at = excluded.arrival_at, failure_code = excluded.failure_code, updated_at = now()
  returning * into payout;
  update private.stripe_webhook_events set processing_status = 'processed', processed_at = now() where environment = p_environment and provider_event_id = p_provider_event_id;
  return jsonb_build_object('ok', true, 'payout_record_id', payout.id, 'status', payout.status);
end;
$$;

create or replace function public.stripe_server_record_reconciliation(
  p_environment text, p_scope text, p_subject_reference uuid, p_status text, p_safe_result_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare run_id uuid;
begin
  perform private.require_stripe_service_role();
  insert into private.stripe_reconciliation_runs(environment, scope, subject_reference, status, safe_result_code, completed_at)
  values (p_environment, p_scope, p_subject_reference, p_status, left(p_safe_result_code, 120), case when p_status <> 'started' then now() else null end)
  returning id into run_id;
  return jsonb_build_object('ok', true, 'reconciliation_run_id', run_id);
end;
$$;

create or replace function public.stripe_server_update_controls(
  p_stripe_payments_enabled boolean,
  p_stripe_connected_onboarding_enabled boolean,
  p_stripe_job_funding_enabled boolean,
  p_stripe_transfers_enabled boolean,
  p_stripe_refunds_enabled boolean,
  p_reason_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare control private.stripe_runtime_controls%rowtype;
begin
  perform private.require_stripe_service_role();
  if char_length(btrim(coalesce(p_reason_code, ''))) < 8 then raise exception 'control_change_reason_required'; end if;
  update private.stripe_runtime_controls set
    stripe_payments_enabled = p_stripe_payments_enabled,
    stripe_connected_onboarding_enabled = p_stripe_connected_onboarding_enabled,
    stripe_job_funding_enabled = p_stripe_job_funding_enabled,
    stripe_transfers_enabled = p_stripe_transfers_enabled,
    stripe_refunds_enabled = p_stripe_refunds_enabled,
    updated_at = now()
  where singleton returning * into control;
  insert into private.stripe_financial_audit_events(environment, event_type, subject_type, safe_reason_code, field_names)
  values (private.stripe_environment_for_mode(control.mode), 'runtime_controls_changed', 'stripe_runtime_controls', left(p_reason_code, 120),
    array['stripe_payments_enabled','stripe_connected_onboarding_enabled','stripe_job_funding_enabled','stripe_transfers_enabled','stripe_refunds_enabled']);
  return jsonb_build_object('ok', true, 'mode', control.mode, 'payments_enabled', control.stripe_payments_enabled,
    'connected_onboarding_enabled', control.stripe_connected_onboarding_enabled, 'job_funding_enabled', control.stripe_job_funding_enabled,
    'transfers_enabled', control.stripe_transfers_enabled, 'refunds_enabled', control.stripe_refunds_enabled);
end;
$$;

create or replace function public.get_stripe_live_readiness()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare control private.stripe_runtime_controls%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  select * into control from private.stripe_runtime_controls where singleton;
  return jsonb_build_object(
    'ready', false,
    'live_mode_enabled', control.stripe_live_mode_enabled,
    'owner_approved', control.live_owner_approved,
    'connected_accounts_approved', control.connected_accounts_approved,
    'payouts_approved', control.payouts_approved,
    'external_review_required', true,
    'physical_android_test_required', true,
    'legal_review_required', true,
    'minor_payout_confirmation_required', true
  );
end;
$$;

revoke all on function public.get_stripe_runtime_status() from public, anon;
revoke all on function public.get_my_stripe_payout_status() from public, anon;
revoke all on function public.preview_job_funding(uuid) from public, anon;
revoke all on function public.get_job_payment_summary(uuid) from public, anon;
revoke all on function public.get_stripe_live_readiness() from public, anon;
grant execute on function public.get_stripe_runtime_status() to authenticated;
grant execute on function public.get_my_stripe_payout_status() to authenticated;
grant execute on function public.preview_job_funding(uuid) to authenticated;
grant execute on function public.get_job_payment_summary(uuid) to authenticated;
grant execute on function public.get_stripe_live_readiness() to authenticated;

revoke all on function public.stripe_server_prepare_connected_account(uuid, text) from public, anon, authenticated;
revoke all on function public.stripe_server_record_connected_account(uuid, text, text, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_record_connected_account_status(text, text, text, boolean, boolean, boolean, text, text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_record_onboarding_session(uuid, text, text, text, text, timestamptz) from public, anon, authenticated;
revoke all on function public.stripe_server_prepare_job_payment(uuid, uuid, text, integer) from public, anon, authenticated;
revoke all on function public.stripe_server_record_customer(uuid, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_record_payment_intent(uuid, uuid, text, integer, text, text, text, uuid) from public, anon, authenticated;
revoke all on function public.stripe_server_claim_webhook_event(text, text, text, timestamptz, text) from public, anon, authenticated;
revoke all on function public.stripe_server_apply_payment_event(text, text, text, text, text, integer, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_fail_webhook_event(text, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_prepare_transfer(uuid, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_record_transfer(uuid, text, text, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_prepare_refund(uuid, text, integer, text, uuid, integer) from public, anon, authenticated;
revoke all on function public.stripe_server_record_refund(uuid, text, integer, text, uuid, integer, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_apply_dispute_event(text, text, text, text, integer, text, text, text, timestamptz) from public, anon, authenticated;
revoke all on function public.stripe_server_apply_transfer_event(text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_apply_payout_event(text, text, text, text, integer, text, text, text, text, timestamptz, text) from public, anon, authenticated;
revoke all on function public.stripe_server_record_reconciliation(text, text, uuid, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_update_controls(boolean, boolean, boolean, boolean, boolean, text) from public, anon, authenticated;

grant execute on function public.stripe_server_prepare_connected_account(uuid, text) to service_role;
grant execute on function public.stripe_server_record_connected_account(uuid, text, text, text, text) to service_role;
grant execute on function public.stripe_server_record_connected_account_status(text, text, text, boolean, boolean, boolean, text, text, text, text, text, text) to service_role;
grant execute on function public.stripe_server_record_onboarding_session(uuid, text, text, text, text, timestamptz) to service_role;
grant execute on function public.stripe_server_prepare_job_payment(uuid, uuid, text, integer) to service_role;
grant execute on function public.stripe_server_record_customer(uuid, text, text) to service_role;
grant execute on function public.stripe_server_record_payment_intent(uuid, uuid, text, integer, text, text, text, uuid) to service_role;
grant execute on function public.stripe_server_claim_webhook_event(text, text, text, timestamptz, text) to service_role;
grant execute on function public.stripe_server_apply_payment_event(text, text, text, text, text, integer, text, text) to service_role;
grant execute on function public.stripe_server_fail_webhook_event(text, text, text) to service_role;
grant execute on function public.stripe_server_prepare_transfer(uuid, text, text) to service_role;
grant execute on function public.stripe_server_record_transfer(uuid, text, text, text, text) to service_role;
grant execute on function public.stripe_server_prepare_refund(uuid, text, integer, text, uuid, integer) to service_role;
grant execute on function public.stripe_server_record_refund(uuid, text, integer, text, uuid, integer, text, text) to service_role;
grant execute on function public.stripe_server_apply_dispute_event(text, text, text, text, integer, text, text, text, timestamptz) to service_role;
grant execute on function public.stripe_server_apply_transfer_event(text, text, text, text, text) to service_role;
grant execute on function public.stripe_server_apply_payout_event(text, text, text, text, integer, text, text, text, text, timestamptz, text) to service_role;
grant execute on function public.stripe_server_record_reconciliation(text, text, uuid, text, text) to service_role;
grant execute on function public.stripe_server_update_controls(boolean, boolean, boolean, boolean, boolean, text) to service_role;

revoke all on all tables in schema private from anon, authenticated;
