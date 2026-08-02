-- Preserve the verified application transition engine while adding an
-- authenticated idempotency boundary and optimistic concurrency contract.

create table public.application_transition_requests (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  client_request_id uuid not null,
  application_id uuid not null references public.applications(id) on delete cascade,
  action text not null,
  expected_updated_at timestamptz,
  succeeded boolean,
  response jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint application_transition_requests_action_check check (
    action in (
      'adult_review', 'guardian_rejected', 'viewed', 'accepted', 'rejected',
      'withdrawn', 'in_progress', 'proof_submitted', 'completed'
    )
  ),
  unique (actor_id, client_request_id)
);

create index application_transition_requests_application_created_idx
on public.application_transition_requests (application_id, created_at desc);

alter table public.application_transition_requests enable row level security;
alter table public.application_transition_requests force row level security;

create policy application_transition_requests_participant_select
on public.application_transition_requests for select to authenticated
using (
  actor_id = auth.uid()
  or public.is_admin()
  or public.is_application_participant(application_id)
);

revoke all on public.application_transition_requests
from public, anon, authenticated;
grant select on public.application_transition_requests to authenticated;
grant all on public.application_transition_requests to service_role;

create or replace function public.update_application_status_v3(
  p_application_id uuid,
  p_action text,
  p_client_request_id uuid,
  p_expected_updated_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_profile public.profiles%rowtype;
  v_application public.applications%rowtype;
  v_request public.application_transition_requests%rowtype;
  v_response jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_profile
  from public.profiles profile
  where profile.id = v_user_id;
  if v_profile.id is null or v_profile.account_status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'user_account_restricted');
  end if;
  if p_application_id is null
     or p_client_request_id is null
     or v_action not in (
       'adult_review', 'guardian_rejected', 'viewed', 'accepted', 'rejected',
       'withdrawn', 'in_progress', 'proof_submitted', 'completed'
     ) then
    return jsonb_build_object(
      'ok', false, 'code', 'invalid_application_transition_request'
    );
  end if;

  insert into public.application_transition_requests (
    actor_id, client_request_id, application_id, action, expected_updated_at
  ) values (
    v_user_id, p_client_request_id, p_application_id, v_action,
    p_expected_updated_at
  )
  on conflict (actor_id, client_request_id) do nothing
  returning * into v_request;

  if v_request.id is null then
    select * into v_request
    from public.application_transition_requests request
    where request.actor_id = v_user_id
      and request.client_request_id = p_client_request_id;
    if v_request.application_id <> p_application_id
       or v_request.action <> v_action then
      return jsonb_build_object('ok', false, 'code', 'client_request_conflict');
    end if;
    return coalesce(
      v_request.response || jsonb_build_object('replayed', true),
      jsonb_build_object('ok', false, 'code', 'request_in_progress')
    );
  end if;

  select * into v_application
  from public.applications application
  where application.id = p_application_id;
  if v_application.id is null then
    v_response := jsonb_build_object(
      'ok', false, 'code', 'application_not_found'
    );
  elsif p_expected_updated_at is not null
        and v_application.updated_at is distinct from p_expected_updated_at then
    v_response := jsonb_build_object(
      'ok', false, 'code', 'stale_application_state'
    );
  else
    v_response := public.update_application_status_v2(
      p_application_id,
      v_action
    );
  end if;

  update public.application_transition_requests
  set succeeded = coalesce((v_response->>'ok')::boolean, false),
      response = v_response,
      completed_at = now()
  where id = v_request.id;

  return v_response;
end;
$$;

revoke all on function public.update_application_status_v3(
  uuid, text, uuid, timestamptz
) from public, anon;
grant execute on function public.update_application_status_v3(
  uuid, text, uuid, timestamptz
) to authenticated, service_role;

revoke execute on function public.update_application_status_v2(uuid, text)
from authenticated;
grant execute on function public.update_application_status_v2(uuid, text)
to service_role;
