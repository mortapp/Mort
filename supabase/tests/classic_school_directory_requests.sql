-- Run inside an outer transaction after the school request migration.
do $$
declare
  v_result jsonb;
  v_count integer;
begin
  if pg_catalog.has_table_privilege(
    'anon', 'private.school_directory_requests', 'SELECT'
  ) or pg_catalog.has_table_privilege(
    'authenticated', 'private.school_directory_requests', 'INSERT'
  ) then
    raise exception 'School request queue privileges are too broad';
  end if;
  v_result := public.request_school_directory_entry(
    'Synthetic Unknown Academy', 'Indianapolis', 'IN',
    'https://example.invalid/school', 'students.example.invalid'
  );
  if v_result->>'code' <> 'request_received' then
    raise exception 'Valid school request failed: %', v_result;
  end if;
  v_result := public.request_school_directory_entry(
    ' synthetic unknown academy ', 'INDIANAPOLIS', 'in', null, null
  );
  if v_result->>'code' <> 'request_received' then
    raise exception 'Duplicate school request did not remain opaque';
  end if;
  select count(*) into v_count from private.school_directory_requests
  where lower(requested_school_name) = 'synthetic unknown academy';
  if v_count <> 1 then
    raise exception 'Duplicate school requests were inserted';
  end if;
  if exists (select 1 from public.search_schools('Synthetic Unknown Academy', 10))
     or exists (
       select 1 from public.school_domains
       where normalized_domain = 'students.example.invalid'
     ) then
    raise exception 'School request created directory or domain authority';
  end if;
  v_result := public.request_school_directory_entry(
    'Pike High School', 'Indianapolis', 'IN', null, null
  );
  if v_result->>'code' <> 'school_already_listed' then
    raise exception 'Listed school was accepted as unknown: %', v_result;
  end if;
  v_result := public.request_school_directory_entry(
    'Synthetic Second School', 'Indianapolis', 'IN',
    'http://example.invalid', 'teen@gmail.com'
  );
  if v_result->>'code' <> 'invalid_school_request' then
    raise exception 'Invalid website or email-shaped domain was accepted';
  end if;
end;
$$;

set local role anon;
do $$
declare v_result jsonb;
begin
  v_result := public.request_school_directory_entry(
    'Synthetic Anonymous School', 'Indianapolis', 'IN', null, null
  );
  if v_result->>'code' <> 'request_received' then
    raise exception 'Anonymous pre-account school request failed: %', v_result;
  end if;
end;
$$;
reset role;
