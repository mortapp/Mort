-- Participant-safe tip attempt read contract.
-- Provider credentials and internal financial rows remain private.

create or replace function public.get_my_tip_attempt_state_v1(
  p_tip_attempt_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  tip private.stripe_tip_attempts%rowtype;
begin
  if actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  select * into tip
  from private.stripe_tip_attempts
  where id = p_tip_attempt_id;

  if tip.id is null then
    return null;
  end if;

  if actor not in (tip.payer_id, tip.worker_id) then
    raise exception 'tip_party_required' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'tip_attempt_id', tip.id,
    'settlement_id', tip.settlement_id,
    'job_id', tip.job_id,
    'amount_cents', tip.amount_cents,
    'teen_amount_cents', tip.teen_amount_cents,
    'mort_fee_cents', tip.mort_fee_cents,
    'currency_code', tip.currency_code,
    'state', tip.normalized_state,
    'updated_at', tip.updated_at
  );
end;
$$;

revoke all on function public.get_my_tip_attempt_state_v1(uuid)
  from public, anon;

grant execute on function public.get_my_tip_attempt_state_v1(uuid)
  to authenticated;
