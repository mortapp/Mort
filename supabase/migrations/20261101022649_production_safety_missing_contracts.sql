-- Additive parity for the existing production user_blocks and guardian_links
-- contracts. This migration creates no new user-data tables and does not alter
-- or remove existing rows. It is a proposal only; do not apply to production
-- before isolated integration tests and review.

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
begin
  if v_actor is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_blocked_id is null or p_blocked_id = v_actor or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_block_target');
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_blocked_id) then
    return jsonb_build_object('ok', false, 'code', 'block_target_not_found');
  end if;

  -- The composite primary key makes retries idempotent even though the live
  -- user_blocks table does not store client_request_id.
  insert into public.user_blocks (blocker_id, blocked_id)
  values (v_actor, p_blocked_id)
  on conflict (blocker_id, blocked_id) do nothing;
  get diagnostics v_rows = row_count;

  return jsonb_build_object(
    'ok', true,
    'blocked_id', p_blocked_id,
    'created', v_rows = 1
  );
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

create or replace function private.reject_blocked_conversation_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_recipient uuid;
begin
  if v_actor is not null and new.sender_id <> v_actor then
    raise exception using errcode = '42501', message = 'message_sender_mismatch';
  end if;

  if not exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = new.conversation_id
      and cm.user_id = new.sender_id
  ) then
    raise exception using errcode = '42501', message = 'conversation_member_required';
  end if;

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

