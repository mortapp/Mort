-- Settlement refunds require an assigned financial operator, refundable
-- provider-confirmed funds, a global cap reservation, and no unresolved payout
-- or dispute. This backend intentionally has no transfer-reversal operation.
create or replace function public.stripe_server_prepare_settlement_refund_v1(
  p_settlement_id uuid,
  p_environment text,
  p_reason_code text,
  p_requested_by uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  control private.stripe_runtime_controls%rowtype;
  settlement private.stripe_job_settlements%rowtype;
  payment private.stripe_job_payment_intents%rowtype;
  refund private.stripe_job_refunds%rowtype;
  amount integer;
  captured integer;
  reserved integer;
begin
  perform private.require_stripe_service_role();
  if p_requested_by is null or not private.has_stripe_financial_role(
    p_requested_by, array['payment_operations', 'financial_admin']
  ) then raise exception 'payment_operations_role_required' using errcode = '42501'; end if;
  if p_reason_code is null or p_reason_code !~ '^[a-z0-9_:-]{3,120}$' then
    raise exception 'refund_reason_required';
  end if;
  select * into control from private.stripe_runtime_controls where singleton for share;
  if p_environment <> private.stripe_environment_for_mode(control.mode) then
    raise exception 'stripe_environment_mismatch';
  end if;
  if not control.stripe_refunds_enabled then raise exception 'stripe_refunds_disabled'; end if;
  if p_environment = 'live' and (not control.stripe_live_mode_enabled or not control.live_owner_approved) then
    raise exception 'stripe_live_disabled';
  end if;
  select * into settlement from private.stripe_job_settlements
   where id = p_settlement_id for update;
  if settlement.id is null or settlement.environment <> p_environment then
    raise exception 'settlement_not_found';
  end if;
  select * into payment from private.stripe_job_payment_intents
   where id = settlement.payment_intent_id for update;
  if payment.id is null then raise exception 'refundable_payment_required'; end if;
  amount := settlement.base_refund_cents + settlement.service_fee_refund_cents;
  if amount <= 0 then raise exception 'no_refund_due'; end if;
  captured := coalesce(payment.captured_amount_cents, payment.total_amount_cents);
  select coalesce(sum(amount_cents) filter (where status in ('pending', 'succeeded')), 0)::integer
    into reserved from private.stripe_job_refunds where payment_intent_id = payment.id;
  select * into refund from private.stripe_job_refunds
   where idempotency_key = p_environment || ':settlement-refund:' || settlement.id::text || ':' || p_reason_code
   order by created_at desc limit 1 for update;
  if refund.id is not null then
    return jsonb_build_object(
      'ok', true, 'existing', true, 'refund_record_id', refund.id,
      'provider_refund_id', refund.provider_refund_id, 'status', refund.status,
      'amount_cents', refund.amount_cents, 'currency_code', payment.currency_code,
      'provider_payment_intent_id', payment.provider_payment_intent_id,
      'idempotency_key', refund.idempotency_key
    );
  end if;
  if payment.normalized_state <> 'SUCCEEDED'
     or payment.status not in ('funded', 'partially_refunded') then
    raise exception 'refundable_payment_required';
  end if;
  if amount > captured - reserved then raise exception 'refund_amount_exceeds_remaining_balance'; end if;
  if exists (select 1 from private.stripe_job_transfers t
    where t.payment_intent_id = payment.id and t.status in ('created', 'paid', 'partially_reversed')) then
    raise exception 'transfer_reversal_required';
  end if;
  if exists (select 1 from private.stripe_job_disputes d
    where d.payment_intent_id = payment.id and d.status not in ('won', 'closed')) then
    raise exception 'active_payment_dispute';
  end if;
  insert into private.stripe_job_refunds (
    payment_intent_id, requested_by, environment, amount_cents,
    idempotency_key, reason_code, status
  ) values (
    payment.id, p_requested_by, p_environment, amount,
    p_environment || ':settlement-refund:' || settlement.id::text || ':' || p_reason_code,
    p_reason_code, 'pending'
  ) returning * into refund;
  return jsonb_build_object('ok', true, 'existing', false,
    'refund_record_id', refund.id, 'amount_cents', refund.amount_cents,
    'currency_code', payment.currency_code,
    'provider_payment_intent_id', payment.provider_payment_intent_id,
    'idempotency_key', refund.idempotency_key);
end;
$$;
