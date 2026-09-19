create table private.stripe_job_settlements (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid not null references private.stripe_job_payment_intents(id) on delete restrict,
  funding_quote_id uuid not null references private.stripe_job_funding_quotes(id) on delete restrict,
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  policy_version_id uuid not null references private.stripe_financial_policy_versions(id) on delete restrict,
  funded_base_cents integer not null check (funded_base_cents >= 0),
  compensated_base_cents integer not null check (compensated_base_cents >= 0),
  base_refund_cents integer not null check (base_refund_cents >= 0),
  service_fee_cents integer not null check (service_fee_cents >= 0),
  service_fee_refund_cents integer not null check (service_fee_refund_cents >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  decision_reason_code text not null check (char_length(decision_reason_code) between 3 and 120),
  decision_source text not null check (decision_source in ('policy', 'operator', 'adjudication')),
  outcome_code text not null check (char_length(outcome_code) between 3 and 120),
  authoritative_facts jsonb not null default '{}'::jsonb check (jsonb_typeof(authoritative_facts) = 'object'),
  finalized_at timestamptz not null default statement_timestamp(),
  created_at timestamptz not null default statement_timestamp(),
  unique (payment_intent_id),
  check (compensated_base_cents + base_refund_cents = funded_base_cents),
  check (service_fee_refund_cents <= service_fee_cents)
);

create table private.stripe_financial_ledger_events (
  id uuid primary key default gen_random_uuid(),
  settlement_id uuid references private.stripe_job_settlements(id) on delete restrict,
  payment_intent_id uuid references private.stripe_job_payment_intents(id) on delete restrict,
  contract_id uuid references public.job_contracts(id) on delete restrict,
  environment text not null check (environment in ('test', 'live')),
  event_type text not null check (event_type in (
    'job_funding_principal', 'service_fee', 'worker_compensation',
    'adult_refund', 'tip_principal', 'transfer', 'provider_refund',
    'adjustment', 'reversal'
  )),
  component text not null check (component in ('base', 'service_fee', 'tip', 'adjustment')),
  amount_cents integer not null check (amount_cents >= 0),
  direction text not null check (direction in ('credit', 'debit')),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  immutable_metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(immutable_metadata) = 'object'),
  created_at timestamptz not null default statement_timestamp()
);

create index stripe_financial_ledger_events_contract_idx
  on private.stripe_financial_ledger_events(contract_id, created_at, id);

create or replace function public.stripe_server_finalize_job_settlement_v1(
  p_payment_intent_id uuid,
  p_outcome_code text,
  p_decision_reason_code text,
  p_decision_source text,
  p_authoritative_facts jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  payment private.stripe_job_payment_intents%rowtype;
  quote private.stripe_job_funding_quotes%rowtype;
  settlement private.stripe_job_settlements%rowtype;
  compensation record;
  partial_policy private.stripe_financial_policy_versions%rowtype;
  service_fee_refund_bps integer;
  service_fee_refund integer;
begin
  perform private.require_stripe_service_role();
  if p_payment_intent_id is null or p_outcome_code is null
     or p_decision_reason_code is null
     or p_decision_source not in ('policy', 'operator', 'adjudication') then
    raise exception 'settlement_inputs_required';
  end if;
  if jsonb_typeof(coalesce(p_authoritative_facts, '{}'::jsonb)) <> 'object' then
    raise exception 'settlement_facts_object_required';
  end if;

  select * into payment
    from private.stripe_job_payment_intents
   where id = p_payment_intent_id
   for update;
  if payment.id is null then raise exception 'payment_intent_not_found'; end if;
  if payment.normalized_state <> 'SUCCEEDED' then
    raise exception 'provider_confirmed_funding_required';
  end if;

  select * into settlement
    from private.stripe_job_settlements
   where payment_intent_id = payment.id;
  if settlement.id is not null then
    return jsonb_build_object('ok', true, 'settlement_id', settlement.id, 'idempotent', true);
  end if;

  select * into quote
    from private.stripe_job_funding_quotes
   where id = payment.funding_quote_id;
  if quote.id is null then raise exception 'funding_quote_not_found'; end if;

  select * into compensation
    from private.evaluate_partial_compensation_v1(
      payment.environment,
      payment.currency_code,
      'global',
      p_outcome_code,
      payment.earnings_amount_cents,
      p_authoritative_facts,
      statement_timestamp()
    );
  if compensation.policy_version_id is null then
    raise exception 'partial_compensation_policy_missing';
  end if;
  select * into partial_policy
    from private.stripe_financial_policy_versions
   where id = compensation.policy_version_id;

  service_fee_refund_bps := case
    when partial_policy.configuration ? 'service_fee_refund_bps'
      then (partial_policy.configuration->>'service_fee_refund_bps')::integer
    else null
  end;
  if service_fee_refund_bps is null or service_fee_refund_bps < 0 or service_fee_refund_bps > 10000 then
    raise exception 'service_fee_refund_policy_missing';
  end if;
  service_fee_refund := ((payment.service_fee_cents::bigint * service_fee_refund_bps + 5000) / 10000)::integer;

  insert into private.stripe_job_settlements (
    payment_intent_id, funding_quote_id, contract_id, environment,
    policy_version_id, funded_base_cents, compensated_base_cents,
    base_refund_cents, service_fee_cents, service_fee_refund_cents,
    currency_code, decision_reason_code, decision_source, outcome_code,
    authoritative_facts
  )
  values (
    payment.id, quote.id, payment.contract_id, payment.environment,
    compensation.policy_version_id, payment.earnings_amount_cents,
    compensation.compensated_base_cents,
    payment.earnings_amount_cents - compensation.compensated_base_cents,
    payment.service_fee_cents, service_fee_refund, payment.currency_code,
    p_decision_reason_code, p_decision_source, p_outcome_code,
    p_authoritative_facts
  )
  returning * into settlement;

  insert into private.stripe_financial_ledger_events (
    settlement_id, payment_intent_id, contract_id, environment,
    event_type, component, amount_cents, direction, currency_code,
    immutable_metadata
  )
  values
    (settlement.id, payment.id, payment.contract_id, payment.environment,
     'job_funding_principal', 'base', payment.earnings_amount_cents, 'credit',
     payment.currency_code, jsonb_build_object('source', 'provider_confirmed_funding')),
    (settlement.id, payment.id, payment.contract_id, payment.environment,
     'service_fee', 'service_fee', payment.service_fee_cents, 'credit',
     payment.currency_code, jsonb_build_object('policy_version_id', compensation.policy_version_id)),
    (settlement.id, payment.id, payment.contract_id, payment.environment,
     'worker_compensation', 'base', compensation.compensated_base_cents, 'credit',
     payment.currency_code, jsonb_build_object('decision_reason_code', p_decision_reason_code)),
    (settlement.id, payment.id, payment.contract_id, payment.environment,
     'adult_refund', 'base', payment.earnings_amount_cents - compensation.compensated_base_cents, 'debit',
     payment.currency_code, jsonb_build_object('linked_settlement_id', settlement.id)),
    (settlement.id, payment.id, payment.contract_id, payment.environment,
     'provider_refund', 'service_fee', service_fee_refund, 'debit',
     payment.currency_code, jsonb_build_object('policy_version_id', compensation.policy_version_id));

  return jsonb_build_object(
    'ok', true,
    'settlement_id', settlement.id,
    'policy_version_id', compensation.policy_version_id,
    'funded_base_cents', settlement.funded_base_cents,
    'compensated_base_cents', settlement.compensated_base_cents,
    'base_refund_cents', settlement.base_refund_cents,
    'service_fee_refund_cents', settlement.service_fee_refund_cents,
    'currency_code', settlement.currency_code,
    'idempotent', false
  );
end;
$$;

revoke all on function public.stripe_server_finalize_job_settlement_v1(
  uuid, text, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.stripe_server_finalize_job_settlement_v1(
  uuid, text, text, text, jsonb
) to service_role;