-- Preserve the live production signature, owner, ACL and empty search path.
create or replace function private.has_staff_role(required_roles public.mort_role[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from private.user_roles r
    join public.profiles p on p.id = r.user_id
    where r.user_id = (select auth.uid())
      and r.role = any(required_roles)
      and p.account_status = 'active'
  );
$$;
revoke all on function private.has_staff_role(public.mort_role[]) from public, anon;
grant execute on function private.has_staff_role(public.mort_role[]) to authenticated;
