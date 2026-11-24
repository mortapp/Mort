-- Disposable standalone GoTrue database only. This is a database contract
-- fixture, not authorization evidence. Everything is rolled back.
\set ON_ERROR_STOP on
do $$ begin
  if current_database() <> 'mort_lean_auth' then
    raise exception 'Refusing to run outside the disposable local GoTrue database';
  end if;
end $$;
begin;
create schema private;
create role anon;
create role authenticated;
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade);
create table public.account_deletion_requests (processor_user_id uuid, status text);
create table private.account_deletion_legal_holds (subject_id uuid, released_at timestamptz);
create table private.verification_provider_results (user_id uuid);
create table public.verification_cases (user_id uuid);
create table public.consents (user_id uuid);
create table public.job_safety_checkins (adult_user_id uuid, teen_user_id uuid);
create table public.role_requests (user_id uuid);
create table public.team_hustles (poster_id uuid);
create table public.notification_preferences (
  user_id uuid references public.profiles(id) on delete cascade
);
create table public.purchase_records (user_id uuid references public.profiles(id) on delete cascade);
create table private.stripe_saved_payment_consents (
  adult_id uuid references auth.users(id) on delete cascade
);
\ir ../20261122152000_deletion_unapproved_application_cascades.sql

insert into auth.users (id)
values ('10000000-0000-4000-8000-000000000001'), ('10000000-0000-4000-8000-000000000002');
insert into public.profiles select id from auth.users where id in
  ('10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002');
insert into public.account_deletion_requests
select id, 'processing' from public.profiles;
insert into public.purchase_records values ('10000000-0000-4000-8000-000000000001');
insert into private.stripe_saved_payment_consents values ('10000000-0000-4000-8000-000000000001');
insert into public.notification_preferences values ('10000000-0000-4000-8000-000000000002');

do $$
declare
  protected uuid := '10000000-0000-4000-8000-000000000001';
  ordinary uuid := '10000000-0000-4000-8000-000000000002';
begin
  if private.mort_deletion_protected_history(protected)
      is distinct from array['private.stripe_saved_payment_consents','public.purchase_records']::text[] then
    raise exception 'Financial rows were not individually identified';
  end if;
  if private.mort_deletion_protected_history(ordinary) is distinct from '{}'::text[] then
    raise exception 'Disposable preferences incorrectly blocked the separate account';
  end if;
  begin
    delete from auth.users where id=protected;
    raise exception 'Protected account unexpectedly deleted';
  exception when foreign_key_violation then
    if sqlerrm <> 'account_deletion_protected_history' then raise; end if;
  end;
  if not exists (select 1 from private.stripe_saved_payment_consents where adult_id=protected)
    or not exists (select 1 from public.purchase_records where user_id=protected) then
    raise exception 'Financial evidence did not survive';
  end if;
  delete from auth.users where id=ordinary;
  if exists (select 1 from public.notification_preferences where user_id=ordinary) then
    raise exception 'Disposable preferences still present';
  end if;
  raise notice 'PASS: both regulated financial cascades held and retained; different disposable fixture removed';
end $$;
rollback;
