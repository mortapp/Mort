-- Narrow isolated-replica port of the internal call admission probe. This
-- does not provision support queues, evidence, provider bindings, or actors.
begin;

create function public.support_internal_authorize()
returns boolean
language sql stable security invoker set search_path = ''
as $$
  select coalesce((select auth.role()) = 'service_role', false)
$$;

revoke all on function public.support_internal_authorize() from public, anon, authenticated;
grant execute on function public.support_internal_authorize() to service_role;

commit;
