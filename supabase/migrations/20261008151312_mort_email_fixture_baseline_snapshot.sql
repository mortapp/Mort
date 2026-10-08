-- Additive replacement: capture the verified baseline before taking the mutation
-- lock without a temporary relation that cannot be checked by plpgsql_check.
begin;
create or replace function mort_auth_guard.fixture_transition(action text,fixture_id uuid,next_generation bigint)
returns void language plpgsql security invoker set search_path='' as $$
declare c mort_auth_guard.control%rowtype; observed uuid; baseline jsonb;
begin
  if action not in('activate','rollback','restore') or to_regclass('mort_fixture.identity') is null then raise exception 'fixture control rejected';end if;
  execute 'SELECT id FROM mort_fixture.identity' into strict observed;
  if observed<>fixture_id then raise exception 'fixture control rejected';end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'email',email,'email_confirmed_at',email_confirmed_at)),'[]'::jsonb)
    into baseline from auth.users where email_confirmed_at is not null and deleted_at is null
      and (banned_until is null or banned_until<=clock_timestamp());
  lock table auth.users in share row exclusive mode;
  select * into c from mort_auth_guard.control where singleton for update;
  if next_generation<=greatest(c.activation_generation,c.restore_generation) then raise exception 'fixture generation rejected';end if;
  update mort_auth_guard.control set enabled=false,activation_generation=next_generation,restore_generation=next_generation,session_not_before=clock_timestamp();
  update mort_auth_guard.families set state='retired',inflight_until=null where state='active';
  update mort_auth_guard.items set state='retired';
  update mort_auth_guard.capabilities set state='retired' where state in('issued','reserved');
  update mort_auth_guard.operation_grants set state='fenced',completed_at=clock_timestamp() where state in('reserved','pending');
  update mort_auth_guard.address_proofs set retired_at=clock_timestamp();
  update mort_auth_guard.outbox set encrypted_envelope=null,state='terminal',lease_id=null,lease_until=null,lease_generation=lease_generation+1;
  update mort_auth_guard.delivery_attempts set outcome=case when dispatched_at is null then 'expired' else 'ambiguous' end,finished_at=clock_timestamp() where outcome is null;
  insert into mort_auth_guard.account_generations(account_id,recipient_hash)
    select id,encode(extensions.digest(convert_to(email,'UTF8'),'sha256'),'hex') from auth.users where email is not null and deleted_at is null
    on conflict(account_id) do update set
      address_generation=mort_auth_guard.account_generations.address_generation+case when mort_auth_guard.account_generations.recipient_hash<>excluded.recipient_hash then 1 else 0 end,
      recipient_hash=excluded.recipient_hash,fence_generation=mort_auth_guard.account_generations.fence_generation+1;
  insert into mort_auth_guard.address_proofs(account_id,address_generation,recipient_hash,activation_generation,restore_generation,source,proved_at)
    select u.id,g.address_generation,g.recipient_hash,next_generation,next_generation,'confirmed_baseline',clock_timestamp()
    from auth.users u join jsonb_to_recordset(baseline) as b(id uuid,email text,email_confirmed_at timestamptz)
      on b.id=u.id and b.email=u.email and b.email_confirmed_at=u.email_confirmed_at
    join mort_auth_guard.account_generations g on g.account_id=u.id
    where u.deleted_at is null and g.deleted_at is null
    on conflict(account_id) do update set address_generation=excluded.address_generation,recipient_hash=excluded.recipient_hash,
      activation_generation=excluded.activation_generation,restore_generation=excluded.restore_generation,source=excluded.source,proved_at=excluded.proved_at,retired_at=null;
  update mort_auth_guard.control set enabled=(action<>'rollback');
end $$;
revoke all on function mort_auth_guard.fixture_transition(text,uuid,bigint) from public,anon,authenticated,service_role,supabase_auth_admin;
commit;
