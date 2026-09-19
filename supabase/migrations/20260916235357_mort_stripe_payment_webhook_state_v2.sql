-- Reduce provider-confirmed payment events into the normalized state contract
-- while preserving the legacy status projection used by existing job gates.

create or replace function public.stripe_server_apply_payment_event_v2(
  p_environment text,
  p_provider_event_id text,
  p_event_type text,
  p_provider_payment_intent_id text,
  p_provider_charge_id text,
  p_amount_cents integer,
  p_currency_code text,
  p_safe_failure_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  payment private.stripe_job_payment_intents%rowtype;
  observed_state text;
  next_state text;
  next_status text;
begin
  perform private.require_stripe_service_role();
  observed_state := case p_event_type
    when 'payment_intent.succeeded' then 'SUCCEEDED'
    when 'payment_intent.processing' then 'PROCESSING'
    when 'payment_intent.payment_failed' then 'DECLINED'
    when 'payment_intent.canceled' then 'CANCELLED'
    else null
  end;
  next_status := case p_event_type
    when 'payment_intent.succeeded' then 'funded'
    when 'payment_intent.processing' then 'processing'
    when 'payment_intent.payment_failed' then 'funding_failed'
    when 'payment_intent.canceled' then 'canceled'
    else null
  end;
  if observed_state is null or next_status is null then
    raise exception 'unsupported_payment_event';
  end if;

  select *
    into payment
    from private.stripe_job_payment_intents
   where environment = p_environment
     and provider_payment_intent_id = p_provider_payment_intent_id
   for update;
  if payment.id is null then
    raise exception 'stripe_payment_intent_not_found';
  end if;
  if p_amount_cents is not null and p_amount_cents <> payment.total_amount_cents then
    raise exception 'stripe_payment_amount_mismatch';
  end if;
  if p_currency_code is not null and upper(p_currency_code) <> payment.currency_code then
    raise exception 'stripe_payment_currency_mismatch';
  end if;

  next_state := case
    when payment.normalized_state = 'READY' and observed_state = 'SUCCEEDED'
      then 'SUCCEEDED'
    else private.reduce_stripe_payment_state_v1(payment.normalized_state, observed_state)
  end;

  update private.stripe_job_payment_intents
     set status = next_status,
         normalized_state = next_state,
         provider_charge_id = coalesce(p_provider_charge_id, provider_charge_id),
         captured_amount_cents = case when next_state = 'SUCCEEDED' then p_amount_cents else captured_amount_cents end,
         captured_currency_code = case when next_state = 'SUCCEEDED' then upper(p_currency_code) else captured_currency_code end,
         provider_confirmed_at = case when next_state = 'SUCCEEDED' then coalesce(provider_confirmed_at, statement_timestamp()) else provider_confirmed_at end,
         last_failure_code = case when next_state = 'DECLINED' then left(p_safe_failure_code, 120) else null end,
         funded_at = case when next_state = 'SUCCEEDED' then coalesce(funded_at, statement_timestamp()) else funded_at end,
         canceled_at = case when next_state = 'CANCELLED' then coalesce(canceled_at, statement_timestamp()) else canceled_at end,
         last_reconciled_at = statement_timestamp(),
         last_synchronized_at = statement_timestamp(),
         row_version = row_version + 1,
         updated_at = statement_timestamp()
   where id = payment.id;

  update private.stripe_webhook_events
     set processing_status = 'processed',
         processed_at = statement_timestamp(),
         processing_lease_token = null,
         processing_lease_until = null
   where environment = p_environment
     and provider_event_id = p_provider_event_id;

  return jsonb_build_object(
    'ok', true,
    'payment_record_id', payment.id,
    'normalized_state', next_state,
    'status', next_status
  );
end;
$$;

revoke all on function public.stripe_server_apply_payment_event_v2(
  text, text, text, text, text, integer, text, text
) from public, anon, authenticated;
grant execute on function public.stripe_server_apply_payment_event_v2(
  text, text, text, text, text, integer, text, text
) to service_role;