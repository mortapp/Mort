-- Bind every start/finish confirmation attempt to a caller request. The ledger
-- stores only bcrypt PIN fingerprints and safe responses; PIN values never
-- enter events, analytics, support content, or client-readable tables.

create table if not exists private.job_pin_confirmation_requests (
  actor_id uuid not null references auth.users(id) on delete cascade,
  client_request_id uuid not null,
  application_id uuid not null references public.applications(id) on delete cascade,
  pin_kind text not null check (pin_kind in ('start', 'finish')),
  pin_hash text not null,
  person_matches_profile boolean,
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor_id, client_request_id)
);

alter table private.job_pin_confirmation_requests enable row level security;
alter table private.job_pin_confirmation_requests force row level security;
revoke all on private.job_pin_confirmation_requests from public, anon, authenticated;
grant all on private.job_pin_confirmation_requests to service_role;

create or replace function public.confirm_job_start_pin_v2(
  p_application_id uuid,
  p_pin text,
  p_person_matches_profile boolean,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_request private.job_pin_confirmation_requests%rowtype;
  v_handshake public.job_arrival_handshakes%rowtype;
  v_response jsonb;
begin
  if v_actor_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_actor_id::text || ':' || p_client_request_id::text, 0)
  );
  select * into v_request
  from private.job_pin_confirmation_requests request
  where request.actor_id = v_actor_id
    and request.client_request_id = p_client_request_id;
  if found then
    if v_request.application_id <> p_application_id
       or v_request.pin_kind <> 'start'
       or v_request.person_matches_profile is distinct from coalesce(p_person_matches_profile, false)
       or extensions.crypt(coalesce(p_pin, ''), v_request.pin_hash) <> v_request.pin_hash then
      return jsonb_build_object('ok', false, 'code', 'pin_request_payload_mismatch');
    end if;
    return v_request.response || jsonb_build_object('replayed', true);
  end if;

  select * into v_handshake
  from public.job_arrival_handshakes
  where application_id = p_application_id
  for update;
  if v_handshake.id is null or v_handshake.teen_id <> v_actor_id then
    return jsonb_build_object('ok', false, 'code', 'assigned_worker_required');
  end if;
  if v_handshake.start_pin_used_at is not null then
    v_response := jsonb_build_object('ok', false, 'code', 'start_pin_already_used');
  else
    v_response := public.confirm_job_start_pin(
      p_application_id,
      p_pin,
      p_person_matches_profile,
      p_client_request_id
    );
  end if;
  insert into private.job_pin_confirmation_requests(
    actor_id, client_request_id, application_id, pin_kind,
    pin_hash, person_matches_profile, response
  ) values (
    v_actor_id, p_client_request_id, p_application_id, 'start',
    extensions.crypt(coalesce(p_pin, ''), extensions.gen_salt('bf', 10)),
    coalesce(p_person_matches_profile, false), v_response
  );
  return v_response || jsonb_build_object('replayed', false);
end;
$$;

create or replace function public.confirm_job_finish_pin_v2(
  p_application_id uuid,
  p_pin text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_request private.job_pin_confirmation_requests%rowtype;
  v_handshake public.job_arrival_handshakes%rowtype;
  v_response jsonb;
begin
  if v_actor_id is null then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if p_client_request_id is null then return jsonb_build_object('ok', false, 'code', 'request_id_required'); end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_actor_id::text || ':' || p_client_request_id::text, 0)
  );
  select * into v_request
  from private.job_pin_confirmation_requests request
  where request.actor_id = v_actor_id
    and request.client_request_id = p_client_request_id;
  if found then
    if v_request.application_id <> p_application_id
       or v_request.pin_kind <> 'finish'
       or extensions.crypt(coalesce(p_pin, ''), v_request.pin_hash) <> v_request.pin_hash then
      return jsonb_build_object('ok', false, 'code', 'pin_request_payload_mismatch');
    end if;
    return v_request.response || jsonb_build_object('replayed', true);
  end if;

  select * into v_handshake
  from public.job_arrival_handshakes
  where application_id = p_application_id
  for update;
  if v_handshake.id is null or v_handshake.teen_id <> v_actor_id then
    return jsonb_build_object('ok', false, 'code', 'assigned_worker_required');
  end if;
  if v_handshake.finish_pin_used_at is not null then
    v_response := jsonb_build_object('ok', false, 'code', 'finish_pin_already_used');
  else
    v_response := public.confirm_job_finish_pin(
      p_application_id,
      p_pin,
      p_client_request_id
    );
  end if;
  insert into private.job_pin_confirmation_requests(
    actor_id, client_request_id, application_id, pin_kind,
    pin_hash, person_matches_profile, response
  ) values (
    v_actor_id, p_client_request_id, p_application_id, 'finish',
    extensions.crypt(coalesce(p_pin, ''), extensions.gen_salt('bf', 10)),
    null, v_response
  );
  return v_response || jsonb_build_object('replayed', false);
end;
$$;

revoke all on function public.confirm_job_start_pin(uuid,text,boolean,uuid)
from public, anon, authenticated;
grant execute on function public.confirm_job_start_pin(uuid,text,boolean,uuid) to service_role;
revoke all on function public.confirm_job_finish_pin(uuid,text,uuid)
from public, anon, authenticated;
grant execute on function public.confirm_job_finish_pin(uuid,text,uuid) to service_role;
revoke all on function public.generate_job_arrival_code(uuid)
from public, anon, authenticated;
grant execute on function public.generate_job_arrival_code(uuid) to service_role;
revoke all on function public.confirm_job_arrival_code(uuid,text,boolean)
from public, anon, authenticated;
grant execute on function public.confirm_job_arrival_code(uuid,text,boolean) to service_role;

revoke all on function public.confirm_job_start_pin_v2(uuid,text,boolean,uuid)
from public, anon;
grant execute on function public.confirm_job_start_pin_v2(uuid,text,boolean,uuid)
to authenticated, service_role;
revoke all on function public.confirm_job_finish_pin_v2(uuid,text,uuid)
from public, anon;
grant execute on function public.confirm_job_finish_pin_v2(uuid,text,uuid)
to authenticated, service_role;

comment on table private.job_pin_confirmation_requests is
'Server-only idempotency ledger. Contains bcrypt fingerprints, never plaintext PIN values.';
