-- Seeded authorization checks for the private-location contract. Execute only
-- against an isolated database after replaying the production schema snapshot
-- and candidate migrations. All fixtures are rolled back at the end.
begin;
select plan(9);

insert into auth.users (
  id, aud, role, email, encrypted_password, raw_app_meta_data,
  raw_user_meta_data, created_at, updated_at, email_confirmed_at
) values
  ('a1000000-0000-4000-8000-000000000041', 'authenticated', 'authenticated', 'location-owner@example.invalid', '', '{}', '{"date_of_birth":"2000-01-01"}', now(), now(), now()),
  ('a1000000-0000-4000-8000-000000000042', 'authenticated', 'authenticated', 'location-teen@example.invalid', '', '{}', '{"date_of_birth":"2010-01-01"}', now(), now(), now()),
  ('a1000000-0000-4000-8000-000000000043', 'authenticated', 'authenticated', 'location-outsider@example.invalid', '', '{}', '{"date_of_birth":"2000-01-01"}', now(), now(), now());

update public.profiles set role = 'adult', account_status = 'active'
where id = 'a1000000-0000-4000-8000-000000000041';
update public.profiles set role = 'teen', account_status = 'active'
where id = 'a1000000-0000-4000-8000-000000000042';
update public.profiles set role = 'adult', account_status = 'active'
where id = 'a1000000-0000-4000-8000-000000000043';

insert into public.jobs (
  id, poster_id, title, description, category, pay_amount, city, region,
  status, safety_review_status
) values (
  'a2000000-0000-4000-8000-000000000041',
  'a1000000-0000-4000-8000-000000000041',
  'Private location QA',
  'This fixture description is long enough to pass publication validation.',
  'yard_work', 20, 'Indianapolis', 'IN', 'open', 'approved'
);
insert into public.job_applications (id, job_id, applicant_id, status)
values (
  'a3000000-0000-4000-8000-000000000041',
  'a2000000-0000-4000-8000-000000000041',
  'a1000000-0000-4000-8000-000000000042',
  'accepted'
);

select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000041', true);
select is(
  (public.save_job_private_location_v1(
    'a2000000-0000-4000-8000-000000000041',
    '501 Synthetic QA Lane', 'Meet at the front gate', null,
    'a4000000-0000-4000-8000-000000000041'
  )->>'ok')::boolean,
  true,
  'active job owner can save an exact address through the protected RPC'
);
select ok(
  not (public.save_job_private_location_v1(
    'a2000000-0000-4000-8000-000000000041',
    '501 Synthetic QA Lane', 'Meet at the front gate', null,
    'a4000000-0000-4000-8000-000000000041'
  ) ? 'exact_address'),
  'save response does not echo the exact address'
);

select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000043', true);
select is(
  public.get_released_job_location('a3000000-0000-4000-8000-000000000041')->>'code',
  'exact_location_not_released',
  'unrelated user is denied exact location'
);
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000042', true);
select is(
  public.get_released_job_location('a3000000-0000-4000-8000-000000000041')->>'code',
  'exact_location_not_released',
  'applicant without an active assignment is denied exact location'
);

insert into public.job_assignments (
  job_id, application_id, teen_user_id, adult_user_id, status,
  agreed_amount, accepted_at, started_at
) values (
  'a2000000-0000-4000-8000-000000000041',
  'a3000000-0000-4000-8000-000000000041',
  'a1000000-0000-4000-8000-000000000042',
  'a1000000-0000-4000-8000-000000000041',
  'in_progress', 20, now(), now()
);
insert into public.job_safety_agreements (
  application_id, job_id, teen_id, adult_id, agreement_version,
  terms_snapshot, material_terms_hash, status, teen_confirmed_at,
  adult_confirmed_at, teen_confirmed_version, adult_confirmed_version,
  location_version
) values (
  'a3000000-0000-4000-8000-000000000041',
  'a2000000-0000-4000-8000-000000000041',
  'a1000000-0000-4000-8000-000000000042',
  'a1000000-0000-4000-8000-000000000041',
  1, '{}'::jsonb, repeat('a', 64), 'confirmed', now(), now(), 1, 1, 1
);
update public.jobs
set status = 'in_progress'
where id = 'a2000000-0000-4000-8000-000000000041';

select ok(
  (public.get_released_job_location('a3000000-0000-4000-8000-000000000041')->>'exact_address') = '501 Synthetic QA Lane',
  'properly assigned teen receives exact location only after current dual-confirmed agreement'
);
insert into public.user_blocks (blocker_id, blocked_id)
values (
  'a1000000-0000-4000-8000-000000000041',
  'a1000000-0000-4000-8000-000000000042'
);
select is(
  public.get_released_job_location('a3000000-0000-4000-8000-000000000041')->>'code',
  'exact_location_not_released',
  'block between assigned participants immediately revokes exact-location access'
);
delete from public.user_blocks
where blocker_id = 'a1000000-0000-4000-8000-000000000041'
  and blocked_id = 'a1000000-0000-4000-8000-000000000042';
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000041', true);
select ok(
  (public.get_released_job_location('a3000000-0000-4000-8000-000000000041')->>'exact_address') = '501 Synthetic QA Lane',
  'job owner can read its exact location while the job is active'
);
update public.job_safety_agreements
set location_version = location_version + 1
where application_id = 'a3000000-0000-4000-8000-000000000041';
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000042', true);
select is(
  public.get_released_job_location('a3000000-0000-4000-8000-000000000041')->>'code',
  'exact_location_not_released',
  'stale location-version confirmation denies assigned teen access'
);
update public.jobs
set status = 'cancelled'
where id = 'a2000000-0000-4000-8000-000000000041';
select is(
  public.get_released_job_location('a3000000-0000-4000-8000-000000000041')->>'code',
  'exact_location_not_released',
  'cancelled job denies exact-location access'
);

select * from finish();
rollback;
