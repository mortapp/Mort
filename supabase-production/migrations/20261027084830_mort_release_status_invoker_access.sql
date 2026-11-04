alter table private.mort_release_control set schema public;

revoke all on table public.mort_release_control from public, anon, authenticated, service_role;
grant select on table public.mort_release_control to anon, authenticated;
grant select, update on table public.mort_release_control to service_role;

create policy mort_release_control_public_status_read
on public.mort_release_control
for select
to anon, authenticated
using (is_primary);

create or replace function public.get_release_mode_status()
returns jsonb
language sql
stable
security invoker
set search_path to ''
as $function$
  select coalesce(
    (
      select jsonb_build_object(
        'release_mode', control.release_mode,
        'maintenance_mode', control.maintenance_mode,
        'public_marketplace_enabled', control.public_marketplace_enabled,
        'real_document_collection', control.real_document_collection
      )
      from public.mort_release_control control
      where control.is_primary
    ),
    jsonb_build_object(
      'release_mode', 'unconfigured',
      'maintenance_mode', true,
      'public_marketplace_enabled', false,
      'real_document_collection', false
    )
  );
$function$;

revoke all on function public.get_release_mode_status() from public, anon, authenticated, service_role;
grant execute on function public.get_release_mode_status() to anon, authenticated, service_role;

