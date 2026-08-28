-- Preserve benign tool-use false-positive protection while covering common
-- active-danger actor/location phrasing found by the deterministic corpus.
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
  if v_message ~ '(suicid|kill myself|kill me|hurt myself|self.?harm|kill (him|her|them|someone)|kidnap|abduct|traffick|immediate danger|being followed right now|sexual assault|rape|won.?t let me leave|trapped at (the )?job|\mcsam\M|child pornography|underage nude|(someone|a person)( at (the )?(location|job))? (has|brought|pulled out|pointed) (a )?(gun|knife|weapon)|there is (a )?(gun|knife|weapon) (here|at)|threaten.{0,30}(gun|knife|weapon)|(gun|knife|weapon).{0,30}(pointed|attacked|threat|scared))' then
    v_level := 3;
    v_band := 'urgent';
    v_category := 'immediate_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  elsif v_message ~ '(threat|stalk|harass|blackmail|extort|sextort|groom|sexual message|sexual photo|private (photo|picture|image)|send.{0,30}(nude|private (photo|picture|image))|ask.{0,30}(nude|private (photo|picture|image))|request.{0,30}(nude|private (photo|picture|image))|meet.*alone|keep (this|it) (a )?secret|don.?t tell ((your|my|the) )?(parent|guardian)|off.platform|move.{0,20}(text|chat|message).{0,20}(off|outside)|cashapp|gift card|verification code|\mpin\M|(start|finish|end) (code|pin)|password|social security|\mssn\M|passport|driver.?s license|card number|\mcvc\M|\mcvv\M|exact (home )?(address|location)|share.{0,20}(live|exact) location|unsafe at (the )?job|scam|fraud|(bring|buy|sell|use|drink|smoke).{0,30}(alcohol|beer|liquor|drug|weed|marijuana|vape)|(alcohol|beer|liquor|drug|weed|marijuana|vape).{0,30}(teen|minor|job)|(use|operate|climb|work).{0,30}(chainsaw|chain saw|circular saw|power tool|roof|ladder).{0,30}(alone|unsupervised|no supervision)|ignore.*instruction|system prompt|developer message|service.?role|another user|other user.?s|database rows|dump.*table|show.*transcript)' then
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

comment on function private.support_classify_message(text) is
'Deterministic non-diagnostic support triage with contextual weapon danger matching and benign tool-use protection.';
