-- Service-only Stripe payment preparation for the new job_assignments model.
-- Charges are created on MORT's Stripe platform account; transfers remain a
-- separate, explicitly disabled operation until all Connect/legal controls pass.

create table if not exists private.mort_edge_action_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (action ~ '^[a-z0-9_]{1,80}$'),
  window_started_at timestamptz not null,
  request_count integer not null check (request_count > 0),
  primary key (user_id, action, window_started_at)
);
alter table private.mort_edge_action_limits enable row level security;
revoke all on table private.mort_edge_action_limits from public, anon, authenticated;
grant select, insert, update, delete on table private.mort_edge_action_limits to service_role;

create or replace function public.consume_my_edge_action_limit(p_action text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_window timestamptz := date_trunc('minute', now());
  v_limit integer;
  v_count integer;
begin
  if v_user is null then return false; end if;
  if p_action not in (
    'stripe_job_funding_quote', 'stripe_tip_payment_intent', 'stripe_job_payment_intent',
    'stripe_connected_account_status', 'stripe_connected_account_create', 'stripe_onboarding_link',
    'stripe_financial_document', 'stripe_financial_history', 'stripe_job_payment_status',
    'stripe_job_resolution', 'stripe_assignment_payment_intent'
  ) then return false; end if;
  v_limit := case
    when p_action in ('stripe_tip_payment_intent', 'stripe_job_payment_intent', 'stripe_assignment_payment_intent') then 4
    when p_action in ('stripe_connected_account_create', 'stripe_onboarding_link') then 3
    else 20
  end;
  insert into private.mort_edge_action_limits(user_id, action, window_started_at, request_count)
  values (v_user, p_action, v_window, 1)
  on conflict (user_id, action, window_started_at) do update
    set request_count = private.mort_edge_action_limits.request_count + 1
    where private.mort_edge_action_limits.request_count < v_limit
  returning request_count into v_count;
  return found;
end;
$$;
revoke all on function public.consume_my_edge_action_limit(text) from public, anon;
grant execute on function public.consume_my_edge_action_limit(text) to authenticated;

create or replace function public.stripe_server_prepare_assignment_payment(
  p_payer_id uuid,
  p_assignment_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  controls private.stripe_runtime_controls%rowtype;
  assignment public.job_assignments%rowtype;
  job public.jobs%rowtype;
  connected private.stripe_connected_accounts%rowtype;
  ledger private.stripe_payment_intents%rowtype;
  env text;
  gross_big bigint;
  gross integer;
  fee integer;
  net integer;
begin
  perform private.require_stripe_service_role();
  if p_payer_id is null or p_assignment_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_payment_request');
  end if;
  select * into strict controls from private.stripe_runtime_controls where singleton;
  if controls.mode = 'disabled'
    or not controls.payments_enabled
    or not controls.job_funding_enabled then
    return jsonb_build_object('ok', false, 'code', 'stripe_job_funding_disabled');
  end if;
  if controls.mode = 'live' and (not controls.live_mode_enabled or not controls.live_owner_approved) then
    return jsonb_build_object('ok', false, 'code', 'stripe_live_not_approved');
  end if;
  env := case controls.mode when 'sandbox' then 'test' when 'live' then 'live' else null end;

  select * into assignment from public.job_assignments where id = p_assignment_id for update;
  if not found or assignment.adult_user_id <> p_payer_id
    or assignment.status not in ('accepted', 'in_progress', 'awaiting_confirmation') then
    return jsonb_build_object('ok', false, 'code', 'active_assignment_required');
  end if;
  select * into job from public.jobs where id = assignment.job_id;
  if not found or job.status not in ('filled', 'in_progress') then
    return jsonb_build_object('ok', false, 'code', 'active_assignment_required');
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = p_payer_id and p.role = 'adult'::public.mort_role and p.account_status = 'active'
  ) or not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = p_payer_id and vc.verification_type = 'identity'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > now())
  ) then
    return jsonb_build_object('ok', false, 'code', 'verified_adult_payer_required');
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = assignment.teen_user_id and p.role = 'teen'::public.mort_role and p.account_status = 'active'
      and p.date_of_birth is not null
      and extract(year from age(current_date, p.date_of_birth)) between job.age_min and job.age_max
  ) or not exists (
    select 1 from public.verification_cases vc
    where vc.user_id = assignment.teen_user_id and vc.verification_type = 'age'
      and vc.status = 'verified'::public.mort_verification_status
      and (vc.expires_at is null or vc.expires_at > now())
  ) then
    return jsonb_build_object('ok', false, 'code', 'verified_teen_payee_required');
  end if;
  if not controls.connected_accounts_approved or not controls.payouts_approved then
    return jsonb_build_object('ok', false, 'code', 'stripe_connected_accounts_not_approved');
  end if;
  select * into connected from private.stripe_connected_accounts
  where user_id = assignment.teen_user_id and environment = env;
  if not found or not connected.payouts_enabled or connected.transfers_capability_status <> 'active'
    or connected.requirements_status <> 'satisfied' then
    return jsonb_build_object('ok', false, 'code', 'verified_connected_payout_account_required');
  end if;

  gross_big := round(assignment.agreed_amount * 100)::bigint;
  if gross_big < 1000 or gross_big > 99999999 then
    return jsonb_build_object('ok', false, 'code', 'assignment_amount_not_fundable');
  end if;
  gross := gross_big::integer;
  fee := controls.service_fee_cents;
  net := gross - fee;
  if fee < 0 or net <= 0 then
    return jsonb_build_object('ok', false, 'code', 'assignment_amount_not_fundable');
  end if;

  select * into ledger from private.stripe_payment_intents
  where assignment_id = assignment.id and environment = env and operation_version = 1
  for update;
  if not found then
    insert into private.stripe_payment_intents(
      assignment_id, payer_id, payee_id, environment, operation_version,
      gross_amount_cents, service_fee_cents, teen_net_cents, currency_code,
      idempotency_key, status
    ) values (
      assignment.id, assignment.adult_user_id, assignment.teen_user_id, env, 1,
      gross, fee, net, controls.currency_code,
      'mort:' || env || ':assignment:' || assignment.id::text || ':payment:v1', 'prepared'
    ) returning * into ledger;
  elsif ledger.payer_id <> assignment.adult_user_id
    or ledger.payee_id <> assignment.teen_user_id
    or ledger.gross_amount_cents <> gross
    or ledger.service_fee_cents <> fee
    or ledger.currency_code <> controls.currency_code then
    return jsonb_build_object('ok', false, 'code', 'payment_snapshot_conflict');
  end if;

  return jsonb_build_object(
    'ok', true,
    'ledger_id', ledger.id,
    'assignment_id', ledger.assignment_id,
    'environment', ledger.environment,
    'gross_amount_cents', ledger.gross_amount_cents,
    'service_fee_cents', ledger.service_fee_cents,
    'teen_net_cents', ledger.teen_net_cents,
    'currency_code', ledger.currency_code,
    'idempotency_key', ledger.idempotency_key,
    'provider_payment_intent_id', ledger.provider_payment_intent_id,
    'status', ledger.status
  );
end;
$$;
revoke all on function public.stripe_server_prepare_assignment_payment(uuid,uuid) from public, anon, authenticated;
grant execute on function public.stripe_server_prepare_assignment_payment(uuid,uuid) to service_role;

create or replace function public.stripe_server_record_assignment_payment_intent(
  p_ledger_id uuid,
  p_provider_payment_intent_id text,
  p_provider_status text,
  p_provider_created_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  ledger private.stripe_payment_intents%rowtype;
  mapped_status text;
begin
  perform private.require_stripe_service_role();
  if p_provider_payment_intent_id !~ '^pi_[A-Za-z0-9]+$' then
    raise exception 'stripe_payment_intent_id_invalid';
  end if;
  mapped_status := case p_provider_status
    when 'requires_payment_method' then 'requires_payment_method'
    when 'requires_action' then 'requires_action'
    when 'processing' then 'processing'
    when 'succeeded' then 'succeeded'
    when 'canceled' then 'cancelled'
    when 'requires_confirmation' then 'requires_payment_method'
    else 'unknown'
  end;
  select * into strict ledger from private.stripe_payment_intents where id = p_ledger_id for update;
  if ledger.provider_payment_intent_id is not null
    and ledger.provider_payment_intent_id <> p_provider_payment_intent_id then
    raise exception 'stripe_payment_intent_conflict';
  end if;
  update private.stripe_payment_intents
  set provider_payment_intent_id = p_provider_payment_intent_id,
      status = mapped_status,
      last_provider_event_at = coalesce(p_provider_created_at, last_provider_event_at),
      updated_at = now()
  where id = p_ledger_id
  returning * into ledger;
  return jsonb_build_object(
    'ledger_id', ledger.id,
    'provider_payment_intent_id', ledger.provider_payment_intent_id,
    'status', ledger.status
  );
end;
$$;
revoke all on function public.stripe_server_record_assignment_payment_intent(uuid,text,text,timestamptz) from public, anon, authenticated;
grant execute on function public.stripe_server_record_assignment_payment_intent(uuid,text,text,timestamptz) to service_role;

comment on function public.stripe_server_prepare_assignment_payment(uuid,uuid) is
  'Builds an immutable, idempotent server-authored funding snapshot for an accepted assignment; blocked unless Stripe live/sandbox and payout gates are explicitly enabled.';
comment on function public.stripe_server_record_assignment_payment_intent(uuid,text,text,timestamptz) is
  'Service-only persistence for a Stripe PaymentIntent created from the server-authored assignment snapshot.';

