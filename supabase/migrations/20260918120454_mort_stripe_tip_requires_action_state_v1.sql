-- Preserve requires_action for post-work tip PaymentIntents.
-- Hosted migration: 20260918120454_mort_stripe_tip_requires_action_state_v1.

create or replace function public.stripe_server_apply_tip_event_v1(
  p_tip_attempt_id uuid,
  p_provider_payment_intent_id text,
  p_provider_status text,
  p_amount_cents integer,
  p_currency_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tip private.stripe_tip_attempts%rowtype;
  next_state text;
begin
  perform private.require_stripe_service_role();

  next_state := case p_provider_status
    when 'payment_intent.succeeded' then 'SUCCEEDED'
    when 'payment_intent.processing' then 'PROCESSING'
    when 'payment_intent.requires_action' then 'REQUIRES_ACTION'
    when 'payment_intent.payment_failed' then 'DECLINED'
    when 'payment_intent.canceled' then 'CANCELLED'
    else 'UNKNOWN'
  end;

  select *
    into tip
    from private.stripe_tip_attempts
   where id = p_tip_attempt_id
   for update;

  if tip.id is null then raise exception 'tip_attempt_not_found'; end if;
  if tip.provider_payment_intent_id is not null
     and tip.provider_payment_intent_id <> p_provider_payment_intent_id then
    raise exception 'tip_provider_payment_intent_mismatch';
  end if;
  if p_amount_cents <> tip.amount_cents or upper(p_currency_code) <> tip.currency_code then
    raise exception 'tip_amount_currency_mismatch';
  end if;
  if tip.normalized_state in ('SUCCEEDED', 'DECLINED', 'FAILED', 'CANCELLED', 'DUPLICATE_BLOCKED')
     and tip.normalized_state <> next_state then
    raise exception 'tip_state_regression';
  end if;

  update private.stripe_tip_attempts
     set provider_payment_intent_id = p_provider_payment_intent_id,
         normalized_state = next_state,
         updated_at = statement_timestamp()
   where id = tip.id;

  return jsonb_build_object(
    'ok', true,
    'tip_attempt_id', tip.id,
    'normalized_state', next_state
  );
end;
$$;

revoke all on function public.stripe_server_apply_tip_event_v1(uuid, text, text, integer, text)
  from public, anon, authenticated;
grant execute on function public.stripe_server_apply_tip_event_v1(uuid, text, text, integer, text)
  to service_role;
