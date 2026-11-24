-- The legacy 3-argument service-role RPC has no actor identity; make it fail
-- closed. New code must call the 4-argument actor-bound overload.
create or replace function public.stripe_server_prepare_settlement_transfer_v1(
  p_payment_intent_id uuid, p_environment text, p_eligibility_path text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_stripe_service_role();
  raise exception 'authorized_operation_actor_required';
end;
$$;
revoke all on function public.stripe_server_prepare_settlement_transfer_v1(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.stripe_server_prepare_settlement_transfer_v1(uuid, text, text)
  to service_role;

create or replace function public.stripe_server_prepare_settlement_transfer_v1(
  p_payment_intent_id uuid,
  p_environment text,
  p_eligibility_path text,
  p_requested_by uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  control private.stripe_runtime_controls%rowtype;
  payment private.stripe_job_payment_intents%rowtype;
  settlement private.stripe_job_settlements%rowtype;
  account private.stripe_connected_accounts%rowtype;
  transfer private.stripe_job_transfers%rowtype;
begin
  perform private.require_stripe_service_role();
  if p_requested_by is null or not private.has_stripe_financial_role(
    p_requested_by, array['payment_operations', 'financial_admin']
  ) then raise exception 'payment_operations_role_required' using errcode = '42501'; end if;
  if p_eligibility_path not in (
    'mutual_completion_confirmed', 'completion_confirmed_after_review',
    'completion_without_code_approved', 'partial_completion_approved',
    'authorized_safety_exit_payment'
  ) then raise exception 'invalid_transfer_eligibility_path'; end if;
  select * into control from private.stripe_runtime_controls where singleton for share;
  if p_environment <> private.stripe_environment_for_mode(control.mode) then
    raise exception 'stripe_environment_mismatch';
  end if;
  if not control.stripe_transfers_enabled
     or not control.connected_accounts_approved
     or not control.payouts_approved then
    raise exception 'stripe_transfers_disabled';
  end if;
  if p_environment = 'live' and (not control.stripe_live_mode_enabled or not control.live_owner_approved) then
    raise exception 'stripe_live_disabled';
  end if;
  select * into payment from private.stripe_job_payment_intents
   where id = p_payment_intent_id and environment = p_environment for update;
  if payment.id is null or payment.normalized_state <> 'SUCCEEDED'
     or payment.status <> 'funded' then raise exception 'provider_confirmed_funding_required'; end if;
  if exists (select 1 from private.stripe_job_refunds r
    where r.payment_intent_id = payment.id and r.status in ('pending', 'succeeded')) then
    raise exception 'payment_refund_blocks_transfer';
  end if;
  if exists (select 1 from private.stripe_job_disputes d
    where d.payment_intent_id = payment.id and d.status not in ('won', 'closed')) then
    raise exception 'active_payment_dispute';
  end if;
  select * into settlement from private.stripe_job_settlements
   where payment_intent_id = payment.id for update;
  if settlement.id is null then raise exception 'finalized_settlement_required'; end if;
  if settlement.compensated_base_cents <= 0 then raise exception 'positive_compensation_required'; end if;
  select * into account from private.stripe_connected_accounts
   where user_id = payment.teen_id and environment = p_environment for share;
  if account.id is null or account.onboarding_status <> 'complete'
     or not account.details_submitted or not account.payouts_enabled
     or account.transfers_capability_status <> 'active'
     or account.requirements_status <> 'satisfied'
     or account.guardian_requirement_status <> 'provider_managed_satisfied' then
    raise exception 'connected_account_not_ready';
  end if;
  select * into transfer from private.stripe_job_transfers
   where payment_intent_id = payment.id for update;
  if transfer.id is not null then
    return jsonb_build_object('ok', true, 'existing', true,
      'transfer_record_id', transfer.id, 'provider_transfer_id', transfer.provider_transfer_id,
      'status', transfer.status, 'amount_cents', transfer.amount_cents,
      'currency_code', transfer.currency_code,
      'provider_connected_account_id', account.provider_account_id,
      'provider_source_charge_id', transfer.provider_source_charge_id,
      'payment_record_id', payment.id, 'transfer_group', payment.transfer_group,
      'idempotency_key', transfer.idempotency_key);
  end if;
  insert into private.stripe_job_transfers (
    payment_intent_id, connected_account_id, environment, amount_cents,
    currency_code, provider_source_charge_id, idempotency_key,
    eligibility_path, status
  ) values (
    payment.id, account.id, p_environment, settlement.compensated_base_cents,
    payment.currency_code, payment.provider_charge_id,
    p_environment || ':settlement-transfer:' || settlement.id::text,
    p_eligibility_path, 'pending'
  ) returning * into transfer;
  return jsonb_build_object('ok', true, 'existing', false,
    'transfer_record_id', transfer.id, 'amount_cents', transfer.amount_cents,
    'currency_code', transfer.currency_code,
    'provider_connected_account_id', account.provider_account_id,
    'provider_source_charge_id', transfer.provider_source_charge_id,
    'payment_record_id', payment.id, 'transfer_group', payment.transfer_group,
    'idempotency_key', transfer.idempotency_key);
end;
$$;
revoke all on function public.stripe_server_prepare_settlement_transfer_v1(uuid, text, text, uuid)
  from public, anon, authenticated;
grant execute on function public.stripe_server_prepare_settlement_transfer_v1(uuid, text, text, uuid)
  to service_role;
