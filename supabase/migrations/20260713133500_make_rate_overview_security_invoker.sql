create or replace function public.admin_rate_limit_overview()
returns table (
  action text,
  total_events bigint,
  unique_users bigint
)
language plpgsql
security invoker
set search_path = public, pg_temp
stable
as $$
begin
  if not public.is_admin() then
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

