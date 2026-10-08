-- Disabled by default; backend-only lifecycle helpers, not public RPC routes.
begin;
create or replace function mort_auth_guard.expire_delivery()
returns void language plpgsql security definer set search_path='' as $$
declare now_at timestamptz:=clock_timestamp();
begin
  -- Caller holds the control lock. Abandoned attempts retain their dispatch
  -- charges, and an older successfully delivered item remains untouched.
  update mort_auth_guard.delivery_attempts set outcome=case when dispatched_at is null then 'expired' else 'ambiguous' end,finished_at=now_at
    where outcome is null and expires_at<=now_at;
  update mort_auth_guard.items i set state='retired',delivery_state='expired'
    where i.state='issued' and exists(select 1 from mort_auth_guard.outbox o where o.item_id=i.id and o.state<>'terminal' and
      (o.expires_at<=now_at or (o.state='leased' and (o.lease_until<=now_at or exists(select 1 from mort_auth_guard.delivery_attempts a where a.id=o.lease_id and a.outcome is not null)))));
  update mort_auth_guard.outbox o set state='terminal',encrypted_envelope=null
    where o.state<>'terminal' and exists(select 1 from mort_auth_guard.items i where i.id=o.item_id and i.state='retired');
  update mort_auth_guard.families f set inflight_until=null where f.inflight_until is not null and not exists(
    select 1 from mort_auth_guard.items i join mort_auth_guard.outbox o on o.item_id=i.id where i.family_id=f.id and o.state<>'terminal');
end $$;

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

-- Preserve the authenticated ingress identity for every individual resend.
alter table mort_auth_guard.outbox add column if not exists source_hash text check(source_hash ~ '^[0-9a-f]{64}$');
-- Existing queued rows predate this implementation and cannot be dispatched.
update mort_auth_guard.outbox set state='terminal',encrypted_envelope=null where source_hash is null;

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
      'accountId',f.account_id,'purpose',f.purpose,'recipientHash',f.recipient_hash,'activationGeneration',f.activation_generation,
      'restoreGeneration',f.restore_generation,'familyExpiresAt',f.family_expires_at,'leaseExpiresAt',expiry);
  end loop;
  return '{"ok":false}'::jsonb;
end $$;

create or replace function mort_auth_guard.begin_dispatch(lease jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c mort_auth_guard.control%rowtype;g mort_auth_guard.account_generations%rowtype;f mort_auth_guard.families%rowtype;
  o mort_auth_guard.outbox%rowtype;a mort_auth_guard.delivery_attempts%rowtype;u auth.users%rowtype;now_at timestamptz;global_count bigint;
begin
  if coalesce(lease->>'itemId','')!~'^[0-9a-f-]{36}$' or coalesce(lease->>'attemptId','')!~'^[0-9a-f-]{36}$' then return '{"ok":false}'::jsonb;end if;
  select * into c from mort_auth_guard.control where singleton for update;
  if not found or not c.enabled then return '{"ok":false}'::jsonb;end if;
  select * into f from mort_auth_guard.families where id=(select family_id from mort_auth_guard.items where id=(lease->>'itemId')::uuid);
  select * into g from mort_auth_guard.account_generations where account_id=f.account_id for update;
  select * into f from mort_auth_guard.families where id=f.id for update;
  select * into o from mort_auth_guard.outbox where item_id=(lease->>'itemId')::uuid for update;
  select * into a from mort_auth_guard.delivery_attempts where id=(lease->>'attemptId')::uuid for update;
  now_at:=clock_timestamp();
  select * into u from auth.users where id=f.account_id;
  if g.account_id is null or f.id is null or u.id is null or o.item_id is null or a.id is null or a.item_id<>o.item_id or o.lease_id<>a.id or o.state<>'leased' or a.outcome is not null or a.dispatched_at is not null
    or a.generation::text<>coalesce(lease->>'generation','') or now_at>=a.expires_at or now_at>=o.expires_at or now_at>=f.family_expires_at
    or f.state<>'active' or f.failures>=5 or f.activation_generation<>c.activation_generation or f.restore_generation<>c.restore_generation
    or g.deleted_at is not null or f.address_generation<>g.address_generation or f.credential_generation<>g.credential_generation
    or g.recipient_hash<>f.recipient_hash or o.source_hash is null or u.email is null or u.deleted_at is not null or u.banned_until>now_at
    or encode(sha256(convert_to(u.email,'UTF8')),'hex')<>f.recipient_hash
    or (f.purpose='confirmation' and u.email_confirmed_at is not null) or (f.purpose='recovery' and u.email_confirmed_at is null) then return '{"ok":false}'::jsonb;end if;
  global_count:=(select count(*) from mort_auth_guard.quota_events where kind='dispatch' and occurred_at>now_at-interval '1 hour');
  if global_count>=c.global_hourly or (select count(*) from mort_auth_guard.quota_events where kind='dispatch' and recipient_hash=f.recipient_hash and occurred_at>now_at-interval '1 hour')>=c.recipient_hourly
    or (select count(*) from mort_auth_guard.quota_events where kind='dispatch' and source_hash=o.source_hash and occurred_at>now_at-interval '1 hour')>=c.source_hourly then
    update mort_auth_guard.delivery_attempts set outcome='failed',finished_at=now_at where id=a.id;
    update mort_auth_guard.items set state='retired',delivery_state='failed' where id=o.item_id;
    update mort_auth_guard.outbox set state='terminal',encrypted_envelope=null where item_id=o.item_id;
    update mort_auth_guard.families set inflight_until=null where id=f.id;
    return '{"ok":false}'::jsonb;
  end if;
  insert into mort_auth_guard.quota_events(id,kind,account_id,purpose,recipient_hash,source_hash,occurred_at,item_id,attempt_id)
    values(gen_random_uuid(),'dispatch',f.account_id,f.purpose,f.recipient_hash,o.source_hash,now_at,o.item_id,a.id);
  update mort_auth_guard.delivery_attempts set dispatched_at=now_at where id=a.id;
  if global_count+1>=20 and (c.last_threshold_alert is null or c.last_threshold_alert<=now_at-interval '1 hour') then
    insert into mort_auth_guard.quota_events(id,kind,occurred_at) values(gen_random_uuid(),'global_threshold',now_at);
    update mort_auth_guard.control set last_threshold_alert=now_at where singleton;
  end if;
  return jsonb_build_object('ok',true,'leaseExpiresAt',a.expires_at);
exception when unique_violation or invalid_text_representation then raise exception 'MORT challenge operation denied' using errcode='22023';
end $$;

create or replace function mort_auth_guard.finish_delivery(lease jsonb,outcome text)
returns boolean language plpgsql security definer set search_path='' as $$
declare c mort_auth_guard.control%rowtype;g mort_auth_guard.account_generations%rowtype;f mort_auth_guard.families%rowtype;
  o mort_auth_guard.outbox%rowtype;a mort_auth_guard.delivery_attempts%rowtype;i mort_auth_guard.items%rowtype;u auth.users%rowtype;now_at timestamptz;promote boolean;
  delivery_outcome text:=outcome;
begin
  if outcome is null or outcome not in('acknowledged','failed','ambiguous') or coalesce(lease->>'itemId','')!~'^[0-9a-f-]{36}$' or coalesce(lease->>'attemptId','')!~'^[0-9a-f-]{36}$' then return false;end if;
  select * into c from mort_auth_guard.control where singleton for update;
  if not found or not c.enabled then return false;end if;
  select * into f from mort_auth_guard.families where id=(select family_id from mort_auth_guard.items where id=(lease->>'itemId')::uuid);
  select * into g from mort_auth_guard.account_generations where account_id=f.account_id for update;
  select * into f from mort_auth_guard.families where id=f.id for update;
  select * into i from mort_auth_guard.items where id=(lease->>'itemId')::uuid for update;
  select * into o from mort_auth_guard.outbox where item_id=i.id for update;
  select * into a from mort_auth_guard.delivery_attempts where id=(lease->>'attemptId')::uuid for update;
  now_at:=clock_timestamp();
  select * into u from auth.users where id=f.account_id;
  if a.id is null or a.item_id<>i.id or o.lease_id<>a.id or o.state<>'leased' or a.outcome is not null or a.generation::text<>coalesce(lease->>'generation','') then return false;end if;
  promote:=delivery_outcome='acknowledged' and a.dispatched_at is not null and now_at<a.expires_at and now_at<o.expires_at and now_at<f.family_expires_at
    and f.state='active' and f.failures<5 and i.state='issued' and g.deleted_at is null
    and f.address_generation=g.address_generation and f.credential_generation=g.credential_generation
    and f.activation_generation=c.activation_generation and f.restore_generation=c.restore_generation
    and u.id is not null and u.email is not null and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now_at)
    and encode(sha256(convert_to(u.email,'UTF8')),'hex')=f.recipient_hash
    and ((f.purpose='confirmation' and u.email_confirmed_at is null) or (f.purpose='recovery' and u.email_confirmed_at is not null));
  update mort_auth_guard.delivery_attempts set outcome=case when now_at>=a.expires_at then 'expired' when delivery_outcome='acknowledged' and not coalesce(promote,false) then 'failed' else delivery_outcome end,finished_at=now_at where id=a.id;
  update mort_auth_guard.outbox set state='terminal',encrypted_envelope=null where item_id=i.id;
  update mort_auth_guard.families set inflight_until=null where id=f.id;
  if not coalesce(promote,false) then
    update mort_auth_guard.items set state='retired',delivery_state=case when now_at>=a.expires_at then 'expired' when delivery_outcome='acknowledged' then 'failed' else delivery_outcome end where id=i.id;return false;
  end if;
  update mort_auth_guard.items set state='retired' where family_id=f.id and state='grace';
  update mort_auth_guard.items set state='grace',grace_until=least(now_at+interval '60 seconds',f.family_expires_at) where family_id=f.id and state='usable';
  update mort_auth_guard.items set state='usable',delivery_state='acknowledged',promoted_at=now_at where id=i.id;
  update mort_auth_guard.families set last_promoted_at=now_at where id=f.id;
  return true;
exception when invalid_text_representation then raise exception 'MORT challenge operation denied' using errcode='22023';
end $$;
revoke all on function mort_auth_guard.expire_delivery(),mort_auth_guard.issue_event(jsonb,jsonb),mort_auth_guard.claim_delivery(),mort_auth_guard.begin_dispatch(jsonb),mort_auth_guard.finish_delivery(jsonb,text) from public,anon,authenticated;
grant execute on function mort_auth_guard.issue_event(jsonb,jsonb),mort_auth_guard.claim_delivery(),mort_auth_guard.begin_dispatch(jsonb),mort_auth_guard.finish_delivery(jsonb,text) to service_role;

-- Bind consumption to the current provider-owned exact mailbox bytes.
create or replace function mort_auth_guard.consume_item(input jsonb, material jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  control_row mort_auth_guard.control%rowtype;
  generation_row mort_auth_guard.account_generations%rowtype;
  family_row mort_auth_guard.families%rowtype;
  item_row mort_auth_guard.items%rowtype;
  account_row auth.users%rowtype;
  now_at timestamptz;
  failure jsonb := '{"ok":false,"message":"That request is not valid."}'::jsonb;
  candidate_digest text;
  matching boolean;
begin
  -- Authenticated browser roles never execute this helper. Still validate the
  -- digested server envelope defensively before lookup/mutation.
  if input->>'itemId' is null or input->>'itemId' !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    or input->>'kind' is null or input->>'kind' not in ('code','link')
    or input->>'credentialDigest' is null or input->>'credentialDigest' !~ '^[0-9a-f]{64}$'
    or input->>'verifierHash' is null or input->>'verifierHash' !~ '^[0-9a-f]{64}$'
    or material->>'capabilityDigest' is null or material->>'capabilityDigest' !~ '^[0-9a-f]{64}$' then return failure; end if;
  select * into control_row from mort_auth_guard.control where singleton for update;
  if not found or control_row.enabled is not true then return failure; end if;
  select * into item_row from mort_auth_guard.items where id=(input->>'itemId')::uuid;
  if not found then return failure; end if;
  select * into family_row from mort_auth_guard.families where id=item_row.family_id;
  if not found then return failure; end if;
  select * into generation_row from mort_auth_guard.account_generations where account_id=family_row.account_id for update;
  if not found or generation_row.deleted_at is not null then return failure; end if;
  select * into family_row from mort_auth_guard.families where id=item_row.family_id for update;
  select * into item_row from mort_auth_guard.items where id=(input->>'itemId')::uuid for update;
  -- Authoritative time is obtained AFTER every contention boundary.
  now_at := clock_timestamp();
  if family_row.state<>'active' or family_row.failures>=5 or now_at>=family_row.family_expires_at
    or family_row.address_generation<>generation_row.address_generation
    or family_row.credential_generation<>generation_row.credential_generation
    or family_row.recipient_hash<>generation_row.recipient_hash
    or family_row.activation_generation<>control_row.activation_generation
    or family_row.restore_generation<>control_row.restore_generation
    or item_row.delivery_state<>'acknowledged'
    or (item_row.state<>'usable' and (item_row.state<>'grace' or item_row.grace_until is null or now_at>=item_row.grace_until)) then return failure; end if;
  -- Queued during signup is permissible; consuming before provider commit is not.
  select * into account_row from auth.users where id=family_row.account_id;
  if not found or account_row.deleted_at is not null or account_row.email is null
    or account_row.banned_until>now_at
    or encode(sha256(convert_to(account_row.email,'UTF8')),'hex')<>family_row.recipient_hash
    or (family_row.purpose='confirmation' and account_row.email_confirmed_at is not null)
    or (family_row.purpose='recovery' and account_row.email_confirmed_at is null) then return failure; end if;
  candidate_digest:=case input->>'kind' when 'code' then item_row.code_hmac else item_row.link_digest end;
  matching:=candidate_digest=input->>'credentialDigest';
  if not matching then
    update mort_auth_guard.families set failures=failures+1,
      state=case when failures+1>=5 then 'exhausted' else state end where id=family_row.id;
    if family_row.failures+1>=5 then
      update mort_auth_guard.items set state='retired' where family_id=family_row.id;
      update mort_auth_guard.outbox set state='terminal',encrypted_envelope=null where item_id in(select id from mort_auth_guard.items where family_id=family_row.id);
    end if;
    -- Normal return is essential: raising here would roll back the failed guess.
    return failure;
  end if;
  insert into mort_auth_guard.capabilities(digest,family_id,account_id,purpose,address_generation,credential_generation,activation_generation,restore_generation,verifier_hash,issued_at,expires_at)
    values(material->>'capabilityDigest',family_row.id,family_row.account_id,family_row.purpose,
      family_row.address_generation,family_row.credential_generation,control_row.activation_generation,control_row.restore_generation,
      input->>'verifierHash',now_at,now_at+interval '300 seconds');
  update mort_auth_guard.families set state='consumed' where id=family_row.id;
  update mort_auth_guard.items set state='retired' where family_id=family_row.id;
  update mort_auth_guard.outbox set state='terminal',encrypted_envelope=null where item_id in(select id from mort_auth_guard.items where family_id=family_row.id);
  return jsonb_build_object('ok',true,'purpose',family_row.purpose,
    'maskedRecipient',left(split_part(account_row.email,'@',1),1)||'***@'||split_part(account_row.email,'@',2),
    'familyExpiresAt',family_row.family_expires_at,'capabilityExpiresAt',now_at+interval '300 seconds');
exception when unique_violation then
  -- Do not expose a credential digest in PostgreSQL's duplicate-key DETAIL.
  raise exception 'MORT challenge operation denied' using errcode='23505';
end $$;
revoke all on function mort_auth_guard.consume_item(jsonb,jsonb) from public,anon,authenticated;
grant usage on schema mort_auth_guard to service_role;
grant execute on function mort_auth_guard.consume_item(jsonb,jsonb) to service_role;
commit;
