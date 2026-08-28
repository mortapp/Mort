-- SECURITY DEFINER changes the database execution identity, so session_user is
-- not a safe signal for distinguishing an authenticated RPC caller from a
-- server maintenance operation. Trust only the caller JWT or an explicit
-- transaction-local maintenance flag.

create or replace function public.enforce_server_authoritative_onboarding_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_internal_update text := current_setting('mort.internal_update', true);
  v_validated_completion text := current_setting('mort.onboarding_completion', true);
  v_jwt_role text := coalesce(auth.jwt()->>'role', '');
  v_trusted_server boolean :=
    v_jwt_role = 'service_role'
    or v_internal_update = 'true';
begin
  if new.onboarding_completed
     and (tg_op = 'INSERT' or not old.onboarding_completed)
     and not v_trusted_server
     and v_validated_completion <> 'true' then
    raise exception 'onboarding_completion_rpc_required';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_server_authoritative_onboarding_completion()
from public, anon, authenticated;

comment on function public.enforce_server_authoritative_onboarding_completion() is
'Blocks authenticated SECURITY DEFINER profile writes from bypassing complete_my_onboarding; trusts only service JWTs, explicit maintenance, or the validated completion flag.';
