-- Reconcile the production release-control table into the versioned schema.
-- The live project already has this singleton; IF NOT EXISTS keeps the migration
-- safe there while making clean local resets deterministic before the activation
-- migration runs.
create table if not exists public.mort_release_control (
  is_primary boolean primary key default true check (is_primary),
  release_mode text not null default 'unconfigured'
    check (release_mode in ('production_public', 'unconfigured')),
  maintenance_mode boolean not null default false,
  public_marketplace_enabled boolean not null default false,
  real_document_collection boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.mort_release_control enable row level security;

revoke all on table public.mort_release_control from public, anon, authenticated;
grant select on table public.mort_release_control to anon, authenticated;

drop policy if exists mort_release_control_public_status_read
  on public.mort_release_control;
create policy mort_release_control_public_status_read
  on public.mort_release_control
  for select to anon, authenticated
  using (is_primary);

insert into public.mort_release_control (
  is_primary,
  release_mode,
  maintenance_mode,
  public_marketplace_enabled,
  real_document_collection
)
values (true, 'production_public', false, false, false)
on conflict (is_primary) do nothing;
