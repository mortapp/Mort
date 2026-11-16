-- Expose the production RPC name to the generic local migration chain while
-- delegating transitions to its applications-based, ownership-checked engine.
-- The production-baseline equivalent uses the production job_applications schema.
BEGIN;

create or replace function public.update_my_job_application_status_v3(
  p_application_id uuid,
  p_action text,
  p_client_request_id uuid,
  p_expected_updated_at timestamptz default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_action text := lower(btrim(coalesce(p_action, '')));
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  if p_application_id is null
     or p_client_request_id is null
     or v_action not in (
       'adult_review', 'guardian_rejected', 'viewed', 'accepted',
       'rejected', 'withdrawn', 'in_progress', 'completed'
     ) then
    return jsonb_build_object(
      'ok', false,
      'code', 'invalid_application_transition_request'
    );
  end if;

  -- Check current participation before delegating to the idempotency-aware
  -- engine so a stored response cannot be replayed after access is lost.
  if not public.is_application_participant(p_application_id) then
    return jsonb_build_object(
      'ok', false,
      'code', 'application_not_available',
      'replayed', false
    );
  end if;

  return public.update_application_status_v3(
    p_application_id,
    v_action,
    p_client_request_id,
    p_expected_updated_at
  );
end;
$function$;

revoke all on function public.update_my_job_application_status_v3(
  uuid, text, uuid, timestamptz
) from public, anon;
grant execute on function public.update_my_job_application_status_v3(
  uuid, text, uuid, timestamptz
) to authenticated, service_role;

COMMIT;
