-- Forward-only recovery and least-privilege guards for the MORT test Stripe flow.
-- No provider operation is performed by this migration.

-- Financial documents stay private; authenticated reads are narrowly owner-filtered.
create or replace function public.get_my_financial_document_v1(p_receipt_id text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(document)
  from (
    select id, document_type, receipt_id, order_number, document_date,
      amount_cents, currency_code, status, masked_provider_reference,
      immutable_snapshot, linked_document_refs, created_at
    from private.financial_documents
    where owner_id = auth.uid() and receipt_id = p_receipt_id
  ) document
$$;
revoke all on function public.get_my_financial_document_v1(text) from public, anon;
grant execute on function public.get_my_financial_document_v1(text) to authenticated;

-- A card payment failure is an attempt-level outcome, not necessarily a
-- terminal PaymentIntent. Stripe permits another payment method on that same
-- intent. Permit a later provider-confirmed ready/action/processing/success
-- observation while keeping cancellation and succeeded states terminal.
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
    ) then raise exception 'invalid_payment_state'; end if;
    return p_observed;
  end if;
  if p_observed is null or p_observed not in (
    'READY', 'PROCESSING', 'REQUIRES_ACTION', 'PENDING', 'SUCCEEDED',
    'DECLINED', 'FAILED', 'CANCELLED', 'UNKNOWN', 'PROVIDER_UNAVAILABLE',
    'DUPLICATE_BLOCKED'
  ) then raise exception 'invalid_payment_state'; end if;

  if p_current = 'SUCCEEDED' then
    if p_observed = 'SUCCEEDED' then return p_current; end if;
    raise exception 'payment_state_regression';
  end if;
  if p_current = 'DECLINED' and p_observed in (
    'READY', 'REQUIRES_ACTION', 'PROCESSING', 'SUCCEEDED'
  ) then return p_observed; end if;
  if p_current in ('FAILED', 'CANCELLED', 'DUPLICATE_BLOCKED') then
    if p_observed = p_current then return p_current; end if;
    raise exception 'payment_state_regression';
  end if;
  if p_current = 'READY' and p_observed in (
    'PROCESSING', 'REQUIRES_ACTION', 'SUCCEEDED', 'DECLINED', 'FAILED',
    'CANCELLED', 'UNKNOWN', 'PROVIDER_UNAVAILABLE'
  ) then return p_observed; end if;
  if p_current = 'PROCESSING' and p_observed in (
    'READY', 'REQUIRES_ACTION', 'PENDING', 'SUCCEEDED', 'DECLINED',
    'FAILED', 'CANCELLED', 'UNKNOWN', 'PROVIDER_UNAVAILABLE'
  ) then return p_observed; end if;
  if p_current = 'REQUIRES_ACTION' and p_observed in (
    'READY', 'PROCESSING', 'PENDING', 'SUCCEEDED', 'DECLINED', 'FAILED',
    'CANCELLED', 'UNKNOWN'
  ) then return p_observed; end if;
  if p_current = 'PENDING' and p_observed in (
    'READY', 'PROCESSING', 'REQUIRES_ACTION', 'SUCCEEDED', 'DECLINED',
    'FAILED', 'CANCELLED', 'UNKNOWN'
  ) then return p_observed; end if;
  if p_current = 'UNKNOWN' and p_observed in (
    'READY', 'PROCESSING', 'REQUIRES_ACTION', 'PENDING', 'SUCCEEDED',
    'DECLINED', 'FAILED', 'CANCELLED', 'PROVIDER_UNAVAILABLE'
  ) then return p_observed; end if;
  if p_current = 'PROVIDER_UNAVAILABLE' and p_observed in (
    'READY', 'PROCESSING', 'UNKNOWN'
  ) then return p_observed; end if;
  if p_current = p_observed then return p_current; end if;
  raise exception 'payment_state_transition_not_allowed';
end;
$$;

-- A new quote cannot be consumed while an earlier PaymentIntent could still
-- charge. Only a Stripe-canceled prior intent permits a new operation version.
create or replace function public.stripe_server_consume_job_funding_quote_v1(
  p_payer_id uuid,
  p_quote_id uuid,
  p_attempt_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_quote private.stripe_job_funding_quotes%rowtype;
  v_control private.stripe_runtime_controls%rowtype;
  v_prior private.stripe_job_payment_intents%rowtype;
begin
  perform private.require_stripe_service_role();
  if p_payer_id is null or p_quote_id is null or p_attempt_request_id is null then
    raise exception 'funding_quote_consumption_identifiers_required';
  end if;
  select * into v_quote from private.stripe_job_funding_quotes
   where id = p_quote_id for update;
  if v_quote.id is null or v_quote.payer_id <> p_payer_id then
    raise exception 'funding_quote_not_found' using errcode = '42501';
  end if;
  select * into v_control from private.stripe_runtime_controls
   where singleton for share;
  if v_control.singleton is distinct from true
     or v_quote.environment <> private.stripe_environment_for_mode(v_control.mode)
     or not coalesce(v_control.stripe_payments_enabled, false)
     or not coalesce(v_control.stripe_job_funding_enabled, false) then
    raise exception 'stripe_job_funding_disabled';
  end if;
  if v_quote.environment = 'live'
     and (not v_control.stripe_live_mode_enabled or not v_control.live_owner_approved) then
    raise exception 'stripe_live_disabled';
  end if;
  if not coalesce(v_control.connected_accounts_approved, false)
     or not coalesce(v_control.payouts_approved, false)
     or v_quote.payment_eligibility is distinct from true then
    raise exception 'recipient_model_not_approved_or_ready';
  end if;

  if v_quote.state = 'CONSUMED' then
    if v_quote.consumed_request_id <> p_attempt_request_id then
      raise exception 'funding_quote_already_consumed';
    end if;
    return private.job_funding_quote_dto_v1(v_quote) || jsonb_build_object('idempotent', true);
  end if;
  if v_quote.state <> 'ACTIVE' then raise exception 'funding_quote_not_active'; end if;
  if not private.funding_quote_is_usable_v1(v_quote.state, v_quote.expires_at, v_now) then
    update private.stripe_job_funding_quotes
       set state = 'EXPIRED', expired_at = v_now
     where id = v_quote.id returning * into v_quote;
    return jsonb_build_object('ok', false, 'code', 'funding_quote_expired',
      'quote_id', v_quote.id, 'expires_at', v_quote.expires_at);
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    v_quote.environment || ':' || v_quote.contract_version_id::text, 0
  ));
  select * into v_prior from private.stripe_job_payment_intents
   where contract_version_id = v_quote.contract_version_id
     and environment = v_quote.environment
   order by operation_version desc limit 1 for update;
  if v_prior.id is not null and v_prior.normalized_state <> 'CANCELLED' then
    raise exception 'prior_payment_attempt_not_canceled';
  end if;

  update private.stripe_job_funding_quotes
     set state = 'CONSUMED', consumed_at = v_now,
         consumed_request_id = p_attempt_request_id
   where id = v_quote.id returning * into v_quote;
  return private.job_funding_quote_dto_v1(v_quote) || jsonb_build_object('idempotent', false);
end;
$$;
revoke all on function public.stripe_server_consume_job_funding_quote_v1(uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.stripe_server_consume_job_funding_quote_v1(uuid, uuid, uuid)
  to service_role;

-- Preserve one provider intent per quote and allocate a new contract operation
-- version only after the prior PaymentIntent is actually canceled.
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
  prior private.stripe_job_payment_intents%rowtype;
  next_state text;
  next_status text;
  operation_version integer;
begin
  perform private.require_stripe_service_role();
  if p_quote_id is null or p_request_id is null then
    raise exception 'funding_quote_and_request_required';
  end if;
  if p_provider_payment_intent_id is null
     or p_provider_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    raise exception 'provider_payment_intent_required';
  end if;
  select * into quote from private.stripe_job_funding_quotes
   where id = p_quote_id for update;
  if quote.id is null or quote.state <> 'CONSUMED' then
    raise exception 'funding_quote_not_consumed';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    quote.environment || ':' || quote.contract_version_id::text, 0
  ));

  select * into payment from private.stripe_job_payment_intents
   where environment = quote.environment and funding_quote_id = quote.id
   for update;
  if payment.id is not null then
    if payment.provider_payment_intent_id is not null
       and payment.provider_payment_intent_id <> p_provider_payment_intent_id then
      raise exception 'provider_payment_intent_conflict';
    end if;
    operation_version := payment.operation_version;
  else
    select * into prior from private.stripe_job_payment_intents
     where contract_version_id = quote.contract_version_id
       and environment = quote.environment
     order by operation_version desc limit 1 for update;
    if prior.id is not null and prior.normalized_state <> 'CANCELLED' then
      raise exception 'prior_payment_attempt_not_canceled';
    end if;
    operation_version := coalesce(prior.operation_version, 0) + 1;
  end if;

  next_state := case p_provider_status
    when 'requires_payment_method' then 'READY'
    when 'requires_action' then 'REQUIRES_ACTION'
    when 'processing' then 'PROCESSING'
    when 'succeeded' then 'PROCESSING'
    when 'canceled' then 'CANCELLED'
    else 'UNKNOWN'
  end;
  next_status := case p_provider_status
    when 'requires_payment_method' then 'requires_payment_method'
    when 'requires_action' then 'requires_action'
    when 'processing' then 'processing'
    when 'succeeded' then 'processing'
    when 'canceled' then 'canceled'
    else 'processing'
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
    quote.payer_id, quote.worker_id, quote.environment, operation_version,
    quote.base_pay_cents, quote.service_fee_cents,
    quote.authoritative_total_cents, quote.currency_code,
    p_provider_customer_id, p_provider_payment_intent_id,
    'MORT_JOB_' || replace(quote.job_id::text, '-', ''),
    quote.environment || ':quote:' || quote.id::text,
    next_status, quote.id, quote.request_payload_sha256, p_request_id,
    next_state, null, statement_timestamp()
  )
  on conflict (environment, funding_quote_id) do update set
    provider_customer_id = coalesce(
      private.stripe_job_payment_intents.provider_customer_id,
      excluded.provider_customer_id
    ),
    provider_payment_intent_id = coalesce(
      private.stripe_job_payment_intents.provider_payment_intent_id,
      excluded.provider_payment_intent_id
    ),
    status = excluded.status,
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

  return jsonb_build_object('ok', true, 'payment_intent_id', payment.id,
    'operation_version', payment.operation_version,
    'normalized_state', payment.normalized_state, 'provider_confirmed', false);
end;
$$;
revoke all on function public.stripe_server_record_payment_intent_v2(
  uuid, uuid, text, text, text, timestamptz
) from public, anon, authenticated;
grant execute on function public.stripe_server_record_payment_intent_v2(
  uuid, uuid, text, text, text, timestamptz
) to service_role;
