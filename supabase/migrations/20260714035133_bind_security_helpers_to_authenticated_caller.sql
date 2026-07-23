-- These helpers are intentionally SECURITY DEFINER to avoid RLS recursion.
-- Bind their direct RPC surface to the signed-in caller so arbitrary UUIDs
-- cannot be used to probe private account, guardian, pause, or block state.

create or replace function public.is_profile_active(
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null
    and (p_user_id = auth.uid() or public.is_admin())
    and exists (
      select 1
      from public.profiles profile
      where profile.id = p_user_id
        and profile.account_status = 'active'
        and (profile.blocked_until is null or profile.blocked_until < now())
    );
$$;

create or replace function public.guardian_is_connected_to_teen(
  p_teen_id uuid,
  p_guardian_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null
    and (
      auth.uid() = p_teen_id
      or auth.uid() = p_guardian_id
      or public.is_admin()
    )
    and exists (
      select 1
      from public.guardian_connections connection
      where connection.teen_id = p_teen_id
        and connection.guardian_id = p_guardian_id
        and connection.status = 'active'
    );
$$;

create or replace function public.guardian_receives_safety_pings(
  p_teen_id uuid,
  p_guardian_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null
    and (
      auth.uid() = p_teen_id
      or auth.uid() = p_guardian_id
      or public.is_admin()
    )
    and exists (
      select 1
      from public.guardian_connections connection
      join public.guardian_preferences preference
        on preference.link_id = connection.id
      where connection.teen_id = p_teen_id
        and connection.guardian_id = p_guardian_id
        and connection.status = 'active'
        and preference.safety_ping_alerts
    );
$$;

create or replace function public.teen_is_paused(p_teen_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null
    and (
      auth.uid() = p_teen_id
      or public.guardian_is_connected_to_teen(p_teen_id, auth.uid())
      or public.is_admin()
    )
    and exists (
      select 1
      from public.teen_profiles teen
      where teen.user_id = p_teen_id
        and teen.paused_by_guardian
    );
$$;

create or replace function public.users_are_blocked(
  p_user_one uuid,
  p_user_two uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null
    and (
      auth.uid() = p_user_one
      or auth.uid() = p_user_two
      or public.is_admin()
    )
    and exists (
      select 1
      from public.blocks block_record
      where (
        block_record.blocker_id = p_user_one
        and block_record.blocked_id = p_user_two
      ) or (
        block_record.blocker_id = p_user_two
        and block_record.blocked_id = p_user_one
      )
    );
$$;

revoke execute on function public.is_profile_active(uuid)
from public, anon;
revoke execute on function public.guardian_is_connected_to_teen(uuid, uuid)
from public, anon;
revoke execute on function public.guardian_receives_safety_pings(uuid, uuid)
from public, anon;
revoke execute on function public.teen_is_paused(uuid)
from public, anon;
revoke execute on function public.users_are_blocked(uuid, uuid)
from public, anon;

grant execute on function public.is_profile_active(uuid)
to authenticated, service_role;
grant execute on function public.guardian_is_connected_to_teen(uuid, uuid)
to authenticated, service_role;
grant execute on function public.guardian_receives_safety_pings(uuid, uuid)
to authenticated, service_role;
grant execute on function public.teen_is_paused(uuid)
to authenticated, service_role;
grant execute on function public.users_are_blocked(uuid, uuid)
to authenticated, service_role;
