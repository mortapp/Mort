begin;
select plan(18);

select has_function('public', 'block_user_v2', array['uuid', 'uuid']);
select has_function('public', 'unblock_user', array['uuid']);
select has_function('public', 'resend_guardian_invite', array['uuid']);
select has_trigger('public', 'messages', 'messages_reject_blocked_pair');
select ok(
  not has_function_privilege('anon', 'public.block_user_v2(uuid,uuid)', 'execute'),
  'anonymous clients cannot block through the protected RPC'
);
select ok(
  has_function_privilege('authenticated', 'public.block_user_v2(uuid,uuid)', 'execute'),
  'authenticated clients can use the protected block RPC'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, raw_app_meta_data,
  raw_user_meta_data, created_at, updated_at
) values
  ('10000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'qa-teen-1@example.invalid', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('10000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'qa-adult-1@example.invalid', '', '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.profiles (id, role, account_status, date_of_birth)
values
  ('10000000-0000-4000-8000-000000000001', 'teen', 'active', current_date - interval '16 years'),
  ('10000000-0000-4000-8000-000000000002', 'adult', 'active', current_date - interval '25 years')
on conflict (id) do update
set role = excluded.role,
    account_status = excluded.account_status,
    date_of_birth = excluded.date_of_birth;

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select ok(
  (public.block_user_v2('10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001'::uuid)->>'created')::boolean,
  'first block creates one user_blocks row'
);
select ok(
  not (public.block_user_v2('10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002'::uuid)->>'created')::boolean,
  'repeated block is idempotent'
);
select is(
  public.block_user_v2('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000003'::uuid)->>'code',
  'invalid_block_target',
  'self-blocking is rejected'
);

create temporary table qa_guardian_invite as
select response, (response->>'link_id')::uuid as initial_link_id
from (select public.create_guardian_invite_v2(null) as response) invitation;
select ok((select (response->>'ok')::boolean from qa_guardian_invite), 'teen can create a Guardian invite');
create temporary table qa_guardian_resend as
select public.resend_guardian_invite(initial_link_id) as response
from qa_guardian_invite;
select is((select (response->>'ok')::boolean from qa_guardian_resend), true, 'owner can rotate a pending Guardian invite');
select is(
  (select status from public.guardian_links where id = (select initial_link_id from qa_guardian_invite)),
  'revoked',
  'resend revokes the prior pending link without deleting its audit row'
);
select ok(
  (select nullif(response->>'invite_code', '') is not null from qa_guardian_resend),
  'resend returns a fresh one-time code to the link owner'
);
select is(
  (select (response->>'link_id')::uuid = initial_link_id from qa_guardian_resend cross join qa_guardian_invite),
  false,
  'resend issues a new link identifier'
);
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select is(
  public.resend_guardian_invite((select initial_link_id from qa_guardian_invite))->>'code',
  'guardian_invite_not_available',
  'a different account cannot resend another teen invitation'
);
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);

insert into public.conversations (id, conversation_type, status)
values ('30000000-0000-4000-8000-000000000001', 'job', 'active');
insert into public.conversation_members (conversation_id, user_id)
values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001'),
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002');

select throws_ok(
  $$insert into public.messages(conversation_id, sender_id, body)
    values ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'blocked message')$$,
  '42501',
  'message_blocked_by_safety_control',
  'a blocked participant cannot receive a new message'
);

select is(
  (public.unblock_user('10000000-0000-4000-8000-000000000002')->>'removed')::boolean,
  true,
  'unblock removes only the caller-to-target block'
);
select lives_ok(
  $$insert into public.messages(conversation_id, sender_id, body)
    values ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'message after unblock')$$,
  'a new message is allowed after the caller unblocks the participant'
);

select * from finish();
rollback;
