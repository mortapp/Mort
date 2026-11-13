-- Regression contract for team-hustle location-note privacy.
-- Run after the matching production-baseline migration on a disposable database.

do $test$
declare
  v_definition text := pg_get_functiondef('public.list_team_hustles_v1()'::regprocedure);
begin
  if has_table_privilege('authenticated', 'public.team_hustles', 'SELECT') then
    raise exception 'authenticated must not have direct SELECT on team_hustles';
  end if;
  if has_table_privilege('anon', 'public.team_hustles', 'SELECT') then
    raise exception 'anon must not have direct SELECT on team_hustles';
  end if;
  if not has_table_privilege('service_role', 'public.team_hustles', 'SELECT') then
    raise exception 'service_role must retain its existing SELECT access';
  end if;
  if not has_function_privilege('authenticated', 'public.list_team_hustles_v1()', 'EXECUTE') then
    raise exception 'authenticated must retain the team-hustle listing RPC';
  end if;
  if has_function_privilege('anon', 'public.list_team_hustles_v1()', 'EXECUTE') then
    raise exception 'anon must not execute the team-hustle listing RPC';
  end if;
  if position('case' in lower(v_definition)) = 0
     or position('th.location_notes' in v_definition) = 0
     or position('th.poster_id = v_user' in v_definition) = 0
     or position('private.has_staff_role' in v_definition) = 0 then
    raise exception 'listing RPC must conditionally disclose location_notes only to poster/staff';
  end if;
  if position('not private.is_active_user()' in v_definition) = 0 then
    raise exception 'listing RPC must retain its active-account gate';
  end if;
  if position('th.location_notes, th.status' in v_definition) > 0 then
    raise exception 'listing RPC must not return raw location_notes to every listing reader';
  end if;
  if not exists (
    select 1 from pg_proc p
    where p.oid = 'public.list_team_hustles_v1()'::regprocedure
      and p.prosecdef
      and 'search_path=""' = any(p.proconfig)
  ) then
    raise exception 'listing RPC must remain SECURITY DEFINER with empty search_path';
  end if;
end;
$test$;
