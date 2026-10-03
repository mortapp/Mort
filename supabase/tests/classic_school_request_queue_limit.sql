-- Run after classic_school_directory_requests.sql in the same outer rollback.
do $$
declare
  v_result jsonb;
  v_count integer;
begin
  insert into private.school_directory_requests (
    requested_school_name, requested_city, requested_state, created_at
  )
  select 'Synthetic Hourly School ' || n, 'Indianapolis', 'IN',
         pg_catalog.clock_timestamp() - interval '10 minutes'
  from generate_series(1, 28) as n;

  v_result := public.request_school_directory_entry(
    'Synthetic Hourly Denied School', 'Indianapolis', 'IN'
  );
  if v_result->>'code' <> 'rate_limited' then
    raise exception 'Hourly quota did not fail closed: %', v_result;
  end if;
  v_result := public.request_school_directory_entry(
    'Synthetic Unknown Academy', 'Indianapolis', 'IN'
  );
  if v_result->>'code' <> 'request_received' then
    raise exception 'Duplicate must remain opaque at quota: %', v_result;
  end if;
  select count(*) into v_count from private.school_directory_requests;
  if v_count <> 30 then
    raise exception 'Hourly denial or duplicate mutated queue: %', v_count;
  end if;

  delete from private.school_directory_requests
  where requested_school_name like 'Synthetic Hourly School %';
  insert into private.school_directory_requests (
    requested_school_name, requested_city, requested_state, created_at
  )
  select 'Synthetic Daily School ' || n, 'Indianapolis', 'IN',
         pg_catalog.clock_timestamp() - interval '2 hours'
  from generate_series(1, 198) as n;

  v_result := public.request_school_directory_entry(
    'Synthetic Daily Denied School', 'Indianapolis', 'IN'
  );
  if v_result->>'code' <> 'rate_limited' then
    raise exception 'Daily quota did not fail closed: %', v_result;
  end if;
  select count(*) into v_count from private.school_directory_requests;
  if v_count <> 200 then
    raise exception 'Daily denial mutated queue: %', v_count;
  end if;

  update private.school_directory_requests
  set created_at = pg_catalog.clock_timestamp() - interval '2 days';
  v_result := public.request_school_directory_entry(
    'Synthetic Quota Reset School', 'Indianapolis', 'IN'
  );
  if v_result->>'code' <> 'request_received' then
    raise exception 'Expired quota did not reopen: %', v_result;
  end if;
end;
$$;
