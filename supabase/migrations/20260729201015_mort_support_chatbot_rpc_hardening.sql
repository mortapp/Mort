-- Forward hardening found while integrating the Edge Function surface.

create or replace function public.support_consume_endpoint_limit(p_scope text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer;
  v_window integer;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select setting.request_limit, setting.window_seconds
  into v_limit, v_window
  from (values
    ('kb_search', 30, 600),
    ('ticket_create', 5, 3600),
    ('tool_execute', 20, 600),
    ('feedback', 20, 3600),
    ('upload_authorize', 8, 3600),
    ('attachment_submit', 12, 3600),
    ('attachment_download', 30, 300),
    ('admin_copilot', 30, 600)
  ) as setting(scope, request_limit, window_seconds)
  where setting.scope = p_scope;
  if v_limit is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_rate_limit_scope');
  end if;
  if not private.support_take_rate_limit(auth.uid(), p_scope, v_limit, v_window) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.support_search_kb(
  p_query text,
  p_limit integer default 5
)
returns table (
  id uuid,
  title text,
  excerpt text,
  source_url text,
  navigation_route text,
  rank real
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_query tsquery;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return;
  end if;
  if char_length(btrim(coalesce(p_query, ''))) not between 2 and 500 then
    return;
  end if;
  if not private.support_take_rate_limit(auth.uid(), 'kb_search', 30, 600) then
    return;
  end if;
  v_role := public.current_profile_role()::text;
  v_query := websearch_to_tsquery('english'::regconfig, left(btrim(p_query), 500));
  return query
  select document.id,
    document.title,
    left(document.content, 700),
    document.source_url,
    document.navigation_route,
    ts_rank(document.search_vector, v_query)
  from public.support_kb_documents document
  where document.status = 'published'
    and document.review_due_at >= current_date
    and ('all' = any(document.audience) or v_role = any(document.audience))
    and document.search_vector @@ v_query
  order by ts_rank(document.search_vector, v_query) desc, document.title
  limit least(greatest(coalesce(p_limit, 5), 1), 8);
end;
$$;

create or replace function public.support_server_record_assistant(
  p_owner_id uuid,
  p_conversation_id uuid,
  p_content text,
  p_intent text,
  p_safety_level smallint,
  p_response_mode text,
  p_cited_document_ids uuid[] default '{}'::uuid[],
  p_client_request_id uuid default gen_random_uuid(),
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation public.support_conversations%rowtype;
  v_message public.support_messages%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;
  if char_length(btrim(coalesce(p_content, ''))) not between 1 and 4000
    or char_length(btrim(coalesce(p_intent, ''))) not between 3 and 80
    or p_safety_level not between 0 and 3
    or p_response_mode not in ('deterministic', 'anthropic', 'disabled', 'staff')
    or cardinality(coalesce(p_cited_document_ids, '{}'::uuid[])) > 8 then
    return jsonb_build_object('ok', false, 'code', 'invalid_assistant_response');
  end if;
  select * into v_conversation
  from public.support_conversations conversation
  where conversation.id = p_conversation_id
    and conversation.owner_id = p_owner_id
    and conversation.status <> 'deleted'
  for update;
  if v_conversation.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_conversation_not_found');
  end if;

  select * into v_message
  from public.support_messages message
  where message.conversation_id = v_conversation.id
    and message.role = 'assistant'
    and message.client_request_id = p_client_request_id;
  if v_message.id is not null then
    return jsonb_build_object('ok', true, 'replayed', true, 'message', to_jsonb(v_message));
  end if;

  insert into public.support_messages (
    conversation_id, role, content, intent, safety_level, response_mode,
    cited_document_ids, client_request_id
  ) values (
    v_conversation.id, 'assistant', btrim(p_content), btrim(p_intent),
    p_safety_level, p_response_mode, coalesce(p_cited_document_ids, '{}'::uuid[]),
    p_client_request_id
  )
  on conflict (conversation_id, client_request_id)
    where client_request_id is not null and role = 'assistant'
  do nothing
  returning * into v_message;

  if v_message.id is null then
    select * into v_message
    from public.support_messages message
    where message.conversation_id = v_conversation.id
      and message.role = 'assistant'
      and message.client_request_id = p_client_request_id;
    return jsonb_build_object('ok', true, 'replayed', true, 'message', to_jsonb(v_message));
  end if;

  update public.support_conversations
  set response_mode = p_response_mode,
      highest_safety_level = greatest(highest_safety_level, p_safety_level),
      last_message_at = now()
  where id = v_conversation.id;
  insert into public.support_action_audit (
    actor_id, conversation_id, action, authorization_basis,
    target_type, target_id, correlation_id, safe_metadata
  ) values (
    null, v_conversation.id, 'assistant_response_recorded', 'edge_service',
    'support_message', v_message.id, p_correlation_id,
    jsonb_build_object('mode', p_response_mode, 'safety_level', p_safety_level,
      'citation_count', cardinality(coalesce(p_cited_document_ids, '{}'::uuid[])))
  );
  return jsonb_build_object('ok', true, 'replayed', false, 'message', to_jsonb(v_message));
end;
$$;

create or replace function public.support_delete_my_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  delete from public.support_messages message
  using public.support_conversations conversation
  where conversation.id = p_conversation_id
    and conversation.owner_id = auth.uid()
    and message.conversation_id = conversation.id;
  update public.support_conversations conversation
  set status = 'deleted',
      title = 'Deleted support conversation',
      highest_safety_level = 0,
      last_message_at = now(),
      retention_until = now()
  where conversation.id = p_conversation_id
    and conversation.owner_id = auth.uid();
  get diagnostics v_count = row_count;
  return jsonb_build_object(
    'ok', v_count = 1,
    'code', case when v_count = 1 then 'deleted' else 'support_conversation_not_found' end
  );
end;
$$;

revoke all on function public.support_consume_endpoint_limit(text) from public, anon;
grant execute on function public.support_consume_endpoint_limit(text) to authenticated, service_role;
revoke all on function public.support_search_kb(text, integer) from public, anon;
grant execute on function public.support_search_kb(text, integer) to authenticated, service_role;
revoke all on function public.support_server_record_assistant(
  uuid, uuid, text, text, smallint, text, uuid[], uuid, uuid
) from public, anon, authenticated;
grant execute on function public.support_server_record_assistant(
  uuid, uuid, text, text, smallint, text, uuid[], uuid, uuid
) to service_role;
revoke all on function public.support_delete_my_conversation(uuid) from public, anon;
grant execute on function public.support_delete_my_conversation(uuid) to authenticated, service_role;
