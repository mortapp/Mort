create table private.stripe_tip_transfers (
  id uuid primary key default gen_random_uuid(),
  tip_attempt_id uuid not null references private.stripe_tip_attempts(id) on delete restrict,
  connected_account_id uuid not null references private.stripe_connected_accounts(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  amount_cents integer not null check (amount_cents > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  provider_transfer_id text check (provider_transfer_id is null or provider_transfer_id ~ '^tr_[A-Za-z0-9]+$'),
  idempotency_key text not null,
  status text not null default 'pending' check (status in ('pending', 'created', 'paid', 'failed', 'reversed')),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  unique (tip_attempt_id),
  unique (environment, idempotency_key),
  unique (environment, provider_transfer_id)
);

create or replace function public.stripe_server_apply_tip_event_v1(
  p_tip_attempt_id uuid,
  p_provider_payment_intent_id text,
  p_provider_status text,
  p_amount_cents integer,
  p_currency_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tip private.stripe_tip_attempts%rowtype;
  next_state text;
begin
  perform private.require_stripe_service_role();
  next_state := case p_provider_status
    when 'payment_intent.succeeded' then 'SUCCEEDED'
    when 'payment_intent.processing' then 'PROCESSING'
    when 'payment_intent.payment_failed' then 'DECLINED'
    when 'payment_intent.canceled' then 'CANCELLED'
    else 'UNKNOWN'
  end;
  select * into tip from private.stripe_tip_attempts where id = p_tip_attempt_id for update;
  if tip.id is null then raise exception 'tip_attempt_not_found'; end if;
  if tip.provider_payment_intent_id is not null
     and tip.provider_payment_intent_id <> p_provider_payment_intent_id then
    raise exception 'tip_provider_payment_intent_mismatch';
  end if;
  if p_amount_cents <> tip.amount_cents or upper(p_currency_code) <> tip.currency_code then
    raise exception 'tip_amount_currency_mismatch';
  end if;
  if tip.normalized_state in ('SUCCEEDED', 'DECLINED', 'FAILED', 'CANCELLED', 'DUPLICATE_BLOCKED')
     and tip.normalized_state <> next_state then
    raise exception 'tip_state_regression';
  end if;
  update private.stripe_tip_attempts
     set provider_payment_intent_id = p_provider_payment_intent_id,
         normalized_state = next_state,
         updated_at = statement_timestamp()
   where id = tip.id;
  return jsonb_build_object('ok', true, 'tip_attempt_id', tip.id, 'normalized_state', next_state);
end;
$$;

create or replace function public.stripe_server_prepare_tip_transfer_v1(
  p_tip_attempt_id uuid,
  p_environment text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tip private.stripe_tip_attempts%rowtype;
  account private.stripe_connected_accounts%rowtype;
  transfer private.stripe_tip_transfers%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into tip from private.stripe_tip_attempts where id = p_tip_attempt_id and environment = p_environment for share;
  if tip.id is null then raise exception 'tip_attempt_not_found'; end if;
  if tip.normalized_state <> 'SUCCEEDED' then raise exception 'tip_provider_confirmation_required'; end if;
  select * into account from private.stripe_connected_accounts where user_id = tip.worker_id and environment = p_environment;
  if account.id is null or account.onboarding_status <> 'complete'
     or not account.payouts_enabled or account.transfers_capability_status <> 'active'
     or account.requirements_status <> 'satisfied'
     or account.guardian_requirement_status <> 'provider_managed_satisfied'
  then raise exception 'connected_account_not_ready'; end if;
  select * into transfer from private.stripe_tip_transfers where tip_attempt_id = tip.id for update;
  if transfer.id is not null then
    return jsonb_build_object('ok', true, 'existing', true, 'tip_transfer_id', transfer.id,
      'provider_transfer_id', transfer.provider_transfer_id, 'status', transfer.status);
  end if;
  insert into private.stripe_tip_transfers (
    tip_attempt_id, connected_account_id, environment, amount_cents, currency_code, idempotency_key
  )
  values (
    tip.id, account.id, p_environment, tip.teen_amount_cents, tip.currency_code,
    p_environment || ':tip-transfer:' || tip.id::text
  )
  returning * into transfer;
  return jsonb_build_object('ok', true, 'existing', false, 'tip_transfer_id', transfer.id,
    'amount_cents', transfer.amount_cents, 'currency_code', transfer.currency_code,
    'provider_connected_account_id', account.provider_account_id,
    'provider_source_charge_id', null, 'idempotency_key', transfer.idempotency_key);
end;
$$;

create or replace function public.stripe_server_record_tip_transfer_v1(
  p_tip_transfer_id uuid,
  p_provider_transfer_id text,
  p_provider_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  transfer private.stripe_tip_transfers%rowtype;
  next_status text;
begin
  perform private.require_stripe_service_role();
  if p_provider_transfer_id is null or p_provider_transfer_id !~ '^tr_[A-Za-z0-9]+$' then
    raise exception 'tip_provider_transfer_required';
  end if;
  next_status := case p_provider_status when 'paid' then 'paid' when 'failed' then 'failed' else 'created' end;
  update private.stripe_tip_transfers
     set provider_transfer_id = p_provider_transfer_id, status = next_status, updated_at = statement_timestamp()
   where id = p_tip_transfer_id
   returning * into transfer;
  if transfer.id is null then raise exception 'tip_transfer_not_found'; end if;
  insert into private.stripe_financial_ledger_events (
    payment_intent_id, environment, event_type, component, amount_cents,
    direction, currency_code, immutable_metadata
  )
  select null, transfer.environment, 'tip_principal', 'tip', transfer.amount_cents,
    'debit', transfer.currency_code, jsonb_build_object('tip_attempt_id', transfer.tip_attempt_id,
      'provider_transfer_id', p_provider_transfer_id)
  where next_status = 'paid'
    and not exists (
      select 1 from private.stripe_financial_ledger_events event
       where event.event_type = 'tip_principal'
         and event.immutable_metadata->>'tip_attempt_id' = transfer.tip_attempt_id::text
         and event.immutable_metadata->>'provider_transfer_id' = p_provider_transfer_id
    );
  return jsonb_build_object('ok', true, 'tip_transfer_id', transfer.id, 'status', transfer.status);
end;
$$;

revoke all on function public.stripe_server_apply_tip_event_v1(uuid, text, text, integer, text)
  from public, anon, authenticated;
revoke all on function public.stripe_server_prepare_tip_transfer_v1(uuid, text)
  from public, anon, authenticated;
revoke all on function public.stripe_server_record_tip_transfer_v1(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.stripe_server_apply_tip_event_v1(uuid, text, text, integer, text)
  to service_role;
grant execute on function public.stripe_server_prepare_tip_transfer_v1(uuid, text)
  to service_role;
grant execute on function public.stripe_server_record_tip_transfer_v1(uuid, text, text)
  to service_role;