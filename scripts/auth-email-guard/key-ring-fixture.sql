-- Owned disposable fixture adapter only. Not an applied migration.
create table mort_fixture.item_key_ids(item_id uuid primary key references mort_auth_guard.items(id) on delete cascade,kid text not null check(kid ~ '^[A-Za-z0-9_-]{1,32}$'));
alter table mort_fixture.item_key_ids enable row level security;
revoke all on mort_fixture.item_key_ids from public,anon,authenticated,service_role;
create function mort_fixture.issue_with_kid(event jsonb,material jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;kid text:=material->>'codeKid';
begin
 if kid is null or kid!~'^[A-Za-z0-9_-]{1,32}$' or position('v2.'||kid||'.' in coalesce(material->>'encryptedEnvelope',''))<>1 then return '{"ok":false}'::jsonb;end if;
 -- Preserve the applied function's v1 validation. Install the complete versioned
 -- ciphertext in the same transaction before anything can claim this outbox row.
 result:=mort_auth_guard.issue_event(event,material||jsonb_build_object('encryptedEnvelope',substring(material->>'encryptedEnvelope' from length('v2.'||kid||'.')+1)));
 if coalesce((result->>'ok')::boolean,false) and not coalesce((result->>'replayed')::boolean,false) then
 insert into mort_fixture.item_key_ids(item_id,kid) values((material->>'itemId')::uuid,kid);
 update mort_auth_guard.outbox set encrypted_envelope=material->>'encryptedEnvelope' where item_id=(material->>'itemId')::uuid;
 end if;
 return result;
end $$;
revoke all on function mort_fixture.issue_with_kid(jsonb,jsonb) from public,anon,authenticated;
grant execute on function mort_fixture.issue_with_kid(jsonb,jsonb) to service_role;
