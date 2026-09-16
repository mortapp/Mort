-- Add a lease without changing the legacy completion contract. This prevents
-- concurrent webhook deliveries from applying the same event twice.

alter table private.stripe_webhook_events
  add column if not exists processing_lease_token uuid,
  add column if not exists processing_lease_until timestamptz,
  add column if not exists processing_attempts integer not null default 0
    check (processing_attempts >= 0),
  add column if not exists last_claimed_at timestamptz;

create or replace function public.stripe_server_claim_webhook_event_v2(
  p_environment text,
  p_provider_event_id text,
  p_event_type text,
  p_provider_created_at timestamptz,
  p_payload_sha256 text,
  p_lease_seconds integer default 120
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  event private.stripe_webhook_events%rowtype;
  control private.stripe_runtime_controls%rowtype;
  lease_token uuid;
  can_claim boolean;
begin
  perform private.require_stripe_service_role();
  if p_lease_seconds < 30 or p_lease_seconds > 900 then
    raise exception 'invalid_webhook_lease';
  end if;
  select * into control from private.stripe_runtime_controls where singleton;
  if p_environment <> private.stripe_environment_for_mode(control.mode) then
    raise exception 'stripe_environment_mismatch';
  end if;
  if p_provider_event_id is null or p_provider_event_id !~ '^evt_[A-Za-z0-9]+$'
     or p_payload_sha256 is null or p_payload_sha256 !~ '^[a-f0-9]{64}$' then
    raise exception 'invalid_webhook_identity';
  end if;

  insert into private.stripe_webhook_events (
    environment,
    provider_event_id,
    event_type,
    provider_created_at,
    payload_sha256,
    signature_verified
  )
  values (
    p_environment,
    p_provider_event_id,
    p_event_type,
    p_provider_created_at,
    p_payload_sha256,
    true
  )
  on conflict (environment, provider_event_id) do nothing;

  select *
    into event
    from private.stripe_webhook_events
   where environment = p_environment
     and provider_event_id = p_provider_event_id
   for update;

  if event.payload_sha256 <> p_payload_sha256 then
    raise exception 'stripe_webhook_replay_payload_mismatch';
  end if;

  can_claim := event.processing_status in ('received', 'failed')
    and (
      event.processing_lease_until is null
      or event.processing_lease_until <= statement_timestamp()
    );
  if not can_claim then
    return jsonb_build_object(
      'ok', true,
      'claimed', false,
      'event_record_id', event.id,
      'processing_status', event.processing_status
    );
  end if;

  lease_token := gen_random_uuid();
  update private.stripe_webhook_events
     set processing_lease_token = lease_token,
         processing_lease_until = statement_timestamp() + make_interval(secs => p_lease_seconds),
         processing_attempts = processing_attempts + 1,
         last_claimed_at = statement_timestamp()
   where id = event.id;

  return jsonb_build_object(
    'ok', true,
    'claimed', true,
    'event_record_id', event.id,
    'lease_token', lease_token,
    'processing_status', event.processing_status
  );
end;
$$;

revoke all on function public.stripe_server_claim_webhook_event_v2(
  text, text, text, timestamptz, text, integer
) from public, anon, authenticated;
grant execute on function public.stripe_server_claim_webhook_event_v2(
  text, text, text, timestamptz, text, integer
) to service_role;