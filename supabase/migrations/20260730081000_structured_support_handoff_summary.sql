-- Phase 8: persist a privacy-minimized, structured handoff summary without
-- copying raw conversation content into queue metadata.

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
  conversation public.support_conversations%rowtype;
  ticket public.support_tickets%rowtype;
  priority text := 'normal';
  queue_key text := 'support';
  latest_intent text := 'general_support';
  message_count integer := 0;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles profile where profile.id = auth.uid()
  ) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(btrim(coalesce(p_subject, ''))) not between 3 and 120
     or char_length(btrim(coalesce(p_summary, ''))) not between 10 and 2000
     or p_category not in (
       'account_sign_in', 'profile_avatar', 'verification', 'job_application',
       'start_finish_pin', 'job_cancellation', 'payment_compensation',
       'adult_refused_completion', 'teen_abandonment', 'evidence_submission',
       'report_block', 'privacy_deletion', 'mort_plus_play_billing', 'other'
     ) then
    return jsonb_build_object('ok', false, 'code', 'invalid_handoff_request');
  end if;
  select * into conversation
  from public.support_conversations item
  where item.id = p_conversation_id
    and item.owner_id = auth.uid()
    and item.status <> 'deleted'
  for update;
  if conversation.id is null then
    return jsonb_build_object('ok', false, 'code', 'support_conversation_not_found');
  end if;
  if conversation.ticket_id is not null then
    return jsonb_build_object(
      'ok', true, 'replayed', true,
      'conversation_id', conversation.id,
      'ticket_id', conversation.ticket_id
    );
  end if;
  if not private.support_take_rate_limit(auth.uid(), 'handoff', 5, 3600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;

  if conversation.highest_safety_level >= 3 then priority := 'urgent_safety';
  elsif conversation.highest_safety_level = 2 then priority := 'high';
  end if;
  queue_key := case
    when conversation.highest_safety_level >= 2 or p_category = 'report_block' then 'trust_safety'
    when p_category = 'privacy_deletion' then 'privacy'
    when p_category in ('payment_compensation', 'mort_plus_play_billing') then 'billing'
    else 'support'
  end;
  select coalesce(count(*), 0)::integer into message_count
  from public.support_messages message
  where message.conversation_id = conversation.id;
  select coalesce(message.intent, 'general_support') into latest_intent
  from public.support_messages message
  where message.conversation_id = conversation.id and message.role = 'user'
  order by message.created_at desc limit 1;

  insert into public.support_tickets (
    requester_id, subject, status, category, priority, source,
    last_user_message_at, waiting_on_party, ai_assisted,
    human_review_requested_at, queue_key, escalation_summary
  ) values (
    auth.uid(), btrim(p_subject), 'open', p_category, priority,
    'automated_support', now(), 'staff', true, now(), queue_key,
    jsonb_build_object(
      'source', 'assistant_handoff',
      'category', p_category,
      'intent', latest_intent,
      'highest_safety_level', conversation.highest_safety_level,
      'safety_band', case conversation.highest_safety_level
        when 3 then 'urgent' when 2 then 'serious' when 1 then 'concern' else 'routine'
      end,
      'message_count', message_count,
      'user_summary_present', true,
      'user_summary_length', char_length(btrim(p_summary)),
      'requires_human_decision', true,
      'raw_conversation_copied', false
    )
  ) returning * into ticket;
  insert into public.support_ticket_messages (
    ticket_id, sender_id, body, sender_kind, message_source, client_request_id
  ) values (
    ticket.id, auth.uid(), btrim(p_summary), 'user',
    'automated_support', p_correlation_id
  );
  update public.support_conversations
  set ticket_id = ticket.id, status = 'handed_off', channel = 'human_support'
  where id = conversation.id;
  insert into public.support_ticket_events (
    ticket_id, conversation_id, actor_id, event_type, correlation_id, safe_metadata
  ) values (
    ticket.id, conversation.id, auth.uid(), 'assistant_handoff_created',
    p_correlation_id,
    jsonb_build_object(
      'priority', priority,
      'queue', queue_key,
      'highest_safety_level', conversation.highest_safety_level,
      'summary_shape', 'privacy_minimized_v1'
    )
  );
  insert into public.support_action_audit (
    actor_id, conversation_id, ticket_id, action, authorization_basis,
    target_type, target_id, correlation_id
  ) values (
    auth.uid(), conversation.id, ticket.id, 'human_handoff_created',
    'conversation_owner', 'support_ticket', ticket.id, p_correlation_id
  );
  return jsonb_build_object(
    'ok', true, 'replayed', false,
    'conversation_id', conversation.id,
    'ticket_id', ticket.id,
    'case_number', ticket.case_number,
    'priority', priority,
    'queue', queue_key,
    'summary_shape', 'privacy_minimized_v1'
  );
end;
$$;

revoke all on function public.support_escalate_conversation(uuid, text, text, text, uuid)
from public, anon;
grant execute on function public.support_escalate_conversation(uuid, text, text, text, uuid)
to authenticated, service_role;
