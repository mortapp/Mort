-- Let Stripe retries reclaim failed events promptly, and clear stale lease
-- metadata on completion. Token fencing remains a separate required hardening.
create or replace function public.stripe_server_fail_webhook_event(
  p_environment text, p_provider_event_id text, p_safe_failure_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_stripe_service_role();
  update private.stripe_webhook_events
     set processing_status = 'failed',
         safe_failure_code = left(p_safe_failure_code, 120),
         processed_at = statement_timestamp(),
         processing_lease_token = null,
         processing_lease_until = null
   where environment = p_environment and provider_event_id = p_provider_event_id;
  return jsonb_build_object('ok', found);
end;
$$;
create or replace function public.stripe_server_complete_webhook_event(
  p_environment text,
  p_provider_event_id text,
  p_processing_status text,
  p_safe_result_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare event private.stripe_webhook_events%rowtype;
begin
  perform private.require_stripe_service_role();
  if p_processing_status not in ('processed', 'ignored') then
    raise exception 'invalid_webhook_completion_status';
  end if;
  update private.stripe_webhook_events
     set processing_status = p_processing_status,
         safe_failure_code = left(nullif(p_safe_result_code, ''), 120),
         processed_at = statement_timestamp(),
         processing_lease_token = null,
         processing_lease_until = null
   where environment = p_environment and provider_event_id = p_provider_event_id
     and processing_status = 'received'
  returning * into event;
  if event.id is null then
    select * into event from private.stripe_webhook_events
     where environment = p_environment and provider_event_id = p_provider_event_id;
  end if;
  if event.id is null then raise exception 'stripe_webhook_event_not_found'; end if;
  if event.processing_status <> p_processing_status and event.processing_status <> 'processed' then
    raise exception 'webhook_event_not_owned_or_already_final';
  end if;
  return jsonb_build_object('ok', true, 'event_record_id', event.id,
    'processing_status', event.processing_status);
end;
$$;
revoke all on function public.stripe_server_fail_webhook_event(text, text, text)
  from public, anon, authenticated;
revoke all on function public.stripe_server_complete_webhook_event(text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.stripe_server_fail_webhook_event(text, text, text)
  to service_role;
grant execute on function public.stripe_server_complete_webhook_event(text, text, text, text)
  to service_role;
