-- Local rehearsal controls require the independent fixture identity. No hosted
-- activation entrypoint or scheduled hosted job is created by this migration.
begin;
create function mort_auth_guard.fixture_transition(action text,fixture_id uuid,next_generation bigint)
returns void language plpgsql security invoker set search_path='' as $$
declare c mort_auth_guard.control%rowtype; observed uuid;
begin
  if action not in('activate','rollback','restore') or to_regclass('mort_fixture.identity') is null then raise exception 'fixture control rejected';end if;
  execute 'SELECT id FROM mort_fixture.identity' into strict observed;
  if observed<>fixture_id then raise exception 'fixture control rejected';end if;
  -- Capture BEFORE waiting for the provider mutation boundary. A confirmation
  -- committed while waiting is not part of the pre-cutover verified baseline.
  create temporary table mort_guard_baseline on commit drop as
    select id,email,email_confirmed_at from auth.users
    where email_confirmed_at is not null and deleted_at is null and (banned_until is null or banned_until<=clock_timestamp());
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
    from auth.users u join pg_temp.mort_guard_baseline b on b.id=u.id and b.email=u.email and b.email_confirmed_at=u.email_confirmed_at
    join mort_auth_guard.account_generations g on g.account_id=u.id
    where u.deleted_at is null and g.deleted_at is null
    on conflict(account_id) do update set address_generation=excluded.address_generation,recipient_hash=excluded.recipient_hash,
      activation_generation=excluded.activation_generation,restore_generation=excluded.restore_generation,source=excluded.source,proved_at=excluded.proved_at,retired_at=null;
  update mort_auth_guard.control set enabled=(action<>'rollback');
end $$;
revoke all on function mort_auth_guard.fixture_transition(text,uuid,bigint) from public,anon,authenticated,service_role,supabase_auth_admin;
create function mort_auth_guard.maintain_retention()
returns void language plpgsql security definer set search_path='' as $$
declare n timestamptz;
begin
  -- Same boundary/order as provider mutation and control. No delayed provider
  -- transaction can straddle permission deletion and use an old granted write.
  lock table auth.users in share row exclusive mode;
  perform singleton from mort_auth_guard.control where singleton for update;
  n:=clock_timestamp();
  perform mort_auth_guard.expire_delivery();
  update mort_auth_guard.families set state='expired',inflight_until=null where state='active' and family_expires_at<=n;
  update mort_auth_guard.operation_grants set state='fenced',completed_at=n where state in('reserved','pending') and expires_at<=n;
  update mort_auth_guard.capabilities set state='retired' where state in('issued','reserved') and expires_at<=n;
  update mort_auth_guard.items i set state='retired' where exists(select 1 from mort_auth_guard.families f where f.id=i.family_id and f.state<>'active');
  update mort_auth_guard.outbox o set encrypted_envelope=null,state='terminal',lease_id=null,lease_until=null,lease_generation=lease_generation+1
    where (o.encrypted_envelope is not null or o.state<>'terminal') and (o.expires_at<=n or exists(select 1 from mort_auth_guard.items i where i.id=o.item_id and i.state='retired'));
  -- Preserve the one-hour abuse window, with a one-hour cleanup margin. Retain
  -- terminal private metadata 24h for reconciliation; neither changes expiry.
  delete from mort_auth_guard.operation_grants where state in('committed','fenced') and expires_at<n-interval '24 hours';
  delete from mort_auth_guard.capabilities c where c.state in('consumed','retired') and c.expires_at<n-interval '24 hours'
    and not exists(select 1 from mort_auth_guard.operation_grants g where g.capability_digest=c.digest);
  delete from mort_auth_guard.families f where f.state<>'active' and f.family_expires_at<n-interval '24 hours'
    and not exists(select 1 from mort_auth_guard.capabilities c where c.family_id=f.id);
  delete from mort_auth_guard.hook_events where received_at<n-interval '24 hours';
  delete from mort_auth_guard.quota_events where occurred_at<n-interval '2 hours';
  delete from mort_auth_guard.address_proofs p where (p.retired_at is not null and p.retired_at<n-interval '24 hours')
    or not exists(select 1 from auth.users u where u.id=p.account_id and u.deleted_at is null);
  delete from mort_auth_guard.account_generations g where not exists(select 1 from auth.users u where u.id=g.account_id and u.deleted_at is null)
    and not exists(select 1 from mort_auth_guard.families f where f.account_id=g.account_id)
    and not exists(select 1 from mort_auth_guard.operation_grants o where o.account_id=g.account_id)
    and not exists(select 1 from mort_auth_guard.address_proofs p where p.account_id=g.account_id);
end $$;
revoke all on function mort_auth_guard.maintain_retention() from public,anon,authenticated,supabase_auth_admin;
grant execute on function mort_auth_guard.maintain_retention() to service_role;
commit;
