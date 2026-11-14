-- Chat attachments (private bucket, 10MiB) authorization.
-- This is the design verified on mort-p-backend-test by the adversarial
-- exploit suite (scripts/qa-security-exploit-suite.mjs, 30/30) and the
-- content-swap exploit test (scripts/qa-swap-exploit-test.mjs).
--
-- Security properties:
--  * Sender may create objects only inside their own <uuid> folder and only
--    while an active platform user (private.is_active_user()).
--  * Anonymous users can neither upload nor read (bucket is private and
--    policies apply to authenticated only).
--  * Reads: staff (admin/moderator), the owner, or members of a conversation
--    whose message (approved, not deleted) carries this attachment_path.
--  * Deletes: staff only.
--  * No UPDATE policy exists by design: bound objects cannot be overwritten,
--    so the sender cannot swap bytes after staff approval (verified).
--  * attach_message_file_v1 (SECURITY DEFINER, empty search_path) binds a
--    message to an uploaded object, re-quarantines the message (flagged, or
--    blocked stays blocked), and writes the moderation log entry.

create policy mort_chat_attachments_insert_own_folder
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.is_active_user()
  );

create policy mort_chat_attachments_read_authorized
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (
      private.has_staff_role(array['admin'::mort_role, 'moderator'::mort_role])
      or (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.messages message
        join public.conversation_members member
          on member.conversation_id = message.conversation_id
        where message.attachment_path = storage.objects.name
          and member.user_id = auth.uid()
          and message.deleted_at is null
          and message.moderation_status = 'approved'
      )
    )
  );

create policy mort_chat_attachments_delete_staff
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and private.has_staff_role(array['admin'::mort_role, 'moderator'::mort_role])
  );

create or replace function public.attach_message_file_v1(
  p_message_id uuid,
  p_attachment_path text
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := (select auth.uid());
  v_message public.messages%rowtype;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_message_id is null or nullif(btrim(p_attachment_path), '') is null then
    return jsonb_build_object('ok', false, 'code', 'attachment_request_invalid');
  end if;

  if p_attachment_path !~ ('^' || v_user::text || '/[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp|pdf)$') then
    return jsonb_build_object('ok', false, 'code', 'attachment_path_invalid');
  end if;

  select * into v_message
  from public.messages
  where id = p_message_id
    and sender_id = v_user
    and deleted_at is null;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'message_not_found');
  end if;
  if v_message.attachment_path is not null then
    return jsonb_build_object('ok', false, 'code', 'attachment_already_set');
  end if;

  if not exists (
    select 1 from storage.objects
    where bucket_id = 'chat-attachments'
      and name = p_attachment_path
  ) then
    return jsonb_build_object('ok', false, 'code', 'attachment_not_uploaded');
  end if;

  update public.messages
  set attachment_path = p_attachment_path,
      moderation_status = case
        when moderation_status = 'blocked' then 'blocked'
        else 'flagged'
      end,
      moderation_reason = case
        when moderation_status = 'blocked' then moderation_reason
        else 'This attachment is held for safety review before it can be delivered.'
      end
  where id = p_message_id
    and sender_id = v_user
    and attachment_path is null;

  insert into private.message_moderation_log(
    message_id, conversation_id, sender_id, rule_id, category, scan_result
  ) values (
    p_message_id, v_message.conversation_id, v_user, 'attachment-quarantine',
    'attachment', 'flag'
  );

  return jsonb_build_object(
    'ok', true,
    'message_id', p_message_id,
    'scanner_status', case
      when v_message.moderation_status = 'blocked' then 'blocked'
      else 'flagged'
    end
  );
end;
$function$;

grant execute on function public.attach_message_file_v1(uuid, text) to authenticated;
