-- MORT 0.9.9: repair historical Auth users that predate profile bootstrap and
-- make post-login profile creation caller-bound and idempotent.

create or replace function private.safe_auth_display_name(p_metadata jsonb)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  with sanitized as (
    select
      nullif(
        pg_catalog.substr(
          pg_catalog.btrim(
            pg_catalog.regexp_replace(
              coalesce(p_metadata->>'display_name', ''),
              '[[:cntrl:]]+',
              ' ',
              'g'
            )
          ),
          1,
          80
        ),
        ''
      ) as display_name,
      nullif(
        pg_catalog.substr(
          pg_catalog.btrim(
            pg_catalog.regexp_replace(
              coalesce(p_metadata->>'full_name', ''),
              '[[:cntrl:]]+',
              ' ',
              'g'
            )
          ),
          1,
          80
        ),
        ''
      ) as full_name
  )
  select coalesce(sanitized.display_name, sanitized.full_name)
  from sanitized;
$$;

revoke all on function private.safe_auth_display_name(jsonb)
from public, anon, authenticated;
grant execute on function private.safe_auth_display_name(jsonb)
to service_role;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.set_config('mort.internal_update', 'true', true);

  insert into public.profiles (id, display_name)
  values (
    new.id,
    private.safe_auth_display_name(new.raw_user_meta_data)
  )
  on conflict (id) do nothing;

  perform pg_catalog.set_config('mort.internal_update', '', true);
  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_trigger
    where tgname = 'on_auth_user_created'
      and tgrelid = 'auth.users'::regclass
      and not tgisinternal
  ) then
    create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_auth_user();
  end if;
end;
$$;

create or replace function private.ensure_my_profile()
returns setof public.profiles
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_metadata jsonb;
  v_inserted_count integer := 0;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'authentication_required';
  end if;

  select auth_user.raw_user_meta_data
  into v_metadata
  from auth.users as auth_user
  where auth_user.id = v_user_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'authentication_required';
  end if;

  perform pg_catalog.set_config('mort.internal_update', 'true', true);

  insert into public.profiles (id, display_name)
  values (
    v_user_id,
    private.safe_auth_display_name(v_metadata)
  )
  on conflict (id) do nothing;

  get diagnostics v_inserted_count = row_count;
  perform pg_catalog.set_config('mort.internal_update', '', true);

  if v_inserted_count = 1 then
    insert into public.account_security_events (
      user_id,
      event_type,
      severity,
      session_reference,
      event_data,
      status
    ) values (
      v_user_id,
      'auth_profile_bootstrap_repaired',
      'info',
      null,
      pg_catalog.jsonb_build_object(
        'category', 'profile_bootstrap_repaired',
        'correlation_id', gen_random_uuid()::text
      ),
      'cleared'
    );
  end if;

  if not exists (
    select 1 from public.profiles as profile where profile.id = v_user_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'profile_bootstrap_failed';
  end if;

  return query
  select profile.*
  from public.profiles as profile
  where profile.id = v_user_id;
end;
$$;

create or replace function public.ensure_my_profile()
returns setof public.profiles
language sql
volatile
security invoker
set search_path = ''
as $$
  select * from private.ensure_my_profile();
$$;

revoke all on function private.ensure_my_profile()
from public, anon;
revoke all on function public.ensure_my_profile()
from public, anon;
grant execute on function private.ensure_my_profile()
to authenticated, service_role;
grant execute on function public.ensure_my_profile()
to authenticated, service_role;

comment on function public.ensure_my_profile() is
'Creates only the authenticated caller profile when missing and returns the persisted row without accepting identity or privilege fields.';

do $$
begin
  perform pg_catalog.set_config('mort.internal_update', 'true', true);

  with inserted_profiles as (
    insert into public.profiles (id, display_name)
    select
      auth_user.id,
      private.safe_auth_display_name(auth_user.raw_user_meta_data)
    from auth.users as auth_user
    left join public.profiles as profile on profile.id = auth_user.id
    where profile.id is null
    on conflict (id) do nothing
    returning id
  )
  insert into public.account_security_events (
    user_id,
    event_type,
    severity,
    session_reference,
    event_data,
    status
  )
  select
    inserted.id,
    'auth_profile_backfill_repaired',
    'info',
    null,
    pg_catalog.jsonb_build_object(
      'category', 'profile_backfill_repaired',
      'correlation_id', gen_random_uuid()::text
    ),
    'cleared'
  from inserted_profiles as inserted;

  perform pg_catalog.set_config('mort.internal_update', '', true);
end;
$$;
