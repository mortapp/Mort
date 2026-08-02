-- Safety classification and restricted-account support happen before ordinary
-- chat quota or any external provider decision.

create or replace function private.support_classify_message(p_message text)
returns jsonb
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  v_message text := lower(btrim(coalesce(p_message, '')));
  v_level smallint := 0;
  v_category text := 'general';
  v_intent text := 'general_support';
  v_action text := 'answer';
begin
  if v_message ~ '(suicid|kill myself|hurt myself|self.?harm|kill (him|her|them|someone)|kidnap|abduct|traffick|weapon|gun|knife|immediate danger|being followed right now|sexual assault|rape|won.?t let me leave|trapped at (the )?job)' then
    v_level := 3;
    v_category := 'immediate_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  elsif v_message ~ '(threat|stalk|harass|blackmail|extort|nude|sexual message|meet.*alone|keep (this|it) (a )?secret|don.?t tell (your )?(parent|guardian)|off.platform|cashapp|gift card|verification code|\bpin\b|password|social security|\bssn\b|passport|driver.?s license|card number|\bcvc\b|\bcvv\b|exact (home )?address|unsafe at (the )?job|scam|fraud)' then
    v_level := 2;
    v_category := 'trust_safety';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_message ~ '(human|real person|support agent|talk to (a )?person|report|block|unsafe|privacy|delete.*account|payment|paid|refund|dispute|identity|verify|login|sign.?in|account|application|job|guardian)' then
    v_level := 1;
    v_category := case
      when v_message ~ '(human|real person|support agent|talk to (a )?person)' then 'support'
      when v_message ~ '(report|block|unsafe)' then 'trust_safety'
      when v_message ~ '(privacy|delete.*account)' then 'privacy'
      when v_message ~ '(payment|paid|refund|dispute)' then 'billing'
      when v_message ~ '(login|sign.?in|account|identity|verify)' then 'account'
      else 'marketplace'
    end;
    v_intent := case
      when v_category = 'support' then 'human_handoff'
      when v_category = 'trust_safety' then 'report_or_block'
      when v_category = 'privacy' then 'privacy_or_deletion'
      when v_category = 'billing' then 'payment_or_dispute'
      when v_category = 'account' then 'account_access'
      else 'jobs_or_applications'
    end;
    v_action := case when v_category = 'support' then 'required_handoff' else 'offer_handoff' end;
  end if;

  return jsonb_build_object(
    'level', v_level,
    'category', v_category,
    'intent', v_intent,
    'action', v_action,
    'provider_allowed', v_level < 2 and v_intent <> 'human_handoff'
  );
end;
$$;

create or replace function public.support_get_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_preferences public.support_user_preferences%rowtype;
  v_account_status text;
  v_deletion_pending boolean;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select profile.account_status::text into v_account_status
  from public.profiles profile where profile.id = auth.uid();
  if v_account_status is null then
    return jsonb_build_object('ok', false, 'code', 'profile_required');
  end if;
  select exists (
    select 1 from public.account_deletion_requests request
    where request.user_id = auth.uid()
      and request.status in ('requested', 'processing', 'retry_pending')
  ) into v_deletion_pending;
  select * into v_preferences
  from public.support_user_preferences preference
  where preference.user_id = auth.uid();
  return jsonb_build_object(
    'ok', true,
    'assistant_enabled', coalesce(v_preferences.assistant_enabled, true),
    'save_history', coalesce(v_preferences.save_history, true),
    'retention_days', coalesce(v_preferences.retention_days, 30),
    'human_support_available', true,
    'guardian_chat_access', false,
    'account_restricted', v_account_status <> 'active',
    'deletion_pending', v_deletion_pending,
    'warning', 'Do not share passwords, PINs, verification codes, payment credentials, government IDs, exact home addresses, or emergency evidence.'
  );
end;
$$;

create or replace function public.support_classify_intent(p_message text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles profile where profile.id = auth.uid()
  ) then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 3 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_message');
  end if;
  if not private.support_take_rate_limit(auth.uid(), 'intent', 60, 600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;
  return jsonb_build_object('ok', true, 'classification', private.support_classify_message(p_message));
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
  if auth.uid() is null or not exists (
    select 1 from public.profiles profile where profile.id = auth.uid()
  ) then return; end if;
  if char_length(btrim(coalesce(p_query, ''))) not between 2 and 500 then return; end if;
  if not private.support_take_rate_limit(auth.uid(), 'kb_search', 30, 600) then return; end if;
  v_role := public.current_profile_role()::text;
  v_query := websearch_to_tsquery('english'::regconfig, left(btrim(p_query), 500));
  return query
  select document.id, document.title, left(document.content, 700),
    document.source_url, document.navigation_route,
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

create or replace function public.support_begin_chat(
  p_message text,
  p_conversation_id uuid default null,
  p_client_request_id uuid default gen_random_uuid(),
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_message_text text := btrim(coalesce(p_message, ''));
  v_conversation public.support_conversations%rowtype;
  v_message public.support_messages%rowtype;
  v_classification jsonb;
  v_preferences public.support_user_preferences%rowtype;
  v_existing public.support_messages%rowtype;
  v_retention integer := 30;
  v_account_status text;
  v_deletion_pending boolean := false;
  v_restricted boolean := false;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select profile.account_status::text into v_account_status
  from public.profiles profile where profile.id = v_user_id;
  if v_account_status is null then
    return jsonb_build_object('ok', false, 'code', 'profile_required');
  end if;
  if char_length(v_message_text) not between 3 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_message');
  end if;
  if p_client_request_id is null or p_correlation_id is null then
    return jsonb_build_object('ok', false, 'code', 'request_identifiers_required');
  end if;

  select message.* into v_existing
  from public.support_messages message
  join public.support_conversations conversation on conversation.id = message.conversation_id
  where conversation.owner_id = v_user_id
    and message.author_id = v_user_id
    and message.client_request_id = p_client_request_id
  limit 1;
  if v_existing.id is not null then
    return jsonb_build_object(
      'ok', true, 'replayed', true,
      'conversation_id', v_existing.conversation_id,
      'message_id', v_existing.id
    );
  end if;

  select exists (
    select 1 from public.account_deletion_requests request
    where request.user_id = v_user_id
      and request.status in ('requested', 'processing', 'retry_pending')
  ) into v_deletion_pending;
  v_restricted := v_account_status <> 'active' or v_deletion_pending;
  v_classification := private.support_classify_message(v_message_text);
  if v_restricted then
    v_classification := jsonb_build_object(
      'level', 1,
      'category', case when v_deletion_pending then 'privacy' else 'account' end,
      'intent', case when v_deletion_pending then 'deletion_pending' else 'account_restricted' end,
      'action', 'required_handoff',
      'provider_allowed', false
    );
  end if;

  if (v_classification->>'level')::integer >= 2 then
    if not private.support_take_rate_limit(v_user_id, 'safety_chat', 60, 600) then
      return jsonb_build_object('ok', false, 'code', 'safety_support_rate_limited');
    end if;
  elsif not private.support_take_rate_limit(v_user_id, 'chat', 30, 600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;

  if (v_classification->>'level')::integer < 2 and p_conversation_id is not null
    and exists (
      select 1 from public.support_messages prior
      where prior.conversation_id = p_conversation_id
        and prior.author_id = v_user_id
        and prior.role = 'user'
        and lower(prior.content) = lower(v_message_text)
        and prior.created_at > now() - interval '60 seconds'
    ) then
    return jsonb_build_object('ok', false, 'code', 'repeated_support_message');
  end if;

  select * into v_preferences
  from public.support_user_preferences preference
  where preference.user_id = v_user_id;
  if found then
    v_retention := case when v_preferences.save_history then v_preferences.retention_days else 1 end;
  end if;

  if p_conversation_id is null then
    insert into public.support_conversations (
      owner_id, client_request_id, title, response_mode, retention_until
    ) values (
      v_user_id, p_client_request_id, left(v_message_text, 80),
      case when v_restricted or not coalesce(v_preferences.assistant_enabled, true)
        then 'disabled' else 'deterministic' end,
      now() + make_interval(days => v_retention)
    ) returning * into v_conversation;
  else
    select * into v_conversation
    from public.support_conversations conversation
    where conversation.id = p_conversation_id
      and conversation.owner_id = v_user_id
      and conversation.status = 'active'
    for update;
    if v_conversation.id is null then
      return jsonb_build_object('ok', false, 'code', 'support_conversation_not_found');
    end if;
  end if;

  insert into public.support_messages (
    conversation_id, author_id, role, content, intent, safety_level,
    response_mode, client_request_id
  ) values (
    v_conversation.id, v_user_id, 'user', v_message_text,
    v_classification->>'intent', (v_classification->>'level')::smallint,
    v_conversation.response_mode, p_client_request_id
  ) returning * into v_message;

  update public.support_conversations
  set last_message_at = now(),
      highest_safety_level = greatest(highest_safety_level, v_message.safety_level),
      retention_until = now() + make_interval(days => v_retention)
  where id = v_conversation.id
  returning * into v_conversation;

  if v_message.safety_level >= 2 then
    insert into public.support_ai_incidents (
      owner_id, conversation_id, message_id, category, severity,
      requires_human_review, redacted_excerpt, correlation_id
    ) values (
      v_user_id, v_conversation.id, v_message.id,
      v_classification->>'category', v_message.safety_level, true,
      '[content withheld; review the authorized conversation]', p_correlation_id
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'conversation', to_jsonb(v_conversation),
    'message', to_jsonb(v_message),
    'classification', v_classification,
    'assistant_enabled', coalesce(v_preferences.assistant_enabled, true) and not v_restricted,
    'account_restricted', v_account_status <> 'active',
    'deletion_pending', v_deletion_pending
  );
end;
$$;

create or replace function public.support_escalate_conversation(
  p_conversation_id uuid,
  p_subject text,
  p_category text default 'other',
  p_summary text default 'User requested human support.',
  p_correlation_id uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation public.support_conversations%rowtype;
  v_ticket public.support_tickets%rowtype;
  v_priority text := 'normal';
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles profile where profile.id = auth.uid()
  ) then return jsonb_build_object('ok', false, 'code', 'authentication_required'); end if;
  if char_length(btrim(coalesce(p_subject, ''))) not between 3 and 120
    or char_length(btrim(coalesce(p_summary, ''))) not between 10 and 2000
    or p_category not in (
      'account_sign_in', 'profile_avatar', 'verification', 'job_application',
      'start_finish_pin', 'job_cancellation', 'payment_compensation',
      'adult_refused_completion', 'teen_abandonment', 'evidence_submission',
      'report_block', 'privacy_deletion', 'mort_plus_play_billing', 'other'
    ) then return jsonb_build_object('ok', false, 'code', 'invalid_handoff_request'); end if;
  select * into v_conversation
  from public.support_conversations conversation
  where conversation.id = p_conversation_id
    and conversation.owner_id = auth.uid()
    and conversation.status <> 'deleted'
  for update;
  if v_conversation.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_conversation_not_found');
  end if;
  if v_conversation.ticket_id is not null then
    return jsonb_build_object(
      'ok', true, 'replayed', true,
      'conversation_id', v_conversation.id,
      'ticket_id', v_conversation.ticket_id
    );
  end if;
  if not private.support_take_rate_limit(auth.uid(), 'handoff', 5, 3600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;
  if v_conversation.highest_safety_level >= 3 then v_priority := 'urgent_safety';
  elsif v_conversation.highest_safety_level = 2 then v_priority := 'high'; end if;

  insert into public.support_tickets (
    requester_id, subject, status, category, priority, source,
    last_user_message_at, waiting_on_party, ai_assisted,
    human_review_requested_at
  ) values (
    auth.uid(), btrim(p_subject), 'open', p_category, v_priority,
    'automated_support', now(), 'staff', true, now()
  ) returning * into v_ticket;
  insert into public.support_ticket_messages (
    ticket_id, sender_id, body, sender_kind, message_source, client_request_id
  ) values (
    v_ticket.id, auth.uid(), btrim(p_summary), 'user',
    'automated_support', p_correlation_id
  );
  update public.support_conversations
  set ticket_id = v_ticket.id, status = 'handed_off', channel = 'human_support'
  where id = v_conversation.id;
  insert into public.support_ticket_events (
    ticket_id, conversation_id, actor_id, event_type, correlation_id, safe_metadata
  ) values (
    v_ticket.id, v_conversation.id, auth.uid(), 'assistant_handoff_created',
    p_correlation_id,
    jsonb_build_object('priority', v_priority,
      'highest_safety_level', v_conversation.highest_safety_level)
  );
  insert into public.support_action_audit (
    actor_id, conversation_id, ticket_id, action, authorization_basis,
    target_type, target_id, correlation_id
  ) values (
    auth.uid(), v_conversation.id, v_ticket.id, 'human_handoff_created',
    'conversation_owner', 'support_ticket', v_ticket.id, p_correlation_id
  );
  return jsonb_build_object(
    'ok', true, 'replayed', false,
    'conversation_id', v_conversation.id,
    'ticket_id', v_ticket.id,
    'case_number', v_ticket.case_number,
    'priority', v_priority
  );
end;
$$;

revoke all on function private.support_classify_message(text) from public, anon, authenticated;
grant execute on function private.support_classify_message(text) to service_role;
revoke all on function public.support_get_config() from public, anon;
grant execute on function public.support_get_config() to authenticated, service_role;
revoke all on function public.support_classify_intent(text) from public, anon;
grant execute on function public.support_classify_intent(text) to authenticated, service_role;
revoke all on function public.support_search_kb(text, integer) from public, anon;
grant execute on function public.support_search_kb(text, integer) to authenticated, service_role;
revoke all on function public.support_begin_chat(text, uuid, uuid, uuid) from public, anon;
grant execute on function public.support_begin_chat(text, uuid, uuid, uuid) to authenticated, service_role;
revoke all on function public.support_escalate_conversation(uuid, text, text, text, uuid) from public, anon;
grant execute on function public.support_escalate_conversation(uuid, text, text, text, uuid) to authenticated, service_role;
