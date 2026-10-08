-- Private atomic consume primitive. Inert while control.enabled=false.
-- No HTTP route, token hook, provider trigger or hosted activation is installed.
begin;
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
