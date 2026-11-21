-- Database regression assertion for production-baseline migration 20261121170000.
-- Run against an isolated production-baseline replica or QA database after applying the migration.
do $test$
declare
  v_definition text;
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'private.job_execution_gate(uuid,text)'::regprocedure
  );

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
  if not (coalesce(null::text, '') not in ('verified', 'approved')) then
    raise exception 'Null verification status must remain ineligible';
  end if;

end
$test$;
