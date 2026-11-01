-- Run only on a disposable database matching production's active migration set,
-- after applying the proposal. This transaction leaves no QA rows behind.
begin;
select plan(5);

insert into auth.users(id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('70000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'qa-reviewer@example.invalid', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('70000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'qa-teen@example.invalid', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('70000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'qa-adult@example.invalid', '', '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.profiles(id, role, account_status, date_of_birth)
values
  ('70000000-0000-4000-8000-000000000001', 'admin', 'active', current_date - interval '40 years'),
  ('70000000-0000-4000-8000-000000000002', 'teen', 'active', current_date - interval '16 years'),
  ('70000000-0000-4000-8000-000000000003', 'pending', 'pending', current_date - interval '25 years');
insert into private.user_roles(user_id, role)
values ('70000000-0000-4000-8000-000000000001', 'admin');
insert into public.verification_cases(user_id, verification_type, status, submitted_at, reviewed_at)
values
  ('70000000-0000-4000-8000-000000000002', 'identity', 'verified', now(), now()),
  ('70000000-0000-4000-8000-000000000003', 'identity', 'verified', now(), now());
insert into public.role_requests(id, user_id, requested_role, status)
values
  ('71000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000002', 'adult', 'pending'),
  ('71000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000003', 'adult', 'pending');

select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$select public.mort_review_role_request('71000000-0000-4000-8000-000000000001', true, 'QA minor role escalation')$$,
  'P0001', 'adult_minimum_age_required',
  'a verified identity case cannot promote a teen with a DOB under 18 to adult'
);
select is(
  (select role::text from public.profiles where id = '70000000-0000-4000-8000-000000000002'),
  'teen', 'rejected adult escalation leaves teen role intact'
);
select is(
  (select status from public.role_requests where id = '71000000-0000-4000-8000-000000000001'),
  'pending', 'rejected adult escalation leaves role request pending for safe review'
);
select lives_ok(
  $$select public.mort_review_role_request('71000000-0000-4000-8000-000000000002', true, 'QA adult role approval')$$,
  'an 18+ applicant with verified identity can be approved as adult'
);
select is(
  (select role::text from public.profiles where id = '70000000-0000-4000-8000-000000000003'),
  'adult', 'eligible adult is assigned the requested role'
);
select * from finish();
rollback;
