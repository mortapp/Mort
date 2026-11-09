-- Issue #70 regression contract for public.get_my_job_applications(uuid).
-- Run only against a disposable local database reconstructed from production
-- migrations with scripts/qa-issue-70-guardian-application-reader.ps1. The
-- runner applies the proposal and these fixtures in one rollback transaction.
-- All synthetic users and rows are rolled back at the end.
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public, auth, pg_catalog;

select plan(51);

create temporary table issue70_users (
  user_key text primary key,
  id uuid not null default gen_random_uuid(),
  profile_role public.mort_role not null,
  account_status text not null,
  date_of_birth date,
  email_confirmed boolean not null
) on commit drop;

insert into issue70_users (user_key, profile_role, account_status, date_of_birth, email_confirmed)
values
  ('applicant', 'teen', 'active', date '2010-01-01', true),
  ('other_applicant', 'teen', 'active', date '2010-01-01', true),
  ('poster', 'adult', 'active', date '1988-01-01', true),
  ('eligible_guardian', 'guardian', 'active', date '1980-01-01', true),
  ('underage_account', 'pending', 'active', date '2010-01-01', true),
  ('unverified_guardian', 'guardian', 'active', date '1980-01-01', false),
  ('inactive_guardian', 'guardian', 'suspended', date '1980-01-01', true),
  ('wrong_role_adult', 'adult', 'active', date '1980-01-01', true),
  ('missing_dob_guardian', 'guardian', 'active', null, true),
  ('missing_teen_consent_guardian', 'guardian', 'active', date '1980-01-01', true),
  ('missing_guardian_consent_guardian', 'guardian', 'active', date '1980-01-01', true),
  ('pending_link_guardian', 'guardian', 'active', date '1980-01-01', true),
  ('revoked_link_guardian', 'guardian', 'active', date '1980-01-01', true),
  ('unrelated_adult', 'adult', 'active', date '1980-01-01', true),
  ('administrator', 'admin', 'active', date '1980-01-01', true);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, invited_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  u.id,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated',
  'authenticated',
  u.user_key || '@issue70.example.test',
  '',
  case when u.email_confirmed then now() else null end,
  case when u.date_of_birth is null then now() else null end,
  '{}'::jsonb,
  jsonb_build_object('date_of_birth', u.date_of_birth::text, 'display_name', u.user_key),
  now(),
  now()
from issue70_users u;

update public.profiles p
set role = u.profile_role,
    account_status = u.account_status,
    date_of_birth = u.date_of_birth
from issue70_users u
where p.id = u.id;

create temporary table issue70_jobs (
  job_key text primary key,
  id uuid not null default gen_random_uuid()
) on commit drop;

insert into issue70_jobs (job_key) values ('primary'), ('other_applicant');

insert into public.jobs (
  id, poster_id, title, description, category, status, pay_amount, city, region,
  safety_review_status, requires_guardian_approval
)
select
  j.id,
  (select id from issue70_users where user_key = 'poster'),
  'Synthetic job ' || j.job_key,
  'Synthetic job description used only by this rolled-back authorization test.',
  'other',
  'open',
  10,
  'Test City',
  'Test Region',
  'approved',
  false
from issue70_jobs j;

create temporary table issue70_applications (
  app_key text primary key,
  id uuid not null default gen_random_uuid()
) on commit drop;

insert into issue70_applications (app_key) values ('applicant'), ('other_applicant');

insert into public.job_applications (id, job_id, applicant_id, guardian_id, availability_confirmed)
select
  a.id,
  (select id from issue70_jobs where job_key = case when a.app_key = 'applicant' then 'primary' else a.app_key end),
  (select id from issue70_users where user_key = a.app_key),
  (select id from issue70_users where user_key = 'eligible_guardian'),
  true
from issue70_applications a;

insert into public.guardian_links (
  teen_user_id, guardian_user_id, status, initiated_by, teen_consent_at, guardian_consent_at
)
select
  (select id from issue70_users where user_key = 'applicant'),
  u.id,
  case when u.user_key = 'eligible_guardian' then 'active' else 'revoked' end,
  (select id from issue70_users where user_key = 'applicant'),
  case when u.user_key = 'missing_teen_consent_guardian' then null else now() end,
  case when u.user_key = 'missing_guardian_consent_guardian' then null else now() end
from issue70_users u
where u.user_key in (
  'eligible_guardian', 'underage_account', 'unverified_guardian',
  'inactive_guardian', 'wrong_role_adult', 'missing_dob_guardian',
  'missing_teen_consent_guardian', 'missing_guardian_consent_guardian',
  'pending_link_guardian', 'revoked_link_guardian'
);

select ok(
  (select p.prosecdef from pg_proc p where p.oid = 'public.get_my_job_applications(uuid)'::regprocedure),
  'reader remains SECURITY DEFINER'
);
select ok(
  (select 'search_path=""' = any(p.proconfig) from pg_proc p where p.oid = 'public.get_my_job_applications(uuid)'::regprocedure),
  'reader keeps an empty search_path'
);
select ok(not has_function_privilege('anon', 'public.get_my_job_applications(uuid)', 'EXECUTE'), 'anon cannot execute the reader');
select ok(has_function_privilege('authenticated', 'public.get_my_job_applications(uuid)', 'EXECUTE'), 'authenticated can execute the reader');
select ok(has_function_privilege('service_role', 'public.get_my_job_applications(uuid)', 'EXECUTE'), 'service_role keeps existing execute access');
select ok(has_table_privilege('service_role', 'public.job_applications', 'SELECT'), 'service_role keeps existing direct application SELECT');
select ok(
  (select p.prosecdef from pg_proc p where p.oid = 'public.update_my_job_application_status(uuid,text,timestamptz)'::regprocedure),
  'status-update RPC remains SECURITY DEFINER'
);
select ok(
  (select 'search_path=""' = any(p.proconfig) from pg_proc p where p.oid = 'public.update_my_job_application_status(uuid,text,timestamptz)'::regprocedure),
  'status-update RPC keeps an empty search_path'
);
select ok(not has_function_privilege('anon', 'public.update_my_job_application_status(uuid,text,timestamptz)', 'EXECUTE'), 'anon cannot execute status-update RPC');
select ok(has_function_privilege('authenticated', 'public.update_my_job_application_status(uuid,text,timestamptz)', 'EXECUTE'), 'authenticated retains status-update RPC access');
select ok(not has_table_privilege('anon', 'public.job_applications', 'SELECT'), 'anon has no direct application SELECT');
select ok(not has_table_privilege('authenticated', 'public.job_applications', 'SELECT'), 'authenticated has no direct application SELECT');
select ok(
  position('private.is_admin()' in pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure)) = 0,
  'reader does not add a broad administrator bypass'
);
select is(
  (length(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure)) -
   length(replace(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure), 'guardian_profile.role', ''))) /
   length('guardian_profile.role'),
  3,
  'Guardian role is checked at account gate, row selection, and ID disclosure'
);
select is(
  (length(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure)) -
   length(replace(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure), 'guardian_profile.account_status', ''))) /
   length('guardian_profile.account_status'),
  3,
  'active account is checked at account gate, row selection, and ID disclosure'
);
select is(
  (length(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure)) -
   length(replace(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure), 'guardian_profile.date_of_birth is not null', ''))) /
   length('guardian_profile.date_of_birth is not null'),
  3,
  'DOB presence is checked at account gate, row selection, and ID disclosure'
);
select is(
  (length(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure)) -
   length(replace(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure), 'extract(year from age(current_date', ''))) /
   length('extract(year from age(current_date'),
  3,
  'age 18+ is checked at account gate, row selection, and ID disclosure'
);
select is(
  (length(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure)) -
   length(replace(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure), 'guardian_auth.email_confirmed_at is not null', ''))) /
   length('guardian_auth.email_confirmed_at is not null'),
  3,
  'confirmed email is checked at account gate, row selection, and ID disclosure'
);
select is(
  (length(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure)) -
   length(replace(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure), 'gl.teen_consent_at is not null', ''))) /
   length('gl.teen_consent_at is not null'),
  2,
  'teen consent is checked in both row selection and ID disclosure'
);
select is(
  (length(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure)) -
   length(replace(pg_get_functiondef('public.get_my_job_applications(uuid)'::regprocedure), 'gl.guardian_consent_at is not null', ''))) /
   length('gl.guardian_consent_at is not null'),
  2,
  'Guardian consent is checked in both row selection and ID disclosure'
);

select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'eligible_guardian'), true);
select is(
  jsonb_array_length(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items'),
  1,
  'eligible connected Guardian can read the linked teen application'
);
select is(
  public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items'->0->>'guardian_id',
  (select id::text from issue70_users where user_key = 'eligible_guardian'),
  'eligible connected Guardian receives the intended Guardian ID'
);
select is(
  jsonb_array_length(public.get_my_job_applications((select id from issue70_applications where app_key = 'other_applicant'))->'items'),
  0,
  'eligible Guardian cannot read an unrelated teen application'
);
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'applicant'), true);
select is(
  jsonb_array_length(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items'),
  1,
  'teen applicant can read their own application'
);
select is(
  public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items'->0->>'guardian_id',
  (select id::text from issue70_users where user_key = 'eligible_guardian'),
  'teen applicant retains Guardian ID visibility'
);

select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'poster'), true);
select is(
  jsonb_array_length(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items'),
  1,
  'job poster can read applications for their own job'
);
select is(
  public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items'->0->'guardian_id',
  'null'::jsonb,
  'job poster receives a masked Guardian ID'
);
select is(
  public.update_my_job_application_status((select id from issue70_applications where app_key = 'applicant'), 'viewed')->>'ok',
  'true',
  'job poster status update returns an authorized nested application response'
);
select is(
  public.update_my_job_application_status((select id from issue70_applications where app_key = 'applicant'), 'viewed')->'application'->>'id',
  (select id::text from issue70_applications where app_key = 'applicant'),
  'nested status response contains only the poster-owned application'
);
select is(
  public.update_my_job_application_status((select id from issue70_applications where app_key = 'applicant'), 'viewed')->'application'->'guardian_id',
  'null'::jsonb,
  'nested status response masks Guardian ID from the job poster'
);
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'administrator'), true);
select is(
  jsonb_array_length(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items'),
  0,
  'administrator does not receive applications through the user-facing reader'
);
create temporary table issue70_admin_status_response (response jsonb) on commit drop;
insert into issue70_admin_status_response (response)
select public.update_my_job_application_status(
  (select id from issue70_applications where app_key = 'applicant'),
  'viewed'
);
select ok(
  not (select response ? 'application' from issue70_admin_status_response),
  'administrator does not receive application data through the status-update response'
);
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'applicant'), true);
create temporary table issue70_status_response (response jsonb) on commit drop;
insert into issue70_status_response (response)
select public.update_my_job_application_status(
  (select id from issue70_applications where app_key = 'applicant'),
  'withdrawn'
);
select is(
  (select response->>'ok' from issue70_status_response),
  'true',
  'teen withdrawal returns an authorized nested application response'
);
select is(
  (select response->'application'->>'guardian_id' from issue70_status_response),
  (select id::text from issue70_users where user_key = 'eligible_guardian'),
  'nested status response preserves Guardian ID for the applicant'
);
select is(
  public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items'->0->>'guardian_id',
  (select id::text from issue70_users where user_key = 'eligible_guardian'),
  'applicant retains Guardian ID in direct reader after withdrawal'
);

select is(
  public.unlink_guardian((select id from public.guardian_links where guardian_user_id = (select id from issue70_users where user_key = 'eligible_guardian'))),
  jsonb_build_object(
    'ok', true,
    'status', 'revoked',
    'link_id', (select id from public.guardian_links where guardian_user_id = (select id from issue70_users where user_key = 'eligible_guardian'))
  ),
  'teen revocation RPC succeeds for the connected Guardian link'
);
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'eligible_guardian'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'Guardian loses application access after the supported unlink operation'
);
select is(
  public.update_my_job_application_status((select id from issue70_applications where app_key = 'applicant'), 'viewed')->>'code',
  'active_account_required',
  'Guardian status-update call is denied by the active-account gate'
);
select ok(
  not (public.update_my_job_application_status((select id from issue70_applications where app_key = 'applicant'), 'viewed') ? 'application'),
  'unauthorized Guardian status response contains no application object'
);

update public.guardian_links
set status = 'active'
where guardian_user_id = (select id from issue70_users where user_key = 'underage_account');
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'underage_account'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'underage account receives no application data'
);
update public.guardian_links
set status = 'revoked'
where guardian_user_id = (select id from issue70_users where user_key = 'underage_account');
select throws_ok(
  format('update public.profiles set role = %L::public.mort_role where id = %L::uuid',
    'guardian', (select id from issue70_users where user_key = 'underage_account')),
  '23514',
  'MORT_MINOR_ROLE_REQUIRED',
  'database rejects an underage Guardian profile'
);

update public.guardian_links
set status = 'active'
where guardian_user_id = (select id from issue70_users where user_key = 'unverified_guardian');
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'unverified_guardian'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'Guardian with unconfirmed Auth email receives no application data'
);
update public.guardian_links
set status = 'revoked'
where guardian_user_id = (select id from issue70_users where user_key = 'unverified_guardian');

update public.guardian_links
set status = 'active'
where guardian_user_id = (select id from issue70_users where user_key = 'inactive_guardian');
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'inactive_guardian'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'inactive Guardian receives no application data'
);
update public.guardian_links
set status = 'revoked'
where guardian_user_id = (select id from issue70_users where user_key = 'inactive_guardian');

update public.guardian_links
set status = 'active'
where guardian_user_id = (select id from issue70_users where user_key = 'wrong_role_adult');
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'wrong_role_adult'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'active adult with a Guardian link but the wrong profile role receives no application data'
);
update public.guardian_links
set status = 'revoked'
where guardian_user_id = (select id from issue70_users where user_key = 'wrong_role_adult');

update public.guardian_links
set status = 'active'
where guardian_user_id = (select id from issue70_users where user_key = 'missing_dob_guardian');
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'missing_dob_guardian'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'Guardian profile with no DOB receives no application data'
);
update public.guardian_links
set status = 'revoked'
where guardian_user_id = (select id from issue70_users where user_key = 'missing_dob_guardian');

update public.guardian_links
set status = 'active'
where guardian_user_id = (select id from issue70_users where user_key = 'missing_teen_consent_guardian');
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'missing_teen_consent_guardian'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'Guardian with missing teen consent receives no application data'
);
update public.guardian_links
set status = 'revoked'
where guardian_user_id = (select id from issue70_users where user_key = 'missing_teen_consent_guardian');

update public.guardian_links
set status = 'active'
where guardian_user_id = (select id from issue70_users where user_key = 'missing_guardian_consent_guardian');
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'missing_guardian_consent_guardian'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'Guardian with missing Guardian consent receives no application data'
);
update public.guardian_links
set status = 'revoked'
where guardian_user_id = (select id from issue70_users where user_key = 'missing_guardian_consent_guardian');

update public.guardian_links
set status = 'pending'
where guardian_user_id = (select id from issue70_users where user_key = 'pending_link_guardian');
select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'pending_link_guardian'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'Guardian with an inactive pending link receives no application data'
);

select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'revoked_link_guardian'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'Guardian with a revoked link receives no application data'
);

select set_config('request.jwt.claim.sub', (select id::text from issue70_users where user_key = 'unrelated_adult'), true);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_applications where app_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'unrelated user receives no application data'
);
select is(
  jsonb_array_length(coalesce(public.get_my_job_applications((select id from issue70_users where user_key = 'applicant'))->'items', '[]'::jsonb)),
  0,
  'direct RPC call with another user UUID as the application parameter returns no data'
);

select * from finish();
rollback;
