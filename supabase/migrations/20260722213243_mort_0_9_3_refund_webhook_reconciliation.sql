create or replace function public.stripe_server_apply_refund_event(
  p_environment text,
  p_provider_event_id text,
  p_provider_payment_intent_id text,
  p_provider_refund_id text,
  p_amount_cents integer,
  p_currency_code text,
  p_status text,
  p_failure_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment private.stripe_job_payment_intents%rowtype;
  v_refund private.stripe_job_refunds%rowtype;
  v_status text;
  v_total_refunded integer;
  v_total_pending integer;
begin
  perform private.require_stripe_service_role();
  if p_environment not in ('test', 'live') then raise exception 'stripe_environment_mismatch'; end if;
  if p_provider_refund_id !~ '^re_[A-Za-z0-9]+$' then raise exception 'stripe_refund_reference_invalid'; end if;
  if p_status not in ('pending', 'succeeded', 'failed', 'canceled') then raise exception 'stripe_refund_status_invalid'; end if;
  select * into v_payment from private.stripe_job_payment_intents
  where environment = p_environment
    and provider_payment_intent_id = p_provider_payment_intent_id
  for update;
  if v_payment.id is null then raise exception 'stripe_payment_intent_not_found'; end if;
  if p_amount_cents <= 0 or p_amount_cents > v_payment.total_amount_cents
     or upper(p_currency_code) <> v_payment.currency_code then
    raise exception 'stripe_refund_amount_mismatch';
  end if;
  v_status := p_status;
  insert into private.stripe_job_refunds(
    payment_intent_id, requested_by, environment, amount_cents,
    provider_refund_id, idempotency_key, reason_code, status, failure_code
  ) values (
    v_payment.id, null, p_environment, p_amount_cents,
    p_provider_refund_id,
    p_environment || ':provider-refund:' || p_provider_refund_id,
    'provider_webhook_reconciled', v_status, left(p_failure_code, 120)
  )
  on conflict (environment, provider_refund_id) do update set
    amount_cents = excluded.amount_cents,
    status = excluded.status,
    failure_code = excluded.failure_code,
    updated_at = now()
  where private.stripe_job_refunds.payment_intent_id = excluded.payment_intent_id
  returning * into v_refund;
  if v_refund.id is null then raise exception 'stripe_refund_reference_conflict'; end if;
  select
    coalesce(sum(amount_cents) filter (where status = 'succeeded'), 0)::integer,
    coalesce(sum(amount_cents) filter (where status = 'pending'), 0)::integer
  into v_total_refunded, v_total_pending
  from private.stripe_job_refunds where payment_intent_id = v_payment.id;
  if v_total_refunded + v_total_pending > v_payment.total_amount_cents then
    raise exception 'stripe_refund_total_exceeds_capture';
  end if;
  update private.stripe_job_payment_intents set
    status = case
      when v_total_refunded >= total_amount_cents then 'refunded'
      when v_total_refunded > 0 then 'partially_refunded'
      when v_total_pending > 0 then 'refund_pending'
      else status
    end,
    last_failure_code = case when v_status = 'failed' then left(p_failure_code, 120) else last_failure_code end,
    last_synchronized_at = now(), updated_at = now()
  where id = v_payment.id
  returning * into v_payment;
  update private.stripe_payment_resolutions set
    status = case
      when v_status = 'pending' and status = 'financial_execution_started' then 'provider_processing'
      when v_status = 'failed' and provider_refund_id = p_provider_refund_id then 'failed'
      else status
    end,
    safe_failure_code = case when v_status = 'failed' then left(p_failure_code, 120) else safe_failure_code end,
    updated_at = now()
  where payment_intent_id = v_payment.id
    and provider_refund_id = p_provider_refund_id;
  update private.stripe_webhook_events set
    processing_status = 'processed', processed_at = now(), safe_failure_code = null
  where environment = p_environment and provider_event_id = p_provider_event_id;
  insert into private.stripe_financial_audit_events(
    actor_id, environment, event_type, subject_type, subject_id,
    safe_reason_code, field_names
  ) values (
    null, p_environment, 'refund_webhook_reconciled',
    'stripe_job_refund', v_refund.id, v_status,
    array['status', 'amount_cents', 'failure_code']
  );
  return jsonb_build_object(
    'ok', true, 'refund_record_id', v_refund.id,
    'refund_status', v_refund.status,
    'payment_status', v_payment.status,
    'total_refunded_cents', v_total_refunded
  );
end;
$$;

revoke all on function public.stripe_server_apply_refund_event(
  text, text, text, text, integer, text, text, text
) from public, anon, authenticated;
grant execute on function public.stripe_server_apply_refund_event(
  text, text, text, text, integer, text, text, text
) to service_role;
