-- Forward-only hardening for financial resolution outcomes, webhook lease fencing,
-- and client write access to public.profiles. Never mutates provider state.

-- Preserve the exact deployed resolution function body (including safety gates)
-- while narrowing its disputed-obligation transition to pending_completion only.
do $resolution_obligation_fix$
declare
  v_signature regprocedure := 'public.stripe_server_record_resolution_result(uuid,text,text,text,text,text)'::regprocedure;
  v_definition text;
  v_replacement text;
  v_anchor text;
  v_guard text;
begin
  v_definition := pg_get_functiondef(v_signature);
  v_replacement := replace(
    v_definition,
    'status in (''pending_release'', ''disputed'')',
    'status = ''pending_completion'''
  );
  if v_replacement = v_definition then
    raise exception 'resolution_obligation_transition_pattern_not_found';
  end if;
  v_anchor := 'if v_resolution.status not in (''financial_execution_started'', ''provider_processing'') then raise exception ''resolution_execution_not_claimed''; end if;';
  if position(v_anchor in v_replacement) = 0 then
    raise exception 'resolution_operation_status_guard_pattern_not_found';
  end if;
  v_guard := v_anchor || E'\n  if p_provider_status = ''succeeded'' and (\n    (v_resolution.transfer_amount_cents > 0 and v_resolution.transfer_status <> ''succeeded'')\n    or (v_resolution.refund_amount_cents > 0 and v_resolution.refund_status <> ''succeeded'')\n  ) then raise exception ''resolution_operations_not_confirmed''; end if;';
  v_replacement := replace(v_replacement, v_anchor, v_guard);
  v_replacement := replace(
    v_replacement,
    'if v_resolution.transfer_amount_cents > 0 and p_provider_transfer_id !~ ''^tr_[A-Za-z0-9]+$'' then raise exception ''provider_transfer_reference_required''; end if;',
    'if p_provider_transfer_id is not null and p_provider_transfer_id !~ ''^tr_[A-Za-z0-9]+$'' then raise exception ''provider_transfer_reference_invalid''; end if; if p_provider_status = ''succeeded'' and v_resolution.transfer_amount_cents > 0 and p_provider_transfer_id is null then raise exception ''provider_transfer_reference_required''; end if;'
  );
  v_replacement := replace(
    v_replacement,
    'if v_resolution.refund_amount_cents > 0 and p_provider_refund_id !~ ''^re_[A-Za-z0-9]+$'' then raise exception ''provider_refund_reference_required''; end if;',
    'if p_provider_refund_id is not null and p_provider_refund_id !~ ''^re_[A-Za-z0-9]+$'' then raise exception ''provider_refund_reference_invalid''; end if; if p_provider_status = ''succeeded'' and v_resolution.refund_amount_cents > 0 and p_provider_refund_id is null then raise exception ''provider_refund_reference_required''; end if;'
  );
  execute v_replacement;
end;
$resolution_obligation_fix$;

-- Keep transfer and refund operation state independently observable. Historical
-- completed records are backfilled only when their provider object is present;
-- ambiguous old outcomes remain unknown and require reconciliation.
alter table private.stripe_payment_resolutions
  add column if not exists transfer_status text not null default 'not_started',
  add column if not exists refund_status text not null default 'not_started';

update private.stripe_payment_resolutions
set transfer_status = case
      when transfer_amount_cents = 0 then 'not_required'
      when status = 'completed' and provider_transfer_id is not null then 'succeeded'
      when status = 'failed' and provider_transfer_id is null then 'failed'
      when status in ('financial_execution_started', 'provider_processing') then 'unknown'
      when provider_transfer_id is not null then 'unknown'
      else 'not_started'
    end,
    refund_status = case
      when refund_amount_cents = 0 then 'not_required'
      when status = 'completed' and provider_refund_id is not null then 'succeeded'
      when status = 'failed' and provider_refund_id is null then 'failed'
      when status in ('financial_execution_started', 'provider_processing') then 'unknown'
      when provider_refund_id is not null then 'unknown'
      else 'not_started'
    end;

alter table private.stripe_payment_resolutions
  drop constraint if exists stripe_resolution_transfer_status_check,
  drop constraint if exists stripe_resolution_refund_status_check,
  add constraint stripe_resolution_transfer_status_check
    check (transfer_status in ('not_required', 'not_started', 'pending', 'succeeded', 'failed', 'unknown')),
  add constraint stripe_resolution_refund_status_check
    check (refund_status in ('not_required', 'not_started', 'pending', 'succeeded', 'failed', 'unknown'));

create or replace function private.set_resolution_operation_initial_states()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.transfer_amount_cents = 0 then
    new.transfer_status := 'not_required';
  end if;
  if new.refund_amount_cents = 0 then
    new.refund_status := 'not_required';
  end if;
  return new;
end;
$$;
revoke all on function private.set_resolution_operation_initial_states() from public, anon, authenticated;
drop trigger if exists stripe_resolution_operation_initial_states on private.stripe_payment_resolutions;
create trigger stripe_resolution_operation_initial_states
before insert on private.stripe_payment_resolutions
for each row execute function private.set_resolution_operation_initial_states();

create or replace function public.stripe_server_record_resolution_operation_result(
  p_resolution_id uuid,
  p_environment text,
  p_operation text,
  p_operation_status text,
  p_provider_object_id text,
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
  v_transfer private.stripe_job_transfers%rowtype;
  v_refund private.stripe_job_refunds%rowtype;
  v_current_status text;
  v_amount integer;
  v_idempotency_key text;
  v_next_transfer_status text;
  v_next_refund_status text;
begin
  perform private.require_stripe_service_role();
  if p_operation not in ('transfer', 'refund') then raise exception 'resolution_operation_invalid'; end if;
  if p_operation_status not in ('pending', 'succeeded', 'failed', 'unknown') then raise exception 'resolution_operation_status_invalid'; end if;

  select * into v_resolution
  from private.stripe_payment_resolutions
  where id = p_resolution_id and environment = p_environment
  for update;
  if v_resolution.id is null then raise exception 'payment_resolution_not_found'; end if;
  if v_resolution.status not in ('financial_execution_started', 'provider_processing', 'failed') then
    raise exception 'resolution_execution_not_claimed';
  end if;

  select * into v_payment
  from private.stripe_job_payment_intents
  where id = v_resolution.payment_intent_id
  for update;
  if v_payment.id is null then raise exception 'resolution_payment_not_found'; end if;

  if p_operation = 'transfer' then
    v_amount := v_resolution.transfer_amount_cents;
    v_idempotency_key := v_resolution.transfer_idempotency_key;
    v_current_status := v_resolution.transfer_status;
    if v_amount <= 0 then raise exception 'resolution_transfer_not_required'; end if;
    if p_provider_object_id is not null and p_provider_object_id !~ '^tr_[A-Za-z0-9]+$' then
      raise exception 'provider_transfer_reference_invalid';
    end if;
  else
    v_amount := v_resolution.refund_amount_cents;
    v_idempotency_key := v_resolution.refund_idempotency_key;
    v_current_status := v_resolution.refund_status;
    if v_amount <= 0 then raise exception 'resolution_refund_not_required'; end if;
    if p_provider_object_id is not null and p_provider_object_id !~ '^re_[A-Za-z0-9]+$' then
      raise exception 'provider_refund_reference_invalid';
    end if;
  end if;
  if p_operation_status = 'succeeded' and p_provider_object_id is null then
    raise exception 'provider_object_reference_required';
  end if;

  if v_current_status = 'succeeded' then
    if p_operation_status <> 'succeeded' or p_provider_object_id is distinct from (
      case when p_operation = 'transfer' then v_resolution.provider_transfer_id else v_resolution.provider_refund_id end) then
      raise exception 'resolution_operation_result_conflict';
    end if;
    return jsonb_build_object(
      'ok', true, 'replayed', true, 'operation', p_operation,
      'operation_status', 'succeeded', 'resolution_status', v_resolution.status
    );
  end if;

  if p_operation = 'transfer' then
    if p_operation_status in ('pending', 'succeeded', 'failed') and p_provider_object_id is not null then
      select * into v_account
      from private.stripe_connected_accounts
      where user_id = v_payment.teen_id and environment = p_environment;
      if v_account.id is null then raise exception 'connected_account_not_found'; end if;
      if v_payment.provider_charge_id is null then raise exception 'provider_source_charge_required'; end if;
      insert into private.stripe_job_transfers(
        payment_intent_id, connected_account_id, environment, amount_cents, currency_code,
        provider_transfer_id, provider_source_charge_id, idempotency_key, eligibility_path,
        status, failure_code, transferred_at
      ) values (
        v_payment.id, v_account.id, p_environment, v_amount, v_resolution.currency_code,
        p_provider_object_id, v_payment.provider_charge_id, v_idempotency_key,
        v_resolution.eligibility_path,
        case p_operation_status when 'succeeded' then 'paid' when 'failed' then 'failed' else 'created' end,
        left(p_safe_failure_code, 120),
        case when p_operation_status = 'succeeded' then now() else null end
      )
      on conflict (payment_intent_id) do update set
        provider_transfer_id = coalesce(private.stripe_job_transfers.provider_transfer_id, excluded.provider_transfer_id),
        status = case when private.stripe_job_transfers.status = 'paid' then 'paid' else excluded.status end,
        failure_code = excluded.failure_code,
        transferred_at = coalesce(private.stripe_job_transfers.transferred_at, excluded.transferred_at),
        updated_at = now()
      where private.stripe_job_transfers.environment = excluded.environment
        and private.stripe_job_transfers.idempotency_key = excluded.idempotency_key
        and (private.stripe_job_transfers.provider_transfer_id is null
          or private.stripe_job_transfers.provider_transfer_id = excluded.provider_transfer_id)
      returning * into v_transfer;
      if v_transfer.id is null then raise exception 'provider_transfer_reference_conflict'; end if;
    end if;

    update private.stripe_payment_resolutions set
      transfer_status = p_operation_status,
      provider_transfer_id = coalesce(p_provider_object_id, provider_transfer_id),
      safe_failure_code = case when p_operation_status = 'succeeded' then null else left(p_safe_failure_code, 120) end,
      status = case
        when p_operation_status in ('pending', 'failed', 'unknown') then 'provider_processing'
        else status
      end,
      updated_at = now()
    where id = v_resolution.id;
  else
    if p_operation_status in ('pending', 'succeeded', 'failed') and p_provider_object_id is not null then
      insert into private.stripe_job_refunds(
        payment_intent_id, requested_by, environment, amount_cents,
        provider_refund_id, idempotency_key, reason_code, status, failure_code
      ) values (
        v_payment.id, v_resolution.financial_operator_id, p_environment, v_amount,
        p_provider_object_id, v_idempotency_key, 'resolution_provider_execution',
        case p_operation_status when 'succeeded' then 'succeeded' when 'failed' then 'failed' else 'pending' end,
        left(p_safe_failure_code, 120)
      )
      on conflict (environment, idempotency_key) do update set
        provider_refund_id = coalesce(private.stripe_job_refunds.provider_refund_id, excluded.provider_refund_id),
        status = case when private.stripe_job_refunds.status = 'succeeded' then 'succeeded' else excluded.status end,
        failure_code = excluded.failure_code,
        updated_at = now()
      where private.stripe_job_refunds.payment_intent_id = excluded.payment_intent_id
        and (private.stripe_job_refunds.provider_refund_id is null
          or private.stripe_job_refunds.provider_refund_id = excluded.provider_refund_id)
      returning * into v_refund;
      if v_refund.id is null then raise exception 'provider_refund_reference_conflict'; end if;
    end if;

    update private.stripe_payment_resolutions set
      refund_status = p_operation_status,
      provider_refund_id = coalesce(p_provider_object_id, provider_refund_id),
      safe_failure_code = case when p_operation_status = 'succeeded' then null else left(p_safe_failure_code, 120) end,
      status = case
        when p_operation_status in ('pending', 'failed', 'unknown') then 'provider_processing'
        else status
      end,
      updated_at = now()
    where id = v_resolution.id;
  end if;

  select transfer_status, refund_status into v_next_transfer_status, v_next_refund_status
  from private.stripe_payment_resolutions where id = v_resolution.id;
  return jsonb_build_object(
    'ok', true, 'replayed', false, 'operation', p_operation,
    'operation_status', p_operation_status,
    'transfer_status', v_next_transfer_status,
    'refund_status', v_next_refund_status,
    'resolution_status', (select status from private.stripe_payment_resolutions where id = v_resolution.id)
  );
end;
$$;

revoke all on function public.stripe_server_record_resolution_operation_result(uuid,text,text,text,text,text)
  from public, anon, authenticated;
grant execute on function public.stripe_server_record_resolution_operation_result(uuid,text,text,text,text,text)
  to service_role;

-- Reclaimable webhook leases use both a monotonic epoch and a fresh opaque
-- token. The token is never logged; the epoch is the fencing generation.
alter table private.stripe_webhook_events
  add column if not exists lease_epoch bigint not null default 0,
  add column if not exists lease_token uuid,
  add column if not exists lease_expires_at timestamptz,
  add column if not exists attempt_count integer not null default 0;

alter table private.stripe_webhook_events
  drop constraint if exists stripe_webhook_events_processing_status_check,
  add constraint stripe_webhook_events_processing_status_check
    check (processing_status in ('received', 'processing', 'processed', 'ignored', 'failed'));

create or replace function public.stripe_server_claim_webhook_event(
  p_environment text,
  p_provider_event_id text,
  p_event_type text,
  p_provider_created_at timestamptz,
  p_payload_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event private.stripe_webhook_events%rowtype;
  v_control private.stripe_runtime_controls%rowtype;
  v_inserted boolean := false;
  v_token uuid;
begin
  perform private.require_stripe_service_role();
  select * into v_control from private.stripe_runtime_controls where singleton;
  if p_environment <> private.stripe_environment_for_mode(v_control.mode) then
    raise exception 'stripe_environment_mismatch';
  end if;

  insert into private.stripe_webhook_events(
    environment, provider_event_id, event_type, provider_created_at,
    payload_sha256, signature_verified
  ) values (
    p_environment, p_provider_event_id, p_event_type, p_provider_created_at,
    p_payload_sha256, true
  ) on conflict (environment, provider_event_id) do nothing
  returning * into v_event;
  v_inserted := v_event.id is not null;

  if not v_inserted then
    begin
      select * into v_event
      from private.stripe_webhook_events
      where environment = p_environment and provider_event_id = p_provider_event_id
      for update nowait;
    exception when lock_not_available then
      return jsonb_build_object(
        'ok', true, 'claimed', false, 'in_flight', true,
        'locked', true, 'code', 'stripe_webhook_lease_lost'
      );
    end;
  end if;
  if v_event.id is null then raise exception 'stripe_webhook_event_not_found'; end if;
  if v_event.payload_sha256 <> p_payload_sha256 then raise exception 'stripe_webhook_replay_payload_mismatch'; end if;

  if v_event.processing_status in ('processed', 'ignored') then
    return jsonb_build_object(
      'ok', true, 'claimed', false, 'duplicate', true,
      'event_record_id', v_event.id, 'processing_status', v_event.processing_status,
      'lease_epoch', v_event.lease_epoch
    );
  end if;
  if v_event.processing_status = 'processing' and v_event.lease_expires_at > clock_timestamp() then
    return jsonb_build_object(
      'ok', true, 'claimed', false, 'in_flight', true,
      'event_record_id', v_event.id, 'processing_status', v_event.processing_status,
      'lease_epoch', v_event.lease_epoch
    );
  end if;

  v_token := gen_random_uuid();
  update private.stripe_webhook_events set
    processing_status = 'processing',
    safe_failure_code = null,
    processed_at = null,
    lease_epoch = lease_epoch + 1,
    lease_token = v_token,
    lease_expires_at = clock_timestamp() + interval '90 seconds',
    attempt_count = attempt_count + 1
  where id = v_event.id
  returning * into v_event;

  return jsonb_build_object(
    'ok', true, 'claimed', true, 'event_record_id', v_event.id,
    'processing_status', v_event.processing_status,
    'lease_token', v_event.lease_token,
    'lease_epoch', v_event.lease_epoch,
    'lease_expires_at', v_event.lease_expires_at
  );
end;
$$;

create or replace function public.stripe_server_apply_webhook_event(
  p_environment text,
  p_provider_event_id text,
  p_lease_token uuid,
  p_event_type text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event private.stripe_webhook_events%rowtype;
  v_result jsonb := '{}'::jsonb;
  v_terminal_status text := 'processed';
  v_refund jsonb;
begin
  perform private.require_stripe_service_role();
  select * into v_event
  from private.stripe_webhook_events
  where environment = p_environment and provider_event_id = p_provider_event_id
  for update;
  if v_event.id is null
     or v_event.processing_status <> 'processing'
     or v_event.lease_token is distinct from p_lease_token
     or v_event.lease_expires_at is null
     or v_event.lease_expires_at <= clock_timestamp() then
    raise exception 'stripe_webhook_lease_lost' using errcode = '40001';
  end if;
  if jsonb_typeof(p_payload) <> 'object' then raise exception 'stripe_webhook_payload_invalid'; end if;

  if p_event_type in ('payment_intent.succeeded', 'payment_intent.processing', 'payment_intent.payment_failed', 'payment_intent.canceled') then
    v_result := public.stripe_server_apply_payment_event(
      p_environment, p_provider_event_id, p_event_type,
      p_payload->>'provider_payment_intent_id', p_payload->>'provider_charge_id',
      nullif(p_payload->>'amount_cents', '')::integer,
      p_payload->>'currency_code', p_payload->>'safe_failure_code'
    );
  elsif p_event_type = 'account.updated' then
    v_result := public.stripe_server_record_connected_account_status(
      p_payload->>'provider_account_id', p_environment, p_payload->>'onboarding_status',
      (p_payload->>'details_submitted')::boolean, (p_payload->>'charges_enabled')::boolean,
      (p_payload->>'payouts_enabled')::boolean, p_payload->>'transfers_capability_status',
      p_payload->>'requirements_status', p_payload->>'guardian_requirement_status',
      p_payload->>'disabled_reason_code', p_payload->>'country', p_payload->>'default_currency'
    );
  elsif p_event_type in ('charge.dispute.created', 'charge.dispute.updated', 'charge.dispute.closed') then
    v_result := public.stripe_server_apply_dispute_event(
      p_environment, p_provider_event_id, p_payload->>'provider_payment_intent_id',
      p_payload->>'provider_dispute_id', nullif(p_payload->>'amount_cents', '')::integer,
      p_payload->>'currency_code', p_payload->>'status', p_payload->>'reason_code',
      nullif(p_payload->>'evidence_due_at', '')::timestamptz
    );
  elsif p_event_type in ('transfer.created', 'transfer.updated', 'transfer.reversed') then
    v_result := public.stripe_server_apply_transfer_event(
      p_environment, p_provider_event_id, p_payload->>'provider_transfer_id',
      p_payload->>'status', p_payload->>'failure_code'
    );
  elsif p_event_type in ('payout.created', 'payout.updated', 'payout.paid', 'payout.failed', 'payout.canceled') then
    v_result := public.stripe_server_apply_payout_event(
      p_environment, p_provider_event_id, p_payload->>'provider_account_id',
      p_payload->>'provider_payout_id', nullif(p_payload->>'amount_cents', '')::integer,
      p_payload->>'currency_code', p_payload->>'status', p_payload->>'destination_type',
      p_payload->>'destination_last4', nullif(p_payload->>'arrival_at', '')::timestamptz,
      p_payload->>'failure_code'
    );
  elsif p_event_type in ('refund.created', 'refund.updated', 'refund.failed') then
    v_result := public.stripe_server_apply_refund_event(
      p_environment, p_provider_event_id, p_payload->>'provider_payment_intent_id',
      p_payload->>'provider_refund_id', nullif(p_payload->>'amount_cents', '')::integer,
      p_payload->>'currency_code', p_payload->>'status', p_payload->>'failure_code'
    );
  elsif p_event_type = 'charge.refunded' then
    if jsonb_typeof(p_payload->'refunds') <> 'array' or jsonb_array_length(p_payload->'refunds') = 0 then
      v_terminal_status := 'ignored';
      v_result := jsonb_build_object('ok', true, 'code', 'charge_refund_list_unavailable');
    else
      for v_refund in select value from jsonb_array_elements(p_payload->'refunds') as item(value) loop
        v_result := public.stripe_server_apply_refund_event(
          p_environment, p_provider_event_id, v_refund->>'provider_payment_intent_id',
          v_refund->>'provider_refund_id', nullif(v_refund->>'amount_cents', '')::integer,
          v_refund->>'currency_code', v_refund->>'status', v_refund->>'failure_code'
        );
      end loop;
    end if;
  else
    v_terminal_status := 'ignored';
    v_result := jsonb_build_object('ok', true, 'code', 'event_not_used_by_mort');
  end if;

  update private.stripe_webhook_events set
    processing_status = v_terminal_status,
    safe_failure_code = null,
    processed_at = now(),
    lease_token = null,
    lease_expires_at = null
  where id = v_event.id and lease_token = p_lease_token;
  if not found then raise exception 'stripe_webhook_lease_lost' using errcode = '40001'; end if;
  return jsonb_build_object(
    'ok', true, 'event_record_id', v_event.id,
    'processing_status', v_terminal_status, 'lease_epoch', v_event.lease_epoch,
    'result', v_result
  );
end;
$$;

create or replace function public.stripe_server_fail_webhook_event_fenced(
  p_environment text,
  p_provider_event_id text,
  p_lease_token uuid,
  p_safe_failure_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_event private.stripe_webhook_events%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into v_event
  from private.stripe_webhook_events
  where environment = p_environment and provider_event_id = p_provider_event_id
  for update;
  if v_event.id is null
     or v_event.processing_status <> 'processing'
     or v_event.lease_token is distinct from p_lease_token
     or v_event.lease_expires_at is null
     or v_event.lease_expires_at <= clock_timestamp() then
    raise exception 'stripe_webhook_lease_lost' using errcode = '40001';
  end if;
  update private.stripe_webhook_events set
    processing_status = 'failed',
    safe_failure_code = left(p_safe_failure_code, 120),
    processed_at = now(), lease_token = null, lease_expires_at = null
  where id = v_event.id and lease_token = p_lease_token;
  if not found then raise exception 'stripe_webhook_lease_lost' using errcode = '40001'; end if;
  return jsonb_build_object('ok', true, 'processing_status', 'failed', 'lease_epoch', v_event.lease_epoch);
end;
$$;

revoke all on function public.stripe_server_apply_webhook_event(text,text,uuid,text,jsonb)
  from public, anon, authenticated;
grant execute on function public.stripe_server_apply_webhook_event(text,text,uuid,text,jsonb)
  to service_role;
revoke all on function public.stripe_server_fail_webhook_event_fenced(text,text,uuid,text)
  from public, anon, authenticated;
grant execute on function public.stripe_server_fail_webhook_event_fenced(text,text,uuid,text)
  to service_role;

-- The webhook edge function must use the fenced dispatcher. Other service
-- operations are unaffected; SECURITY DEFINER callers retain owner execution.
revoke all on function public.stripe_server_apply_payment_event(text,text,text,text,text,integer,text,text)
  from public, anon, authenticated, service_role;
revoke all on function public.stripe_server_apply_dispute_event(text,text,text,text,integer,text,text,text,timestamptz)
  from public, anon, authenticated, service_role;
revoke all on function public.stripe_server_apply_transfer_event(text,text,text,text,text)
  from public, anon, authenticated, service_role;
revoke all on function public.stripe_server_apply_payout_event(text,text,text,text,integer,text,text,text,text,timestamptz,text)
  from public, anon, authenticated, service_role;
revoke all on function public.stripe_server_apply_refund_event(text,text,text,text,integer,text,text,text)
  from public, anon, authenticated, service_role;
revoke all on function public.stripe_server_complete_webhook_event(text,text,text,text)
  from public, anon, authenticated, service_role;
revoke all on function public.stripe_server_fail_webhook_event(text,text,text)
  from public, anon, authenticated, service_role;

-- Remove direct client writes. Security-definer self-service functions remain
-- the only supported caller-bound profile write paths.
revoke insert, update, delete, truncate, references, trigger
  on table public.profiles from public, anon, authenticated;
revoke all on function public.save_my_onboarding_profile(text,text,date,text,text,text,boolean,text,uuid)
  from public, anon;
revoke all on function public.update_my_profile(jsonb,timestamptz,uuid)
  from public, anon;
revoke all on function public.complete_my_onboarding()
  from public, anon;
grant execute on function public.save_my_onboarding_profile(text,text,date,text,text,text,boolean,text,uuid)
  to authenticated, service_role;
grant execute on function public.update_my_profile(jsonb,timestamptz,uuid)
  to authenticated, service_role;
grant execute on function public.complete_my_onboarding()
  to authenticated, service_role;

-- Let financial operators resume partially completed resolutions. A completed
-- provider operation is returned to the Edge Function so retries can skip it;
-- unfinished operations continue with their persisted Stripe idempotency key.
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
  if not private.has_stripe_financial_role(p_actor_id, array['payment_operations']) then
    raise exception 'payment_operations_role_required';
  end if;
  select * into v_control
  from private.stripe_runtime_controls
  where singleton
  for share;
  if p_environment <> private.stripe_environment_for_mode(v_control.mode)
     or p_environment <> 'test' then
    raise exception 'stripe_live_disabled';
  end if;
  if not v_control.stripe_transfers_enabled or not v_control.payouts_approved then
    raise exception 'stripe_transfers_disabled';
  end if;
  select * into v_resolution
  from private.stripe_payment_resolutions
  where id = p_resolution_id and environment = p_environment
  for update;
  if v_resolution.id is null then
    raise exception 'payment_resolution_not_found';
  end if;
  if v_resolution.reviewer_id = p_actor_id then
    raise exception 'reviewer_financial_operator_separation_required';
  end if;
  if v_resolution.status = 'completed' then
    return jsonb_build_object(
      'ok', true,
      'replayed', true,
      'resolution_id', v_resolution.id,
      'status', v_resolution.status
    );
  end if;
  if v_resolution.status not in (
    'reviewed_pending_financial_execution',
    'financial_execution_started',
    'provider_processing'
  ) then
    raise exception 'payment_resolution_not_executable';
  end if;
  if v_resolution.execution_request_id is not null
     and v_resolution.execution_request_id <> p_request_id
     and v_resolution.status <> 'provider_processing' then
    raise exception 'resolution_execution_already_claimed';
  end if;
  if v_resolution.refund_amount_cents > 0 and not v_control.stripe_refunds_enabled then
    raise exception 'stripe_refunds_disabled';
  end if;
  if v_resolution.dispute_id is not null and exists (
    select 1
    from public.payment_disputes dispute
    where dispute.id = v_resolution.dispute_id
      and dispute.status not in (
        'resolved_payment_recommended',
        'resolved_partial_payment_recommended'
      )
  ) then
    raise exception 'resolution_changed_or_reopened';
  end if;
  select * into v_payment
  from private.stripe_job_payment_intents
  where id = v_resolution.payment_intent_id
  for update;
  if v_payment.status not in ('funded', 'disputed', 'transfer_pending') then
    raise exception 'payment_state_blocks_resolution';
  end if;
  select * into v_account
  from private.stripe_connected_accounts
  where user_id = v_payment.teen_id
    and environment = p_environment
    and onboarding_status = 'complete'
    and payouts_enabled
    and transfers_capability_status = 'active';
  if v_account.id is null then
    raise exception 'eligible_connected_account_required';
  end if;
  update private.stripe_payment_resolutions
  set status = 'financial_execution_started',
      financial_operator_id = p_actor_id,
      execution_request_id = p_request_id,
      updated_at = now()
  where id = v_resolution.id
  returning * into v_resolution;
  insert into private.stripe_financial_audit_events(
    actor_id,
    environment,
    event_type,
    subject_type,
    subject_id,
    safe_reason_code,
    field_names
  ) values (
    p_actor_id,
    p_environment,
    'resolution_execution_claimed',
    'stripe_payment_resolution',
    v_resolution.id,
    'server_resolution_loaded',
    array['financial_operator_id', 'execution_request_id']
  );
  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'resolution_id', v_resolution.id,
    'transfer_amount_cents', v_resolution.transfer_amount_cents,
    'refund_amount_cents', v_resolution.refund_amount_cents,
    'currency_code', v_resolution.currency_code,
    'provider_connected_account_id', v_account.provider_account_id,
    'provider_source_charge_id', v_payment.provider_charge_id,
    'provider_payment_intent_id', v_payment.provider_payment_intent_id,
    'transfer_idempotency_key', v_resolution.transfer_idempotency_key,
    'refund_idempotency_key', v_resolution.refund_idempotency_key,
    'transfer_status', v_resolution.transfer_status,
    'refund_status', v_resolution.refund_status,
    'provider_transfer_id', v_resolution.provider_transfer_id,
    'provider_refund_id', v_resolution.provider_refund_id
  );
end;
$$;

revoke all on function public.stripe_server_load_resolution_for_execution(uuid,uuid,text,uuid)
  from public, anon, authenticated;
grant execute on function public.stripe_server_load_resolution_for_execution(uuid,uuid,text,uuid)
  to service_role;
