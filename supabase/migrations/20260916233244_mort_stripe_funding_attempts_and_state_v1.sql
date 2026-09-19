-- Additive funding-attempt state contract. Provider success remains separate
-- from local intent creation until an authoritative webhook/reconciliation path
-- records it.

alter table private.stripe_job_payment_intents
  add column if not exists funding_quote_id uuid
    references private.stripe_job_funding_quotes(id) on delete restrict,
  add column if not exists quote_snapshot_sha256 text
    check (quote_snapshot_sha256 is null or quote_snapshot_sha256 ~ '^[a-f0-9]{64}$'),
  add column if not exists client_request_id uuid,
  add column if not exists normalized_state text
    check (normalized_state in (
      'READY', 'PROCESSING', 'REQUIRES_ACTION', 'PENDING', 'SUCCEEDED',
      'DECLINED', 'FAILED', 'CANCELLED', 'UNKNOWN', 'PROVIDER_UNAVAILABLE',
      'DUPLICATE_BLOCKED'
    )),
  add column if not exists captured_amount_cents integer
    check (captured_amount_cents is null or captured_amount_cents >= 0),
  add column if not exists captured_currency_code text
    check (captured_currency_code is null or captured_currency_code ~ '^[A-Z]{3}$'),
  add column if not exists provider_confirmed_at timestamptz,
  add column if not exists last_reconciled_at timestamptz,
  add column if not exists row_version bigint not null default 1 check (row_version > 0);

create unique index if not exists stripe_job_payment_intents_quote_idx
on private.stripe_job_payment_intents (environment, funding_quote_id)
where funding_quote_id is not null;

alter table private.stripe_job_payment_attempts
  add column if not exists operation_kind text not null default 'base_funding'
    check (operation_kind in ('base_funding', 'tip')),
  add column if not exists request_payload_sha256 text
    check (request_payload_sha256 is null or request_payload_sha256 ~ '^[a-f0-9]{64}$'),
  add column if not exists normalized_state text
    check (normalized_state in (
      'READY', 'PROCESSING', 'REQUIRES_ACTION', 'PENDING', 'SUCCEEDED',
      'DECLINED', 'FAILED', 'CANCELLED', 'UNKNOWN', 'PROVIDER_UNAVAILABLE',
      'DUPLICATE_BLOCKED'
    )),
  add column if not exists provider_created_at timestamptz,
  add column if not exists last_reconciled_at timestamptz,
  add column if not exists failure_class text,
  add column if not exists row_version bigint not null default 1 check (row_version > 0);

create index if not exists stripe_job_payment_attempts_state_idx
on private.stripe_job_payment_attempts (payment_intent_id, operation_kind, created_at desc);

create unique index if not exists stripe_job_payment_attempts_one_active_idx
on private.stripe_job_payment_attempts (payment_intent_id, operation_kind)
where normalized_state in (
  'READY', 'PROCESSING', 'REQUIRES_ACTION', 'PENDING', 'UNKNOWN',
  'PROVIDER_UNAVAILABLE'
);

create or replace function private.reduce_stripe_payment_state_v1(
  p_current text,
  p_observed text
)
returns text
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_current is null then
    if p_observed is null or p_observed not in (
      'READY', 'PROCESSING', 'REQUIRES_ACTION', 'PENDING', 'SUCCEEDED',
      'DECLINED', 'FAILED', 'CANCELLED', 'UNKNOWN', 'PROVIDER_UNAVAILABLE',
      'DUPLICATE_BLOCKED'
    ) then
      raise exception 'invalid_payment_state';
    end if;
    return p_observed;
  end if;

  if p_observed is null or p_observed not in (
    'READY', 'PROCESSING', 'REQUIRES_ACTION', 'PENDING', 'SUCCEEDED',
    'DECLINED', 'FAILED', 'CANCELLED', 'UNKNOWN', 'PROVIDER_UNAVAILABLE',
    'DUPLICATE_BLOCKED'
  ) then
    raise exception 'invalid_payment_state';
  end if;

  if p_current in ('SUCCEEDED', 'DECLINED', 'FAILED', 'CANCELLED', 'DUPLICATE_BLOCKED') then
    if p_observed = p_current then
      return p_current;
    end if;
    raise exception 'payment_state_regression';
  end if;

  if p_current = 'READY' and p_observed in ('PROCESSING', 'CANCELLED', 'PROVIDER_UNAVAILABLE') then
    return p_observed;
  end if;
  if p_current = 'PROCESSING' and p_observed in (
    'REQUIRES_ACTION', 'PENDING', 'SUCCEEDED', 'DECLINED', 'FAILED',
    'CANCELLED', 'UNKNOWN', 'PROVIDER_UNAVAILABLE'
  ) then
    return p_observed;
  end if;
  if p_current = 'REQUIRES_ACTION' and p_observed in (
    'PROCESSING', 'PENDING', 'SUCCEEDED', 'DECLINED', 'FAILED',
    'CANCELLED', 'UNKNOWN'
  ) then
    return p_observed;
  end if;
  if p_current = 'PENDING' and p_observed in (
    'SUCCEEDED', 'DECLINED', 'FAILED', 'CANCELLED', 'UNKNOWN'
  ) then
    return p_observed;
  end if;
  if p_current = 'UNKNOWN' and p_observed in (
    'PROCESSING', 'REQUIRES_ACTION', 'PENDING', 'SUCCEEDED', 'DECLINED',
    'FAILED', 'CANCELLED', 'PROVIDER_UNAVAILABLE'
  ) then
    return p_observed;
  end if;
  if p_current = 'PROVIDER_UNAVAILABLE' and p_observed in (
    'READY', 'PROCESSING', 'UNKNOWN'
  ) then
    return p_observed;
  end if;
  if p_current = p_observed then
    return p_current;
  end if;

  raise exception 'payment_state_transition_not_allowed';
end;
$$;

create or replace function public.stripe_server_record_payment_intent_v2(
  p_quote_id uuid,
  p_request_id uuid,
  p_provider_customer_id text,
  p_provider_payment_intent_id text,
  p_provider_status text,
  p_provider_created_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  quote private.stripe_job_funding_quotes%rowtype;
  payment private.stripe_job_payment_intents%rowtype;
  next_state text;
begin
  perform private.require_stripe_service_role();
  if p_quote_id is null or p_request_id is null then
    raise exception 'funding_quote_and_request_required';
  end if;
  if p_provider_payment_intent_id is null
     or p_provider_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    raise exception 'provider_payment_intent_required';
  end if;

  select *
    into quote
    from private.stripe_job_funding_quotes
   where id = p_quote_id
   for update;
  if quote.id is null then
    raise exception 'funding_quote_not_found';
  end if;
  if quote.state <> 'CONSUMED' then
    raise exception 'funding_quote_not_consumed';
  end if;

  next_state := case p_provider_status
    when 'requires_payment_method' then 'READY'
    when 'requires_action' then 'REQUIRES_ACTION'
    when 'processing' then 'PROCESSING'
    when 'succeeded' then 'PROCESSING'
    when 'canceled' then 'CANCELLED'
    else 'UNKNOWN'
  end;

  insert into private.stripe_job_payment_intents (
    contract_id, contract_version_id, obligation_id, adult_id, teen_id,
    environment, operation_version, earnings_amount_cents, service_fee_cents,
    total_amount_cents, currency_code, provider_customer_id,
    provider_payment_intent_id, transfer_group, idempotency_key, status,
    funding_quote_id, quote_snapshot_sha256, client_request_id,
    normalized_state, provider_confirmed_at, last_reconciled_at
  ) values (
    quote.contract_id, quote.contract_version_id, quote.obligation_id,
    quote.payer_id, quote.worker_id, quote.environment, 1, quote.base_pay_cents,
    quote.service_fee_cents, quote.authoritative_total_cents, quote.currency_code,
    p_provider_customer_id, p_provider_payment_intent_id,
    'MORT_JOB_' || replace(quote.job_id::text, '-', ''),
    quote.environment || ':quote:' || quote.id::text,
    'processing', quote.id, quote.request_payload_sha256, p_request_id,
    next_state, null, statement_timestamp()
  )
  on conflict (environment, funding_quote_id) do update set
    provider_customer_id = coalesce(
      private.stripe_job_payment_intents.provider_customer_id,
      excluded.provider_customer_id
    ),
    provider_payment_intent_id = case
      when private.stripe_job_payment_intents.provider_payment_intent_id is null
        or private.stripe_job_payment_intents.provider_payment_intent_id = excluded.provider_payment_intent_id
      then excluded.provider_payment_intent_id
      else private.stripe_job_payment_intents.provider_payment_intent_id
    end,
    normalized_state = private.reduce_stripe_payment_state_v1(
      private.stripe_job_payment_intents.normalized_state,
      excluded.normalized_state
    ),
    last_reconciled_at = statement_timestamp(),
    row_version = private.stripe_job_payment_intents.row_version + 1
  returning * into payment;

  insert into private.stripe_job_payment_attempts (
    payment_intent_id, request_id, initiated_by, outcome,
    operation_kind, request_payload_sha256, normalized_state,
    provider_created_at, last_reconciled_at
  ) values (
    payment.id, p_request_id, quote.payer_id, 'provider_created',
    'base_funding', quote.request_payload_sha256, next_state,
    p_provider_created_at, statement_timestamp()
  )
  on conflict (payment_intent_id, request_id, outcome) do update set
    normalized_state = excluded.normalized_state,
    last_reconciled_at = statement_timestamp(),
    row_version = private.stripe_job_payment_attempts.row_version + 1;

  return jsonb_build_object(
    'ok', true,
    'payment_intent_id', payment.id,
    'normalized_state', payment.normalized_state,
    'provider_confirmed', false
  );
end;
$$;

revoke all on function public.stripe_server_record_payment_intent_v2(
  uuid, uuid, text, text, text, timestamptz
) from public, anon, authenticated;
grant execute on function public.stripe_server_record_payment_intent_v2(
  uuid, uuid, text, text, text, timestamptz
) to service_role;