create table private.mort_release_control (
  is_primary boolean primary key default true check (is_primary),
  release_mode text not null
    check (release_mode in ('production_public', 'unconfigured')),
  maintenance_mode boolean not null default false,
  public_marketplace_enabled boolean not null default false,
  real_document_collection boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table private.mort_release_control enable row level security;
revoke all on table private.mort_release_control from public, anon, authenticated, service_role;
grant select, update on table private.mort_release_control to service_role;

insert into private.mort_release_control (
  is_primary,
  release_mode,
  maintenance_mode,
  public_marketplace_enabled,
  real_document_collection
)
values (true, 'production_public', false, false, false);

create or replace function public.get_release_mode_status()
returns jsonb
language sql
stable
security definer
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
      from private.mort_release_control control
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
