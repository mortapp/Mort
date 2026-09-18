-- Add participant-safe financial read contracts for native/mobile clients.
-- These functions expose only the authenticated participant's own settlement
-- and public policy configuration. They do not weaken private table RLS or
-- authorize provider mutations.

create or replace function public.get_my_financial_policy_config_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  control private.stripe_runtime_controls%rowtype;
  environment text;
  fee_policy private.stripe_financial_policy_versions%rowtype;
  tip_policy private.stripe_financial_policy_versions%rowtype;
begin
  if actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not public.is_profile_active(actor) then
    raise exception 'user_account_restricted' using errcode = '42501';
  end if;

  select * into control
  from private.stripe_runtime_controls
  where singleton;

  if control.singleton is not true then
    raise exception 'stripe_runtime_controls_unavailable';
  end if;

  environment := private.stripe_environment_for_mode(control.mode);

  select * into fee_policy
  from private.resolve_financial_policy_v1(
    environment,
    'service_fee',
    control.currency_code,
    'global',
    statement_timestamp()
  );

  select * into tip_policy
  from private.resolve_financial_policy_v1(
    environment,
    'tip',
    control.currency_code,
    'global',
    statement_timestamp()
  );

  return jsonb_build_object(
    'ok', true,
    'environment', environment,
    'currency_code', control.currency_code,
    'service_fee', case
      when fee_policy.id is null then null
      else jsonb_build_object(
        'version', fee_policy.version,
        'percent_basis_points', fee_policy.service_fee_bps,
        'minimum_cents', fee_policy.service_fee_min_cents,
        'maximum_cents', fee_policy.service_fee_max_cents,
        'quote_ttl_seconds', fee_policy.quote_ttl_seconds
      )
    end,
    'tip', case
      when tip_policy.id is null then null
      else jsonb_build_object(
        'version', tip_policy.version,
        'minimum_cents', tip_policy.tip_min_cents,
        'maximum_cents', tip_policy.tip_max_cents,
        'late_tip_window_seconds', tip_policy.late_tip_window_seconds,
        'teen_share_basis_points', tip_policy.tip_teen_share_bps,
        'mort_fee_basis_points', tip_policy.tip_mort_fee_bps,
        'excluded_from_fair_pay', tip_policy.tip_excluded_from_fair_pay
      )
    end
  );
end;
$$;

create or replace function public.get_my_job_settlement_v1(
  p_contract_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  contract public.job_contracts%rowtype;
  settlement private.stripe_job_settlements%rowtype;
  display_order_number text;
begin
  if actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  select * into contract
  from public.job_contracts
  where id = p_contract_id;

  if contract.id is null then
    return null;
  end if;

  if actor not in (contract.adult_id, contract.teen_id) then
    raise exception 'contract_party_required' using errcode = '42501';
  end if;

  select * into settlement
  from private.stripe_job_settlements
  where contract_id = contract.id
  order by finalized_at desc nulls last, created_at desc, id desc
  limit 1;

  if settlement.id is null then
    return null;
  end if;

  select document.order_number
  into display_order_number
  from private.financial_documents document
  where document.owner_id = actor
    and document.settlement_id = settlement.id
  order by document.created_at desc, document.id desc
  limit 1;

  return jsonb_build_object(
    'ok', true,
    'settlement_id', settlement.id,
    'contract_id', settlement.contract_id,
    'job_id', contract.job_id,
    'order_number', display_order_number,
    'funded_base_cents', settlement.funded_base_cents,
    'compensated_base_cents', settlement.compensated_base_cents,
    'base_refund_cents', settlement.base_refund_cents,
    'service_fee_cents', settlement.service_fee_cents,
    'service_fee_refund_cents', settlement.service_fee_refund_cents,
    'fee_retained_cents',
      greatest(settlement.service_fee_cents - settlement.service_fee_refund_cents, 0),
    'adult_refund_cents',
      settlement.base_refund_cents + settlement.service_fee_refund_cents,
    'currency_code', settlement.currency_code,
    'outcome_code', settlement.outcome_code,
    'decision_reason_code', settlement.decision_reason_code,
    'finalized_at', settlement.finalized_at,
    'explanation', case
      when settlement.base_refund_cents = 0
       and settlement.service_fee_refund_cents = 0
        then 'MORT finalized this job with no customer refund.'
      when settlement.compensated_base_cents = 0
        then 'MORT finalized this job with a customer refund and no worker compensation.'
      else 'MORT finalized this job with partial worker compensation and a customer refund.'
    end
  );
end;
$$;

create or replace function public.get_my_job_financial_document_v1(
  p_contract_id uuid,
  p_document_type text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  contract public.job_contracts%rowtype;
  settlement private.stripe_job_settlements%rowtype;
  document private.financial_documents%rowtype;
  requested_type text := nullif(upper(btrim(coalesce(p_document_type, ''))), '');
begin
  if actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  select * into contract
  from public.job_contracts
  where id = p_contract_id;

  if contract.id is null then
    return null;
  end if;

  if actor not in (contract.adult_id, contract.teen_id) then
    raise exception 'contract_party_required' using errcode = '42501';
  end if;

  select * into settlement
  from private.stripe_job_settlements
  where contract_id = contract.id
  order by finalized_at desc nulls last, created_at desc, id desc
  limit 1;

  if settlement.id is null then
    return null;
  end if;

  select * into document
  from private.financial_documents candidate
  where candidate.owner_id = actor
    and candidate.settlement_id = settlement.id
    and (requested_type is null or upper(candidate.document_type) = requested_type)
  order by candidate.created_at desc, candidate.id desc
  limit 1;

  if document.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'id', document.id,
    'document_type', document.document_type,
    'receipt_id', document.receipt_id,
    'order_number', document.order_number,
    'document_date', document.document_date,
    'amount_cents', document.amount_cents,
    'currency_code', document.currency_code,
    'status', document.status,
    'masked_provider_reference', document.masked_provider_reference,
    'immutable_snapshot', document.immutable_snapshot,
    'linked_document_refs', document.linked_document_refs,
    'created_at', document.created_at
  );
end;
$$;

revoke all on function public.get_my_financial_policy_config_v1()
  from public, anon;
revoke all on function public.get_my_job_settlement_v1(uuid)
  from public, anon;
revoke all on function public.get_my_job_financial_document_v1(uuid, text)
  from public, anon;

grant execute on function public.get_my_financial_policy_config_v1()
  to authenticated;
grant execute on function public.get_my_job_settlement_v1(uuid)
  to authenticated;
grant execute on function public.get_my_job_financial_document_v1(uuid, text)
  to authenticated;
