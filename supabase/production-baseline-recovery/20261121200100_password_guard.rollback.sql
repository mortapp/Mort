-- Manual rollback of the enforcing triggers only. Requires a separately
-- authorized target and a drained password-guard in maintenance mode.
-- The staged guard still needs the quota. Retain historical nonce records.
begin;

drop trigger mort_password_attestation_on_insert on auth.users;
drop trigger mort_password_attestation_on_password_change on auth.users;
drop trigger mort_strip_consumed_password_attestation on auth.users;
drop trigger mort_strip_password_attestation on auth.identities;

do $rollback$
begin
  if to_regprocedure('public.mort_consume_password_guard_rate_limit(text,integer,integer)') is null
    or exists (
      select 1 from pg_catalog.pg_trigger
      where tgrelid in ('auth.users'::regclass, 'auth.identities'::regclass)
        and tgname in (
          'mort_password_attestation_on_insert',
          'mort_password_attestation_on_password_change',
          'mort_strip_consumed_password_attestation',
          'mort_strip_password_attestation'
        )
    ) then
    raise exception 'Password guard rollback did not leave only staged prerequisites';
  end if;
end
$rollback$;

commit;
