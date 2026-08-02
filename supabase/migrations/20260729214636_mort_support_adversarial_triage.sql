-- Prompt injection, cross-user exfiltration, CSAM indicators, and job PIN/code
-- requests are blocked deterministically before provider eligibility.
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
  if v_message ~ '(suicid|kill myself|hurt myself|self.?harm|kill (him|her|them|someone)|kidnap|abduct|traffick|weapon|gun|knife|immediate danger|being followed right now|sexual assault|rape|won.?t let me leave|trapped at (the )?job|\bcsam\b|child pornography|underage nude)' then
    v_level := 3;
    v_category := 'immediate_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  elsif v_message ~ '(threat|stalk|harass|blackmail|extort|nude|sexual message|meet.*alone|keep (this|it) (a )?secret|don.?t tell (your )?(parent|guardian)|off.platform|cashapp|gift card|verification code|\bpin\b|(start|finish|end) (code|pin)|password|social security|\bssn\b|passport|driver.?s license|card number|\bcvc\b|\bcvv\b|exact (home )?address|unsafe at (the )?job|scam|fraud|ignore.*instruction|system prompt|developer message|service.?role|another user|other user.?s|database rows|dump.*table|show.*transcript)' then
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

revoke all on function private.support_classify_message(text) from public, anon, authenticated;
grant execute on function private.support_classify_message(text) to service_role;
