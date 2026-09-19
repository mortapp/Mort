create or replace function public.stripe_server_prepare_quote_payment_v1(
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
  customer private.stripe_customers%rowtype;
  control private.stripe_runtime_controls%rowtype;
  existing private.stripe_job_payment_intents%rowtype;
begin
  perform private.require_stripe_service_role();
  if p_quote_id is null or p_request_id is null then
    raise exception 'funding_quote_and_request_required';
  end if;

  select * into quote
  from private.stripe_job_funding_quotes
  where id = p_quote_id
  for share;
  if quote.id is null or quote.state <> 'CONSUMED' then
    raise exception 'funding_quote_not_consumed';
  end if;

  select * into control
  from private.stripe_runtime_controls
  where singleton
  for share;
  if quote.environment <> private.stripe_environment_for_mode(control.mode) then
    raise exception 'stripe_environment_mismatch';
  end if;
  if not control.stripe_payments_enabled or not control.stripe_job_funding_enabled then
    raise exception 'stripe_job_funding_disabled';
  end if;
  if quote.environment = 'live'
     and (not control.stripe_live_mode_enabled or not control.live_owner_approved) then
    raise exception 'stripe_live_disabled';
  end if;

  select * into customer
  from private.stripe_customers
  where user_id = quote.payer_id
    and environment = quote.environment;

  select * into existing
  from private.stripe_job_payment_intents
  where funding_quote_id = quote.id
    and environment = quote.environment;

  return jsonb_build_object(
    'ok', true,
    'existing', existing.id is not null,
    'record_id', existing.id,
    'provider_payment_intent_id', existing.provider_payment_intent_id,
    'provider_customer_id', coalesce(existing.provider_customer_id, customer.provider_customer_id),
    'contract_id', quote.contract_id,
    'contract_version_id', quote.contract_version_id,
    'obligation_id', quote.obligation_id,
    'adult_id', quote.payer_id,
    'teen_id', quote.worker_id,
    'environment', quote.environment,
    'earnings_amount_cents', quote.base_pay_cents,
    'service_fee_cents', quote.service_fee_cents,
    'total_amount_cents', quote.authoritative_total_cents,
    'currency_code', quote.currency_code,
    'transfer_group', 'MORT_JOB_' || replace(quote.job_id::text, '-', ''),
    'idempotency_key', quote.environment || ':quote:' || quote.id::text
  );
end;
$$;

revoke all on function public.stripe_server_prepare_quote_payment_v1(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.stripe_server_prepare_quote_payment_v1(uuid, uuid)
  to service_role;
