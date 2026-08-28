-- DEV/STAGING ONLY.
-- Do not run this against production.
-- Do not use fake auth users in app code.
-- Create real auth users through Supabase Auth Dashboard/API first, then replace the IDs below.

begin;

-- Trusted SQL seed/admin operation only. This lets the profile trigger allow first admin promotion.
select set_config('mort.internal_update', 'true', true);

with ids as (
  select
    '00000000-0000-0000-0000-000000000101'::uuid as teen_user_id,
    '00000000-0000-0000-0000-000000000102'::uuid as adult_user_id,
    '00000000-0000-0000-0000-000000000103'::uuid as guardian_user_id,
    '00000000-0000-0000-0000-000000000104'::uuid as admin_user_id
)
insert into public.profiles (id, role, display_name, dob, city, state, onboarding_completed, verification_status)
select teen_user_id, 'teen', 'QA Teen', (current_date - interval '15 years')::date, 'Carmel', 'IN', true, 'not_started' from ids
union all
select adult_user_id, 'adult', 'QA Adult', (current_date - interval '30 years')::date, 'Carmel', 'IN', true, 'approved' from ids
union all
select guardian_user_id, 'guardian', 'QA Guardian', (current_date - interval '35 years')::date, 'Carmel', 'IN', true, 'not_started' from ids
union all
select admin_user_id, 'admin', 'QA Admin', (current_date - interval '40 years')::date, 'Carmel', 'IN', true, 'not_started' from ids
on conflict (id) do update
set role = excluded.role,
    display_name = excluded.display_name,
    dob = excluded.dob,
    city = excluded.city,
    state = excluded.state,
    onboarding_completed = excluded.onboarding_completed,
    verification_status = excluded.verification_status;

with ids as (
  select
    '00000000-0000-0000-0000-000000000101'::uuid as teen_user_id,
    '00000000-0000-0000-0000-000000000102'::uuid as adult_user_id,
    '00000000-0000-0000-0000-000000000103'::uuid as guardian_user_id
)
insert into public.teen_profiles (user_id, guardian_approval_required, skills)
select teen_user_id, true, array['yard work', 'pet care'] from ids
on conflict (user_id) do update set guardian_approval_required = excluded.guardian_approval_required, skills = excluded.skills;

with ids as (
  select '00000000-0000-0000-0000-000000000102'::uuid as adult_user_id
)
insert into public.adult_profiles (user_id, business_name, business_type)
select adult_user_id, 'QA Local Business', 'home services' from ids
on conflict (user_id) do update set business_name = excluded.business_name, business_type = excluded.business_type;

with ids as (
  select '00000000-0000-0000-0000-000000000103'::uuid as guardian_user_id
)
insert into public.guardian_profiles (user_id, emergency_contact_name)
select guardian_user_id, 'QA Guardian Contact' from ids
on conflict (user_id) do update set emergency_contact_name = excluded.emergency_contact_name;

with ids as (
  select
    '00000000-0000-0000-0000-000000000101'::uuid as teen_user_id,
    '00000000-0000-0000-0000-000000000103'::uuid as guardian_user_id
)
insert into public.guardian_connections (id, teen_id, guardian_id, status, invite_code)
select '10000000-0000-0000-0000-000000000201'::uuid, teen_user_id, guardian_user_id, 'active', 'QATEST01' from ids
on conflict (id) do update set teen_id = excluded.teen_id, guardian_id = excluded.guardian_id, status = excluded.status;

with ids as (
  select
    '00000000-0000-0000-0000-000000000102'::uuid as adult_user_id,
    '00000000-0000-0000-0000-000000000104'::uuid as admin_user_id
)
insert into public.business_verifications (id, adult_id, business_name, business_type, notes, status, reviewed_by)
select '10000000-0000-0000-0000-000000000301'::uuid, adult_user_id, 'QA Local Business', 'home services', 'Local/staging seed verification.', 'approved', admin_user_id
from ids
on conflict (id) do update set status = excluded.status, reviewed_by = excluded.reviewed_by;

with ids as (
  select '00000000-0000-0000-0000-000000000102'::uuid as adult_user_id
)
insert into public.jobs (id, poster_id, title, description, category, location_text, city, state, pay_label, teen_min_age, teen_max_age, requires_guardian_approval, status)
select '10000000-0000-0000-0000-000000000401'::uuid, adult_user_id, 'QA Yard Cleanup', 'Rake leaves and bag yard waste.', 'yard work', 'Near Main St', 'Carmel', 'IN', '$40 after completion', 13, 17, true, 'open'
from ids
on conflict (id) do update set title = excluded.title, status = excluded.status;

with ids as (
  select
    '00000000-0000-0000-0000-000000000101'::uuid as teen_user_id,
    '00000000-0000-0000-0000-000000000103'::uuid as guardian_user_id,
    '10000000-0000-0000-0000-000000000401'::uuid as job_id
)
insert into public.applications (id, job_id, teen_id, guardian_id, status, note)
select '10000000-0000-0000-0000-000000000501'::uuid, job_id, teen_user_id, guardian_user_id, 'accepted', 'QA accepted application.'
from ids
on conflict (id) do update set status = excluded.status, guardian_id = excluded.guardian_id;

insert into public.proof_uploads (id, application_id, uploaded_by, storage_path, note)
values (
  '10000000-0000-0000-0000-000000000601',
  '10000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000101/qa-proof.jpg',
  'Seed proof record. Upload a matching object in local/staging Storage before signed-preview testing.'
)
on conflict (id) do update set note = excluded.note;

insert into public.messages (thread_id, sender_id, body, scanner_status)
select mt.id, '00000000-0000-0000-0000-000000000101'::uuid, 'I can do this after school and will keep updates in MORT.', 'clean'
from public.message_threads mt
where mt.application_id = '10000000-0000-0000-0000-000000000501'
limit 1;

insert into public.reports (id, reporter_id, target_user_id, target_job_id, reason, details, status)
values (
  '10000000-0000-0000-0000-000000000701',
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000102',
  '10000000-0000-0000-0000-000000000401',
  'QA moderation test',
  'Seed report for admin queue testing.',
  'open'
)
on conflict (id) do update set status = excluded.status;

insert into public.safety_pings (id, teen_id, guardian_id, status, note)
values (
  '10000000-0000-0000-0000-000000000801',
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000103',
  'ok',
  'Seed safety ping.'
)
on conflict (id) do nothing;

insert into public.notification_events (id, recipient_id, title, body, data)
values (
  '10000000-0000-0000-0000-000000000901',
  '00000000-0000-0000-0000-000000000103',
  'MORT QA notification',
  'Open MORT for details.',
  '{"type":"qa-seed"}'
)
on conflict (id) do update set status = 'pending', last_error = null, sent_at = null;

commit;
