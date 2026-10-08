-- Private pre-admission context never reads uncommitted Auth signup rows.
begin;
create or replace function mort_auth_guard.issuance_context(account uuid,recipient text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c mort_auth_guard.control%rowtype;g mort_auth_guard.account_generations%rowtype;
begin
  if account is null or account::text !~'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' or coalesce(recipient,'')!~'^[0-9a-f]{64}$' then return null;end if;
  select * into c from mort_auth_guard.control where singleton;
  if not found or not c.enabled then return null;end if;
  select * into g from mort_auth_guard.account_generations where account_id=account;
  if found and (g.deleted_at is not null or g.recipient_hash<>recipient) then return null;end if;
  return jsonb_build_object('addressGeneration',coalesce(g.address_generation,1),'credentialGeneration',coalesce(g.credential_generation,1),
    'activationGeneration',c.activation_generation,'restoreGeneration',c.restore_generation);
end $$;
revoke all on function mort_auth_guard.issuance_context(uuid,text) from public,anon,authenticated;
grant execute on function mort_auth_guard.issuance_context(uuid,text) to service_role;

create or replace function mort_auth_guard.issue_event(event jsonb,material jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  c mort_auth_guard.control%rowtype;g mort_auth_guard.account_generations%rowtype;
  f mort_auth_guard.families%rowtype;h mort_auth_guard.hook_events%rowtype;
  now_at timestamptz;signed_at timestamptz;expiry timestamptz;fresh boolean:=false;
  denied jsonb:='{"ok":false,"message":"That request is not valid."}'::jsonb;
begin
  if jsonb_typeof(event)<>'object' or jsonb_typeof(material)<>'object'
    or coalesce(event->>'accountId','')!~'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    or coalesce(material->>'familyId','')!~'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    or coalesce(material->>'itemId','')!~'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    or coalesce(event->>'purpose','') not in('confirmation','recovery')
    or coalesce(event->>'recipientHash','')!~'^[0-9a-f]{64}$' or coalesce(event->>'sourceHash','')!~'^[0-9a-f]{64}$'
    or coalesce(event->>'eventDigest','')!~'^[0-9a-f]{64}$' or coalesce(event->>'bodyDigest','')!~'^[0-9a-f]{64}$'
    or coalesce(material->>'codeDigest','')!~'^[0-9a-f]{64}$' or coalesce(material->>'linkDigest','')!~'^[0-9a-f]{64}$'
    or coalesce(material->>'encryptedEnvelope','')!~'^v1\.' or octet_length(material->>'encryptedEnvelope')>32768
    or coalesce(event->>'signedAt','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T' then return denied;end if;
  select * into c from mort_auth_guard.control where singleton for update;
  if not found or not c.enabled then return denied;end if;
  signed_at:=(event->>'signedAt')::timestamptz;now_at:=clock_timestamp();
  if signed_at<now_at-interval '300 seconds' or signed_at>now_at+interval '30 seconds' then return denied;end if;
  select * into h from mort_auth_guard.hook_events where event_digest=event->>'eventDigest';
  if found then
    if h.body_digest<>event->>'bodyDigest' or h.outcome<>'accepted' then return denied;end if;
    select * into f from mort_auth_guard.families where id=(select family_id from mort_auth_guard.items where id=h.item_id);
    return jsonb_build_object('ok',true,'replayed',true,'itemId',h.item_id,'familyId',f.id,'familyExpiresAt',f.family_expires_at);
  end if;
  perform mort_auth_guard.expire_delivery();
  insert into mort_auth_guard.account_generations(account_id,recipient_hash) values((event->>'accountId')::uuid,event->>'recipientHash') on conflict do nothing;
  select * into g from mort_auth_guard.account_generations where account_id=(event->>'accountId')::uuid for update;
  if material->>'addressGeneration' is distinct from g.address_generation::text
    or material->>'credentialGeneration' is distinct from g.credential_generation::text
    or material->>'activationGeneration' is distinct from c.activation_generation::text
    or material->>'restoreGeneration' is distinct from c.restore_generation::text then return denied;end if;
  if g.deleted_at is not null or g.recipient_hash<>event->>'recipientHash' then return denied;end if;
  select * into f from mort_auth_guard.families where account_id=g.account_id and purpose=event->>'purpose' and state='active' for update;
  now_at:=clock_timestamp();
  if found and (f.family_expires_at<=now_at or f.activation_generation<>c.activation_generation or f.restore_generation<>c.restore_generation
    or f.address_generation<>g.address_generation or f.credential_generation<>g.credential_generation) then
    update mort_auth_guard.families set state='expired' where id=f.id;
    update mort_auth_guard.items set state='retired' where family_id=f.id;
    update mort_auth_guard.outbox set state='terminal',encrypted_envelope=null where item_id in(select id from mort_auth_guard.items where family_id=f.id);
    f.id:=null;
  end if;
  if f.id is not null and (f.failures>=5 or f.inflight_until>now_at or f.last_promoted_at>now_at-interval '60 seconds') then return denied;end if;
  if (select count(*) from mort_auth_guard.outbox where state<>'terminal' and expires_at>now_at)>=c.queue_limit then return denied;end if;
  if f.id is null then
    if (select count(*) from mort_auth_guard.quota_events where kind='family' and account_id=g.account_id and purpose=event->>'purpose' and occurred_at>now_at-interval '1 hour')>=c.account_hourly
      or (select count(*) from mort_auth_guard.quota_events where kind='family' and source_hash=event->>'sourceHash' and occurred_at>now_at-interval '1 hour')>=c.source_family_hourly then return denied;end if;
    insert into mort_auth_guard.families(id,account_id,purpose,recipient_hash,source_hash,address_generation,credential_generation,activation_generation,restore_generation,issued_at,family_expires_at)
      values((material->>'familyId')::uuid,g.account_id,event->>'purpose',g.recipient_hash,event->>'sourceHash',g.address_generation,g.credential_generation,c.activation_generation,c.restore_generation,now_at,now_at+interval '600 seconds') returning * into f;
    insert into mort_auth_guard.quota_events(id,kind,account_id,purpose,recipient_hash,source_hash,occurred_at)
      values(gen_random_uuid(),'family',g.account_id,f.purpose,g.recipient_hash,event->>'sourceHash',now_at);
    fresh:=true;
  end if;
  expiry:=least(f.family_expires_at,now_at+interval '30 seconds');
  insert into mort_auth_guard.items(id,family_id,code_hmac,link_digest,issued_at)
    values((material->>'itemId')::uuid,f.id,material->>'codeDigest',material->>'linkDigest',now_at);
  -- Source quota follows each admitted request, not the family's original source.
  insert into mort_auth_guard.outbox(item_id,encrypted_envelope,created_at,expires_at,source_hash)
    values((material->>'itemId')::uuid,material->>'encryptedEnvelope',now_at,expiry,event->>'sourceHash');
  update mort_auth_guard.families set inflight_until=expiry where id=f.id;
  insert into mort_auth_guard.hook_events(event_digest,body_digest,signed_at,received_at,item_id,outcome)
    values(event->>'eventDigest',event->>'bodyDigest',signed_at,now_at,(material->>'itemId')::uuid,'accepted');
  return jsonb_build_object('ok',true,'replayed',false,'itemId',material->>'itemId','familyId',f.id,'familyExpiresAt',f.family_expires_at,'newFamily',fresh);
exception when unique_violation or invalid_datetime_format or datetime_field_overflow then
  raise exception 'MORT challenge operation denied' using errcode='22023';
end $$;
create or replace function mort_auth_guard.claim_delivery()
returns jsonb language plpgsql security definer set search_path='' as $$
declare c mort_auth_guard.control%rowtype;g mort_auth_guard.account_generations%rowtype;f mort_auth_guard.families%rowtype;
  o mort_auth_guard.outbox%rowtype;i mort_auth_guard.items%rowtype;u auth.users%rowtype;now_at timestamptz;attempt uuid;expiry timestamptz;
begin
  select * into c from mort_auth_guard.control where singleton for update;
  if not found or not c.enabled then return '{"ok":false}'::jsonb;end if;
  perform mort_auth_guard.expire_delivery();now_at:=clock_timestamp();
  if (select count(*) from mort_auth_guard.delivery_attempts where outcome is null and expires_at>now_at)>=c.delivery_limit then return '{"ok":false}'::jsonb;end if;
  for o in select * from mort_auth_guard.outbox where state in('queued','deferred') and expires_at>now_at order by created_at,item_id limit 20 loop
    select * into f from mort_auth_guard.families where id=(select family_id from mort_auth_guard.items where id=o.item_id);
    select * into g from mort_auth_guard.account_generations where account_id=f.account_id for update;
    select * into f from mort_auth_guard.families where id=f.id for update;
    select * into i from mort_auth_guard.items where id=o.item_id for update;
    select * into o from mort_auth_guard.outbox where item_id=o.item_id for update;
    now_at:=clock_timestamp();
    select * into u from auth.users where id=f.account_id;
    if not found then
      if now_at<o.expires_at then update mort_auth_guard.outbox set state='deferred' where item_id=o.item_id;end if;
      continue;
    end if;
    if f.state<>'active' or f.failures>=5 or now_at>=f.family_expires_at or now_at>=o.expires_at or i.state<>'issued' or o.source_hash is null
      or f.activation_generation<>c.activation_generation or f.restore_generation<>c.restore_generation or g.deleted_at is not null
      or f.address_generation<>g.address_generation or f.credential_generation<>g.credential_generation or f.recipient_hash<>g.recipient_hash
      or u.deleted_at is not null or u.email is null or u.banned_until>now_at
      or encode(sha256(convert_to(u.email,'UTF8')),'hex')<>f.recipient_hash
      or (f.purpose='confirmation' and u.email_confirmed_at is not null) or (f.purpose='recovery' and u.email_confirmed_at is null) then
      update mort_auth_guard.items set state='retired',delivery_state='expired' where id=i.id;
      update mort_auth_guard.outbox set state='terminal',encrypted_envelope=null where item_id=i.id;
      update mort_auth_guard.families set inflight_until=null where id=f.id;continue;
    end if;
    attempt:=gen_random_uuid();expiry:=least(o.expires_at,f.family_expires_at,now_at+interval '30 seconds');
    insert into mort_auth_guard.delivery_attempts(id,item_id,generation,claimed_at,expires_at) values(attempt,i.id,o.lease_generation,now_at,expiry);
    update mort_auth_guard.outbox set state='leased',lease_id=attempt,lease_until=expiry where item_id=i.id;
    update mort_auth_guard.items set delivery_state='leased' where id=i.id;
    return jsonb_build_object('ok',true,'itemId',i.id,'attemptId',attempt,'generation',o.lease_generation,'encryptedEnvelope',o.encrypted_envelope,
      'addressGeneration',f.address_generation,'credentialGeneration',f.credential_generation,'sourceHash',o.source_hash,'accountId',f.account_id,'purpose',f.purpose,'recipientHash',f.recipient_hash,'activationGeneration',f.activation_generation,
      'restoreGeneration',f.restore_generation,'familyExpiresAt',f.family_expires_at,'leaseExpiresAt',expiry);
  end loop;
  return '{"ok":false}'::jsonb;
end $$;
commit;
