-- Keep low-level rate-limit mutation helpers internal to trusted database code.
revoke execute on function public.check_rate_limit(text, integer, integer)
from public, anon, authenticated;
revoke execute on function public.record_rate_limit_event(text, text)
from public, anon, authenticated;

-- Authenticated callers may ask whether their own action is allowed, but anonymous
-- callers cannot reach any of the rate-limit SECURITY DEFINER functions.
revoke execute on function public.is_action_allowed(text) from public, anon;
grant execute on function public.is_action_allowed(text) to authenticated, service_role;

create or replace function public.admin_rate_limit_overview()
returns table (
  action text,
  total_events bigint,
  unique_users bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
begin
  if not public.is_admin() and coalesce(auth.role(), '') <> 'service_role' then
    raise exception using
      errcode = '42501',
      message = 'Administrator access is required.';
  end if;

  return query
  select
    events.action,
    count(*),
    count(distinct events.user_id)
  from public.rate_limit_events as events
  where events.created_at >= now() - interval '24 hours'
  group by events.action;
end;
$$;

revoke execute on function public.admin_rate_limit_overview()
from public, anon;
grant execute on function public.admin_rate_limit_overview()
to authenticated, service_role;

