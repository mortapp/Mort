-- Run after both school request migrations in the same outer rollback.
do $$
declare
  v_admin uuid := gen_random_uuid();
  v_adult uuid := gen_random_uuid();
  v_request uuid;
  v_result jsonb;
  v_events integer;
begin
  if pg_catalog.has_table_privilege(
    'authenticated', 'private.school_directory_request_review_events', 'SELECT'
  ) or pg_catalog.has_function_privilege(
    'anon', 'public.admin_list_school_directory_requests(text,integer,integer)',
    'EXECUTE'
  ) or pg_catalog.has_function_privilege(
    'anon', 'public.admin_triage_school_directory_request(uuid,text,text)',
    'EXECUTE'
  ) then
    raise exception 'Private school review grants are too broad';
  end if;

  select id into v_request from private.school_directory_requests
  where requested_school_name = 'Synthetic Unknown Academy';
  if v_request is null then
    raise exception 'School review fixture is missing';
  end if;

  insert into auth.users (
    id, aud, role, email, email_confirmed_at, created_at, updated_at
  ) values
    (v_admin, 'authenticated', 'authenticated',
     'school-review-admin@mort.test', now(), now(), now()),
    (v_adult, 'authenticated', 'authenticated',
     'school-review-adult@mort.test', now(), now(), now());
  update public.profiles set role = 'admin', dob = date '1990-01-01'
  where id = v_admin;
  update public.profiles set role = 'adult', dob = date '1990-01-01'
  where id = v_adult;

  perform pg_catalog.set_config('request.jwt.claim.role', 'authenticated', true);
  perform pg_catalog.set_config('request.jwt.claim.sub', v_adult::text, true);
  v_result := public.admin_list_school_directory_requests();
  if v_result->>'code' <> 'admin_required' then
    raise exception 'Adult read private school queue: %', v_result;
  end if;
  v_result := public.admin_triage_school_directory_request(
    v_request, 'rejected', 'Unauthorized fixture action'
  );
  if v_result->>'code' <> 'admin_required' then
    raise exception 'Adult changed private school queue: %', v_result;
  end if;

  perform pg_catalog.set_config('request.jwt.claim.sub', v_admin::text, true);
  v_result := public.admin_list_school_directory_requests('pending', 50);
  if v_result->>'ok' <> 'true'
     or not exists (
       select 1 from jsonb_array_elements(v_result->'items') as item
       where item->>'id' = v_request::text
     ) then
    raise exception 'Admin could not read pending request (code %, count %)',
      v_result->>'code', jsonb_array_length(coalesce(v_result->'items', '[]'::jsonb));
  end if;
  v_result := public.admin_list_school_directory_requests('pending', 1, 1);
  if v_result->>'ok' <> 'true'
     or jsonb_array_length(v_result->'items') <> 1 then
    raise exception 'Admin could not page to an older request';
  end if;
  v_result := public.admin_list_school_directory_requests(null, 25, 0);
  if v_result->>'code' <> 'invalid_filter' then
    raise exception 'Null status filter was accepted';
  end if;
  v_result := public.admin_triage_school_directory_request(
    v_request, null, 'Null decision must fail closed'
  );
  if v_result->>'code' <> 'invalid_review' then
    raise exception 'Null decision was accepted';
  end if;
  v_result := public.admin_triage_school_directory_request(
    v_request, 'accepted', 'This must never approve a school'
  );
  if v_result->>'code' <> 'invalid_review' then
    raise exception 'Client approval path was accepted: %', v_result;
  end if;
  v_result := public.admin_triage_school_directory_request(
    v_request, 'reviewing', 'Verify the official school source'
  );
  if v_result->>'code' <> 'review_recorded' then
    raise exception 'Reviewing transition failed: %', v_result;
  end if;
  v_result := public.admin_triage_school_directory_request(
    v_request, 'rejected', 'No independently verified school evidence'
  );
  if v_result->>'code' <> 'review_recorded' then
    raise exception 'Rejection transition failed: %', v_result;
  end if;
  v_result := public.admin_triage_school_directory_request(
    v_request, 'reviewing', 'Attempt to reopen rejected request'
  );
  if v_result->>'code' <> 'request_closed' then
    raise exception 'Closed review was reopened: %', v_result;
  end if;
  select count(*) into v_events
  from private.school_directory_request_review_events
  where request_id = v_request and reviewer_id = v_admin;
  if v_events <> 2 then
    raise exception 'Review audit event count is wrong: %', v_events;
  end if;
  if exists (
    select 1 from public.schools
    where official_name = 'Synthetic Unknown Academy'
  ) or exists (
    select 1 from private.school_domain_assignments
    where evidence_source_url like '%synthetic-unknown%'
  ) then
    raise exception 'Triage created school or domain authority';
  end if;

  update public.profiles set account_status = 'suspended' where id = v_admin;
  v_result := public.admin_list_school_directory_requests();
  if v_result->>'code' <> 'admin_required' then
    raise exception 'Suspended admin read private queue: %', v_result;
  end if;
end;
$$;
