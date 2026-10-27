do $$
declare
  v_teen_id uuid := gen_random_uuid();
  v_adult_id uuid := gen_random_uuid();
  v_job_id uuid := gen_random_uuid();
  v_application_id uuid := gen_random_uuid();
  v_denied boolean;
begin
  insert into auth.users (id) values (v_teen_id), (v_adult_id);

  update public.profiles
  set role = 'teen'::public.mort_role,
      account_status = 'active',
      date_of_birth = (current_date - interval '15 years')::date
  where id = v_teen_id;

  update public.profiles
  set role = 'adult'::public.mort_role,
      account_status = 'active',
      date_of_birth = (current_date - interval '35 years')::date
  where id = v_adult_id;

  insert into public.verification_cases (user_id, verification_type, status)
  values
    (v_teen_id, 'age', 'verified'::public.mort_verification_status),
    (v_adult_id, 'identity', 'verified'::public.mort_verification_status);

  insert into public.jobs (
    id, poster_id, title, description, category, status, pay_type,
    pay_amount, city, region, age_min, age_max, safety_review_status,
    published_at
  ) values (
    v_job_id, v_adult_id, 'Age restricted job',
    'A safe job for age eligibility testing.', 'yard_work',
    'open'::public.mort_job_status, 'fixed', 25, 'Indianapolis', 'IN',
    16, 17, 'approved', now()
  );

  perform set_config('request.jwt.claim.sub', v_teen_id::text, true);
  v_denied := false;
  begin
    perform public.mort_submit_job_application(v_job_id, null);
    raise exception 'TEST_EXPECTED_APPLY_AGE_REJECTION';
  exception when others then
    if sqlerrm = 'TEST_EXPECTED_APPLY_AGE_REJECTION' then raise; end if;
    if sqlerrm <> 'Applicant age is outside the job requirements' then raise; end if;
    v_denied := true;
  end;
  if not v_denied then raise exception 'Out-of-range application was accepted'; end if;

  insert into public.job_applications (
    id, job_id, applicant_id, status
  ) values (
    v_application_id, v_job_id, v_teen_id,
    'submitted'::public.mort_application_status
  );

  perform set_config('request.jwt.claim.sub', v_adult_id::text, true);
  v_denied := false;
  begin
    perform public.mort_accept_job_application(v_application_id);
    raise exception 'TEST_EXPECTED_ACCEPT_AGE_REJECTION';
  exception when others then
    if sqlerrm = 'TEST_EXPECTED_ACCEPT_AGE_REJECTION' then raise; end if;
    if sqlerrm <> 'Applicant age is outside the job requirements' then raise; end if;
    v_denied := true;
  end;
  if not v_denied then raise exception 'Out-of-range applicant was accepted'; end if;

  delete from public.job_applications where id = v_application_id;
  delete from public.jobs where id = v_job_id;
  delete from public.verification_cases where user_id in (v_teen_id, v_adult_id);
  delete from auth.users where id in (v_teen_id, v_adult_id);
end;
$$;
