-- Verify internal callers from the gateway-validated JWT claim. This survives
-- key rotation and never exposes the service key to SQL results or logs.
create or replace function public.support_internal_authorize()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select auth.role() = 'service_role'
$$;

revoke all on function public.support_internal_authorize() from public, anon;
grant execute on function public.support_internal_authorize() to authenticated, service_role;
