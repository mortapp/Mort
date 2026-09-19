-- Persist the quote-bound attempt before any provider mutation. A provider
-- timeout can therefore be reconciled instead of looking like a missing attempt.

create or replace function public.stripe_server_prepare_payment_intent_v2(
  p_quote_id uuid,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  quote private.stripe_job_funding_quotes%rowtype;
  payment private.stripe_job_payment_intents%rowtype;
  attempt_id uuid;
begin
  perform private.require_stripe_service_role();

  if p_quote_id is null or p_request_id is null then
    raise exception 'funding_quote_and_request_required';
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

  insert into private.stripe_job_payment_intents (
    contract_id,
    contract_version_id,
    obligation_id,
    adult_id,
    teen_id,
    environment,
    operation_version,
    earnings_amount_cents,
    service_fee_cents,
    total_amount_cents,
    currency_code,
    transfer_group,
    idempotency_key,
    status,
    funding_quote_id,
    quote_snapshot_sha256,
    client_request_id,
    normalized_state
  )
  values (
    quote.contract_id,
    quote.contract_version_id,
    quote.obligation_id,
    quote.payer_id,
    quote.worker_id,
    quote.environment,
    1,
    quote.base_pay_cents,
    quote.service_fee_cents,
    quote.authoritative_total_cents,
    quote.currency_code,
    'MORT_JOB_' || replace(quote.job_id::text, '-', ''),
    quote.environment || ':quote:' || quote.id::text,
    'unfunded',
    quote.id,
    quote.request_payload_sha256,
    p_request_id,
    'READY'
  )
  on conflict (environment, funding_quote_id) do update set
    client_request_id = coalesce(
      private.stripe_job_payment_intents.client_request_id,
      excluded.client_request_id
    ),
    normalized_state = case
      when private.stripe_job_payment_intents.normalized_state in (
        'SUCCEEDED', 'DECLINED', 'FAILED', 'CANCELLED', 'DUPLICATE_BLOCKED'
      ) then private.stripe_job_payment_intents.normalized_state
      else 'READY'
    end,
    row_version = private.stripe_job_payment_intents.row_version + 1,
    updated_at = statement_timestamp()
  returning * into payment;

  insert into private.stripe_job_payment_attempts (
    payment_intent_id,
    request_id,
    initiated_by,
    outcome,
    normalized_state,
    request_payload_sha256
  )
  values (
    payment.id,
    p_request_id,
    quote.payer_id,
    'prepared',
    payment.normalized_state,
    quote.request_payload_sha256
  )
  on conflict (payment_intent_id, request_id, outcome) do update set
    normalized_state = excluded.normalized_state,
    row_version = private.stripe_job_payment_attempts.row_version + 1
  returning id into attempt_id;

  return jsonb_build_object(
    'payment_intent_id', payment.id,
    'attempt_id', attempt_id,
    'quote_id', quote.id,
    'normalized_state', payment.normalized_state,
    'idempotency_key', payment.idempotency_key,
    'authoritative_total_cents', payment.total_amount_cents,
    'currency_code', payment.currency_code
  );
end;
$$;

revoke all on function public.stripe_server_prepare_payment_intent_v2(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.stripe_server_prepare_payment_intent_v2(uuid, uuid)
  to service_role;