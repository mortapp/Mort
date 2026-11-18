-- Recheck the existing operational approvals at the final server-side boundary
-- before a funding quote is consumed and a PaymentIntent can be prepared.
-- This preserves the quote-bound API and prevents client-side eligibility bypass.
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
begin
  perform private.require_stripe_service_role();
  if p_payer_id is null or p_quote_id is null or p_attempt_request_id is null then
    raise exception 'funding_quote_consumption_identifiers_required';
  end if;

  select * into v_quote
  from private.stripe_job_funding_quotes
  where id = p_quote_id
  for update;
  if v_quote.id is null or v_quote.payer_id <> p_payer_id then
    raise exception 'funding_quote_not_found' using errcode = '42501';
  end if;

  select * into v_control
  from private.stripe_runtime_controls
  where singleton
  for share;
  if v_control.singleton is distinct from true
     or not coalesce(v_control.stripe_payments_enabled, false)
     or not coalesce(v_control.stripe_job_funding_enabled, false) then
    raise exception 'stripe_job_funding_disabled';
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
  if v_quote.state <> 'ACTIVE' then
    raise exception 'funding_quote_not_active';
  end if;
  if not private.funding_quote_is_usable_v1(v_quote.state, v_quote.expires_at, v_now) then
    update private.stripe_job_funding_quotes
    set state = 'EXPIRED', expired_at = v_now
    where id = v_quote.id
    returning * into v_quote;
    return jsonb_build_object(
      'ok', false, 'code', 'funding_quote_expired',
      'quote_id', v_quote.id, 'expires_at', v_quote.expires_at
    );
  end if;

  update private.stripe_job_funding_quotes
  set state = 'CONSUMED', consumed_at = v_now,
      consumed_request_id = p_attempt_request_id
  where id = v_quote.id
  returning * into v_quote;
  return private.job_funding_quote_dto_v1(v_quote) || jsonb_build_object('idempotent', false);
end;
$$;

revoke all on function public.stripe_server_consume_job_funding_quote_v1(uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.stripe_server_consume_job_funding_quote_v1(uuid, uuid, uuid)
  to service_role;
