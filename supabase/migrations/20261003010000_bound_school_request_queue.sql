-- Bound anonymous school suggestions until a trusted bot challenge can be
-- configured. A global quota is intentionally independent of client headers:
-- callers can forge IP-like headers on a public RPC.
create index school_directory_requests_created_at_idx
  on private.school_directory_requests(created_at);

create or replace function public.request_school_directory_entry(
  p_school_name text,
  p_city text,
  p_state text,
  p_website text default null,
  p_student_domain text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := btrim(coalesce(p_school_name, ''));
  v_city text := btrim(coalesce(p_city, ''));
  v_state text := upper(btrim(coalesce(p_state, '')));
  v_website text := nullif(btrim(coalesce(p_website, '')), '');
  v_domain text := nullif(lower(btrim(coalesce(p_student_domain, ''))), '');
  v_now timestamptz;
begin
  if char_length(v_name) not between 3 and 180
     or char_length(v_city) not between 2 and 100
     or v_state !~ '^[A-Z]{2}$'
     or (v_website is not null and
         (char_length(v_website) > 300 or v_website !~ '^https://'))
     or (v_domain is not null and
         (char_length(v_domain) > 253 or
          v_domain !~ '^[a-z0-9][a-z0-9.-]*[a-z0-9]$')) then
    return jsonb_build_object('ok', false, 'code', 'invalid_school_request');
  end if;

  if exists (
    select 1 from public.schools
    where lower(btrim(official_name)) = lower(v_name)
      and lower(btrim(city)) = lower(v_city)
      and state = v_state and status = 'listed'
  ) then
    return jsonb_build_object('ok', false, 'code', 'school_already_listed');
  end if;

  -- Serialize count and insert across all callers so concurrent anonymous
  -- requests cannot each pass a stale count. Existing suggestions remain
  -- opaque and do not consume another queue slot.
  perform pg_catalog.pg_advisory_xact_lock(741052, 114);
  if exists (
    select 1 from private.school_directory_requests
    where lower(btrim(requested_school_name)) = lower(v_name)
      and lower(btrim(requested_city)) = lower(v_city)
      and requested_state = v_state
  ) then
    return jsonb_build_object('ok', true, 'code', 'request_received');
  end if;

  v_now := pg_catalog.clock_timestamp();
  if (
    select count(*) from private.school_directory_requests
    where created_at >= v_now - interval '1 hour'
  ) >= 30 or (
    select count(*) from private.school_directory_requests
    where created_at >= v_now - interval '1 day'
  ) >= 200 then
    return jsonb_build_object('ok', false, 'code', 'rate_limited');
  end if;

  insert into private.school_directory_requests (
    requested_school_name, requested_city, requested_state,
    school_website, suggested_student_domain
  ) values (v_name, v_city, v_state, v_website, v_domain)
  on conflict do nothing;
  return jsonb_build_object('ok', true, 'code', 'request_received');
end;
$$;

revoke all on function public.request_school_directory_entry(
  text, text, text, text, text
) from public, anon, authenticated;
grant execute on function public.request_school_directory_entry(
  text, text, text, text, text
) to anon, authenticated;
