-- MORT: extend the Google-only identity-event audit RPC to also accept
-- Apple, mirroring the exact same verification rules per provider. Without
-- this, Apple account linking/unlinking (shipped client-side this session)
-- would always fail server-side with provider_not_allowed.

drop index if exists account_security_events_auth_request_unique_idx;

create unique index account_security_events_auth_request_unique_idx
on public.account_security_events (
  user_id,
  event_type,
  (event_data->>'client_request_id')
)
where event_type in (
  'auth_google_sign_in',
  'auth_google_linked',
  'auth_google_unlinked',
  'auth_apple_sign_in',
  'auth_apple_linked',
  'auth_apple_unlinked'
);

create or replace function public.record_my_auth_identity_event(
  p_event_type text,
  p_provider text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_event_type text := lower(btrim(coalesce(p_event_type, '')));
  v_provider text := lower(btrim(coalesce(p_provider, '')));
  v_identity_count integer := 0;
  v_provider_connected boolean := false;
  v_event_id uuid;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;
  if v_provider not in ('google', 'apple') then
    return jsonb_build_object('ok', false, 'code', 'provider_not_allowed');
  end if;
  if v_event_type not in (
    v_provider || '_sign_in',
    v_provider || '_linked',
    v_provider || '_unlinked'
  ) then
    return jsonb_build_object('ok', false, 'code', 'event_type_not_allowed');
  end if;
  if not public.check_rate_limit('auth_identity_event', 30, 3600) then
    return jsonb_build_object('ok', false, 'code', 'rate_limited');
  end if;

  select
    count(*)::integer,
    coalesce(bool_or(identity.provider = v_provider), false)
  into v_identity_count, v_provider_connected
  from auth.identities as identity
  where identity.user_id = v_user_id;

  if v_event_type in (v_provider || '_sign_in', v_provider || '_linked')
    and not v_provider_connected then
    return jsonb_build_object('ok', false, 'code', 'provider_identity_not_connected');
  end if;
  if v_event_type = v_provider || '_unlinked'
    and (v_provider_connected or v_identity_count < 1) then
    return jsonb_build_object('ok', false, 'code', 'provider_identity_state_invalid');
  end if;
  if v_event_type = v_provider || '_unlinked'
    and not exists (
      select 1
      from public.account_security_events as prior_event
      where prior_event.user_id = v_user_id
        and prior_event.event_type = 'auth_' || v_provider || '_linked'
    ) then
    return jsonb_build_object('ok', false, 'code', 'prior_link_event_required');
  end if;

  perform public.record_rate_limit_event('auth_identity_event', null);

  insert into public.account_security_events (
    user_id,
    event_type,
    severity,
    session_reference,
    event_data,
    status
  ) values (
    v_user_id,
    'auth_' || v_event_type,
    'info',
    nullif(left(coalesce(auth.jwt()->>'session_id', ''), 100), ''),
    jsonb_build_object(
      'provider', v_provider,
      'identity_count', v_identity_count,
      'client_request_id', p_client_request_id::text
    ),
    'cleared'
  )
  on conflict do nothing
  returning id into v_event_id;

  if v_event_id is null then
    select event.id
    into v_event_id
    from public.account_security_events as event
    where event.user_id = v_user_id
      and event.event_type = 'auth_' || v_event_type
      and event.event_data->>'client_request_id' = p_client_request_id::text
    limit 1;
  end if;

  return jsonb_build_object(
    'ok', true,
    'event_id', v_event_id,
    'provider_connected', v_provider_connected,
    'identity_count', v_identity_count
  );
end;
$$;

revoke all on function public.record_my_auth_identity_event(text, text, uuid)
from public, anon;
grant execute on function public.record_my_auth_identity_event(text, text, uuid)
to authenticated, service_role;

comment on function public.record_my_auth_identity_event(text, text, uuid) is
'Records an idempotent, caller-bound auth identity event only after verifying the current auth.identities state. Provider-agnostic across google and apple.';
