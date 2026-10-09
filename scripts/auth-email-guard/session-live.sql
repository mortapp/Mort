-- Disposable owned fixture only. No applied migration or hosted policy is edited.
create table if not exists mort_fixture.credential_fences(
  account_id uuid primary key references auth.users(id) on delete cascade,
  not_before timestamptz not null
);
alter table mort_fixture.credential_fences enable row level security;
revoke all on mort_fixture.credential_fences from public,anon,authenticated,service_role,supabase_auth_admin;

create or replace function mort_fixture.retire_password_sessions()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.encrypted_password is distinct from new.encrypted_password then
    insert into mort_fixture.credential_fences values(new.id,clock_timestamp())
      on conflict(account_id) do update set not_before=excluded.not_before;
  end if;
  return new;
end $$;
revoke all on function mort_fixture.retire_password_sessions() from public,anon,authenticated,service_role,supabase_auth_admin;
drop trigger if exists mort_fixture_password_fence on auth.users;
create trigger mort_fixture_password_fence after update of encrypted_password on auth.users
  for each row execute function mort_fixture.retire_password_sessions();

create or replace function mort_fixture.session_is_live()
returns boolean language plpgsql stable security definer set search_path='' as $$
declare claims jsonb:=auth.jwt(); subject text; session text; expiry text;
begin
  subject:=claims->>'sub';session:=claims->>'session_id';expiry:=claims->>'exp';
  if expiry is null or expiry!~'^[0-9]{1,12}$' then return false;end if;
  if extract(epoch from clock_timestamp())>=expiry::bigint then return false;end if;
  if subject is null or session is null or
    subject!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or
    session!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then return false;end if;
  return exists(
    select 1 from auth.sessions s join auth.users u on u.id=s.user_id
      cross join mort_auth_guard.control c
      left join mort_fixture.credential_fences f on f.account_id=u.id
    where s.id=session::uuid and s.user_id=subject::uuid
      and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())
      and s.created_at>=c.session_not_before
      and (f.not_before is null or s.created_at>=f.not_before)
  );
end $$;
revoke all on function mort_fixture.session_is_live() from public,anon,service_role,supabase_auth_admin;
grant usage on schema mort_fixture to authenticated;
grant execute on function mort_fixture.session_is_live() to authenticated;

create policy guard_fixture_live_record on mort_transport.records as restrictive
  for select to authenticated using((select mort_fixture.session_is_live()));
create policy guard_fixture_live_storage on storage.objects as restrictive
  for all to authenticated using(bucket_id<>'mort-fixture' or (select mort_fixture.session_is_live()))
  with check(bucket_id<>'mort-fixture' or (select mort_fixture.session_is_live()));
create policy guard_fixture_live_channel on realtime.messages as restrictive
  for all to authenticated using((select mort_fixture.session_is_live()))
  with check((select mort_fixture.session_is_live()));
notify pgrst,'reload schema';
