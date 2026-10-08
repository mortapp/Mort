-- Default-off commit-time provider-origin check. A stored operation marker alone
-- cannot distinguish Admin writes from the public /user password route.
begin;
create or replace function mort_auth_guard.require_admin_mutation_origin()
returns trigger language plpgsql security definer set search_path='' as $$
declare enabled boolean;verified_oauth boolean:=false;current_xid xid;
begin
  select c.enabled into enabled from mort_auth_guard.control c where c.singleton;
  if enabled is not true or not exists(select 1 from mort_auth_guard.account_generations where account_id=new.id) then return new;end if;
  if old.encrypted_password is not distinct from new.encrypted_password
    and not(old.email_confirmed_at is null and new.email_confirmed_at is not null)
    and (old.raw_app_meta_data->>'mort_email_operation_id') is not distinct from (new.raw_app_meta_data->>'mort_email_operation_id') then return new;end if;
  select exists(select 1 from auth.identities i where i.user_id=new.id and i.provider='keycloak'
    and i.identity_data->>'email'=new.email and i.identity_data->>'email_verified'='true') into verified_oauth;
  if verified_oauth and old.email_confirmed_at is null
    and (old.raw_app_meta_data->>'mort_email_operation_id') is not distinct from (new.raw_app_meta_data->>'mort_email_operation_id')
    and (old.encrypted_password is not distinct from new.encrypted_password or coalesce(new.encrypted_password,'')='') then return new;end if;
  -- AdminUserUpdate writes this provider-owned audit trait in the same database
  -- transaction; UserUpdate never writes the target-user trait. Compare xmin
  -- to the current transaction, so an old Admin audit row is never reusable.
  -- Audit persistence is now a required local/hosted compatibility gate.
  current_xid:=((pg_current_xact_id()::text::numeric % 4294967296)::text)::xid;
  if not exists(select 1 from auth.audit_log_entries a where a.xmin=current_xid
    and a.payload->>'action'='user_modified' and a.payload->'traits'->>'user_id'=new.id::text) then
    raise exception 'MORT credential operation denied';
  end if;
  return new;
end $$;
revoke all on function mort_auth_guard.require_admin_mutation_origin() from public,anon,authenticated,service_role;
create constraint trigger mort_auth_guard_admin_origin after update on auth.users
deferrable initially deferred for each row execute function mort_auth_guard.require_admin_mutation_origin();
commit;
