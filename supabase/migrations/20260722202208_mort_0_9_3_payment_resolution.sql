-- MORT 0.9.3 Stripe resolution boundary.
-- Separate charges and transfers remain authoritative. No client chooses a
-- transfer, refund, destination, or compensation amount.

create table if not exists private.stripe_saved_payment_consents (
  id uuid primary key default gen_random_uuid(),
  adult_id uuid not null references auth.users(id) on delete cascade,
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  consent_version text not null,
  consent_text_hash text not null,
  purpose text not null default 'reuse_for_adult_initiated_future_payment_sheet',
  consented_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint stripe_saved_consent_version_check check (consent_version ~ '^saved-payment-consent-v[0-9]+$'),
  constraint stripe_saved_consent_hash_check check (consent_text_hash ~ '^[a-f0-9]{64}$'),
  constraint stripe_saved_consent_purpose_check check (purpose = 'reuse_for_adult_initiated_future_payment_sheet'),
  unique (adult_id, contract_id, consent_version)
);

create table if not exists private.stripe_payment_resolutions (
  id uuid primary key default gen_random_uuid(),
  environment text not null,
  resolution_source text not null,
  contract_id uuid not null references public.job_contracts(id) on delete restrict,
  payment_intent_id uuid not null references private.stripe_job_payment_intents(id) on delete restrict,
  dispute_id uuid references public.payment_disputes(id) on delete restrict,
  decision_id uuid references public.payment_dispute_decisions(id) on delete restrict,
  eligibility_path text not null,
  transfer_amount_cents integer not null,
  refund_amount_cents integer not null,
  currency_code text not null,
  status text not null default 'reviewed_pending_financial_execution',
  reviewer_id uuid references auth.users(id) on delete restrict,
  financial_operator_id uuid references auth.users(id) on delete restrict,
  review_request_id uuid not null,
  execution_request_id uuid,
  provider_transfer_id text,
  provider_refund_id text,
  transfer_idempotency_key text not null,
  refund_idempotency_key text,
  safe_failure_code text,
  reviewed_at timestamptz not null default now(),
  executed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stripe_resolution_environment_check check (environment in ('test', 'live')),
  constraint stripe_resolution_source_check check (resolution_source in ('normal_completion', 'human_dispute_review')),
  constraint stripe_resolution_path_check check (eligibility_path in ('mutual_completion_confirmed', 'completion_confirmed_after_review', 'completion_without_code_approved', 'partial_completion_approved', 'authorized_safety_exit_payment')),
  constraint stripe_resolution_amount_check check (transfer_amount_cents >= 0 and refund_amount_cents >= 0),
  constraint stripe_resolution_currency_check check (currency_code ~ '^[A-Z]{3}$'),
  constraint stripe_resolution_status_check check (status in ('reviewed_pending_financial_execution', 'financial_execution_started', 'provider_processing', 'completed', 'failed', 'blocked')), 
  constraint stripe_resolution_separation_check check (financial_operator_id is null or reviewer_id is null or financial_operator_id <> reviewer_id),
  constraint stripe_resolution_provider_transfer_check check (provider_transfer_id is null or provider_transfer_id ~ '^tr_[A-Za-z0-9]+$'),
  constraint stripe_resolution_provider_refund_check check (provider_refund_id is null or provider_refund_id ~ '^re_[A-Za-z0-9]+$'),
  unique (environment, contract_id),
  unique (environment, dispute_id),
  unique (environment, review_request_id),
  unique (environment, execution_request_id)
);

create index if not exists stripe_resolution_status_idx on private.stripe_payment_resolutions(environment, status, created_at);
create index if not exists stripe_saved_consents_adult_idx on private.stripe_saved_payment_consents(adult_id, consented_at desc);

alter table private.stripe_saved_payment_consents enable row level security;
alter table private.stripe_saved_payment_consents force row level security;
alter table private.stripe_payment_resolutions enable row level security;
alter table private.stripe_payment_resolutions force row level security;
revoke all on private.stripe_saved_payment_consents, private.stripe_payment_resolutions from public, anon, authenticated;
grant all on private.stripe_saved_payment_consents, private.stripe_payment_resolutions to service_role;

create or replace function private.has_stripe_financial_role(p_user_id uuid, p_role_keys text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and exists (
    select 1 from private.stripe_financial_role_assignments assignment
    where assignment.user_id = p_user_id
      and assignment.role_key = any(p_role_keys)
      and assignment.revoked_at is null
      and assignment.expires_at > now()
  )
$$;
revoke all on function private.has_stripe_financial_role(uuid, text[]) from public, anon, authenticated;
grant execute on function private.has_stripe_financial_role(uuid, text[]) to service_role;

create or replace function public.record_my_saved_payment_consent(
  p_contract_id uuid,
  p_consent_version text,
  p_consent_text text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract public.job_contracts%rowtype;
  v_consent private.stripe_saved_payment_consents%rowtype;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  select * into v_contract from public.job_contracts where id = p_contract_id;
  if v_contract.id is null or v_contract.adult_id <> auth.uid() then return jsonb_build_object('ok', false, 'code', 'adult_contract_party_required'); end if;
  if p_consent_version !~ '^saved-payment-consent-v[0-9]+$' or char_length(btrim(coalesce(p_consent_text, ''))) not between 40 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'explicit_saved_payment_consent_required');
  end if;
  insert into private.stripe_saved_payment_consents(adult_id, contract_id, consent_version, consent_text_hash)
  values (auth.uid(), v_contract.id, p_consent_version, encode(extensions.digest(btrim(p_consent_text), 'sha256'), 'hex'))
  on conflict (adult_id, contract_id, consent_version) do update set
    revoked_at = null, consented_at = now()
  returning * into v_consent;
  return jsonb_build_object('ok', true, 'consent_id', v_consent.id, 'consent_version', v_consent.consent_version, 'consented_at', v_consent.consented_at, 'stored_payment_token', false);
end;
$$;

create or replace function public.revoke_my_saved_payment_consent(p_contract_id uuid, p_consent_version text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.stripe_saved_payment_consents set revoked_at = coalesce(revoked_at, now())
  where adult_id = auth.uid() and contract_id = p_contract_id and consent_version = p_consent_version;
  return jsonb_build_object('ok', found, 'revoked', found);
end;
$$;

create or replace function public.stripe_server_validate_saved_payment_consent(
  p_adult_id uuid,
  p_contract_id uuid,
  p_consent_version text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_consent private.stripe_saved_payment_consents%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into v_consent from private.stripe_saved_payment_consents
  where adult_id = p_adult_id and contract_id = p_contract_id and consent_version = p_consent_version and revoked_at is null;
  if v_consent.id is null then raise exception 'explicit_saved_payment_consent_required'; end if;
  return jsonb_build_object('ok', true, 'consent_id', v_consent.id, 'consent_version', v_consent.consent_version, 'consented_at', v_consent.consented_at);
end;
$$;

create or replace function public.stripe_server_prepare_dispute_resolution(
  p_actor_id uuid,
  p_dispute_id uuid,
  p_environment text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_control private.stripe_runtime_controls%rowtype;
  v_dispute public.payment_disputes%rowtype;
  v_decision public.payment_dispute_decisions%rowtype;
  v_payment private.stripe_job_payment_intents%rowtype;
  v_resolution private.stripe_payment_resolutions%rowtype;
  v_transfer integer;
  v_refund integer;
  v_path text;
begin
  perform private.require_stripe_service_role();
  if not private.has_stripe_financial_role(p_actor_id, array['payment_reviewer']) then raise exception 'payment_reviewer_role_required'; end if;
  select * into v_control from private.stripe_runtime_controls where singleton for share;
  if p_environment <> private.stripe_environment_for_mode(v_control.mode) then raise exception 'stripe_environment_mismatch'; end if;
  if p_environment = 'live' then raise exception 'stripe_live_disabled'; end if;
  select * into v_dispute from public.payment_disputes where id = p_dispute_id for update;
  if v_dispute.id is null then raise exception 'payment_dispute_not_found'; end if;
  if v_dispute.status not in ('resolved_payment_recommended', 'resolved_partial_payment_recommended') then raise exception 'final_review_resolution_required'; end if;
  select * into v_decision from public.payment_dispute_decisions where dispute_id = v_dispute.id order by decided_at desc limit 1;
  if v_decision.id is null or v_decision.reviewer_id <> p_actor_id then raise exception 'reviewer_final_decision_required'; end if;
  if (v_dispute.status = 'resolved_payment_recommended' and v_decision.decision_type <> 'recommend_payment')
     or (v_dispute.status = 'resolved_partial_payment_recommended' and v_decision.decision_type <> 'recommend_partial_payment') then
    raise exception 'decision_status_mismatch';
  end if;
  select * into v_payment from private.stripe_job_payment_intents
  where contract_id = v_dispute.contract_id and environment = p_environment order by operation_version desc limit 1 for update;
  if v_payment.id is null or v_payment.status not in ('funded', 'disputed') then raise exception 'funded_payment_required'; end if;
  if exists (select 1 from private.stripe_job_disputes provider_dispute where provider_dispute.payment_intent_id = v_payment.id and provider_dispute.status not in ('won', 'closed')) then
    raise exception 'provider_dispute_blocks_resolution';
  end if;
  v_transfer := case when v_decision.decision_type = 'recommend_payment' then v_payment.earnings_amount_cents
    else least(v_payment.earnings_amount_cents, greatest(0, coalesce(v_decision.recommended_amount_cents, 0))) end;
  v_refund := v_payment.earnings_amount_cents - v_transfer;
  v_path := case when v_decision.decision_type = 'recommend_payment' then 'completion_confirmed_after_review' else 'partial_completion_approved' end;
  insert into private.stripe_payment_resolutions(
    environment, resolution_source, contract_id, payment_intent_id, dispute_id, decision_id,
    eligibility_path, transfer_amount_cents, refund_amount_cents, currency_code,
    reviewer_id, review_request_id, transfer_idempotency_key, refund_idempotency_key
  ) values (
    p_environment, 'human_dispute_review', v_dispute.contract_id, v_payment.id, v_dispute.id, v_decision.id,
    v_path, v_transfer, v_refund, v_payment.currency_code, p_actor_id, p_request_id,
    p_environment || ':resolution:' || v_dispute.id::text || ':transfer:v1',
    case when v_refund > 0 then p_environment || ':resolution:' || v_dispute.id::text || ':refund:v1' else null end
  )
  on conflict (environment, dispute_id) do update set updated_at = now()
  returning * into v_resolution;
  insert into private.stripe_financial_audit_events(actor_id, environment, event_type, subject_type, subject_id, safe_reason_code, field_names)
  values (p_actor_id, p_environment, 'resolution_reviewed', 'stripe_payment_resolution', v_resolution.id, v_decision.decision_type, array['transfer_amount_cents', 'refund_amount_cents', 'eligibility_path']);
  return jsonb_build_object('ok', true, 'resolution_id', v_resolution.id, 'status', v_resolution.status, 'transfer_amount_cents', v_resolution.transfer_amount_cents, 'refund_amount_cents', v_resolution.refund_amount_cents, 'currency_code', v_resolution.currency_code, 'provider_destination_included', false);
end;
$$;

create or replace function public.stripe_server_prepare_completion_resolution(
  p_actor_id uuid,
  p_contract_id uuid,
  p_environment text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_handshake public.job_arrival_handshakes%rowtype;
  v_contract public.job_contracts%rowtype;
  v_payment private.stripe_job_payment_intents%rowtype;
  v_resolution private.stripe_payment_resolutions%rowtype;
begin
  perform private.require_stripe_service_role();
  if not private.has_stripe_financial_role(p_actor_id, array['payment_reviewer']) then raise exception 'payment_reviewer_role_required'; end if;
  if p_environment <> 'test' then raise exception 'stripe_live_disabled'; end if;
  select * into v_contract from public.job_contracts where id = p_contract_id for update;
  select * into v_handshake from public.job_arrival_handshakes where application_id = v_contract.application_id for update;
  if v_contract.status <> 'completion_pending_release' or v_handshake.execution_state <> 'completion_pending_release' or v_handshake.review_window_ends_at > now() then
    raise exception 'completion_review_window_not_finished';
  end if;
  if exists (select 1 from public.payment_disputes dispute where dispute.contract_id = v_contract.id and dispute.status not in ('closed_confirmed_paid')) then raise exception 'active_dispute_blocks_release'; end if;
  select * into v_payment from private.stripe_job_payment_intents where contract_id = v_contract.id and environment = p_environment order by operation_version desc limit 1 for update;
  if v_payment.id is null or v_payment.status <> 'funded' then raise exception 'funded_payment_required'; end if;
  insert into private.stripe_payment_resolutions(
    environment, resolution_source, contract_id, payment_intent_id, eligibility_path,
    transfer_amount_cents, refund_amount_cents, currency_code, reviewer_id,
    review_request_id, transfer_idempotency_key
  ) values (
    p_environment, 'normal_completion', v_contract.id, v_payment.id, 'mutual_completion_confirmed',
    v_payment.earnings_amount_cents, 0, v_payment.currency_code, p_actor_id,
    p_request_id, p_environment || ':contract:' || v_contract.id::text || ':completion-transfer:v1'
  ) on conflict (environment, contract_id) do update set updated_at = now()
  returning * into v_resolution;
  insert into private.stripe_financial_audit_events(actor_id, environment, event_type, subject_type, subject_id, safe_reason_code, field_names)
  values (p_actor_id, p_environment, 'completion_resolution_reviewed', 'stripe_payment_resolution', v_resolution.id, 'review_window_elapsed', array['transfer_amount_cents']);
  return jsonb_build_object('ok', true, 'resolution_id', v_resolution.id, 'status', v_resolution.status, 'transfer_amount_cents', v_resolution.transfer_amount_cents, 'refund_amount_cents', 0, 'currency_code', v_resolution.currency_code, 'provider_destination_included', false);
end;
$$;

create or replace function public.stripe_server_load_resolution_for_execution(
  p_actor_id uuid,
  p_resolution_id uuid,
  p_environment text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_control private.stripe_runtime_controls%rowtype;
  v_resolution private.stripe_payment_resolutions%rowtype;
  v_payment private.stripe_job_payment_intents%rowtype;
  v_account private.stripe_connected_accounts%rowtype;
begin
  perform private.require_stripe_service_role();
  if not private.has_stripe_financial_role(p_actor_id, array['payment_operations']) then raise exception 'payment_operations_role_required'; end if;
  select * into v_control from private.stripe_runtime_controls where singleton for share;
  if p_environment <> private.stripe_environment_for_mode(v_control.mode) or p_environment <> 'test' then raise exception 'stripe_live_disabled'; end if;
  if not v_control.stripe_transfers_enabled or not v_control.payouts_approved then raise exception 'stripe_transfers_disabled'; end if;
  select * into v_resolution from private.stripe_payment_resolutions where id = p_resolution_id and environment = p_environment for update;
  if v_resolution.id is null then raise exception 'payment_resolution_not_found'; end if;
  if v_resolution.reviewer_id = p_actor_id then raise exception 'reviewer_financial_operator_separation_required'; end if;
  if v_resolution.status = 'completed' then
    return jsonb_build_object('ok', true, 'replayed', true, 'resolution_id', v_resolution.id, 'status', v_resolution.status);
  end if;
  if v_resolution.status not in ('reviewed_pending_financial_execution', 'financial_execution_started', 'provider_processing') then raise exception 'payment_resolution_not_executable'; end if;
  if v_resolution.execution_request_id is not null and v_resolution.execution_request_id <> p_request_id then raise exception 'resolution_execution_already_claimed'; end if;
  if v_resolution.refund_amount_cents > 0 and not v_control.stripe_refunds_enabled then raise exception 'stripe_refunds_disabled'; end if;
  if v_resolution.dispute_id is not null and exists (
    select 1 from public.payment_disputes dispute where dispute.id = v_resolution.dispute_id and dispute.status not in ('resolved_payment_recommended', 'resolved_partial_payment_recommended')
  ) then raise exception 'resolution_changed_or_reopened'; end if;
  select * into v_payment from private.stripe_job_payment_intents where id = v_resolution.payment_intent_id for update;
  if v_payment.status not in ('funded', 'disputed', 'transfer_pending') then raise exception 'payment_state_blocks_resolution'; end if;
  select * into v_account from private.stripe_connected_accounts
  where user_id = v_payment.teen_id and environment = p_environment
    and onboarding_status = 'complete' and payouts_enabled and transfers_capability_status = 'active';
  if v_account.id is null then raise exception 'eligible_connected_account_required'; end if;
  update private.stripe_payment_resolutions set
    status = 'financial_execution_started', financial_operator_id = p_actor_id,
    execution_request_id = p_request_id, updated_at = now()
  where id = v_resolution.id returning * into v_resolution;
  insert into private.stripe_financial_audit_events(actor_id, environment, event_type, subject_type, subject_id, safe_reason_code, field_names)
  values (p_actor_id, p_environment, 'resolution_execution_claimed', 'stripe_payment_resolution', v_resolution.id, 'server_resolution_loaded', array['financial_operator_id', 'execution_request_id']);
  return jsonb_build_object(
    'ok', true, 'replayed', false, 'resolution_id', v_resolution.id,
    'transfer_amount_cents', v_resolution.transfer_amount_cents,
    'refund_amount_cents', v_resolution.refund_amount_cents,
    'currency_code', v_resolution.currency_code,
    'provider_connected_account_id', v_account.provider_account_id,
    'provider_source_charge_id', v_payment.provider_charge_id,
    'provider_payment_intent_id', v_payment.provider_payment_intent_id,
    'transfer_idempotency_key', v_resolution.transfer_idempotency_key,
    'refund_idempotency_key', v_resolution.refund_idempotency_key
  );
end;
$$;

create or replace function public.stripe_server_record_resolution_result(
  p_resolution_id uuid,
  p_environment text,
  p_provider_transfer_id text,
  p_provider_refund_id text,
  p_provider_status text,
  p_safe_failure_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_resolution private.stripe_payment_resolutions%rowtype;
  v_payment private.stripe_job_payment_intents%rowtype;
  v_account private.stripe_connected_accounts%rowtype;
  v_status text;
begin
  perform private.require_stripe_service_role();
  select * into v_resolution from private.stripe_payment_resolutions where id = p_resolution_id and environment = p_environment for update;
  if v_resolution.id is null then raise exception 'payment_resolution_not_found'; end if;
  if v_resolution.status = 'completed' then return jsonb_build_object('ok', true, 'replayed', true, 'status', v_resolution.status); end if;
  if v_resolution.status not in ('financial_execution_started', 'provider_processing') then raise exception 'resolution_execution_not_claimed'; end if;
  select * into v_payment from private.stripe_job_payment_intents where id = v_resolution.payment_intent_id for update;
  select * into v_account from private.stripe_connected_accounts where user_id = v_payment.teen_id and environment = p_environment;
  if v_resolution.transfer_amount_cents > 0 and p_provider_transfer_id !~ '^tr_[A-Za-z0-9]+$' then raise exception 'provider_transfer_reference_required'; end if;
  if v_resolution.refund_amount_cents > 0 and p_provider_refund_id !~ '^re_[A-Za-z0-9]+$' then raise exception 'provider_refund_reference_required'; end if;
  v_status := case p_provider_status when 'succeeded' then 'completed' when 'processing' then 'provider_processing' else 'failed' end;
  if p_provider_status = 'succeeded' and v_resolution.transfer_amount_cents > 0 then
    insert into private.stripe_job_transfers(
      payment_intent_id, connected_account_id, environment, amount_cents, currency_code,
      provider_transfer_id, provider_source_charge_id, idempotency_key, eligibility_path, status, transferred_at
    ) values (
      v_payment.id, v_account.id, p_environment, v_resolution.transfer_amount_cents, v_resolution.currency_code,
      p_provider_transfer_id, v_payment.provider_charge_id, v_resolution.transfer_idempotency_key,
      v_resolution.eligibility_path, 'paid', now()
    ) on conflict (payment_intent_id) do update set
      provider_transfer_id = coalesce(private.stripe_job_transfers.provider_transfer_id, excluded.provider_transfer_id),
      status = 'paid', transferred_at = coalesce(private.stripe_job_transfers.transferred_at, now()), updated_at = now();
  end if;
  if p_provider_status = 'succeeded' and v_resolution.refund_amount_cents > 0 then
    insert into private.stripe_job_refunds(payment_intent_id, requested_by, environment, amount_cents, provider_refund_id, idempotency_key, reason_code, status)
    values (v_payment.id, v_resolution.financial_operator_id, p_environment, v_resolution.refund_amount_cents, p_provider_refund_id, v_resolution.refund_idempotency_key, 'reviewed_partial_resolution', 'succeeded')
    on conflict (environment, idempotency_key) do update set provider_refund_id = excluded.provider_refund_id, status = 'succeeded', updated_at = now();
  end if;
  update private.stripe_payment_resolutions set
    status = v_status, provider_transfer_id = p_provider_transfer_id,
    provider_refund_id = p_provider_refund_id, safe_failure_code = left(p_safe_failure_code, 120),
    executed_at = case when v_status = 'completed' then now() else executed_at end, updated_at = now()
  where id = v_resolution.id returning * into v_resolution;
  if v_status = 'completed' then
    update private.stripe_job_payment_intents set status = case when v_resolution.refund_amount_cents > 0 then 'partially_refunded' else 'transferred' end, updated_at = now() where id = v_payment.id;
    update public.job_contracts set status = 'completed', closed_at = now() where id = v_resolution.contract_id;
    update public.applications set status = 'completed', updated_at = now() where id = (select application_id from public.job_contracts where id = v_resolution.contract_id);
    update public.jobs set status = 'closed', updated_at = now() where id = (select job_id from public.job_contracts where id = v_resolution.contract_id);
    update public.job_arrival_handshakes set execution_state = 'completed', updated_at = now() where application_id = (select application_id from public.job_contracts where id = v_resolution.contract_id);
    update public.job_payment_obligations set status = 'due', became_due_at = coalesce(became_due_at, now()) where id = v_payment.obligation_id and status in ('pending_release', 'disputed');
    if v_resolution.dispute_id is not null then
      insert into public.payment_dispute_timeline(dispute_id, actor_id, event_type, event_summary)
      values (v_resolution.dispute_id, v_resolution.financial_operator_id, 'provider_resolution_completed', 'The approved server resolution completed through the payment provider.');
    end if;
  end if;
  insert into private.stripe_financial_audit_events(actor_id, environment, event_type, subject_type, subject_id, safe_reason_code, field_names)
  values (v_resolution.financial_operator_id, p_environment, 'resolution_provider_result', 'stripe_payment_resolution', v_resolution.id, v_status, array['status', 'provider_transfer_id', 'provider_refund_id']);
  return jsonb_build_object('ok', true, 'replayed', false, 'resolution_id', v_resolution.id, 'status', v_resolution.status);
end;
$$;

-- Existing generic transfer preparation must not release a job that is still
-- in the 0.9.3 completion review window or has any unresolved private dispute.
create or replace function private.stripe_resolution_blocks_generic_release(p_contract_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.job_arrival_handshakes handshake
    join public.job_contracts contract on contract.application_id = handshake.application_id
    where contract.id = p_contract_id
      and (handshake.execution_state <> 'completed' or handshake.review_window_ends_at is null or handshake.review_window_ends_at > now())
  ) or exists (
    select 1 from public.payment_disputes dispute
    where dispute.contract_id = p_contract_id and dispute.status <> 'closed_confirmed_paid'
  )
$$;
revoke all on function private.stripe_resolution_blocks_generic_release(uuid) from public, anon, authenticated;
grant execute on function private.stripe_resolution_blocks_generic_release(uuid) to service_role;

revoke all on function public.record_my_saved_payment_consent(uuid, text, text) from public, anon;
revoke all on function public.revoke_my_saved_payment_consent(uuid, text) from public, anon;
grant execute on function public.record_my_saved_payment_consent(uuid, text, text) to authenticated, service_role;
grant execute on function public.revoke_my_saved_payment_consent(uuid, text) to authenticated, service_role;

do $$
declare signature text;
begin
  foreach signature in array array[
    'public.stripe_server_validate_saved_payment_consent(uuid,uuid,text)',
    'public.stripe_server_prepare_dispute_resolution(uuid,uuid,text,uuid)',
    'public.stripe_server_prepare_completion_resolution(uuid,uuid,text,uuid)',
    'public.stripe_server_load_resolution_for_execution(uuid,uuid,text,uuid)',
    'public.stripe_server_record_resolution_result(uuid,text,text,text,text,text)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', signature);
    execute format('grant execute on function %s to service_role', signature);
  end loop;
end $$;
