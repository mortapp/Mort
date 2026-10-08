-- Disposable fixture adapter, not an applied product migration. No provider OTP,
-- token, metadata or address is persisted in the ingress queue or emitted in logs.
create table if not exists mort_fixture.email_ingress(
  id uuid primary key default gen_random_uuid(), account_id uuid not null,
  action text not null check(action in('signup','recovery')),
  recipient_hash text not null, source_hash text not null,
  created_at timestamptz not null default clock_timestamp(), used_at timestamptz
);
alter table mort_fixture.email_ingress enable row level security;
revoke all on mort_fixture.email_ingress from public,anon,authenticated,service_role,supabase_auth_admin;
create or replace function mort_fixture.send_email(event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare account uuid; recipient text; action text;
begin
  if session_user <> 'supabase_auth_admin' or
    not exists(select 1 from mort_fixture.identity) or
    not exists(select 1 from mort_auth_guard.control where enabled) then
    raise exception 'Fixture email hook unavailable';
  end if;
  account:=(event->'user'->>'id')::uuid;
  recipient:=event->'user'->>'email';
  action:=event->'email_data'->>'email_action_type';
  if recipient !~ '^qa-[0-9a-f-]+@mort-fixture\.invalid$' or action not in('signup','recovery') then
    raise exception 'Fixture email hook unavailable';
  end if;
  insert into mort_fixture.email_ingress(account_id,action,recipient_hash,source_hash)
  values(account,action,encode(extensions.digest(recipient,'sha256'),'hex'),
    -- The PG hook has no authenticated originating client-IP field. All traffic
    -- shares one conservative provider cohort; never invent a fresh quota source
    -- per request or trust caller metadata as its origin.
    (select encode(extensions.digest(id::text||':provider-ingress','sha256'),'hex') from mort_fixture.identity));
  return '{}'::jsonb;
end $$;
revoke all on function mort_fixture.send_email(jsonb) from public,anon,authenticated,service_role;
grant execute on function mort_fixture.send_email(jsonb) to supabase_auth_admin;
