create or replace function public.stripe_server_prepare_settlement_transfer_v1(
  p_payment_intent_id uuid,
  p_environment text,
  p_eligibility_path text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  payment private.stripe_job_payment_intents%rowtype;
  settlement private.stripe_job_settlements%rowtype;
  account private.stripe_connected_accounts%rowtype;
  transfer private.stripe_job_transfers%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into payment from private.stripe_job_payment_intents
   where id = p_payment_intent_id and environment = p_environment for share;
  if payment.id is null then raise exception 'payment_intent_not_found'; end if;
  if payment.normalized_state <> 'SUCCEEDED' then raise exception 'provider_confirmed_funding_required'; end if;
  select * into settlement from private.stripe_job_settlements
   where payment_intent_id = payment.id;
  if settlement.id is null then raise exception 'finalized_settlement_required'; end if;
  if settlement.compensated_base_cents <= 0 then raise exception 'positive_compensation_required'; end if;
  select * into account from private.stripe_connected_accounts
   where user_id = payment.teen_id and environment = p_environment;
  if account.id is null or account.onboarding_status <> 'complete'
     or not account.details_submitted or not account.payouts_enabled
     or account.transfers_capability_status <> 'active'
     or account.requirements_status <> 'satisfied'
     or account.guardian_requirement_status <> 'provider_managed_satisfied'
  then raise exception 'connected_account_not_ready'; end if;

  select * into transfer from private.stripe_job_transfers
   where payment_intent_id = payment.id for update;
  if transfer.id is not null then
    return jsonb_build_object(
      'ok', true, 'existing', true, 'transfer_record_id', transfer.id,
      'provider_transfer_id', transfer.provider_transfer_id, 'status', transfer.status
    );
  end if;

  insert into private.stripe_job_transfers (
    payment_intent_id, connected_account_id, environment, amount_cents,
    currency_code, provider_source_charge_id, idempotency_key,
    eligibility_path, status
  )
  values (
    payment.id, account.id, p_environment, settlement.compensated_base_cents,
    payment.currency_code, payment.provider_charge_id,
    p_environment || ':settlement-transfer:' || settlement.id::text,
    p_eligibility_path, 'pending'
  )
  returning * into transfer;

  return jsonb_build_object(
    'ok', true, 'existing', false, 'transfer_record_id', transfer.id,
    'amount_cents', transfer.amount_cents, 'currency_code', transfer.currency_code,
    'provider_connected_account_id', account.provider_account_id,
    'provider_source_charge_id', transfer.provider_source_charge_id,
    'transfer_group', payment.transfer_group, 'idempotency_key', transfer.idempotency_key
  );
end;
$$;

create or replace function public.stripe_server_record_settlement_transfer_v1(
  p_transfer_record_id uuid,
  p_provider_transfer_id text,
  p_provider_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  transfer private.stripe_job_transfers%rowtype;
  next_status text;
begin
  perform private.require_stripe_service_role();
  if p_provider_transfer_id is null or p_provider_transfer_id !~ '^tr_[A-Za-z0-9]+$' then
    raise exception 'provider_transfer_required';
  end if;
  next_status := case p_provider_status when 'paid' then 'paid' when 'failed' then 'failed' else 'created' end;
  update private.stripe_job_transfers
     set provider_transfer_id = p_provider_transfer_id,
         status = next_status,
         transferred_at = case when next_status = 'paid' then statement_timestamp() else transferred_at end,
         updated_at = statement_timestamp()
   where id = p_transfer_record_id
   returning * into transfer;
  if transfer.id is null then raise exception 'transfer_record_not_found'; end if;
  insert into private.stripe_financial_ledger_events (
    settlement_id, payment_intent_id, contract_id, environment,
    event_type, component, amount_cents, direction, currency_code, immutable_metadata
  )
  select settlement.id, transfer.payment_intent_id, settlement.contract_id, transfer.environment,
    'transfer', 'base', transfer.amount_cents, 'debit', transfer.currency_code,
    jsonb_build_object('provider_transfer_id', p_provider_transfer_id)
  from private.stripe_job_settlements settlement
  where settlement.payment_intent_id = transfer.payment_intent_id
    and next_status = 'paid'
    and not exists (
      select 1 from private.stripe_financial_ledger_events event
       where event.event_type = 'transfer'
         and event.payment_intent_id = transfer.payment_intent_id
         and event.immutable_metadata->>'provider_transfer_id' = p_provider_transfer_id
    );
  return jsonb_build_object('ok', true, 'transfer_record_id', transfer.id, 'status', transfer.status);
end;
$$;

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
  settlement private.stripe_job_settlements%rowtype;
  payment private.stripe_job_payment_intents%rowtype;
  refund private.stripe_job_refunds%rowtype;
  amount integer;
begin
  perform private.require_stripe_service_role();
  select * into settlement from private.stripe_job_settlements where id = p_settlement_id for share;
  if settlement.id is null or settlement.environment <> p_environment then raise exception 'settlement_not_found'; end if;
  select * into payment from private.stripe_job_payment_intents where id = settlement.payment_intent_id for share;
  amount := settlement.base_refund_cents + settlement.service_fee_refund_cents;
  if amount <= 0 then raise exception 'no_refund_due'; end if;
  select * into refund from private.stripe_job_refunds
   where payment_intent_id = payment.id and reason_code = p_reason_code
   order by created_at desc limit 1 for update;
  if refund.id is not null then
    return jsonb_build_object('ok', true, 'existing', true, 'refund_record_id', refund.id,
      'provider_refund_id', refund.provider_refund_id, 'status', refund.status);
  end if;
  insert into private.stripe_job_refunds (
    payment_intent_id, requested_by, environment, amount_cents, idempotency_key, reason_code, status
  )
  values (
    payment.id, p_requested_by, p_environment, amount,
    p_environment || ':settlement-refund:' || settlement.id::text || ':' || p_reason_code,
    p_reason_code, 'pending'
  )
  returning * into refund;
  return jsonb_build_object('ok', true, 'existing', false, 'refund_record_id', refund.id,
    'amount_cents', refund.amount_cents, 'currency_code', payment.currency_code,
    'provider_payment_intent_id', payment.provider_payment_intent_id,
    'idempotency_key', refund.idempotency_key);
end;
$$;

create or replace function public.stripe_server_record_settlement_refund_v1(
  p_refund_record_id uuid,
  p_provider_refund_id text,
  p_provider_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  refund private.stripe_job_refunds%rowtype;
  next_status text;
begin
  perform private.require_stripe_service_role();
  if p_provider_refund_id is null or p_provider_refund_id !~ '^re_[A-Za-z0-9]+$' then
    raise exception 'provider_refund_required';
  end if;
  next_status := case p_provider_status when 'succeeded' then 'succeeded' when 'failed' then 'failed' else 'pending' end;
  update private.stripe_job_refunds
     set provider_refund_id = p_provider_refund_id, status = next_status, updated_at = statement_timestamp()
   where id = p_refund_record_id
   returning * into refund;
  if refund.id is null then raise exception 'refund_record_not_found'; end if;
  return jsonb_build_object('ok', true, 'refund_record_id', refund.id, 'status', refund.status);
end;
$$;

revoke all on function public.stripe_server_prepare_settlement_transfer_v1(uuid, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_record_settlement_transfer_v1(uuid, text, text) from public, anon, authenticated;
revoke all on function public.stripe_server_prepare_settlement_refund_v1(uuid, text, text, uuid) from public, anon, authenticated;
revoke all on function public.stripe_server_record_settlement_refund_v1(uuid, text, text) from public, anon, authenticated;
grant execute on function public.stripe_server_prepare_settlement_transfer_v1(uuid, text, text) to service_role;
grant execute on function public.stripe_server_record_settlement_transfer_v1(uuid, text, text) to service_role;
grant execute on function public.stripe_server_prepare_settlement_refund_v1(uuid, text, text, uuid) to service_role;
grant execute on function public.stripe_server_record_settlement_refund_v1(uuid, text, text) to service_role;