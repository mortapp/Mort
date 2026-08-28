-- MORT Support AI hardening pass (2026-08-11).
--
-- This migration closes four gaps found during an architecture audit of the
-- existing, already-strong support-assistant boundary. It does not change any
-- passing behavior documented in MORT_SUPPORT_CHATBOT_SECURITY_REVIEW.md or
-- MORT_SUPPORT_CHATBOT_AI_EVALUATION_REPORT.md; it only adds new, narrowly
-- scoped checks on top of it.
--
-- 0. A small expansion of level-3 (urgent) phrase coverage for crisis
--    language that does not use "suicide", "kill", or "hurt" (see below).
--
-- 1. Cross-conversation incident lock.
--    `support_begin_chat` already refuses to reuse a conversation once it has
--    been handed to a human (status <> 'active'), so a single thread cannot be
--    "talked back" into automated answers after a serious/urgent message. But
--    a user could previously open a brand-new conversation immediately after
--    and reach the provider again, because `highest_safety_level` lives on the
--    conversation row, not the user, and `support_ai_incidents` was written
--    but never read back. This closes that gap: while a user has an open or
--    in-review severity >= 2 incident, every conversation (new or existing)
--    is forced to provider_allowed = false, independent of the current
--    message's own classification. The deterministic FAQ flow and human
--    handoff remain fully available; only external-provider use is paused.
--    The lock lifts automatically as soon as staff mark the incident
--    'resolved' or 'dismissed' -- no code deploy is required to clear it.
--
-- 2. A service-role-only wrapper around the real classifier
--    (`private.support_classify_message`) so the evaluation runner and the
--    adversarial gauntlet script can grade the actual production classifier
--    over the network, instead of a hand-maintained TypeScript mirror that
--    can silently drift from the SQL source of truth.
--
-- 3. A database-backed provider circuit breaker. Anthropic call failures
--    (timeout, non-2xx, malformed output) are recorded here; once failures
--    cross a short-window threshold, new chat requests skip the provider and
--    fall back to the deterministic path for the rest of that window. This is
--    enforced in Postgres (not edge-function memory) so it holds across
--    concurrently running function instances.

-- ---------------------------------------------------------------------------
-- 0. Expand emergency phrase coverage. The classifier already catches
--    "suicid*", "kill myself", "kill me", and "hurt myself", but real
--    crisis language often does not use any of those words at all. This adds
--    a small set of additional, well-established, low-false-positive crisis
--    phrasings to the existing level-3 pattern. It changes no other behavior.
-- ---------------------------------------------------------------------------

create or replace function private.support_classify_message(p_message text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_message text := lower(btrim(coalesce(p_message, '')));
  v_level smallint := 0;
  v_band text := 'routine';
  v_category text := 'general';
  v_intent text := 'general_support';
  v_action text := 'answer';
begin
  if v_message ~ '(suicid|kill myself|kill me|hurt myself|self.?harm|kill (him|her|them|someone)|kidnap|abduct|traffick|immediate danger|being followed right now|sexual assault|rape|won.?t let me leave|trapped at (the )?job|\mcsam\M|child pornography|underage nude|(someone|a person)( at (the )?(location|job))? (has|brought|pulled out|pointed) (a )?(gun|knife|weapon)|there is (a )?(gun|knife|weapon) (here|at)|threaten.{0,30}(gun|knife|weapon)|(gun|knife|weapon).{0,30}(pointed|attacked|threat|scared)|end(ing)? my life|(don.?t|do not) want to (live|be alive)|not worth living|want(ing)? to die|no reason to (live|keep going))' then
    v_level := 3;
    v_band := 'urgent';
    v_category := 'immediate_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  elsif v_message ~ '(threat|stalk|harass|blackmail|extort|sextort|groom|sexual message|sexual photo|private (photo|picture|image)|send.{0,30}(nude|private (photo|picture|image))|ask.{0,30}(nude|private (photo|picture|image))|request.{0,30}(nude|private (photo|picture|image))|meet.*alone|keep (this|it) (a )?secret|don.?t tell ((your|my|the) )?(parent|guardian)|off.platform|move.{0,20}(text|chat|message).{0,20}(off|outside)|cashapp|gift card|verification code|\mpin\M|(start|finish|end) (code|pin)|password|social security|\mssn\M|passport|driver.?s license|card number|\mcvc\M|\mcvv\M|exact (home )?(address|location)|share.{0,20}(live|exact) location|unsafe at (the )?job|scam|fraud|(bring|buy|sell|use|drink|smoke).{0,30}(alcohol|beer|liquor|drug|weed|marijuana|vape)|(alcohol|beer|liquor|drug|weed|marijuana|vape).{0,30}(teen|minor|job)|(use|operate|climb|work).{0,30}(chainsaw|chain saw|circular saw|power tool|roof|ladder).{0,30}(alone|unsupervised|no supervision)|ignore.*(instruction|guideline)|system prompt|developer message|service.?role|another user|other user.?s|database rows|dump.*table|show.*transcript)' then
    v_level := 2;
    v_band := 'serious';
    v_category := 'trust_safety';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_message ~ '(human|real person|support agent|talk to (a )?person|report|block|unsafe|privacy|delete.*account|account delet|payment|paid|refund|dispute|identity|verif|login|sign.?in|account|application|job|guardian)' then
    v_level := 1;
    v_band := 'concern';
    v_category := case
      when v_message ~ '(human|real person|support agent|talk to (a )?person)' then 'support'
      when v_message ~ '(report|block|unsafe)' then 'trust_safety'
      when v_message ~ '(privacy|delete.*account|account delet)' then 'privacy'
      when v_message ~ '(payment|paid|refund|dispute)' then 'billing'
      when v_message ~ '(login|sign.?in|account|identity|verif)' then 'account'
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
    'triage_band', v_band,
    'category', v_category,
    'intent', v_intent,
    'action', v_action,
    'provider_allowed', v_level < 2 and v_intent <> 'human_handoff'
  );
end;
$$;

revoke all on function private.support_classify_message(text) from public, anon, authenticated;
grant execute on function private.support_classify_message(text) to service_role;

-- ---------------------------------------------------------------------------
-- 1. Cross-conversation incident lock
-- ---------------------------------------------------------------------------

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
  v_pending_incident boolean := false;
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
      'triage_band', 'concern',
      'category', case when v_deletion_pending then 'privacy' else 'account' end,
      'intent', case when v_deletion_pending then 'deletion_pending' else 'account_restricted' end,
      'action', 'required_handoff',
      'provider_allowed', false
    );
  end if;

  -- Hardening addition: a user with an unresolved serious/urgent incident
  -- keeps the provider paused in every conversation, not just the one that
  -- triggered it, until a human clears the incident. The message's own
  -- category/intent/level are left untouched so an unrelated routine question
  -- is not mislabeled; only automated-provider eligibility is affected.
  if (v_classification->>'provider_allowed')::boolean then
    select exists (
      select 1 from public.support_ai_incidents incident
      where incident.owner_id = v_user_id
        and incident.severity >= 2
        and incident.status in ('open', 'reviewing')
    ) into v_pending_incident;
    if v_pending_incident then
      v_classification := jsonb_set(v_classification, '{provider_allowed}', 'false'::jsonb);
    end if;
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

-- ---------------------------------------------------------------------------
-- 2. Service-role-only wrapper around the real classifier, so the evaluation
--    runner and the adversarial gauntlet script can grade the actual
--    production classifier over the network instead of a hand-maintained
--    TypeScript mirror that can silently drift from the SQL source of truth.
-- ---------------------------------------------------------------------------

create or replace function public.support_classify_message_internal(p_message text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'internal_authorization_required');
  end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 1 and 4000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_message');
  end if;
  return jsonb_build_object(
    'ok', true,
    'classification', private.support_classify_message(p_message)
  );
end;
$$;

revoke all on function public.support_classify_message_internal(text) from public, anon, authenticated;
grant execute on function public.support_classify_message_internal(text) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Database-backed provider circuit breaker. Anthropic call failures
--    (timeout, non-2xx, malformed output) are recorded here; once failures
--    cross a short-window threshold, new chat requests skip the provider and
--    fall back to the deterministic path for the rest of that window. This is
--    enforced in Postgres (not edge-function memory) so it holds across
--    concurrently running function instances. It reuses the existing
--    public.support_global_rate_limits ledger under a dedicated
--    'provider_failure' scope rather than introducing a new table.
-- ---------------------------------------------------------------------------

create or replace function public.support_record_provider_failure()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window_seconds integer := 120;
  v_window_started_at timestamptz;
  v_count integer;
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'internal_authorization_required');
  end if;
  v_window_started_at := to_timestamp(
    floor(extract(epoch from now()) / v_window_seconds) * v_window_seconds
  );
  insert into public.support_global_rate_limits (
    scope, window_started_at, window_seconds, request_count, expires_at
  ) values (
    'provider_failure', v_window_started_at, v_window_seconds, 1,
    v_window_started_at + make_interval(secs => v_window_seconds)
  )
  on conflict (scope, window_started_at) do update
  set request_count = least(public.support_global_rate_limits.request_count + 1, 1000000),
      expires_at = excluded.expires_at
  returning request_count into v_count;
  return jsonb_build_object('ok', true, 'failure_count', v_count);
end;
$$;

revoke all on function public.support_record_provider_failure() from public, anon, authenticated;
grant execute on function public.support_record_provider_failure() to service_role;

create or replace function public.support_provider_circuit_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_window_seconds integer := 120;
  v_threshold integer := 5;
  v_window_started_at timestamptz;
  v_count integer := 0;
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'internal_authorization_required');
  end if;
  v_window_started_at := to_timestamp(
    floor(extract(epoch from now()) / v_window_seconds) * v_window_seconds
  );
  select request_count into v_count
  from public.support_global_rate_limits
  where scope = 'provider_failure'
    and window_started_at = v_window_started_at
    and expires_at > now();
  return jsonb_build_object(
    'ok', true,
    'open', coalesce(v_count, 0) >= v_threshold,
    'failure_count', coalesce(v_count, 0),
    'threshold', v_threshold,
    'window_seconds', v_window_seconds
  );
end;
$$;

revoke all on function public.support_provider_circuit_status() from public, anon, authenticated;
grant execute on function public.support_provider_circuit_status() to service_role;
