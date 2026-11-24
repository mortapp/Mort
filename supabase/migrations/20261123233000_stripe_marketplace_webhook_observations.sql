-- Requires the marketplace payment baseline. Do not run over the legacy assignment-only production schema.
alter table private.stripe_webhook_events add column observation_resource_key text;
create index stripe_webhook_resource_lease_idx on private.stripe_webhook_events
  (environment, observation_resource_key, processing_lease_until)
  where processing_status = 'received' and observation_resource_key is not null;

alter table private.stripe_job_transfers add column amount_reversed_cents integer
  check (amount_reversed_cents between 0 and amount_cents);

create table private.stripe_webhook_observations (
  environment text not null check (environment in ('test', 'live')),
  resource_key text not null,
  state_sha256 text not null check (state_sha256 ~ '^[a-f0-9]{64}$'),
  last_applied_at timestamptz not null default statement_timestamp(),
  primary key (environment, resource_key)
);
alter table private.stripe_webhook_observations enable row level security;
revoke all on private.stripe_webhook_observations from public, anon, authenticated;

-- Called under the payment row lock. An unresolved dispute or a lost dispute takes
-- precedence over refund progress; a resolved dispute must not erase prior settlement.
create function private.stripe_webhook_set_payment_summary_v1(p_payment_id uuid, p_previous_status text)
returns void
language plpgsql set search_path = ''
as $$
begin
  update private.stripe_job_payment_intents p set status = case
    when p_previous_status = 'closed' then 'closed'
    when p_previous_status = 'chargeback' or exists (
      select 1 from private.stripe_job_disputes d where d.payment_intent_id = p.id and d.status = 'lost'
    ) then 'chargeback'
    when exists (select 1 from private.stripe_job_disputes d where d.payment_intent_id = p.id
      and d.status not in ('won','lost','closed')) then 'disputed'
    when (select coalesce(sum(r.amount_cents), 0) from private.stripe_job_refunds r
      where r.payment_intent_id = p.id and r.status = 'succeeded') >= p.total_amount_cents then 'refunded'
    when exists (select 1 from private.stripe_job_refunds r
      where r.payment_intent_id = p.id and r.status = 'succeeded') then 'partially_refunded'
    when exists (select 1 from private.stripe_job_refunds r
      where r.payment_intent_id = p.id and r.status = 'pending') then 'refund_pending'
    when exists (select 1 from private.stripe_job_transfers t
      where t.payment_intent_id = p.id and t.status in ('paid', 'partially_reversed', 'reversed')) then 'transferred'
    when exists (select 1 from private.stripe_job_transfers t
      where t.payment_intent_id = p.id and t.status in ('pending', 'created')) then 'transfer_pending'
    when exists (select 1 from private.stripe_job_transfers t
      where t.payment_intent_id = p.id and t.status = 'failed') then 'transfer_failed'
    when p.normalized_state = 'SUCCEEDED' then 'funded'
    else p_previous_status
  end where p.id = p_payment_id;
end;
$$;
revoke all on function private.stripe_webhook_set_payment_summary_v1(uuid, text) from public, anon, authenticated;

create function public.stripe_server_claim_webhook_event_v3(
  p_environment text, p_provider_event_id text, p_event_type text,
  p_provider_created_at timestamptz, p_payload_sha256 text, p_resource_key text
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_claim jsonb;
begin
  perform private.require_stripe_service_role();
  if p_environment is null or p_environment not in ('test', 'live') or p_resource_key is null
     or length(p_resource_key) > 220
     or p_resource_key !~ '^(payment|account|transfer|dispute|refund|charge|payout):(platform|acct_[A-Za-z0-9]+):[a-z]+_[A-Za-z0-9]+$'
  then raise exception 'invalid_webhook_resource'; end if;
  if p_environment is distinct from (
    select private.stripe_environment_for_mode(mode)
    from private.stripe_runtime_controls where singleton
  ) then raise exception 'stripe_environment_mismatch'; end if;

  -- Serialize admission for the resource, but do not hold a DB transaction open during Stripe reads.
  perform pg_advisory_xact_lock(hashtextextended('stripe_webhook:' || p_environment || ':' || p_resource_key, 0));
  if exists (
    select 1 from private.stripe_webhook_events
    where environment = p_environment and observation_resource_key = p_resource_key
      and processing_status = 'received' and processing_lease_until > clock_timestamp()
      and provider_event_id <> p_provider_event_id
  ) then
    return jsonb_build_object('ok', true, 'claimed', false, 'processing_status', 'busy');
  end if;

  v_claim := public.stripe_server_claim_webhook_event_v2(
    p_environment, p_provider_event_id, p_event_type, p_provider_created_at, p_payload_sha256, 120
  );
  if (v_claim->>'claimed')::boolean then
    update private.stripe_webhook_events set observation_resource_key = p_resource_key
    where environment = p_environment and provider_event_id = p_provider_event_id
      and (observation_resource_key is null or observation_resource_key = p_resource_key);
    if not found then raise exception 'stripe_webhook_resource_mismatch'; end if;
  end if;
  return v_claim;
end;
$$;

create function public.stripe_server_finish_webhook_observation_v3(
  p_environment text, p_provider_event_id text, p_lease_token uuid, p_observation jsonb
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_event private.stripe_webhook_events%rowtype;
  v_payment private.stripe_job_payment_intents%rowtype;
  v_transfer private.stripe_job_transfers%rowtype;
  v_result jsonb;
  v_status text := 'processed';
  v_code text := 'stripe_provider_state_synchronized';
  v_kind text := p_observation->>'kind';
  v_id text := p_observation->>'id';
  v_account text := p_observation->>'account';
  v_state text := p_observation->>'state';
  v_amount integer := (p_observation->>'amount')::integer;
  v_currency text := p_observation->>'currency';
  v_failure text := p_observation->>'failure';
  v_reversed integer := (p_observation->>'reversed')::integer;
  v_hash text;
  v_recipient text;
begin
  perform private.require_stripe_service_role();
  select * into v_event from private.stripe_webhook_events
  where environment = p_environment and provider_event_id = p_provider_event_id for update;
  if v_event.id is null or v_event.observation_resource_key is null or p_lease_token is null
     or v_event.processing_status is distinct from 'received'
     or v_event.processing_lease_token is distinct from p_lease_token
     or v_event.processing_lease_until is null or v_event.processing_lease_until <= clock_timestamp()
  then raise exception 'stripe_webhook_claim_no_longer_active'; end if;

  if p_observation is null then
    v_status := 'failed';
    v_code := 'webhook_processing_retry_required';
  elsif v_kind in ('ignored', 'recorded') then
    v_status := case when v_kind = 'ignored' then 'ignored' else 'processed' end;
    v_code := p_observation->>'code';
    if v_code is null or v_code !~ '^[a-z_]{8,90}$' then raise exception 'invalid_webhook_outcome'; end if;
  else
    if v_kind is null or v_id is null or v_state is null or
       v_event.observation_resource_key <> v_kind || ':' ||
        (case when v_kind = 'account' then v_id else coalesce(v_account, 'platform') end) || ':' || v_id
    then raise exception 'stripe_webhook_observation_identity_mismatch'; end if;
    v_hash := encode(sha256(convert_to(p_observation::text, 'UTF8')), 'hex');
    if exists (
      select 1 from private.stripe_webhook_observations
      where environment = p_environment and resource_key = v_event.observation_resource_key and state_sha256 = v_hash
    ) then
      v_code := 'stripe_provider_state_already_applied';
    else
      case v_kind
      when 'payment' then
        if p_observation->>'tip' is not null then
          v_result := public.stripe_server_apply_tip_event_v1(
            (p_observation->>'tip')::uuid, v_id, v_state, v_amount, v_currency
          );
        else
          select * into v_payment from private.stripe_job_payment_intents
          where environment = p_environment and provider_payment_intent_id = v_id for update;
          if not found then raise exception 'stripe_payment_intent_not_found'; end if;
          if v_amount is distinct from v_payment.total_amount_cents or v_currency is distinct from v_payment.currency_code
          then raise exception 'stripe_payment_amount_or_currency_mismatch'; end if;
          -- A replayed success must not reset a refunded, disputed, or settled payment to funded.
          if v_payment.normalized_state = 'SUCCEEDED' then
            v_result := jsonb_build_object('ok', true);
            v_code := 'stripe_payment_already_funded_preserved';
          else
            v_result := public.stripe_server_apply_payment_event_v2(
              p_environment, p_provider_event_id, v_state, v_id, p_observation->>'charge', v_amount, v_currency, v_failure
            );
          end if;
        end if;
      when 'account' then
        v_result := public.stripe_server_record_connected_account_status(
          v_id, p_environment, v_state, (p_observation->>'submitted')::boolean,
          (p_observation->>'charges')::boolean, (p_observation->>'payouts')::boolean,
          p_observation->>'transfers', p_observation->>'requirements', p_observation->>'guardian',
          p_observation->>'disabled', p_observation->>'country', p_observation->>'currency'
        );
      when 'dispute' then
        select * into v_payment from private.stripe_job_payment_intents
        where environment = p_environment and provider_payment_intent_id = p_observation->>'payment' for update;
        if not found then raise exception 'stripe_payment_intent_not_found'; end if;
        if exists (
          select 1 from private.stripe_job_disputes d
          where d.environment = p_environment and d.provider_dispute_id = v_id
            and (d.payment_intent_id is distinct from v_payment.id or d.amount_cents is distinct from v_amount
              or d.currency_code is distinct from v_currency)
        ) then raise exception 'stripe_dispute_value_or_payment_mismatch'; end if;
        v_result := public.stripe_server_apply_dispute_event(
          p_environment, p_provider_event_id, p_observation->>'payment', v_id,
          v_amount, v_currency, v_state, p_observation->>'reason', (p_observation->>'evidenceDue')::timestamptz
        );
        perform private.stripe_webhook_set_payment_summary_v1(v_payment.id, v_payment.status);
      when 'transfer' then
        select * into v_transfer from private.stripe_job_transfers
        where environment = p_environment and provider_transfer_id = v_id for update;
        if not found then raise exception 'stripe_transfer_not_found'; end if;
        select provider_account_id into v_recipient from private.stripe_connected_accounts
        where environment = p_environment and id = v_transfer.connected_account_id;
        if v_recipient is null or v_recipient is distinct from (p_observation->>'destination')
           or v_amount is distinct from v_transfer.amount_cents or v_currency is distinct from v_transfer.currency_code
           or v_reversed is null or v_reversed not between coalesce(v_transfer.amount_reversed_cents, 0) and v_transfer.amount_cents
           or v_state is distinct from (case when v_reversed = v_amount then 'reversed'
               when v_reversed > 0 then 'partially_reversed' else 'paid' end)
        then raise exception 'stripe_transfer_value_or_recipient_mismatch'; end if;
        -- Never reopen an obligation or erase a dispute merely because a transfer was reversed.
        update private.stripe_job_transfers set status = v_state, amount_reversed_cents = v_reversed,
          transferred_at = coalesce(transferred_at, statement_timestamp()),
          reversed_at = case when v_reversed > 0 then coalesce(reversed_at, statement_timestamp()) else reversed_at end,
          updated_at = statement_timestamp()
        where id = v_transfer.id;
        v_result := jsonb_build_object('ok', true);
      when 'payout' then
        if exists (
          select 1 from private.stripe_payout_events p join private.stripe_connected_accounts a on a.id = p.connected_account_id
          where p.environment = p_environment and p.provider_payout_id = v_id
            and (a.provider_account_id is distinct from v_account or p.amount_cents is distinct from v_amount
              or p.currency_code is distinct from v_currency)
        ) then raise exception 'stripe_payout_value_or_recipient_mismatch'; end if;
        v_result := public.stripe_server_apply_payout_event(
          p_environment, p_provider_event_id, v_account, v_id, v_amount, v_currency, v_state,
          'unknown', null, (p_observation->>'arrival')::timestamptz, v_failure
        );
      when 'refund' then
        select * into v_payment from private.stripe_job_payment_intents
        where environment = p_environment and provider_payment_intent_id = p_observation->>'payment' for update;
        if not found then raise exception 'stripe_payment_intent_not_found'; end if;
        v_result := public.stripe_server_apply_refund_event(
          p_environment, p_provider_event_id, p_observation->>'payment', v_id,
          v_amount, v_currency, v_state, v_failure
        );
        perform private.stripe_webhook_set_payment_summary_v1(v_payment.id, v_payment.status);
      else
        raise exception 'stripe_webhook_observation_unsupported';
      end case;
      if v_result->>'ok' is distinct from 'true' then raise exception 'stripe_webhook_apply_not_acknowledged'; end if;
      insert into private.stripe_webhook_observations(environment, resource_key, state_sha256)
      values (p_environment, v_event.observation_resource_key, v_hash)
      on conflict (environment, resource_key) do update set
        state_sha256 = excluded.state_sha256, last_applied_at = statement_timestamp();
    end if;
  end if;

  update private.stripe_webhook_events set processing_status = v_status, safe_failure_code = v_code,
    processed_at = statement_timestamp(), processing_lease_token = null, processing_lease_until = null
  where id = v_event.id;
  return jsonb_build_object('ok', true, 'processing_status', v_status, 'code', v_code);
end;
$$;

revoke all on function public.stripe_server_claim_webhook_event_v3(text, text, text, timestamptz, text, text)
  from public, anon, authenticated;
revoke all on function public.stripe_server_finish_webhook_observation_v3(text, text, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.stripe_server_claim_webhook_event_v3(text, text, text, timestamptz, text, text) to service_role;
grant execute on function public.stripe_server_finish_webhook_observation_v3(text, text, uuid, jsonb) to service_role;

-- Small, read-only signal for operations. Includes only counts, never event payloads or customer identifiers.
create function public.stripe_server_webhook_reconciliation_status_v1(p_environment text)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  perform private.require_stripe_service_role();
  if p_environment is null or p_environment not in ('test', 'live') then
    raise exception 'stripe_environment_mismatch';
  end if;
  return jsonb_build_object(
    'ok', true, 'environment', p_environment,
    'failed', (select count(*) from private.stripe_webhook_events
      where environment = p_environment and processing_status = 'failed'),
    'expired_or_unclaimed', (select count(*) from private.stripe_webhook_events
      where environment = p_environment and processing_status = 'received'
        and coalesce(processing_lease_until, received_at + interval '2 minutes') <= statement_timestamp()),
    'unquantified_transfer_reversals', (select count(*) from private.stripe_job_transfers
      where environment = p_environment and status in ('partially_reversed', 'reversed')
        and amount_reversed_cents is null)
  );
end;
$$;
revoke all on function public.stripe_server_webhook_reconciliation_status_v1(text) from public, anon, authenticated;
grant execute on function public.stripe_server_webhook_reconciliation_status_v1(text) to service_role;
