-- Keep the Flutter conversation API aligned with the production conversation
-- model (`conversations` / `conversation_members` / `messages`).

alter table public.messages
  add column if not exists client_request_id uuid;

create unique index if not exists messages_sender_client_request_id_uidx
  on public.messages (sender_id, client_request_id)
  where client_request_id is not null;

create or replace function private.message_thread_summary(
  p_conversation_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_conversation public.conversations%rowtype;
  v_counterparty public.profiles%rowtype;
  v_teen_id uuid;
  v_adult_id uuid;
  v_guardian_id uuid;
  v_job_title text;
  v_last_message text;
  v_last_message_at timestamptz;
  v_unread_count integer;
begin
  if p_user_id is null or p_user_id <> (select auth.uid()) then
    return null;
  end if;

  select conversation.* into v_conversation
  from public.conversations as conversation
  where conversation.id = p_conversation_id
    and private.can_access_conversation(conversation.id);
  if not found then return null; end if;

  select profile.* into v_counterparty
  from public.conversation_members as member
  join public.profiles as profile on profile.id = member.user_id
  where member.conversation_id = p_conversation_id
    and member.user_id <> p_user_id
  order by member.joined_at, member.user_id
  limit 1;

  select profile.id into v_teen_id
  from public.conversation_members as member
  join public.profiles as profile on profile.id = member.user_id
  where member.conversation_id = p_conversation_id
    and profile.role = 'teen'::public.mort_role
  order by member.joined_at, member.user_id
  limit 1;

  select profile.id into v_adult_id
  from public.conversation_members as member
  join public.profiles as profile on profile.id = member.user_id
  where member.conversation_id = p_conversation_id
    and profile.role = 'adult'::public.mort_role
  order by member.joined_at, member.user_id
  limit 1;

  select profile.id into v_guardian_id
  from public.conversation_members as member
  join public.profiles as profile on profile.id = member.user_id
  where member.conversation_id = p_conversation_id
    and profile.role = 'guardian'::public.mort_role
  order by member.joined_at, member.user_id
  limit 1;

  select job.title into v_job_title
  from public.jobs as job
  where job.id = v_conversation.job_id;

  select left(message.body, 160), message.created_at
    into v_last_message, v_last_message_at
  from public.messages as message
  where message.conversation_id = p_conversation_id
    and message.deleted_at is null
    and message.moderation_status = 'approved'
  order by message.created_at desc, message.id desc
  limit 1;

  select count(*)::integer into v_unread_count
  from public.messages as message
  join public.conversation_members as member
    on member.conversation_id = message.conversation_id
   and member.user_id = p_user_id
  where message.conversation_id = p_conversation_id
    and message.sender_id <> p_user_id
    and message.deleted_at is null
    and message.moderation_status = 'approved'
    and (member.last_read_at is null or message.created_at > member.last_read_at);

  return jsonb_build_object(
    'id', v_conversation.id,
    'job_id', v_conversation.job_id,
    'application_id', null,
    'teen_id', v_teen_id,
    'adult_id', v_adult_id,
    'guardian_id', v_guardian_id,
    'lifecycle_status', v_conversation.status,
    'updated_at', v_conversation.updated_at,
    'unread_count', coalesce(v_unread_count, 0),
    'job_title', v_job_title,
    'counterparty_id', v_counterparty.id,
    'counterparty_display_name', v_counterparty.display_name,
    'counterparty_role', v_counterparty.role::text,
    'counterparty_verification_status', v_counterparty.verification_status,
    'last_message_preview', v_last_message,
    'last_message_at', v_last_message_at
  );
end;
$function$;

revoke all on function private.message_thread_summary(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.list_my_message_threads_page(
  p_query text default '',
  p_cursor_updated_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_query text := lower(btrim(coalesce(p_query, '')));
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_items jsonb;
  v_has_more boolean;
  v_next_cursor jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not exists (
    select 1 from public.profiles as profile
    where profile.id = v_user_id and profile.account_status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if (p_cursor_updated_at is null) <> (p_cursor_id is null) then
    return jsonb_build_object('ok', false, 'code', 'message_cursor_invalid');
  end if;

  with candidates as (
    select conversation.id, conversation.updated_at
    from public.conversations as conversation
    join public.conversation_members as member
      on member.conversation_id = conversation.id
     and member.user_id = v_user_id
    where (p_cursor_updated_at is null
      or (conversation.updated_at, conversation.id) < (p_cursor_updated_at, p_cursor_id))
      and (
        v_query = ''
        or exists (
          select 1
          from public.jobs as job
          where job.id = conversation.job_id
            and position(v_query in lower(job.title)) > 0
        )
        or exists (
          select 1
          from public.conversation_members as other_member
          join public.profiles as other_profile on other_profile.id = other_member.user_id
          where other_member.conversation_id = conversation.id
            and other_member.user_id <> v_user_id
            and position(v_query in lower(coalesce(other_profile.display_name, ''))) > 0
        )
        or exists (
          select 1 from public.messages as message
          where message.conversation_id = conversation.id
            and message.deleted_at is null
            and message.moderation_status = 'approved'
            and position(v_query in lower(message.body)) > 0
        )
      )
    order by conversation.updated_at desc, conversation.id desc
    limit v_limit + 1
  ), numbered as (
    select candidates.id, candidates.updated_at,
      row_number() over (order by candidates.updated_at desc, candidates.id desc) as row_number,
      private.message_thread_summary(candidates.id, v_user_id) as item
    from candidates
  )
  select coalesce(
      jsonb_agg(numbered.item order by numbered.updated_at desc, numbered.id desc)
        filter (where numbered.row_number <= v_limit),
      '[]'::jsonb
    ),
    count(*) > v_limit
  into v_items, v_has_more
  from numbered;

  if v_has_more then
    with candidates as (
      select conversation.id, conversation.updated_at
      from public.conversations as conversation
      join public.conversation_members as member
        on member.conversation_id = conversation.id
       and member.user_id = v_user_id
      where (p_cursor_updated_at is null
        or (conversation.updated_at, conversation.id) < (p_cursor_updated_at, p_cursor_id))
        and (
          v_query = ''
          or exists (select 1 from public.jobs as job
            where job.id = conversation.job_id
              and position(v_query in lower(job.title)) > 0)
          or exists (select 1 from public.conversation_members as other_member
            join public.profiles as other_profile on other_profile.id = other_member.user_id
            where other_member.conversation_id = conversation.id
              and other_member.user_id <> v_user_id
              and position(v_query in lower(coalesce(other_profile.display_name, ''))) > 0)
          or exists (select 1 from public.messages as message
            where message.conversation_id = conversation.id
              and message.deleted_at is null
              and message.moderation_status = 'approved'
              and position(v_query in lower(message.body)) > 0)
        )
      order by conversation.updated_at desc, conversation.id desc
      limit v_limit + 1
    )
    select jsonb_build_object('updated_at', candidates.updated_at, 'id', candidates.id)
      into v_next_cursor
    from candidates
    order by candidates.updated_at desc, candidates.id desc
    offset v_limit - 1 limit 1;
  end if;

  return jsonb_build_object(
    'items', v_items,
    'has_more', coalesce(v_has_more, false),
    'next_cursor', v_next_cursor
  );
end;
$function$;

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

create or replace function public.mark_message_thread_read(p_thread_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_thread_id is null or not private.can_access_conversation(p_thread_id) then
    return jsonb_build_object('ok', false, 'code', 'conversation_unavailable');
  end if;

  update public.conversation_members
  set last_read_at = now()
  where conversation_id = p_thread_id and user_id = v_user_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'conversation_unavailable');
  end if;
  return jsonb_build_object('ok', true);
end;
$function$;

create or replace function public.send_safe_message_v2(
  p_thread_id uuid,
  p_body text,
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_message_id uuid;
  v_message public.messages%rowtype;
  v_body text := btrim(coalesce(p_body, ''));
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if p_thread_id is null or p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'message_request_invalid');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text || ':' || p_client_request_id::text, 0)
  );

  select message.id, message.conversation_id, message.body
    into v_message_id, v_message.conversation_id, v_message.body
  from public.messages as message
  where message.sender_id = v_user_id
    and message.client_request_id = p_client_request_id;
  if found then
    if v_message.conversation_id <> p_thread_id or v_message.body <> v_body then
      return jsonb_build_object('ok', false, 'code', 'message_request_id_reused');
    end if;
    select * into v_message from public.messages where id = v_message_id;
  else
    v_message_id := public.mort_send_message(p_thread_id, v_body);
    update public.messages
    set client_request_id = p_client_request_id
    where id = v_message_id and sender_id = v_user_id
    returning * into v_message;
  end if;

  return jsonb_build_object(
    'id', v_message.id,
    'thread_id', v_message.conversation_id,
    'sender_id', v_message.sender_id,
    'body', v_message.body,
    'scanner_status', v_message.moderation_status,
    'scanner_reason', null,
    'created_at', v_message.created_at
  );
end;
$function$;

revoke all on function public.list_my_message_threads_page(text, timestamptz, uuid, integer)
  from public, anon;
revoke all on function public.list_thread_messages_page(uuid, timestamptz, uuid, integer)
  from public, anon;
revoke all on function public.mark_message_thread_read(uuid)
  from public, anon;
revoke all on function public.send_safe_message_v2(uuid, text, uuid)
  from public, anon;
grant execute on function public.list_my_message_threads_page(text, timestamptz, uuid, integer)
  to authenticated;
grant execute on function public.list_thread_messages_page(uuid, timestamptz, uuid, integer)
  to authenticated;
grant execute on function public.mark_message_thread_read(uuid)
  to authenticated;
grant execute on function public.send_safe_message_v2(uuid, text, uuid)
  to authenticated;

