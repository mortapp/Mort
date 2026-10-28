-- Keep held or otherwise non-approved message bodies private to their sender.
-- Table SELECT, Realtime delivery, and the privileged message-page RPC must
-- enforce the same participant visibility rule.
drop policy if exists messages_select_member on public.messages;
create policy messages_select_member
on public.messages
for select
to authenticated
using (
  private.can_access_conversation(conversation_id)
  and ((deleted_at is null) or sender_id = (select auth.uid()))
  and (
    moderation_status = 'approved'
    or sender_id = (select auth.uid())
  )
);

create or replace function public.list_thread_messages_page(
  p_thread_id uuid,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 40
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_items jsonb;
  v_has_more boolean;
  v_next_cursor jsonb;
  v_thread jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_thread_id is null or not private.can_access_conversation(p_thread_id) then
    return jsonb_build_object('ok', false, 'code', 'conversation_unavailable');
  end if;
  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    return jsonb_build_object('ok', false, 'code', 'message_cursor_invalid');
  end if;

  v_thread := private.message_thread_summary(p_thread_id, v_user_id);
  if v_thread is null then
    return jsonb_build_object('ok', false, 'code', 'conversation_unavailable');
  end if;

  with candidates as (
    select message.id, message.conversation_id, message.sender_id,
      message.body, message.moderation_status, message.created_at
    from public.messages as message
    where message.conversation_id = p_thread_id
      and message.deleted_at is null
      and (
        message.moderation_status = 'approved'
        or message.sender_id = v_user_id
      )
      and (p_cursor_created_at is null
        or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id))
    order by message.created_at desc, message.id desc
    limit v_limit + 1
  ), numbered as (
    select candidates.*,
      row_number() over (order by candidates.created_at desc, candidates.id desc) as row_number
    from candidates
  )
  select coalesce(
      jsonb_agg(jsonb_build_object(
        'id', numbered.id,
        'thread_id', numbered.conversation_id,
        'sender_id', numbered.sender_id,
        'body', numbered.body,
        'scanner_status', numbered.moderation_status,
        'scanner_reason', null,
        'created_at', numbered.created_at
      ) order by numbered.created_at desc, numbered.id desc)
        filter (where numbered.row_number <= v_limit),
      '[]'::jsonb
    ),
    count(*) > v_limit
  into v_items, v_has_more
  from numbered;

  if v_has_more then
    with candidates as (
      select message.id, message.created_at
      from public.messages as message
      where message.conversation_id = p_thread_id
        and message.deleted_at is null
        and (
          message.moderation_status = 'approved'
          or message.sender_id = v_user_id
        )
        and (p_cursor_created_at is null
          or (message.created_at, message.id) < (p_cursor_created_at, p_cursor_id))
      order by message.created_at desc, message.id desc
      limit v_limit + 1
    )
    select jsonb_build_object('created_at', candidates.created_at, 'id', candidates.id)
      into v_next_cursor
    from candidates
    order by candidates.created_at desc, candidates.id desc
    offset v_limit - 1 limit 1;
  end if;

  return jsonb_build_object(
    'items', v_items,
    'has_more', coalesce(v_has_more, false),
    'next_cursor', v_next_cursor,
    'lifecycle_status', v_thread->>'lifecycle_status',
    'thread', v_thread
  );
end;
$function$;
