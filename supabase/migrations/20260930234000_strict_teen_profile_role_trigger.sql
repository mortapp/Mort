-- Covers direct profile writes as well as onboarding RPCs. Auth bootstrap may
-- still create a role-less identity so users can reach Safety/account controls.
create or replace function private.require_school_email_for_teen_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role_change boolean := tg_op = 'INSERT';
begin
  if tg_op = 'UPDATE' then
    v_role_change := old.role is distinct from new.role;
  end if;
  if new.role = 'teen' and v_role_change
     and not private.has_current_teen_school_email(new.id) then
    raise exception 'verified_school_email_required' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.require_school_email_for_teen_role()
  from public, anon, authenticated;

create trigger profiles_require_school_email_for_teen_role
before insert or update of role on public.profiles
for each row execute function private.require_school_email_for_teen_role();
