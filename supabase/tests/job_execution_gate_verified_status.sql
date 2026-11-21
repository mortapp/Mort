-- Database regression assertion for migration 20261121170000.
-- Run against an isolated QA database after applying the migration.
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
end
$test$;
