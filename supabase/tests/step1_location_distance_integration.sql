-- Docker-only integration test for the Step 1 location notification and
-- coarse-distance migrations. Fixtures are synthetic and rolled back.
begin;

insert into public.mort_release_control (is_primary, release_mode, maintenance_mode, public_marketplace_enabled)
values (true, 'production_public', false, true)
on conflict (is_primary) do update
set maintenance_mode = false, public_marketplace_enabled = true;

create temporary table step1_ids (
  teen_id uuid, adult_id uuid, unverified_teen_id uuid,
  job_id uuid, closed_job_id uuid, guardian_job_id uuid,
  application_id uuid
) on commit drop;

insert into step1_ids values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid());
grant select on step1_ids to authenticated;

insert into auth.users (id, aud, role, email, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select teen_id, 'authenticated', 'authenticated', teen_id||'@step1.test', now(),
  '{"provider":"google"}'::jsonb, jsonb_build_object('date_of_birth', (current_date - interval '15 years')::date::text), now(), now()
from step1_ids
union all
select adult_id, 'authenticated', 'authenticated', adult_id||'@step1.test', now(),
  '{"provider":"google"}'::jsonb, jsonb_build_object('date_of_birth', (current_date - interval '30 years')::date::text), now(), now()
from step1_ids
union all
select unverified_teen_id, 'authenticated', 'authenticated', unverified_teen_id||'@step1.test', now(),
  '{"provider":"google"}'::jsonb, jsonb_build_object('date_of_birth', (current_date - interval '15 years')::date::text), now(), now()
from step1_ids;

update public.profiles p set role = 'teen', account_status = 'active'
from step1_ids i where p.id in (i.teen_id, i.unverified_teen_id);
update public.profiles p set role = 'adult', account_status = 'active'
from step1_ids i where p.id = i.adult_id;

insert into public.verification_cases (id, user_id, verification_type, status, submitted_at, reviewed_at)
select gen_random_uuid(), teen_id, 'age', 'verified', now(), now() from step1_ids;

insert into public.jobs (id, poster_id, title, description, category, pay_type, pay_amount,
  status, safety_review_status, applications_open, age_min, age_max, city, region,
  requires_guardian_approval)
select job_id, adult_id, 'Step one test job', 'Synthetic job description for local contract testing.',
  'yard_work', 'fixed', 20, 'open'::public.mort_job_status, 'approved', true, 13, 17, 'Indianapolis', 'IN', false
from step1_ids
union all
select closed_job_id, adult_id, 'Step one closed job', 'Synthetic closed job description for local contract testing.',
  'yard_work', 'fixed', 20, 'filled'::public.mort_job_status, 'approved', false, 13, 17, 'Indianapolis', 'IN', false
from step1_ids
union all
select guardian_job_id, adult_id, 'Step one guardian job', 'Synthetic Guardian-gated job description for testing.',
  'yard_work', 'fixed', 20, 'open'::public.mort_job_status, 'approved', true, 13, 17, 'Indianapolis', 'IN', true
from step1_ids;

insert into public.job_applications (id, job_id, applicant_id, status)
select application_id, job_id, teen_id, 'accepted' from step1_ids;

insert into public.job_safety_agreements (application_id, job_id, teen_id, adult_id,
  agreement_version, terms_snapshot, material_terms_hash, status,
  teen_confirmed_at, adult_confirmed_at, teen_confirmed_version, adult_confirmed_version)
select application_id, job_id, teen_id, adult_id, 1, '{}'::jsonb,
  encode(extensions.digest('seed', 'sha256'), 'hex'), 'confirmed', now(), now(), 1, 1
from step1_ids;

select private.refresh_job_safety_agreement(application_id) from step1_ids;

do $$
declare
  i step1_ids%rowtype;
  v_count integer;
  v_agreement public.job_safety_agreements%rowtype;
begin
  select * into i from step1_ids;
  select * into v_agreement from public.job_safety_agreements where application_id = i.application_id;
  if v_agreement.status <> 'reconfirmation_required'
     or v_agreement.agreement_version <> 2
     or v_agreement.teen_confirmed_at is not null
     or v_agreement.adult_confirmed_at is not null then
    raise exception 'FAIL: agreement was not invalidated/reset';
  end if;
  select count(*) into v_count from public.notifications
  where notification_type = 'safety_reconfirmation_required'
    and user_id in (i.teen_id, i.adult_id)
    and data->>'application_id' = i.application_id::text
    and (data->>'agreement_version')::integer = 2;
  if v_count <> 2 then raise exception 'FAIL: expected both party notifications, got %', v_count; end if;
end;
$$;

-- Adult owner may save an approximate center. Server rounding is asserted.
select set_config('request.jwt.claim.sub', teen_id::text, true) from step1_ids;
set local role authenticated;
do $$
declare i step1_ids%rowtype; v jsonb;
begin
  select * into i from step1_ids;
  v := public.get_job_distance_v1(i.job_id, 39.7684, -86.1581);
  if v->>'code' <> 'age_verification_required' then
    raise exception 'FAIL: unverified teen not denied: %', v;
  end if;
end;
$$;
reset role;
select set_config('request.jwt.claim.sub', adult_id::text, true) from step1_ids;
set local role authenticated;
do $$
declare i step1_ids%rowtype; v jsonb;
begin
  select * into i from step1_ids;
  v := public.set_job_approx_location_v1(i.job_id, 39.7684, -86.1581);
  if v->>'ok' <> 'true' then raise exception 'FAIL: adult owner cannot save approximate center: %', v; end if;
  v := public.set_job_approx_location_v1(i.closed_job_id, 39.7684, -86.1581);
  if v->>'ok' <> 'false' then raise exception 'FAIL: poster cannot add center to non-open/draft job: %', v; end if;
end;
$$;
reset role;
do $$
declare i step1_ids%rowtype;
begin
  select * into i from step1_ids;
  if not exists (select 1 from private.job_distance_centers c where c.job_id=i.job_id
                 and c.approx_latitude=39.77 and c.approx_longitude=-86.16) then
    raise exception 'FAIL: center was not rounded server-side';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', teen_id::text, true) from step1_ids;
set local role authenticated;
do $$
declare i step1_ids%rowtype; v jsonb; n integer;
begin
  select * into i from step1_ids;
  v := public.get_job_distance_v1(i.job_id, 39.7684, -86.1581);
  if v->>'ok' <> 'true' or v->>'distance_band' <> 'under_1_mile'
     or v ? 'distance_miles' or v ? 'latitude' or v ? 'longitude' then
    raise exception 'FAIL: distance response is not coarse/minimal: %', v;
  end if;
  v := public.get_job_distance_v1(i.closed_job_id, 39.7684, -86.1581);
  if v->>'code' <> 'job_not_visible' then raise exception 'FAIL: closed job visible: %', v; end if;
  v := public.get_job_distance_v1(i.guardian_job_id, 39.7684, -86.1581);
  if v->>'code' <> 'guardian_approval_required' then raise exception 'FAIL: missing Guardian link not denied: %', v; end if;
  if has_table_privilege('authenticated', 'private.job_distance_centers', 'select') then
    raise exception 'FAIL: authenticated has direct access to private distance centers';
  end if;
  for n in 1..29 loop
    perform public.get_job_distance_v1(i.job_id, 39.7684, -86.1581);
  end loop;
  v := public.get_job_distance_v1(i.job_id, 39.7684, -86.1581);
  if v->>'code' <> 'job_distance_rate_limit_reached' then
    raise exception 'FAIL: request limit not enforced: %', v;
  end if;
end;
$$;

-- Revoke the local test release switch and verify fail-closed behavior.
reset role;
update public.mort_release_control set public_marketplace_enabled=false where is_primary;
select set_config('request.jwt.claim.sub', teen_id::text, true) from step1_ids;
set local role authenticated;
do $$
declare i step1_ids%rowtype; v jsonb;
begin
  select * into i from step1_ids;
  v := public.get_job_distance_v1(i.job_id, 39.7684, -86.1581);
  if v->>'code' <> 'public_marketplace_disabled' then
    raise exception 'FAIL: RPC did not fail closed with marketplace disabled: %', v;
  end if;
end;
$$;

reset role;
rollback;
