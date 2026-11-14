-- Regression contract for team-hustle location-note privacy.
-- Run after the matching production-baseline migration on a disposable database.
-- Synthetic fixtures are rolled back; never run against a production database.

begin;

do $fixtures$
declare
  poster_id uuid := '92929292-9292-4292-8292-929292929201';
  viewer_id uuid := '92929292-9292-4292-8292-929292929202';
  staff_id uuid := '92929292-9292-4292-8292-929292929204';
  hustle_id uuid := '92929292-9292-4292-8292-929292929203';
begin
  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values
    (poster_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'team-hustle-poster@privacy-test.invalid', '', now(), '{}'::jsonb, '{"date_of_birth":"1988-01-01"}'::jsonb, now(), now()),
    (viewer_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'team-hustle-viewer@privacy-test.invalid', '', now(), '{}'::jsonb, '{"date_of_birth":"2011-01-01"}'::jsonb, now(), now()),
    (staff_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'team-hustle-staff@privacy-test.invalid', '', now(), '{}'::jsonb, '{"date_of_birth":"1980-01-01"}'::jsonb, now(), now());

  insert into public.profiles (id, role, account_status, date_of_birth, display_name)
  values
    (poster_id, 'adult', 'active', date '1988-01-01', 'Synthetic Poster'),
    (viewer_id, 'teen', 'active', date '2011-01-01', 'Synthetic Viewer'),
    (staff_id, 'admin', 'active', date '1980-01-01', 'Synthetic Staff')
  on conflict (id) do update
  set role = excluded.role,
      account_status = excluded.account_status,
      date_of_birth = excluded.date_of_birth,
      display_name = excluded.display_name;

  insert into private.user_roles (user_id, role)
  values (staff_id, 'moderator'::public.mort_role);

  insert into public.team_hustles (
    id, poster_id, title, description, location_notes
  ) values (
    hustle_id, poster_id, 'Synthetic location privacy test',
    'A synthetic team hustle used only by the rolled-back privacy test.',
    'SYNTHETIC PRIVATE MEETING NOTE - DO NOT EXPOSE'
  );
end;
$fixtures$;

do $contract$
declare
  v_definition text := pg_get_functiondef('public.list_team_hustles_v1()'::regprocedure);
begin
  if has_table_privilege('authenticated', 'public.team_hustles', 'SELECT')
     or has_any_column_privilege('authenticated', 'public.team_hustles', 'SELECT') then
    raise exception 'authenticated must not retain table or column SELECT on team_hustles';
  end if;
  if has_table_privilege('anon', 'public.team_hustles', 'SELECT')
     or has_any_column_privilege('anon', 'public.team_hustles', 'SELECT') then
    raise exception 'anon must not have direct table or column SELECT on team_hustles';
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
  if not has_function_privilege('service_role', 'public.list_team_hustles_v1()', 'EXECUTE') then
    raise exception 'service_role must retain the team-hustle listing RPC';
  end if;
  if position('th.location_notes' in v_definition) = 0
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
$contract$;

set local role authenticated;

do $behavior$
declare
  poster_id uuid := '92929292-9292-4292-8292-929292929201';
  viewer_id uuid := '92929292-9292-4292-8292-929292929202';
  staff_id uuid := '92929292-9292-4292-8292-929292929204';
  hustle_id uuid := '92929292-9292-4292-8292-929292929203';
  v_listing jsonb;
  v_note text;
begin
  perform set_config('request.jwt.claim.sub', viewer_id::text, true);
  v_listing := public.list_team_hustles_v1();
  select item->>'location_notes' into v_note
  from jsonb_array_elements(v_listing) item
  where item->>'id' = hustle_id::text;
  if v_note is not null then
    raise exception 'unrelated authenticated viewer received private location notes';
  end if;

  begin
    execute 'select location_notes from public.team_hustles where id = $1' using hustle_id;
    raise exception 'direct authenticated SELECT unexpectedly succeeded';
  exception
    when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub', poster_id::text, true);
  v_listing := public.list_team_hustles_v1();
  select item->>'location_notes' into v_note
  from jsonb_array_elements(v_listing) item
  where item->>'id' = hustle_id::text;
  if v_note is distinct from 'SYNTHETIC PRIVATE MEETING NOTE - DO NOT EXPOSE' then
    raise exception 'poster did not receive their own location notes';
  end if;

  perform set_config('request.jwt.claim.sub', staff_id::text, true);
  v_listing := public.list_team_hustles_v1();
  select item->>'location_notes' into v_note
  from jsonb_array_elements(v_listing) item
  where item->>'id' = hustle_id::text;
  if v_note is distinct from 'SYNTHETIC PRIVATE MEETING NOTE - DO NOT EXPOSE' then
    raise exception 'authorized moderator did not receive the location notes';
  end if;
end;
$behavior$;

rollback;
