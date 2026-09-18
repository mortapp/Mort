create or replace function public.stripe_server_get_payment_state_for_qa_v1(
  p_provider_payment_intent_id text
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  c private.stripe_runtime_controls%rowtype;
  p private.stripe_job_payment_intents%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into c from private.stripe_runtime_controls where singleton;
  if c.mode <> 'sandbox' or not c.sandbox_provider_qa_approved
     or c.stripe_live_mode_enabled or c.live_owner_approved then
    raise exception 'sandbox_qa_gate_closed';
  end if;
  select * into p
  from private.stripe_job_payment_intents
  where environment='test'
    and provider_payment_intent_id=p_provider_payment_intent_id;
  if p.id is null then return null; end if;
  return jsonb_build_object(
    'record_id',p.id,
    'normalized_state',p.normalized_state,
    'status',p.status,
    'provider_charge_id',p.provider_charge_id,
    'funding_quote_id',p.funding_quote_id,
    'captured_amount_cents',p.captured_amount_cents,
    'currency_code',p.currency_code
  );
end;
$$;

revoke all on function public.stripe_server_get_payment_state_for_qa_v1(text) from public;
revoke all on function public.stripe_server_get_payment_state_for_qa_v1(text) from anon;
revoke all on function public.stripe_server_get_payment_state_for_qa_v1(text) from authenticated;
grant execute on function public.stripe_server_get_payment_state_for_qa_v1(text) to service_role;
