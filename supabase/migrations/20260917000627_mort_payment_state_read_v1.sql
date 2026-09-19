create or replace function public.get_my_payment_attempt_state_v1(p_payment_intent_id text)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'payment_intent_id', payment.provider_payment_intent_id,
    'state', payment.normalized_state,
    'legacy_status', payment.status,
    'provider_confirmed_at', payment.provider_confirmed_at,
    'last_reconciled_at', payment.last_reconciled_at
  )
  from private.stripe_job_payment_intents payment
  where payment.provider_payment_intent_id = p_payment_intent_id
    and (payment.adult_id = auth.uid() or payment.teen_id = auth.uid())
$$;

revoke all on function public.get_my_payment_attempt_state_v1(text) from public, anon;
grant execute on function public.get_my_payment_attempt_state_v1(text) to authenticated;
