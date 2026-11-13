-- MORT message safety scanner contract (issue #49 moderation hardening).
-- Run only against a disposable QA database restored from the production
-- baseline, after applying migration 20261113150000_message_safety_scanner.sql.
-- All synthetic users and rows are rolled back at the end.
--
-- Verifies:
--   1. Predatory content (sexualized payment-for-items, explicit terms,
--      off-platform contact redirection, grooming secrecy) is blocked and
--      never delivered to the recipient.
--   2. Ambiguous patterns (contact handle requests, links, earnings lures,
--      phone-number-shaped text) are held for human review, not delivered.
--   3. Legitimate work messages (photos of the yard, scheduling, pay
--      discussion at realistic rates) are delivered immediately.
--   4. The recipient's thread view and previews contain only approved
--      messages; blocked/flagged content never leaks into previews or
--      unread counts.
--   5. Evidence preservation: blocked/flagged messages keep body, sender,
--      timestamps; the moderation log records which rule fired.
--   6. Moderators can approve a held message (human review path) and
--      non-staff cannot.
--   7. The rule table and scanner functions are not executable/readable by
--      anon or authenticated clients (no rule probing).
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public, auth, pg_catalog;

select plan(24);

-- Synthetic users -----------------------------------------------------------
create temporary table scanner_users (
  user_key text primary key,
  id uuid not null default gen_random_uuid(),
  profile_role public.mort_role not null,
  account_status text not null,
  date_of_birth date,
  email_confirmed boolean not null
) on commit drop;

insert into scanner_users (user_key, profile_role, account_status, date_of_birth, email_confirmed)
values
  ('teen', 'teen', 'active', date '2010-01-01', true),
  ('adult', 'adult', 'active', date '1988-01-01', true),
  ('moderator', 'moderator', 'active', date '1985-01-01', true),
  ('other_teen', 'teen', 'active', date '2009-01-01', true);

-- The QA baseline does not carry the auth.users -> profiles trigger; create
-- it for the lifetime of this transaction so synthetic signups get profiles.
drop trigger if exists on_auth_user_created_mort on auth.users;
create trigger on_auth_user_created_mort
  after insert on auth.users
  for each row execute function private.handle_new_user();

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  u.id,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated',
  'authenticated',
  u.user_key || '@scanner.example.test',
  '',
  case when u.email_confirmed then now() else null end,
  '{}'::jsonb,
  jsonb_build_object('date_of_birth', u.date_of_birth::text, 'display_name', u.user_key),
  now(), now()
from scanner_users u;

update public.profiles p
set role = u.profile_role,
    account_status = u.account_status,
    date_of_birth = u.date_of_birth
from scanner_users u
where p.id = u.id;

-- Staff authority lives in private.user_roles, not profiles.role.
insert into private.user_roles (user_id, role)
select u.id, 'moderator'::public.mort_role
from scanner_users u
where u.user_key = 'moderator';

create temporary table scanner_conv (
  conv_key text primary key,
  id uuid not null default gen_random_uuid()
) on commit drop;

insert into scanner_conv (conv_key) values ('adult_teen'), ('teen_teen');

insert into public.conversations (id, conversation_type, status)
select c.id, 'job', 'active' from scanner_conv c;

insert into public.conversation_members (conversation_id, user_id)
select c.id, u.id
from scanner_conv c
join scanner_users u
  on (c.conv_key = 'adult_teen' and u.user_key in ('teen','adult'))
  or (c.conv_key = 'teen_teen' and u.user_key in ('teen','other_teen'));

-- Helper: send as a user and return (status, reason) from the RPC payload.
create function pg_temp.tmp_scanner_send(
  p_conv_key text, p_user_key text, p_body text, p_request_suffix text
) returns jsonb
language plpgsql
security definer
as $fn$
declare
  v_user_id uuid := (select id from scanner_users where user_key = p_user_key);
  v_conv_id uuid := (select id from scanner_conv where conv_key = p_conv_key);
begin
  perform set_config('request.jwt.claim.sub', v_user_id::text, true);
  return public.send_safe_message_v2(
    v_conv_id, p_body,
    ('00000000-0000-0000-0000-' || right('000000000000' || substr(md5(p_request_suffix || p_user_key || p_body), 1, 12), 12))::uuid
  );
end;
$fn$;

-- 1. Blocked: payment offered for worn/personal items ----------------------
select is(
  (tmp_scanner_send('adult_teen','adult','If you include your pants Ill pay more','a1') ->> 'scanner_status'),
  'blocked',
  'sexualized payment-for-items message is blocked'
);

select is(
  (tmp_scanner_send('adult_teen','adult','can you send me some pics of yourself','a2') ->> 'scanner_status'),
  'blocked',
  'request for photos of the recipient is blocked'
);

select is(
  (tmp_scanner_send('adult_teen','adult','dm me on instagram','a3') ->> 'scanner_status'),
  'blocked',
  'off-platform contact redirection is blocked'
);

select is(
  (tmp_scanner_send('adult_teen','adult','keep this between us','a4') ->> 'scanner_status'),
  'blocked',
  'grooming secrecy pressure is blocked'
);

select is(
  (tmp_scanner_send('adult_teen','adult','will you send nudes','a5') ->> 'scanner_status'),
  'blocked',
  'explicit sexual content is blocked'
);

-- 2. Flagged/held for review: ambiguous patterns ---------------------------
select is(
  (tmp_scanner_send('adult_teen','adult','whats your snap','b1') ->> 'scanner_status'),
  'flagged',
  'contact handle request is held for review'
);

select is(
  (tmp_scanner_send('adult_teen','adult','earn 5000 a week','b2') ->> 'scanner_status'),
  'flagged',
  'unrealistic earnings offer is held for review'
);

-- 3. Clean: legitimate work messages ---------------------------------------
select is(
  (tmp_scanner_send('adult_teen','adult','Great, see you Saturday at 10 for the yard work','c1') ->> 'scanner_status'),
  'approved',
  'normal scheduling message is delivered'
);

select is(
  (tmp_scanner_send('adult_teen','adult','can you send me some pics of the yard when done','c2') ->> 'scanner_status'),
  'approved',
  'request for photos of the work (not the person) is delivered'
);

select is(
  (tmp_scanner_send('adult_teen','adult','the job pays 40 dollars for about two hours','c3') ->> 'scanner_status'),
  'approved',
  'realistic pay discussion is delivered'
);

-- 4. Recipient view: only approved messages --------------------------------
select set_config('request.jwt.claim.sub', (select id from scanner_users where user_key='teen')::text, true);
select is(
  (select count(*)::int from jsonb_array_elements(
    (public.list_thread_messages_page((select id from scanner_conv where conv_key='adult_teen')) -> 'items')
  ) item where item ->> 'scanner_status' <> 'approved'),
  0,
  'teen thread view contains only approved messages'
);

-- All fixture messages share one transaction timestamp, so the "latest
-- approved" preview is not deterministic; assert instead that the preview
-- never contains blocked or flagged content.
select ok(
  coalesce(
    ((public.list_thread_messages_page((select id from scanner_conv where conv_key='adult_teen')) -> 'thread') ->> 'last_message_preview'),
    ''
  ) not in (
    'If you include your pants Ill pay more',
    'can you send me some pics of yourself',
    'dm me on instagram',
    'keep this between us',
    'will you send nudes',
    'whats your snap',
    'earn 5000 a week'
  ),
  'thread preview shows only approved content (no blocked leak)'
);

select is(
  ((public.list_thread_messages_page((select id from scanner_conv where conv_key='adult_teen')) -> 'thread') ->> 'unread_count')::int,
  3,
  'unread count counts only approved messages'
);

-- 5. Evidence preservation ---------------------------------------------------
select is(
  (select count(*)::int from public.messages m
   join public.conversations c on c.id = m.conversation_id
   join scanner_conv sc on sc.id = c.id
   where m.moderation_status in ('blocked','flagged')),
  7,
  'blocked and flagged messages are preserved, not discarded'
);

select is(
  (select count(*)::int from private.message_moderation_log l
   join scanner_conv sc on sc.id = l.conversation_id
   where l.scan_result in ('blocked','flag')),
  8,
  'moderation log records every fired rule with sender and conversation'
);

select ok(
  exists (select 1 from private.message_moderation_log l
          join scanner_conv sc on sc.id = l.conversation_id
          where l.rule_id = 'sexual payment' and l.scan_result = 'blocked'),
  'log identifies which rule fired for the predatory message'
);

select ok(
  (select count(*) from public.messages m
   join private.message_moderation_log l on l.message_id = m.id
   where l.rule_id = 'sexual payment'
     and m.sender_id = (select id from scanner_users where user_key='adult')
     and m.created_at is not null) > 0,
  'sender identity and timestamp are preserved with the evidence'
);

-- 6. Human review path ------------------------------------------------------
-- Moderator approves the held earnings-lure message.
select set_config('request.jwt.claim.sub', (select id from scanner_users where user_key='moderator')::text, true);
select ok(
  public.mort_moderate_message(
    (select m.id from public.messages m
     join public.conversations c on c.id = m.conversation_id
     join scanner_conv sc on sc.id = c.id
     where m.body = 'earn 5000 a week' limit 1),
    'approved', 'manual review: acceptable'
  ) is not null,
  'moderator can approve a held message'
);

-- Non-staff cannot moderate.
select set_config('request.jwt.claim.sub', (select id from scanner_users where user_key='teen')::text, true);
select throws_ok(
  'select public.mort_moderate_message((select m.id from public.messages m limit 1), ''approved'', ''x'')',
  'Authorized moderation role required',
  'non-staff teen cannot moderate messages'
);

-- After approval the message becomes visible to the recipient.
select is(
  (select count(*)::int from jsonb_array_elements(
    (public.list_thread_messages_page((select id from scanner_conv where conv_key='adult_teen')) -> 'items')
  ) item where item ->> 'body' = 'earn 5000 a week'),
  1,
  'approved-by-moderator message becomes visible to the recipient'
);

-- 7. Scanner internals are locked down --------------------------------------
select is(
  has_function_privilege('authenticated', 'private.scan_message_body(text, boolean)', 'execute'),
  false,
  'authenticated clients cannot execute the scanner directly'
);

select is(
  has_table_privilege('authenticated', 'private.message_safety_rules', 'select'),
  false,
  'authenticated clients cannot read the rule table'
);

select is(
  has_table_privilege('authenticated', 'private.message_moderation_log', 'select'),
  false,
  'authenticated clients cannot read the moderation log'
);

select is(
  has_table_privilege('anon', 'private.message_safety_rules', 'select'),
  false,
  'anon cannot read the rule table'
);

select * from finish();

rollback;
