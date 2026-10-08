-- Owned synthetic records and private channels only; no product tables changed.
create schema if not exists mort_transport;
grant usage on schema mort_transport to authenticated;
create table if not exists mort_transport.records(id uuid primary key,owner uuid not null,value text not null);
alter table mort_transport.records enable row level security;
grant select on mort_transport.records to authenticated;
drop policy if exists own_record on mort_transport.records;
create policy own_record on mort_transport.records for select to authenticated using(owner=(select auth.uid()));
drop policy if exists guard_fixture_read on storage.objects;
create policy guard_fixture_read on storage.objects for select to authenticated
  using(bucket_id='mort-fixture' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists guard_fixture_write on storage.objects;
create policy guard_fixture_write on storage.objects for insert to authenticated
  with check(bucket_id='mort-fixture' and (storage.foldername(name))[1]=(select auth.uid())::text);
grant usage on schema realtime to authenticated;
grant select,insert on realtime.messages to authenticated;
drop policy if exists guard_fixture_channel_read on realtime.messages;
create policy guard_fixture_channel_read on realtime.messages for select to authenticated
  using(realtime.topic()='guard:'||(select auth.uid())::text);
drop policy if exists guard_fixture_channel_write on realtime.messages;
create policy guard_fixture_channel_write on realtime.messages for insert to authenticated
  with check(realtime.topic()='guard:'||(select auth.uid())::text);
notify pgrst,'reload schema';
