-- current_setting(..., true) returns NULL when the flag is absent. A normal
-- inequality against NULL is unknown, so use NULL-safe comparison to fail
-- closed when no validated completion flag exists.

create or replace function public.enforce_server_authoritative_onboarding_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_validated_completion text := current_setting('mort.onboarding_completion', true);
begin
  if new.onboarding_completed
     and (tg_op = 'INSERT' or not old.onboarding_completed)
     and v_validated_completion is distinct from 'true' then
    raise exception 'onboarding_completion_rpc_required';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_server_authoritative_onboarding_completion()
from public, anon, authenticated;

comment on function public.enforce_server_authoritative_onboarding_completion() is
'Fails closed on an absent completion flag and permits false-to-true onboarding completion only after validated server checks.';
