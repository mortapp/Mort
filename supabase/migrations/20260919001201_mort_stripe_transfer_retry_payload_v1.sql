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

  select * into payment
    from private.stripe_job_payment_intents
   where id = p_payment_intent_id
     and environment = p_environment
   for share;
  if payment.id is null then raise exception 'payment_intent_not_found'; end if;
  if payment.normalized_state <> 'SUCCEEDED' then
    raise exception 'provider_confirmed_funding_required';
  end if;

  select * into settlement
    from private.stripe_job_settlements
   where payment_intent_id = payment.id;
  if settlement.id is null then raise exception 'finalized_settlement_required'; end if;
  if settlement.compensated_base_cents <= 0 then raise exception 'positive_compensation_required'; end if;

  select * into account
    from private.stripe_connected_accounts
   where user_id = payment.teen_id
     and environment = p_environment;
  if account.id is null
     or account.onboarding_status <> 'complete'
     or not account.details_submitted
     or not account.payouts_enabled
     or account.transfers_capability_status <> 'active'
     or account.requirements_status <> 'satisfied'
     or account.guardian_requirement_status <> 'provider_managed_satisfied'
  then
    raise exception 'connected_account_not_ready';
  end if;

  select * into transfer
    from private.stripe_job_transfers
   where payment_intent_id = payment.id
   for update;

  if transfer.id is not null then
    return jsonb_build_object(
      'ok', true,
      'existing', true,
      'transfer_record_id', transfer.id,
      'provider_transfer_id', transfer.provider_transfer_id,
      'status', transfer.status,
      'amount_cents', transfer.amount_cents,
      'currency_code', transfer.currency_code,
      'provider_connected_account_id', account.provider_account_id,
      'provider_source_charge_id', transfer.provider_source_charge_id,
      'transfer_group', payment.transfer_group,
      'idempotency_key', transfer.idempotency_key
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
    'ok', true,
    'existing', false,
    'transfer_record_id', transfer.id,
    'amount_cents', transfer.amount_cents,
    'currency_code', transfer.currency_code,
    'provider_connected_account_id', account.provider_account_id,
    'provider_source_charge_id', transfer.provider_source_charge_id,
    'transfer_group', payment.transfer_group,
    'idempotency_key', transfer.idempotency_key
  );
end;
$$;
