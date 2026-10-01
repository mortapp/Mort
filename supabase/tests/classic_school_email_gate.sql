-- Run after both classic school migrations inside one outer transaction.
-- All synthetic users and approvals are rolled back by the caller.
do $$
declare
  v_user uuid := gen_random_uuid();
  v_school uuid;
  v_other_school uuid;
  v_domain uuid;
  v_assignment uuid;
  v_result jsonb;
begin
  select id into v_school from public.schools
  where official_name = 'Indiana Math and Science Academy West';
  select id into v_other_school from public.schools
  where official_name = 'Pike High School';
  select id into v_domain from public.school_domains
  where normalized_domain = 'mort.test' and environment = 'sandbox'
    and status = 'approved';
  if v_school is null or v_other_school is null or v_domain is null then
    raise exception 'Synthetic test prerequisites are missing';
  end if;
  if pg_catalog.has_table_privilege(
    'anon', 'private.school_domain_assignments', 'SELECT'
  ) or pg_catalog.has_table_privilege(
    'authenticated', 'private.teen_school_email_bindings', 'SELECT'
  ) or pg_catalog.has_function_privilege(
    'anon', 'public.verify_my_school_email(uuid)', 'EXECUTE'
  ) then
    raise exception 'Private school binding privileges are too broad';
  end if;

  insert into auth.users (
    id, aud, role, email, email_confirmed_at, created_at, updated_at
  ) values (
    v_user, 'authenticated', 'authenticated',
    'classic-school-qa@mort.test', now(), now(), now()
  );
  update public.profiles
  set dob = date '2010-04-18', is_test_account = true,
      account_status = 'active'
  where id = v_user;
  insert into private.school_domain_assignments (
    school_id, domain_id, status, student_allowed, evidence_source_url,
    reviewed_at
  ) values (
    v_school, v_domain, 'approved', true,
    'https://example.invalid/synthetic-qa-only', now()
  ) returning id into v_assignment;

  perform pg_catalog.set_config('request.jwt.claim.sub', v_user::text, true);
  if private.has_marketplace_identity(v_user) then
    raise exception 'Account without role obtained marketplace access';
  end if;
  begin
    update public.profiles set role = 'teen' where id = v_user;
    raise exception 'Direct teen role assignment was allowed';
  exception when check_violation then
    null;
  end;
  v_result := public.save_my_onboarding_role('teen', gen_random_uuid());
  if v_result->>'code' <> 'verified_school_email_required' then
    raise exception 'Teen role was assigned before school verification: %', v_result;
  end if;
  v_result := public.check_school_email_for_signup(
    v_school, 'classic-school-qa@mort.test'
  );
  if not coalesce((v_result->>'eligible')::boolean, false) then
    raise exception 'Approved exact-domain preflight failed: %', v_result;
  end if;
  v_result := public.check_school_email_for_signup(
    v_other_school, 'classic-school-qa@mort.test'
  );
  if coalesce((v_result->>'eligible')::boolean, false) then
    raise exception 'Wrong-school domain was accepted';
  end if;
  v_result := public.check_school_email_for_signup(
    v_school, 'teen@gmail.com'
  );
  if coalesce((v_result->>'eligible')::boolean, false) then
    raise exception 'Personal email was accepted';
  end if;

  v_result := public.verify_my_school_email(v_school);
  if not coalesce((v_result->>'ok')::boolean, false)
     or not private.has_current_teen_school_email(v_user) then
    raise exception 'Confirmed, approved teen email did not bind: %', v_result;
  end if;
  v_result := public.save_my_onboarding_role('teen', gen_random_uuid());
  if not coalesce((v_result->>'ok')::boolean, false) then
    raise exception 'Teen role was not assigned after school verification: %', v_result;
  end if;
  insert into public.identity_verifications (
    user_id, account_role, evidence_route, provider_reference, status,
    verification_level, age_band, environment, decision_source,
    verified_at, risk_flags
  ) values (
    v_user, 'teen', 'verified_school_account',
    'classic-school-qa-synthetic', 'verified', 1, 'teen_13_17',
    'sandbox', 'sandbox_simulation', now(), '{"isolated_qa":true}'::jsonb
  );
  if not private.has_marketplace_identity(v_user) then
    raise exception 'Verified synthetic teen was denied sandbox marketplace';
  end if;
  if exists (
    select 1 from public.school_domains where normalized_domain = 'gmail.com'
  ) then
    raise exception 'Personal provider was added to school domains';
  end if;

  update auth.users set email = 'classic-school-qa@gmail.com' where id = v_user;
  if private.has_current_teen_school_email(v_user)
     or private.has_marketplace_identity(v_user) then
    raise exception 'Changed login email retained school eligibility';
  end if;
  update auth.users set email = 'classic-school-qa@mort.test',
    email_confirmed_at = null where id = v_user;
  if private.has_current_teen_school_email(v_user)
     or private.has_marketplace_identity(v_user) then
    raise exception 'Unconfirmed email retained school eligibility';
  end if;
  update auth.users set email_confirmed_at = now() where id = v_user;
  update private.school_domain_assignments
  set status = 'suspended' where id = v_assignment;
  if private.has_current_teen_school_email(v_user)
     or private.has_marketplace_identity(v_user) then
    raise exception 'Suspended school assignment retained eligibility';
  end if;
end;
$$;
