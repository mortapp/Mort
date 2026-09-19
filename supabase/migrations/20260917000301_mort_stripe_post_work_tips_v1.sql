create table private.stripe_tip_attempts (
  id uuid primary key default gen_random_uuid(),
  settlement_id uuid not null references private.stripe_job_settlements(id) on delete restrict,
  job_id uuid not null references public.jobs(id) on delete restrict,
  payer_id uuid not null references auth.users(id) on delete restrict,
  worker_id uuid not null references auth.users(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  policy_version_id uuid not null references private.stripe_financial_policy_versions(id) on delete restrict,
  amount_cents integer not null check (amount_cents > 0),
  teen_amount_cents integer not null check (teen_amount_cents = amount_cents),
  mort_fee_cents integer not null check (mort_fee_cents = 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  request_id uuid not null,
  idempotency_key text not null,
  provider_customer_id text check (provider_customer_id is null or provider_customer_id ~ '^cus_[A-Za-z0-9]+$'),
  provider_payment_intent_id text check (provider_payment_intent_id is null or provider_payment_intent_id ~ '^pi_[A-Za-z0-9]+$'),
  provider_transfer_id text check (provider_transfer_id is null or provider_transfer_id ~ '^tr_[A-Za-z0-9]+$'),
  normalized_state text not null default 'READY' check (normalized_state in (
    'READY', 'PROCESSING', 'REQUIRES_ACTION', 'PENDING', 'SUCCEEDED',
    'DECLINED', 'FAILED', 'CANCELLED', 'UNKNOWN', 'PROVIDER_UNAVAILABLE',
    'DUPLICATE_BLOCKED'
  )),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  unique (environment, request_id),
  unique (environment, idempotency_key)
);

create or replace function public.stripe_server_prepare_tip_v1(
  p_settlement_id uuid,
  p_amount_cents integer,
  p_request_id uuid,
  p_payer_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  settlement private.stripe_job_settlements%rowtype;
  payment private.stripe_job_payment_intents%rowtype;
  quote private.stripe_job_funding_quotes%rowtype;
  policy private.stripe_financial_policy_versions%rowtype;
  tip private.stripe_tip_attempts%rowtype;
begin
  perform private.require_stripe_service_role();
  if p_settlement_id is null or p_request_id is null or p_payer_id is null
     or p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'tip_inputs_required';
  end if;
  select * into settlement from private.stripe_job_settlements where id = p_settlement_id for share;
  if settlement.id is null then raise exception 'settlement_not_found'; end if;
  select * into payment from private.stripe_job_payment_intents where id = settlement.payment_intent_id for share;
  select * into quote from private.stripe_job_funding_quotes where id = settlement.funding_quote_id for share;
  if payment.adult_id <> p_payer_id then raise exception 'tip_payer_required' using errcode = '42501'; end if;
  if payment.normalized_state <> 'SUCCEEDED' then raise exception 'settled_job_required'; end if;

  select * into policy from private.resolve_financial_policy_v1(
    settlement.environment, 'tip', settlement.currency_code, 'global', statement_timestamp()
  );
  if policy.id is null then raise exception 'tip_policy_missing'; end if;
  if p_amount_cents < policy.tip_min_cents or p_amount_cents > policy.tip_max_cents then
    raise exception 'tip_amount_out_of_policy';
  end if;
  if policy.tip_teen_share_bps <> 10000 or policy.tip_mort_fee_bps <> 0
     or not policy.tip_excluded_from_fair_pay then
    raise exception 'tip_policy_not_approved';
  end if;

  select * into tip from private.stripe_tip_attempts
   where environment = settlement.environment and request_id = p_request_id for update;
  if tip.id is not null then
    if tip.payer_id <> p_payer_id or tip.amount_cents <> p_amount_cents then
      raise exception 'tip_request_conflict';
    end if;
    return jsonb_build_object('ok', true, 'tip_attempt_id', tip.id, 'idempotent', true,
      'normalized_state', tip.normalized_state, 'idempotency_key', tip.idempotency_key);
  end if;

  insert into private.stripe_tip_attempts (
    settlement_id, job_id, payer_id, worker_id, environment, policy_version_id,
    amount_cents, teen_amount_cents, mort_fee_cents, currency_code, request_id, idempotency_key
  )
  values (
    settlement.id, quote.job_id, payment.adult_id, payment.teen_id, settlement.environment,
    policy.id, p_amount_cents, p_amount_cents, 0, settlement.currency_code, p_request_id,
    settlement.environment || ':tip:' || p_request_id::text
  )
  returning * into tip;

  return jsonb_build_object(
    'ok', true, 'tip_attempt_id', tip.id, 'idempotent', false,
    'amount_cents', tip.amount_cents, 'teen_amount_cents', tip.teen_amount_cents,
    'mort_fee_cents', tip.mort_fee_cents, 'currency_code', tip.currency_code,
    'worker_id', tip.worker_id, 'idempotency_key', tip.idempotency_key
  );
end;
$$;

create or replace function public.stripe_server_record_tip_payment_v1(
  p_tip_attempt_id uuid,
  p_provider_customer_id text,
  p_provider_payment_intent_id text,
  p_provider_status text
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
  if p_provider_payment_intent_id is null or p_provider_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    raise exception 'tip_provider_payment_intent_required';
  end if;
  next_state := case p_provider_status
    when 'requires_action' then 'REQUIRES_ACTION'
    when 'processing' then 'PROCESSING'
    when 'succeeded' then 'PROCESSING'
    when 'canceled' then 'CANCELLED'
    when 'requires_payment_method' then 'READY'
    else 'UNKNOWN'
  end;
  update private.stripe_tip_attempts
     set provider_customer_id = p_provider_customer_id,
         provider_payment_intent_id = p_provider_payment_intent_id,
         normalized_state = next_state,
         updated_at = statement_timestamp()
   where id = p_tip_attempt_id
   returning * into tip;
  if tip.id is null then raise exception 'tip_attempt_not_found'; end if;
  return jsonb_build_object('ok', true, 'tip_attempt_id', tip.id,
    'provider_payment_intent_id', tip.provider_payment_intent_id,
    'normalized_state', tip.normalized_state);
end;
$$;

revoke all on function public.stripe_server_prepare_tip_v1(uuid, integer, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.stripe_server_record_tip_payment_v1(uuid, text, text, text)
  from public, anon, authenticated;
grant execute on function public.stripe_server_prepare_tip_v1(uuid, integer, uuid, uuid)
  to service_role;
grant execute on function public.stripe_server_record_tip_payment_v1(uuid, text, text, text)
  to service_role;