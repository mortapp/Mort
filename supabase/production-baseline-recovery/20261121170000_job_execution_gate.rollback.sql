-- Manual rollback for 20261121170000 only. Not an automatic migration.
-- Run as postgres in a transaction after independently confirming the target
-- and receiving rollback authorization. Refuses any unknown installed body.
do $rollback$
declare
  v_gate regprocedure := 'private.job_execution_gate(uuid,text)'::regprocedure;
  v_definition text;
begin
  if not exists (
    select from pg_catalog.pg_proc p
    where p.oid = v_gate and p.prosecdef and p.provolatile = 's'
      and p.proowner = 'postgres'::regrole
      and p.proconfig = array['search_path=""']
      and p.proacl = array['postgres=X/postgres'::aclitem]
      and pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(p.prosrc, 'UTF8')), 'hex')
        = '99e3d5aa07796bc230ae672b7a5ba86f072359ad6e5e1c0e7ab9484f9e204cac'
  ) then
    raise exception 'Unexpected job execution gate; refusing rollback';
  end if;

  v_definition := pg_catalog.pg_get_functiondef(v_gate);
  execute pg_catalog.replace(
    pg_catalog.replace(v_definition,
      $needle$coalesce(v_teen.verification_status::text, '') not in ('verified', 'approved')$needle$,
      $prior$v_teen.verification_status::text <> 'approved'$prior$),
    $needle$coalesce(v_adult.verification_status::text, '') not in ('verified', 'approved')$needle$,
    $prior$v_adult.verification_status::text <> 'approved'$prior$);

  if not exists (
    select from pg_catalog.pg_proc p
    where p.oid = v_gate and p.prosecdef and p.provolatile = 's'
      and p.proowner = 'postgres'::regrole
      and p.proconfig = array['search_path=""']
      and p.proacl = array['postgres=X/postgres'::aclitem]
      and pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(p.prosrc, 'UTF8')), 'hex')
        = '1c6cf0fc9b8eaf072cbe54e9f2e37be75b3342128d879a2b01f669fd025ce30a'
  ) then
    raise exception 'Rollback did not restore the recorded job gate preimage';
  end if;
end
$rollback$;
