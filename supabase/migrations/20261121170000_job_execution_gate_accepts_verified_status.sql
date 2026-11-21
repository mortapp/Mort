-- Align job execution eligibility with the verification states actually written by review.
-- This migration changes only the teen/adult verification predicates in
-- private.job_execution_gate(uuid,text). It does not enable funding or payments.
do $migration$
declare
  v_definition text;
  v_updated text;
  v_teen_old constant text := 'v_teen.verification_status::text <> ''approved''';
  v_adult_old constant text := 'v_adult.verification_status::text <> ''approved''';
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'private.job_execution_gate(uuid,text)'::regprocedure
  );

  if pg_catalog.position(v_teen_old in v_definition) = 0
     or pg_catalog.position(v_adult_old in v_definition) = 0 then
    raise exception 'Expected production verification predicates were not found; refusing to rewrite function';
  end if;

  v_updated := pg_catalog.replace(
    v_definition,
    v_teen_old,
    'coalesce(v_teen.verification_status::text, '''') not in (''verified'', ''approved'')'
  );
  v_updated := pg_catalog.replace(
    v_updated,
    v_adult_old,
    'coalesce(v_adult.verification_status::text, '''') not in (''verified'', ''approved'')'
  );

  if v_updated = v_definition then
    raise exception 'No job_execution_gate verification changes were produced';
  end if;

  execute v_updated;

  v_definition := pg_catalog.pg_get_functiondef(
    'private.job_execution_gate(uuid,text)'::regprocedure
  );
  if pg_catalog.position(
       'coalesce(v_teen.verification_status::text, '''') not in (''verified'', ''approved'')'
       in v_definition
     ) = 0
     or pg_catalog.position(
       'coalesce(v_adult.verification_status::text, '''') not in (''verified'', ''approved'')'
       in v_definition
     ) = 0 then
    raise exception 'Post-migration verification predicate assertion failed';
  end if;
end
$migration$;
