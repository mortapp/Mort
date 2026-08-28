-- Keep privileged profile readers out of the exposed API schema. Public RPCs
-- remain stable invoker wrappers, while the private functions enforce caller
-- identity and cannot be routed through the default Data API schema.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;

create or replace function private.get_my_profile()
returns setof public.profiles
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select profile.*
  from public.profiles profile
  where auth.uid() is not null
    and profile.id = auth.uid();
$$;

create or replace function private.admin_list_profiles(p_limit integer default 50)
returns setof public.profiles
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'admin_access_required';
  end if;

  return query
  select profile.*
  from public.profiles profile
  order by profile.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$$;

revoke execute on function private.get_my_profile() from public, anon;
revoke execute on function private.admin_list_profiles(integer) from public, anon;
grant execute on function private.get_my_profile() to authenticated, service_role;
grant execute on function private.admin_list_profiles(integer) to authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke execute on functions from public;

create or replace function public.get_my_profile()
returns setof public.profiles
language sql
stable
security invoker
set search_path = public, private, pg_temp
as $$
  select * from private.get_my_profile();
$$;

create or replace function public.admin_list_profiles(p_limit integer default 50)
returns setof public.profiles
language sql
stable
security invoker
set search_path = public, private, pg_temp
as $$
  select * from private.admin_list_profiles(p_limit);
$$;

revoke execute on function public.get_my_profile() from public, anon;
revoke execute on function public.admin_list_profiles(integer) from public, anon;
grant execute on function public.get_my_profile() to authenticated, service_role;
grant execute on function public.admin_list_profiles(integer) to authenticated, service_role;
