-- Database regression assertion for production-baseline migration 20261121170000.
-- Run against an isolated production-baseline replica or QA database after applying the migration.
do $test$
declare
  v_gate regprocedure := 'private.job_execution_gate(uuid,text)'::regprocedure;
  v_definition text;
begin
  v_definition := pg_catalog.pg_get_functiondef(v_gate);

  if not exists (
    select from pg_catalog.pg_proc p
    where p.oid = v_gate and p.prosecdef and p.provolatile = 's'
      and p.proowner = 'postgres'::regrole
      and p.proconfig = array['search_path=""']
      and p.proacl = array['postgres=X/postgres'::aclitem]
  ) then
    raise exception 'Job execution gate owner, mode, search path or ACL changed';
  end if;

  if pg_catalog.has_function_privilege('anon', v_gate, 'EXECUTE')
      or pg_catalog.has_function_privilege('authenticated', v_gate, 'EXECUTE')
      or pg_catalog.has_function_privilege('service_role', v_gate, 'EXECUTE') then
    raise exception 'An API role can execute the private job execution gate';
  end if;

  if pg_catalog.strpos(v_definition, $needle$coalesce(v_teen.verification_status::text, '') not in ('verified', 'approved')$needle$) = 0 then
    raise exception 'Teen verified status is not accepted by job_execution_gate';
  end if;

  if pg_catalog.strpos(v_definition, $needle$coalesce(v_adult.verification_status::text, '') not in ('verified', 'approved')$needle$) = 0 then
    raise exception 'Adult verified status is not accepted by job_execution_gate';
  end if;

  if pg_catalog.strpos(v_definition, $needle$v_teen.verification_status::text <> 'approved'$needle$) > 0
     or pg_catalog.strpos(v_definition, $needle$v_adult.verification_status::text <> 'approved'$needle$) > 0 then
    raise exception 'Legacy approved-only verification predicate remains';
  end if;
  -- Exercise the predicate semantics: verified and approved pass; rejected and NULL fail.
  if coalesce('verified'::text, '') not in ('verified', 'approved') then
    raise exception 'Verified status must be eligible';
  end if;
  if coalesce('approved'::text, '') not in ('verified', 'approved') then
    raise exception 'Legacy approved status must remain eligible';
  end if;
  if not (coalesce('rejected'::text, '') not in ('verified', 'approved')) then
    raise exception 'Rejected status must remain ineligible';
  end if;
  if not (coalesce('pending'::text, '') not in ('verified', 'approved')) then
    raise exception 'Pending status must remain ineligible';
  end if;
  if not (coalesce(null::text, '') not in ('verified', 'approved')) then
    raise exception 'Null verification status must remain ineligible';
  end if;

end
$test$;
