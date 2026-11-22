-- Require an active profile before any staff role can authorize a protected operation.
-- This is intentionally forward-only; it does not modify role assignments.
create or replace function private.has_staff_role(required_roles public.mort_role[]) returns boolean
  language sql
  stable
  security definer
  set search_path = ''
as $$
  select exists (
    select 1
    from private.user_roles ur
    join public.profiles profile on profile.id = ur.user_id
    where (select auth.uid()) is not null
      and ur.user_id = (select auth.uid())
      and ur.role = any(required_roles)
      and profile.account_status = 'active'
      and (profile.blocked_until is null or profile.blocked_until < now())
  );
$$;

revoke all on function private.has_staff_role(public.mort_role[]) from public, anon, authenticated;
