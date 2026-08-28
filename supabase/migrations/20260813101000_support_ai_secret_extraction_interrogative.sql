-- Support AI secret extraction pattern enhancement (2026-08-13).
--
-- Refines the direct secret request detection to catch interrogative forms
-- like "What's the CVV on file for my card?" that ask about sensitive data
-- without using direct request verbs like "tell" or "show". This catches
-- additional attack vectors that evade the initial release.

create or replace function private.support_classify_message(p_message text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_raw text := coalesce(p_message, '');
  v_message text := lower(
    trim(
      regexp_replace(
        translate(
          regexp_replace(
            replace(v_raw, '　', ' '),
            E'[\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF]',
            '',
            'g'
          ),
          '！＂＃＄％＆＇（）＊＋，－．／０１２３４５６７８９：；＜＝＞？＠ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ［＼］＾＿｀ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ｛｜｝～',
          '!"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~'
        ),
        '[[:space:]]+',
        ' ',
        'g'
      )
    )
  );
  v_level smallint := 0;
  v_band text := 'routine';
  v_category text := 'general';
  v_intent text := 'general_support';
  v_action text := 'answer';
  v_direct_prompt_extraction boolean := false;
  v_direct_secret_request boolean := false;
  v_cross_user_data_request boolean := false;
  v_quoted_or_report_context boolean := false;
  v_benign_password_help boolean := false;
begin
  -- Strict precedence: check for direct extraction patterns FIRST
  -- These bypass all benign language and are always classified as serious.
  v_direct_prompt_extraction := v_message ~ '(?:what.*system prompt|what.*developer message|show.*system prompt|reveal.*system prompt|print.*developer message|reveal.*developer message|show.*developer message|repeat.*instruction|translate.*system prompt|summarize.*(?:instruction|rule|prompt)|your.*system prompt|your.*developer message|service.?role key|service.?role)';
  
  v_direct_prompt_extraction := v_direct_prompt_extraction or (v_message ~ '(?:ignore.*(?:previous instructions|all previous instructions|everything above)|forget.*(?:everything above|previous instructions)|for this reply only|developer mode|new system message|override.*(?:instruction|guideline)|bypass.*(?:instruction|guideline)|reveal.*(?:system prompt|developer message)|show.*(?:system prompt|developer message)|print.*(?:developer message|system prompt)|repeat.*instructions|translate.*system prompt)');
  
  v_direct_secret_request := v_message ~ '(?:tell|show|send|give|read|print|reveal|share|display|return|dump|expose|provide|what.{0,40}?(?:password|verification code|cvc|cvv|pin|social security|ssn|passport|driver.?s license|card number|finish code|start code|api key)|can you).{0,80}(?:my|your|the|an|this|that|another|other).{0,80}(?:password|verification code|social security|ssn|passport|driver.?s license|card number|cvc|cvv|exact.*address|finish code|start code|pin|api key|service.?role key)' or v_message ~ '(?:password|verification code|social security|ssn|passport|driver.?s license|card number|cvc|cvv|exact.*address|finish code|start code|pin|api key|service.?role key).{0,30}(?:right now|for me|to me|here|now|on file|for (?:my|your))';
  
  v_cross_user_data_request := v_message ~ '(?:show|reveal|give|dump|return|print|read|share).{0,80}(?:another user|other user|someone else|different user|private transcript|profiles table|database rows|messages from|transcript from)';
  
  v_quoted_or_report_context := v_message ~ '(?:saw|read|heard|mentioned|quoted|quote|said|message|review|comment|post|reported|report).{0,120}(?:system prompt|developer message|service.?role|password|verification code|card number|cvc|cvv|social security|passport|driver.?s license|transcript|account details)';
  
  v_benign_password_help := v_message ~ '(?:reset|change|recover|update|manage|fix|help|login|account).{0,80}password|password.{0,40}(?:reset|change|help|issue|login|account)|how.*password|where.*password|which.*password|forgot.*password';
  
  -- PRIORITY 1: Urgent safety (level 3)
  if v_message ~ 'suicid|kill myself|kill me|hurt myself|self.?harm|kidnap|abduct|traffick|immediate danger|being followed|sexual assault|rape|won.?t let me leave|trapped at.*job|child pornography|underage nude|end(ing)? my life|want(ing)? to die|no reason to live|i do not want to live|i do not want to be alive|i am in immediate danger|there is a (gun|knife|weapon)|someone.*has a weapon|someone.*pulled.*knife|a person.*weapon|pulled out.*knife.*threat|knife.*pulled.*threat' then
    v_level := 3;
    v_band := 'urgent';
    v_category := 'immediate_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  -- PRIORITY 2: Direct prompt/secret extraction (level 2)
  -- These are ALWAYS serious, regardless of benign wording
  elsif v_direct_prompt_extraction or v_direct_secret_request or v_cross_user_data_request then
    v_level := 2;
    v_band := 'serious';
    v_category := case
      when v_direct_prompt_extraction then 'prompt_boundary_attack'
      when v_direct_secret_request then 'secret_extraction'
      else 'cross_user_data_request'
    end;
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  -- PRIORITY 3: Other serious trust/safety patterns (level 2)
  elsif v_message ~ 'ignore.*instruction|disregard.*guideline|override.*instruction|bypass.*guideline|forget.*instruction|forget everything above|ignore everything above|ignore all previous instruction|developer mode|no restriction|new system message|as the system administrator|as an admin|i am.*(mort )?(staff|developer|admin)|this is an authorized override|show me another user|show me.*other.*user|someone else.*message|private transcript|database row|dump.*table|show.*transcript|threat|stalk|harass|blackmail|extort|sextort|groom|sexual message|sexual photo|private photo|private image|send.*nude|ask.*nude|request.*nude|meet.*alone|keep.*secret|don.?t tell.*guardian|don.?t tell.*parent|off.platform|move.*chat.*off|cashapp|gift card|(?:tell|show|send|give|read|print|reveal|share|display|return|dump|expose).{0,80}(?:password|verification code|social security|ssn|passport|driver.?s license|card number|cvc|cvv|exact.*address)|(?:tell|show|send|give|read|print|reveal|share|display|return|dump|expose).{0,80}(?:service.?role|developer message|system prompt)|(?:password|verification code|social security|ssn|passport|driver.?s license|card number|cvc|cvv|exact.*address).{0,20}(?:right now|for me|to me|here|now)|(?:i am|i.?m|they.*made|forced).{0,50}unsafe at.*job|at.*job.{0,50}(trapped|won.?t let me leave)|scam|fraud|alcohol.*teen|circular saw.*alone|no supervision' then
    v_level := 2;
    v_band := 'serious';
    v_category := 'trust_safety';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  -- PRIORITY 4: Quoted/reported malicious content OR benign password help (level 1)
  -- These are support-level concerns, not serious exfiltration attempts
  elsif v_quoted_or_report_context or v_benign_password_help then
    v_level := 1;
    v_band := 'concern';
    v_category := 'support';
    v_intent := 'human_handoff';
    v_action := 'required_handoff';
  -- PRIORITY 5: Other support-adjacent keywords (level 1)
  elsif v_message ~ 'human|real person|support agent|talk to.*person|report|block|unsafe|privacy|delete.*account|refund|dispute|identity|login|sign.?in|account access' then
    v_level := 1;
    v_band := 'concern';
    v_category := 'support';
    v_intent := 'human_handoff';
    v_action := 'required_handoff';
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
