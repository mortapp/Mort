-- Run only after replaying the proposed safety migrations in the isolated
-- production-schema QA database. This catalog suite is not a substitute for
-- seeded authorization and two-session lifecycle tests.
begin;
select plan(20);

select has_table('private', 'job_private_locations', 'private job locations table exists');
select has_table('private', 'job_private_location_requests', 'private location idempotency table exists');
select has_table('private', 'job_private_location_history', 'private location history table exists');
select has_table('private', 'job_private_location_access_events', 'private location access log exists');
select has_table('private', 'job_safety_agreement_history', 'private safety agreement history exists');

select has_function('public', 'save_job_private_location_v1', array['uuid', 'text', 'text', 'text', 'uuid']);
select has_function('public', 'get_released_job_location', array['uuid']);

select ok(not has_table_privilege('anon', 'private.job_private_locations', 'SELECT'),
  'anonymous callers cannot read private job addresses');
select ok(not has_table_privilege('authenticated', 'private.job_private_locations', 'SELECT'),
  'authenticated callers cannot read private job addresses directly');
select ok(not has_table_privilege('authenticated', 'private.job_private_location_history', 'SELECT'),
  'authenticated callers cannot read prior private address versions');
select ok(not has_table_privilege('authenticated', 'private.job_safety_agreement_history', 'SELECT'),
  'authenticated callers cannot read archived safety agreements');
select ok(not has_column_privilege('authenticated', 'public.jobs', 'exact_address', 'SELECT'),
  'ordinary authenticated job queries cannot select the legacy exact-address column');

select ok(has_function_privilege('authenticated',
  'public.save_job_private_location_v1(uuid,text,text,text,uuid)', 'EXECUTE'),
  'authenticated adult job owners can call the owner-checked save RPC');
select ok(not has_function_privilege('anon',
  'public.save_job_private_location_v1(uuid,text,text,text,uuid)', 'EXECUTE'),
  'anonymous callers cannot write private locations');
select ok(has_function_privilege('authenticated',
  'public.get_released_job_location(uuid)', 'EXECUTE'),
  'authenticated callers use the authorization-checked exact-location RPC');
select ok(not has_function_privilege('anon',
  'public.get_released_job_location(uuid)', 'EXECUTE'),
  'anonymous callers cannot request exact locations');

select ok(position('v_assignment.adult_user_id = v_job.poster_id' in lower(pg_get_functiondef(
  'public.get_released_job_location(uuid)'::regprocedure
))) > 0, 'assignment adult and job owner must match');
select ok(position('v_agreement.location_version = v_location.location_version' in lower(pg_get_functiondef(
  'public.get_released_job_location(uuid)'::regprocedure
))) > 0, 'release requires the confirmed current location version');
select ok(position('v_location.poster_id is distinct from v_job.poster_id' in lower(pg_get_functiondef(
  'public.get_released_job_location(uuid)'::regprocedure
))) > 0, 'release denies private location rows whose owner differs from the job owner');
select ok(position('if v_job.status::text in (''cancelled'', ''completed'')' in lower(pg_get_functiondef(
  'public.get_released_job_location(uuid)'::regprocedure
))) > position('from public.jobs job' in lower(pg_get_functiondef(
  'public.get_released_job_location(uuid)'::regprocedure
))), 'terminal state is checked only after the locked job row is loaded');

select * from finish();
rollback;
