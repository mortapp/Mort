-- Run only after applying the local proposal on a schema-matched disposable DB.
-- Authorization behavior needs seeded QA users/jobs and is specified in
-- MORT-FLUTTER-BACKEND-CONTRACT-DIFF.md; no production execution.
begin;
select plan(13);

select has_table('private', 'job_private_locations');
select has_table('private', 'job_private_location_requests');
select has_table('private', 'job_private_location_history');
select has_table('private', 'job_location_access_events');
select has_table('private', 'job_safety_agreement_history');
select has_function('public', 'save_job_private_location_v1', array['uuid', 'text', 'uuid']);
select has_function('public', 'record_job_location_geocode_v1', array['uuid', 'integer', 'double precision', 'double precision', 'text']);
select has_function('public', 'get_released_job_location_v1', array['uuid']);
select has_function('public', 'get_my_eligible_job_distance_bands_v1', array['uuid[]']);

select ok(not has_table_privilege('anon', 'private.job_private_locations', 'SELECT'),
  'anonymous callers cannot read private job addresses');
select ok(not has_table_privilege('authenticated', 'private.job_private_locations', 'SELECT'),
  'authenticated callers cannot read private job addresses directly');
select ok(not has_column_privilege('authenticated', 'public.jobs', 'exact_address', 'SELECT'),
  'ordinary authenticated job queries cannot select the legacy exact-address column');
select ok(not has_function_privilege('authenticated',
  'public.record_job_location_geocode_v1(uuid,integer,double precision,double precision,text)', 'EXECUTE'),
  'clients cannot submit geocoded coordinates');

select * from finish();
rollback;
