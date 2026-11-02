
-- Messaging workflow: clients cannot self-mark messages approved or alter moderation outcomes.
revoke insert on public.messages from anon, authenticated;

create or replace function public.mort_send_message(
  p_conversation_id uuid,
  p_body text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_message uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.is_active_user() then raise exception 'Active account required'; end if;
  if p_body is null or char_length(btrim(p_body)) < 1 or char_length(p_body) > 4000 then
    raise exception 'Message must contain 1 to 4000 characters';
  end if;
  if not exists (
    select 1 from public.conversations c
    join public.conversation_members cm on cm.conversation_id=c.id
    where c.id=p_conversation_id and c.status='active' and cm.user_id=v_user
  ) then raise exception 'Conversation unavailable'; end if;
  if exists (
    select 1
    from public.conversation_members mine
    join public.conversation_members theirs
      on theirs.conversation_id=mine.conversation_id and theirs.user_id<>v_user
    join public.user_blocks b
      on (b.blocker_id=v_user and b.blocked_id=theirs.user_id)
      or (b.blocker_id=theirs.user_id and b.blocked_id=v_user)
    where mine.conversation_id=p_conversation_id and mine.user_id=v_user
  ) then raise exception 'Messaging is unavailable'; end if;

  insert into public.messages(conversation_id,sender_id,body,moderation_status)
  values (p_conversation_id,v_user,btrim(p_body),'pending')
  returning id into v_message;

  update public.conversations set updated_at=now() where id=p_conversation_id;
  return v_message;
end;
$$;

create or replace function public.mort_moderate_message(
  p_message_id uuid,
  p_status text,
  p_reason text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized moderation role required';
  end if;
  if p_status not in ('approved','flagged','blocked','removed') then
    raise exception 'Invalid moderation outcome';
  end if;
  update public.messages
  set moderation_status=p_status, moderation_reason=nullif(btrim(p_reason),'')
  where id=p_message_id;
  if not found then raise exception 'Message not found'; end if;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values (v_user,'message_moderated','message',p_message_id::text,
          nullif(btrim(p_reason),''),jsonb_build_object('status',p_status));
  return p_message_id;
end;
$$;

revoke all on function public.mort_send_message(uuid,text) from public, anon;
revoke all on function public.mort_moderate_message(uuid,text,text) from public, anon;
grant execute on function public.mort_send_message(uuid,text) to authenticated;
grant execute on function public.mort_moderate_message(uuid,text,text) to authenticated;
