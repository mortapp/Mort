-- Persist the owner-authorized public marketplace activation on the current
-- production project. Fail closed if the production release-control singleton
-- is absent, duplicated, in maintenance, or not production_public.
do $public_marketplace_activation$
begin
  if (select count(*) from public.mort_release_control where is_primary) <> 1 then
    raise exception 'production_release_control_singleton_invalid';
  end if;

  if not exists (
    select 1
    from public.mort_release_control
    where is_primary
      and release_mode = 'production_public'
      and maintenance_mode = false
  ) then
    raise exception 'public_marketplace_activation_requires_live_production_mode';
  end if;

  update public.mort_release_control
  set public_marketplace_enabled = true,
      updated_at = now()
  where is_primary;

  if not exists (
    select 1
    from public.mort_release_control
    where is_primary
      and public_marketplace_enabled = true
  ) then
    raise exception 'public_marketplace_activation_not_persisted';
  end if;
end;
$public_marketplace_activation$;
