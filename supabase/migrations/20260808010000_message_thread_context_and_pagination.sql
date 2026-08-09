-- Participant-only job chat context and keyset pagination. Job chat remains
-- text-only; private proof and support evidence keep their separate workflows.

create index if not exists message_threads_updated_id_desc_idx
on public.message_threads(updated_at desc, id desc);

create or replace function private.get_message_thread_summary(
  p_thread_id uuid,
  p_user_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', thread.id,
    'job_id', thread.job_id,
    'application_id', thread.application_id,
    'teen_id', thread.teen_id,
    'adult_id', thread.adult_id,
    'guardian_id', thread.guardian_id,
    'lifecycle_status', thread.lifecycle_status,
    'updated_at', thread.updated_at,
    'job_title', job.title,
    'counterparty_id', counterparty.id,
    'counterparty_display_name', coalesce(counterparty.display_name, 'MORT participant'),
    'counterparty_role', counterparty.role::text,
    'counterparty_verification_status', counterparty.verification_status::text
  )
  from public.message_threads thread
  left join public.jobs job on job.id = thread.job_id
  left join public.profiles counterparty
    on counterparty.id = case
      when thread.teen_id = p_user_id then thread.adult_id
      else thread.teen_id
    end
  where thread.id = p_thread_id
    and p_user_id is not null
    and p_user_id in (thread.teen_id, thread.adult_id)
    and public.is_thread_participant(thread.id)
$$;

revoke all on function private.get_message_thread_summary(uuid, uuid)
from public, anon, authenticated, service_role;

create or replace function public.list_my_message_threads_page(
  p_query text default null,
  p_cursor_updated_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_query text := nullif(lower(btrim(coalesce(p_query, ''))), '');
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_items jsonb;
  v_count integer;
  v_next_updated_at timestamptz;
  v_next_id uuid;
begin
  if v_user_id is null then raise exception 'authentication_required'; end if;
  if not public.is_profile_active(v_user_id) then
    raise exception 'user_account_restricted';
  end if;
  if (p_cursor_updated_at is null) <> (p_cursor_id is null) then
    raise exception 'invalid_message_thread_cursor';
  end if;
  if v_query is not null and char_length(v_query) > 100 then
    raise exception 'message_thread_query_too_long';
  end if;

  with candidate_rows as (
    select
      thread.id,
      thread.job_id,
      thread.application_id,
      thread.teen_id,
      thread.adult_id,
      thread.guardian_id,
      thread.lifecycle_status,
      thread.updated_at,
      job.title as job_title,
      counterparty.id as counterparty_id,
      coalesce(counterparty.display_name, 'MORT participant')
        as counterparty_display_name,
      counterparty.role::text as counterparty_role,
      counterparty.verification_status::text
        as counterparty_verification_status,
      case
        when latest.scanner_status = 'blocked' then 'Blocked by scanner'
        else left(latest.body, 120)
      end as last_message_preview,
      latest.created_at as last_message_at,
      coalesce(unread.unread_count, 0)::integer as unread_count
    from public.conversation_participants participant
    join public.conversations conversation
      on conversation.id = participant.conversation_id
    join public.message_threads thread
      on thread.id = conversation.legacy_thread_id
    left join public.jobs job on job.id = thread.job_id
    left join public.profiles counterparty
      on counterparty.id = case
        when thread.teen_id = v_user_id then thread.adult_id
        else thread.teen_id
      end
    left join lateral (
      select message.body, message.scanner_status, message.created_at
      from public.messages message
      where message.thread_id = thread.id
      order by message.created_at desc, message.id desc
      limit 1
    ) latest on true
    left join lateral (
      select count(*)::integer as unread_count
      from public.messages message
      where message.thread_id = thread.id
        and message.sender_id <> v_user_id
        and message.created_at > participant.last_read_at
    ) unread on true
    where participant.user_id = v_user_id
      and participant.role in ('teen', 'adult')
      and public.is_thread_participant(thread.id)
      and (
        p_cursor_updated_at is null
        or (thread.updated_at, thread.id)
          < (p_cursor_updated_at, p_cursor_id)
      )
      and (
        v_query is null
        or strpos(lower(coalesce(job.title, '')), v_query) > 0
        or strpos(lower(coalesce(counterparty.display_name, '')), v_query) > 0
      )
    order by thread.updated_at desc, thread.id desc
    limit v_limit + 1
  ), page as (
    select *
    from candidate_rows
    order by updated_at desc, id desc
    limit v_limit
  )
  select
    coalesce(
      jsonb_agg(to_jsonb(page) order by page.updated_at desc, page.id desc),
      '[]'::jsonb
    ),
    (select count(*)::integer from candidate_rows),
    (select updated_at from page order by updated_at asc, id asc limit 1),
    (select id from page order by updated_at asc, id asc limit 1)
  into v_items, v_count, v_next_updated_at, v_next_id
  from page;

  return jsonb_build_object(
    'items', v_items,
    'has_more', v_count > v_limit,
    'next_cursor', case
      when v_count > v_limit then jsonb_build_object(
        'updated_at', v_next_updated_at,
        'id', v_next_id
      )
      else null
    end
  );
end;
$$;

revoke all on function public.list_my_message_threads_page(
  text, timestamptz, uuid, integer
) from public, anon;
grant execute on function public.list_my_message_threads_page(
  text, timestamptz, uuid, integer
) to authenticated, service_role;

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
as $$
declare
  v_user_id uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_items jsonb;
  v_count integer;
  v_next_created_at timestamptz;
  v_next_id uuid;
  v_thread jsonb;
begin
  if v_user_id is null then raise exception 'authentication_required'; end if;
  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    raise exception 'invalid_message_cursor';
  end if;
  if not public.is_profile_active(v_user_id) then
    raise exception 'user_account_restricted';
  end if;
  if not public.is_thread_participant(p_thread_id) then
    raise exception 'thread_participant_required';
  end if;

  v_thread := private.get_message_thread_summary(p_thread_id, v_user_id);
  if v_thread is null then raise exception 'thread_participant_required'; end if;

  with candidates as (
    select message.id, message.thread_id, message.sender_id, message.body,
           message.scanner_status, message.scanner_reason,
           message.safety_category, message.safety_severity,
           message.safer_rewrite_available, message.created_at
    from public.messages message
    where message.thread_id = p_thread_id
      and (
        p_cursor_created_at is null
        or (message.created_at, message.id)
          < (p_cursor_created_at, p_cursor_id)
      )
    order by message.created_at desc, message.id desc
    limit v_limit + 1
  ), page as (
    select * from candidates
    order by created_at desc, id desc
    limit v_limit
  )
  select
    coalesce(
      jsonb_agg(to_jsonb(page) order by page.created_at asc, page.id asc),
      '[]'::jsonb
    ),
    (select count(*)::integer from candidates),
    (select created_at from page order by created_at asc, id asc limit 1),
    (select id from page order by created_at asc, id asc limit 1)
  into v_items, v_count, v_next_created_at, v_next_id
  from page;

  return jsonb_build_object(
    'items', v_items,
    'has_more', v_count > v_limit,
    'lifecycle_status', v_thread->>'lifecycle_status',
    'thread', v_thread,
    'next_cursor', case
      when v_count > v_limit then jsonb_build_object(
        'created_at', v_next_created_at,
        'id', v_next_id
      )
      else null
    end
  );
end;
$$;

revoke all on function public.list_thread_messages_page(
  uuid, timestamptz, uuid, integer
) from public, anon;
grant execute on function public.list_thread_messages_page(
  uuid, timestamptz, uuid, integer
) to authenticated, service_role;

comment on function public.list_my_message_threads_page(
  text, timestamptz, uuid, integer
) is
'Participant-only keyset page with public-safe job and counterparty context.';

comment on function private.get_message_thread_summary(uuid, uuid) is
'Internal participant summary. It excludes exact location, raw scanner evidence, and private identity data.';
