-- Default-off private operation reservation and provider-transaction fences.
-- No hosted hook configuration or activation is performed by this migration.
begin;
create or replace function mort_auth_guard.reserve_password(input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  c mort_auth_guard.control%rowtype;g mort_auth_guard.account_generations%rowtype;
  cap mort_auth_guard.capabilities%rowtype;u auth.users%rowtype;
  now_at timestamptz;failure jsonb:='{"ok":false}'::jsonb;
begin
  if input->>'capabilityDigest' is null or input->>'capabilityDigest' !~ '^[0-9a-f]{64}$'
    or input->>'verifierHash' is null or input->>'verifierHash' !~ '^[0-9a-f]{64}$'
    or input->>'operationId' is null or input->>'operationId' !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    or jsonb_typeof(input->'passwordValid') is distinct from 'boolean' then return failure;end if;
  select * into cap from mort_auth_guard.capabilities where digest=input->>'capabilityDigest';if not found then return failure;end if;
  -- Provider updates already hold auth.users first. Match that order, avoiding
  -- the control/account inversion when reserving or reconciling an operation.
  select * into u from auth.users where id=cap.account_id for update;if not found then return failure;end if;
  select * into c from mort_auth_guard.control where singleton for update;if c.enabled is not true then return failure;end if;
  select * into g from mort_auth_guard.account_generations where account_id=u.id for update;if not found then return failure;end if;
  select * into cap from mort_auth_guard.capabilities where digest=input->>'capabilityDigest' for update;
  now_at:=clock_timestamp();
  if cap.state<>'issued' or cap.verifier_hash<>input->>'verifierHash' or now_at>=cap.expires_at
    or u.email is null or u.deleted_at is not null or u.banned_until>now_at or g.deleted_at is not null
    or encode(extensions.digest(convert_to(u.email,'UTF8'),'sha256'),'hex')<>g.recipient_hash
    or cap.address_generation<>g.address_generation or cap.credential_generation<>g.credential_generation
    or cap.activation_generation<>c.activation_generation or cap.restore_generation<>c.restore_generation
    or (cap.purpose='confirmation' and u.email_confirmed_at is not null)
    or (cap.purpose='recovery' and u.email_confirmed_at is null) then return failure;end if;
  if (input->>'passwordValid')::boolean is not true then return '{"ok":false,"policy":true}'::jsonb;end if;
  update mort_auth_guard.account_generations set fence_generation=fence_generation+1 where account_id=u.id returning * into g;
  update mort_auth_guard.operation_grants set state='fenced',completed_at=now_at where account_id=u.id and state in('reserved','pending');
  update mort_auth_guard.capabilities set state='retired' where account_id=u.id and state in('issued','reserved') and digest<>cap.digest;
  insert into mort_auth_guard.operation_grants(id,account_id,capability_digest,purpose,address_generation,credential_generation,fence_generation,activation_generation,restore_generation,expires_at,reserved_at)
    values((input->>'operationId')::uuid,u.id,cap.digest,cap.purpose,g.address_generation,g.credential_generation,g.fence_generation,c.activation_generation,c.restore_generation,cap.expires_at,now_at);
  update mort_auth_guard.capabilities set state='reserved' where digest=cap.digest;
  return jsonb_build_object('ok',true,'operationId',input->>'operationId','accountId',u.id,'purpose',cap.purpose,'expiresAt',cap.expires_at);
exception when unique_violation then raise exception 'MORT credential operation denied' using errcode='23505';
end $$;

create or replace function mort_auth_guard.guard_auth_user_mutation()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  c mort_auth_guard.control%rowtype;g mort_auth_guard.account_generations%rowtype;
  op mort_auth_guard.operation_grants%rowtype;now_at timestamptz;marker text;
  changed_password boolean;changed_confirmation boolean;changed_marker boolean;verified_oauth boolean:=false;
begin
  select * into c from mort_auth_guard.control where singleton for update;
  if c.enabled is not true then if tg_op='DELETE' then return old;else return new;end if;end if;
  select * into g from mort_auth_guard.account_generations where account_id=old.id for update;
  if not found then if tg_op='DELETE' then return old;else return new;end if;end if;
  now_at:=clock_timestamp();
  if tg_op='DELETE' then
    update mort_auth_guard.account_generations set deleted_at=now_at,address_generation=address_generation+1,credential_generation=credential_generation+1,fence_generation=fence_generation+1 where account_id=old.id;
  elsif old.email is distinct from new.email or old.deleted_at is distinct from new.deleted_at or (new.banned_until>now_at and old.banned_until is distinct from new.banned_until) then
    update mort_auth_guard.account_generations set recipient_hash=encode(extensions.digest(convert_to(coalesce(new.email,''),'UTF8'),'sha256'),'hex'),address_generation=address_generation+1,credential_generation=credential_generation+1,fence_generation=fence_generation+1,deleted_at=new.deleted_at where account_id=old.id;
  else
    changed_password:=old.encrypted_password is distinct from new.encrypted_password;
    changed_confirmation:=old.email_confirmed_at is null and new.email_confirmed_at is not null;
    changed_marker:=(old.raw_app_meta_data->>'mort_email_operation_id') is distinct from (new.raw_app_meta_data->>'mort_email_operation_id');
    if not(changed_password or changed_confirmation or changed_marker) then return new;end if;
    -- Only identities in Auth's provider-owned table are authority. This local
    -- checkpoint permits the signature/audience-verified fixture Keycloak
    -- adapter; live Google/Apple compatibility remains a separate gate.
    select exists(select 1 from auth.identities i where i.user_id=new.id and i.provider='keycloak'
      and i.identity_data->>'email'=new.email and i.identity_data->>'email_verified'='true') into verified_oauth;
    if verified_oauth and not changed_marker and old.email_confirmed_at is null
      and (not changed_password or coalesce(new.encrypted_password,'')='') then
      if changed_password then update mort_auth_guard.account_generations set credential_generation=credential_generation+1,fence_generation=fence_generation+1 where account_id=new.id returning * into g;end if;
      if changed_confirmation then
        insert into mort_auth_guard.address_proofs(account_id,address_generation,recipient_hash,activation_generation,restore_generation,source,proved_at)
          values(new.id,g.address_generation,g.recipient_hash,c.activation_generation,c.restore_generation,'provider_oauth',now_at)
          on conflict(account_id) do update set address_generation=excluded.address_generation,recipient_hash=excluded.recipient_hash,activation_generation=excluded.activation_generation,restore_generation=excluded.restore_generation,source=excluded.source,proved_at=excluded.proved_at,retired_at=null;
      end if;
      update mort_auth_guard.operation_grants set state='fenced',completed_at=now_at where account_id=new.id and state in('reserved','pending');
      update mort_auth_guard.capabilities set state='retired' where account_id=new.id and state in('issued','reserved');
      update mort_auth_guard.families set state='retired' where account_id=new.id and state='active';
      update mort_auth_guard.items set state='retired' where family_id in(select id from mort_auth_guard.families where account_id=new.id);
      update mort_auth_guard.outbox set state='terminal',encrypted_envelope=null where item_id in(select i.id from mort_auth_guard.items i join mort_auth_guard.families f on f.id=i.family_id where f.account_id=new.id);
      return new;
    end if;
    marker:=new.raw_app_meta_data->>'mort_email_operation_id';
    if marker is null or marker !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'MORT credential operation denied';end if;
    select * into op from mort_auth_guard.operation_grants where id=marker::uuid and account_id=new.id for update;
    now_at:=clock_timestamp();
    if not found or op.state not in('reserved','pending') or now_at>=op.expires_at or g.deleted_at is not null
      or op.address_generation<>g.address_generation or op.credential_generation<>g.credential_generation or op.fence_generation<>g.fence_generation
      or op.activation_generation<>c.activation_generation or op.restore_generation<>c.restore_generation
      or encode(extensions.digest(convert_to(new.email,'UTF8'),'sha256'),'hex')<>g.recipient_hash
      or (changed_confirmation and op.purpose<>'confirmation') then raise exception 'MORT credential operation denied';end if;
    if changed_password or changed_confirmation then
      update mort_auth_guard.operation_grants set password_applied=password_applied or changed_password,confirmation_applied=confirmation_applied or changed_confirmation where id=op.id returning * into op;
      if op.password_applied and (op.purpose='recovery' or op.confirmation_applied) then
        update mort_auth_guard.operation_grants set state='committed',completed_at=now_at where id=op.id;
        update mort_auth_guard.capabilities set state='consumed' where digest=op.capability_digest;
        update mort_auth_guard.account_generations set credential_generation=credential_generation+1 where account_id=new.id;
        update mort_auth_guard.operation_grants set state='fenced',completed_at=now_at where account_id=new.id and id<>op.id and state in('reserved','pending');
        update mort_auth_guard.capabilities set state='retired' where account_id=new.id and digest<>op.capability_digest and state in('issued','reserved');
        update mort_auth_guard.families set state='retired' where account_id=new.id and state='active';
        update mort_auth_guard.items set state='retired' where family_id in(select id from mort_auth_guard.families where account_id=new.id);
        update mort_auth_guard.outbox set state='terminal',encrypted_envelope=null where item_id in(select i.id from mort_auth_guard.items i join mort_auth_guard.families f on f.id=i.family_id where f.account_id=new.id);
        if op.purpose='confirmation' then
          insert into mort_auth_guard.address_proofs(account_id,address_generation,recipient_hash,activation_generation,restore_generation,source,proved_at)
            values(new.id,g.address_generation,g.recipient_hash,c.activation_generation,c.restore_generation,'mort_challenge',now_at)
            on conflict(account_id) do update set address_generation=excluded.address_generation,recipient_hash=excluded.recipient_hash,activation_generation=excluded.activation_generation,restore_generation=excluded.restore_generation,source=excluded.source,proved_at=excluded.proved_at,retired_at=null;
        end if;
      end if;
    end if;
    return new;
  end if;
  update mort_auth_guard.operation_grants set state='fenced',completed_at=now_at where account_id=old.id and state in('reserved','pending');
  update mort_auth_guard.capabilities set state='retired' where account_id=old.id and state in('issued','reserved');
  update mort_auth_guard.address_proofs set retired_at=now_at where account_id=old.id and retired_at is null;
  update mort_auth_guard.families set state='retired' where account_id=old.id and state='active';
  update mort_auth_guard.items set state='retired' where family_id in(select id from mort_auth_guard.families where account_id=old.id);
  update mort_auth_guard.outbox set state='terminal',encrypted_envelope=null where item_id in(select i.id from mort_auth_guard.items i join mort_auth_guard.families f on f.id=i.family_id where f.account_id=old.id);
  if tg_op='DELETE' then return old;else return new;end if;
end $$;

create or replace function mort_auth_guard.reconcile_operation(operation_id uuid)
returns text language plpgsql security definer set search_path='' as $$
declare op mort_auth_guard.operation_grants%rowtype;g mort_auth_guard.account_generations%rowtype;c mort_auth_guard.control%rowtype;
begin
  select * into op from mort_auth_guard.operation_grants where id=operation_id;if not found then return 'fenced';end if;
  perform id from auth.users where id=op.account_id for update;
  select * into c from mort_auth_guard.control where singleton for update;
  select * into g from mort_auth_guard.account_generations where account_id=op.account_id for update;
  select * into op from mort_auth_guard.operation_grants where id=operation_id for update;
  if op.state='committed' then return 'committed';end if;
  if op.state='fenced' then return 'fenced';end if;
  if c.enabled is not true or g.deleted_at is not null or clock_timestamp()>=op.expires_at or op.fence_generation<>g.fence_generation
    or op.address_generation<>g.address_generation or op.credential_generation<>g.credential_generation
    or op.activation_generation<>c.activation_generation or op.restore_generation<>c.restore_generation then
    update mort_auth_guard.operation_grants set state='fenced',completed_at=clock_timestamp() where id=op.id;
    update mort_auth_guard.account_generations set fence_generation=fence_generation+1 where account_id=op.account_id and fence_generation=op.fence_generation;
    update mort_auth_guard.capabilities set state='retired' where digest=op.capability_digest and state<>'consumed';return 'fenced';
  end if;
  update mort_auth_guard.operation_grants set state='pending' where id=op.id;return 'pending';
end $$;
revoke all on function mort_auth_guard.reserve_password(jsonb),mort_auth_guard.guard_auth_user_mutation(),mort_auth_guard.reconcile_operation(uuid) from public,anon,authenticated;
grant execute on function mort_auth_guard.reserve_password(jsonb),mort_auth_guard.reconcile_operation(uuid) to service_role;
create trigger mort_auth_guard_mutation before update or delete on auth.users for each row execute function mort_auth_guard.guard_auth_user_mutation();
commit;
