-- Auth-scoped status and lease-fenced webhook reconciliation for assignment payments.
create or replace function public.get_my_assignment_payment_status(p_provider_payment_intent_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  payment private.stripe_payment_intents%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_provider_payment_intent_id is null or p_provider_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    return jsonb_build_object('ok', false, 'code', 'invalid_payment_intent_id');
  end if;
  select * into payment from private.stripe_payment_intents
  where provider_payment_intent_id = p_provider_payment_intent_id
    and auth.uid() in (payer_id, payee_id);
  if not found then
    return jsonb_build_object('ok', false, 'code', 'payment_not_found');
  end if;
  return jsonb_build_object(
    'ok', true,
    'state', case payment.status
      when 'succeeded' then 'SUCCEEDED'
      when 'processing' then 'PROCESSING'
      when 'requires_action' then 'REQUIRES_ACTION'
      when 'authorized' then 'AUTHORIZED'
      when 'failed' then 'FAILED'
      when 'cancelled' then 'CANCELLED'
      when 'refunded' then 'REFUNDED'
      when 'disputed' then 'DISPUTED'
      else 'PENDING'
    end,
    'amount_cents', payment.gross_amount_cents,
    'currency_code', payment.currency_code,
    'updated_at', payment.updated_at
  );
end;
$$;
revoke all on function public.get_my_assignment_payment_status(text) from public, anon;
grant execute on function public.get_my_assignment_payment_status(text) to authenticated;

create or replace function public.stripe_server_apply_assignment_payment_webhook(
  p_environment text,
  p_provider_event_id text,
  p_lease_token uuid,
  p_ledger_id uuid,
  p_provider_payment_intent_id text,
  p_provider_status text,
  p_amount_cents integer,
  p_currency_code text,
  p_event_created_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_row private.stripe_webhook_events%rowtype;
  payment private.stripe_payment_intents%rowtype;
  mapped_status text;
begin
  perform private.require_stripe_service_role();
  if p_environment not in ('test', 'live')
    or p_provider_event_id !~ '^evt_[A-Za-z0-9]+$'
    or p_provider_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    raise exception 'stripe_webhook_payment_envelope_invalid';
  end if;
  mapped_status := case p_provider_status
    when 'requires_payment_method' then 'requires_payment_method'
    when 'requires_action' then 'requires_action'
    when 'requires_confirmation' then 'requires_payment_method'
    when 'requires_capture' then 'authorized'
    when 'processing' then 'processing'
    when 'succeeded' then 'succeeded'
    when 'canceled' then 'cancelled'
    else 'unknown'
  end;
  select * into strict event_row from private.stripe_webhook_events
  where environment = p_environment and provider_event_id = p_provider_event_id
    and processing_status = 'processing' and lease_token = p_lease_token
  for update;
  select * into strict payment from private.stripe_payment_intents
  where id = p_ledger_id and environment = p_environment
  for update;
  if payment.provider_payment_intent_id <> p_provider_payment_intent_id
    or payment.gross_amount_cents <> p_amount_cents
    or lower(payment.currency_code) <> lower(p_currency_code) then
    raise exception 'stripe_payment_snapshot_mismatch';
  end if;
  if p_event_created_at >= coalesce(payment.last_provider_event_at, '-infinity'::timestamptz) then
    update private.stripe_payment_intents
    set status = mapped_status,
        last_provider_event_at = p_event_created_at,
        updated_at = now()
    where id = p_ledger_id
    returning * into payment;
  end if;
  return jsonb_build_object(
    'ok', true,
    'ledger_id', payment.id,
    'status', payment.status,
    'stale_event', p_event_created_at < coalesce(payment.last_provider_event_at, '-infinity'::timestamptz)
  );
end;
$$;
revoke all on function public.stripe_server_apply_assignment_payment_webhook(text,text,uuid,uuid,text,text,integer,text,timestamptz) from public, anon, authenticated;
grant execute on function public.stripe_server_apply_assignment_payment_webhook(text,text,uuid,uuid,text,text,integer,text,timestamptz) to service_role;

comment on function public.get_my_assignment_payment_status(text) is
  'Returns a minimal Stripe assignment payment status only to its adult payer or teen payee.';
comment on function public.stripe_server_apply_assignment_payment_webhook(text,text,uuid,uuid,text,text,integer,text,timestamptz) is
  'Applies signature-verified Stripe PaymentIntent state only through an active event lease and exact amount/currency snapshot match.';
