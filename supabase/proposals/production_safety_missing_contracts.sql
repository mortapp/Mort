-- Proposal only: additive parity for existing user_blocks and guardian_links
-- contracts. Do not apply to production. Idempotency records contain actor,
-- opaque request IDs, target, and safe response only; no message or address data.

create table private.safety_action_idempotency (
  actor_id uuid not null references auth.users(id),
  action text not null check (action in ('block_user_v2')),
  request_id uuid not null,
  target_user_id uuid not null references auth.users(id),
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor_id, action, request_id)
);

alter table private.safety_action_idempotency enable row level security;
alter table private.safety_action_idempotency force row level security;
revoke all on private.safety_action_idempotency from public, anon, authenticated, service_role;

create or replace function public.block_user_v2(
  p_blocked_id uuid,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_rows integer := 0;
  v_existing_target uuid;
  v_response jsonb;
begin
  if v_actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_blocked_id is null or p_blocked_id = v_actor or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_block_target');
  end if;

  -- Serialize retries of the same actor/request, including key reuse with a
  -- different target. The pair lock below then orders block and message work.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'block_user_v2:' || v_actor::text || ':' || p_client_request_id::text,
    0
  ));
  select request.target_user_id, request.response
    into v_existing_target, v_response
  from private.safety_action_idempotency request
  where request.actor_id = v_actor
    and request.action = 'block_user_v2'
    and request.request_id = p_client_request_id
  for update;
  if found then
    if v_existing_target <> p_blocked_id then
      return jsonb_build_object('ok', false, 'code', 'idempotency_key_reused');
    end if;
    return v_response || jsonb_build_object('replayed', true);
  end if;

  if not exists (select 1 from public.profiles p where p.id = p_blocked_id) then
    return jsonb_build_object('ok', false, 'code', 'block_target_not_found');
  end if;

  perform private.lock_user_pair(v_actor, p_blocked_id);
  insert into public.user_blocks (blocker_id, blocked_id)
  values (v_actor, p_blocked_id)
  on conflict (blocker_id, blocked_id) do nothing;
  get diagnostics v_rows = row_count;

  v_response := jsonb_build_object(
    'ok', true,
    'blocked_id', p_blocked_id,
    'created', v_rows = 1,
    'replayed', false
  );
  insert into private.safety_action_idempotency (
    actor_id, action, request_id, target_user_id, response
  ) values (
    v_actor, 'block_user_v2', p_client_request_id, p_blocked_id, v_response
  );
  return v_response;
end;
$function$;

revoke all on function public.block_user_v2(uuid, uuid) from public, anon;
grant execute on function public.block_user_v2(uuid, uuid) to authenticated;

create or replace function public.unblock_user(p_blocked_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_rows integer := 0;
begin
  if v_actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_blocked_id is null or p_blocked_id = v_actor then
    return jsonb_build_object('ok', false, 'code', 'invalid_block_target');
  end if;

  delete from public.user_blocks
  where blocker_id = v_actor and blocked_id = p_blocked_id;
  get diagnostics v_rows = row_count;

  return jsonb_build_object(
    'ok', true,
    'removed', v_rows = 1,
    'blocked_id', p_blocked_id
  );
end;
$function$;

revoke all on function public.unblock_user(uuid) from public, anon;
grant execute on function public.unblock_user(uuid) to authenticated;

create or replace function public.resend_guardian_invite(p_link_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_teen_id uuid;
  v_status text;
  v_invited_email text;
begin
  if v_actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select l.teen_user_id, l.status
    into v_teen_id, v_status
  from public.guardian_links l
  where l.id = p_link_id
  for update;

  if not found or v_teen_id <> v_actor then
    return jsonb_build_object('ok', false, 'code', 'guardian_invite_not_available');
  end if;
  if v_status <> 'pending' then
    return jsonb_build_object('ok', false, 'code', 'guardian_invite_stale');
  end if;

  select c.invited_email into v_invited_email
  from private.guardian_invite_codes c
  where c.guardian_link_id = p_link_id
  order by c.created_at desc
  limit 1;

  -- The existing guarded creator validates teen age/role, applies the invite
  -- rate limit, hashes the new code, expires it after seven days, and revokes
  -- prior pending links. Only the teen receives the one-time plaintext code.
  return public.create_guardian_invite_v2(v_invited_email);
end;
$function$;

revoke all on function public.resend_guardian_invite(uuid) from public, anon;
grant execute on function public.resend_guardian_invite(uuid) to authenticated;

-- Serialize block mutations and message inserts on the same canonical pair
-- key. The hash is only a lock key; a collision can add contention but cannot
-- weaken authorization. The UUID strings are ordered before hashing so both
-- directions map to the same transaction-scoped advisory lock.
create or replace function private.user_pair_lock_key(
  p_left_user uuid,
  p_right_user uuid
)
returns bigint
language sql
immutable
set search_path = ''
as $function$
  select pg_catalog.hashtextextended(
    least(p_left_user::text, p_right_user::text) || ':' ||
    greatest(p_left_user::text, p_right_user::text),
    0
  );
$function$;

revoke all on function private.user_pair_lock_key(uuid, uuid)
  from public, anon, authenticated;

create or replace function private.lock_user_pair(
  p_left_user uuid,
  p_right_user uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_left_user is null or p_right_user is null or p_left_user = p_right_user then
    raise exception using errcode = '22023', message = 'invalid_user_pair';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    private.user_pair_lock_key(p_left_user, p_right_user)
  );
end;
$function$;

revoke all on function private.lock_user_pair(uuid, uuid)
  from public, anon, authenticated;

create or replace function private.lock_user_block_pair_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if tg_op = 'UPDATE' then
    if new.blocker_id <> old.blocker_id or new.blocked_id <> old.blocked_id then
      raise exception using errcode = '42501', message = 'block_pair_immutable';
    end if;
    perform private.lock_user_pair(old.blocker_id, old.blocked_id);
    return new;
  elsif tg_op = 'DELETE' then
    perform private.lock_user_pair(old.blocker_id, old.blocked_id);
    return old;
  else
    perform private.lock_user_pair(new.blocker_id, new.blocked_id);
    return new;
  end if;
end;
$function$;

revoke all on function private.lock_user_block_pair_before_write()
  from public, anon, authenticated;

do $migration$
begin
  if not exists (
    select 1
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'user_blocks'
      and t.tgname = 'user_blocks_lock_pair_before_write'
      and not t.tgisinternal
  ) then
    create trigger user_blocks_lock_pair_before_write
      before insert or update or delete on public.user_blocks
      for each row execute function private.lock_user_block_pair_before_write();
  end if;
end;
$migration$;

create or replace function private.reject_blocked_conversation_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_recipient uuid;
  v_lock_key bigint;
  v_lock_keys bigint[];
  v_conversation_status text;
begin
  if v_actor is not null and new.sender_id <> v_actor then
    raise exception using errcode = '42501', message = 'message_sender_mismatch';
  end if;

  select c.status into v_conversation_status
  from public.conversations c
  where c.id = new.conversation_id
  for share;
  if not found or v_conversation_status <> 'active' then
    raise exception using errcode = '42501', message = 'conversation_unavailable';
  end if;

  if not exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = new.conversation_id
      and cm.user_id = new.sender_id
  ) then
    raise exception using errcode = '42501', message = 'conversation_member_required';
  end if;

  -- A conversation may contain multiple members. Acquire all pair locks in
  -- a stable key order so simultaneous messages cannot deadlock by choosing
  -- opposite sender/recipient traversal orders.
  select pg_catalog.array_agg(pair_lock_key order by pair_lock_key)
    into v_lock_keys
  from (
    select distinct private.user_pair_lock_key(new.sender_id, cm.user_id)
      as pair_lock_key
    from public.conversation_members cm
    where cm.conversation_id = new.conversation_id
      and cm.user_id <> new.sender_id
  ) pairs;

  foreach v_lock_key in array coalesce(v_lock_keys, '{}'::bigint[]) loop
    perform pg_catalog.pg_advisory_xact_lock(v_lock_key);
  end loop;

  for v_recipient in
    select cm.user_id
    from public.conversation_members cm
    where cm.conversation_id = new.conversation_id
      and cm.user_id <> new.sender_id
    order by cm.user_id
  loop
    if exists (
      select 1
      from public.user_blocks b
      where (b.blocker_id = new.sender_id and b.blocked_id = v_recipient)
         or (b.blocker_id = v_recipient and b.blocked_id = new.sender_id)
    ) then
      raise exception using errcode = '42501', message = 'message_blocked_by_safety_control';
    end if;
  end loop;

  return new;
end;
$function$;

revoke all on function private.reject_blocked_conversation_message() from public, anon, authenticated;

do $migration$
begin
  if not exists (
    select 1
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'messages'
      and t.tgname = 'messages_reject_blocked_pair'
      and not t.tgisinternal
  ) then
    create trigger messages_reject_blocked_pair
      before insert on public.messages
      for each row execute function private.reject_blocked_conversation_message();
  end if;
end;
$migration$;

