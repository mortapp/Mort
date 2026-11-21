-- Staff authorization must fail closed when the staff profile is not active.
-- Keep the existing signature, owner, grants, SECURITY DEFINER behavior, and
-- empty search_path; CREATE OR REPLACE preserves the existing ACL.
create or replace function private.has_staff_role(required_roles public.mort_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from private.user_roles ur
    join public.profiles p on p.id = ur.user_id
    where ur.user_id = (select auth.uid())
      and ur.role = any(required_roles)
      and p.account_status = 'active'
  );
$function$;
