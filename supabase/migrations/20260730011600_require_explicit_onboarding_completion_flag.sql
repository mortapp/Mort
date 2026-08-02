-- Completion is a one-way privileged transition. Even service-role and
-- SECURITY DEFINER writes must opt into the same explicit transaction-local
-- flag used by complete_my_onboarding or controlled database maintenance.

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
     and v_validated_completion <> 'true' then
    raise exception 'onboarding_completion_rpc_required';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_server_authoritative_onboarding_completion()
from public, anon, authenticated;

comment on function public.enforce_server_authoritative_onboarding_completion() is
'Allows false-to-true onboarding completion only when the validated transaction-local completion flag is explicitly set.';
