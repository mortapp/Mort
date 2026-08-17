-- Support AI overblocking false-positive fix (2026-08-13).
--
-- Issue: ordinary support questions about account password resets, safety policy
-- guidance, quoted hostile content, and report workflows were being classified as
-- serious trust/safety cases just because the message included words like
-- "password", "system prompt", or "service-role key". This is a false-positive
-- regression in the generic keyword block and causes unnecessary handoffs and
-- rate-limit exhaustion.
--
-- Fix: separate human-support / report / quoted-content contexts from true
-- exfiltration attempts, and require direct request patterns (tell/show/give/
-- reveal) before a message is treated as a serious privacy or trust/safety issue.

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
  v_quoted_or_report_context boolean := false;
  v_benign_password_help boolean := false;
  v_direct_secret_request boolean := false;
  v_direct_prompt_extraction boolean := false;
begin
  v_quoted_or_report_context := v_message ~ '(?:saw|read|heard|mentioned|quoted|quote|said|message|review|comment|post|reported|report).{0,120}(?:system prompt|developer message|service.?role|password|verification code|card number|cvc|cvv|social security|passport|driver.?s license|transcript|account details)';
  v_benign_password_help := v_message ~ '(?:reset|change|recover|update|manage|fix|help|login|account).{0,80}password|password.{0,40}(?:reset|change|help|issue|login|account)|how.*password|where.*password|which.*password|forgot.*password';
  v_direct_secret_request := v_message ~ '(?:tell|show|send|give|read|print|reveal|share|display|return|dump|expose|provide).{0,80}(?:my|your|the|an|this|that|another|other).{0,80}(?:password|verification code|social security|ssn|passport|driver.?s license|card number|cvc|cvv|exact.*address)|(?:password|verification code|social security|ssn|passport|driver.?s license|card number|cvc|cvv|exact.*address).{0,30}(?:right now|for me|to me|here|now)';
  v_direct_prompt_extraction := v_message ~ '(?:what.*system prompt|what.*developer message|show.*system prompt|reveal.*system prompt|print.*developer message|reveal.*developer message|show.*developer message|repeat.*instruction|translate.*system prompt|summarize.*(?:instruction|rule|prompt)|your.*system prompt|your.*developer message|service.?role key|service.?role)';

  if v_message ~ 'suicid|kill myself|kill me|hurt myself|self.?harm|kidnap|abduct|traffick|immediate danger|being followed|sexual assault|rape|won.?t let me leave|trapped at.*job|child pornography|underage nude|end(ing)? my life|want(ing)? to die|no reason to live|i do not want to live|i do not want to be alive|i am in immediate danger|there is a (gun|knife|weapon)|someone.*has a weapon|someone.*pulled.*knife|a person.*weapon|pulled out.*knife.*threat|knife.*pulled.*threat' then
    v_level := 3;
    v_band := 'urgent';
    v_category := 'immediate_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  elsif v_message ~ 'ignore.*instruction|disregard.*guideline|override.*instruction|bypass.*guideline|forget.*instruction|forget everything above|ignore everything above|ignore all previous instruction|developer mode|no restriction|new system message|as the system administrator|as an admin|i am.*(mort )?(staff|developer|admin)|this is an authorized override|show me another user|show me.*other.*user|another user|other user|someone else.*message|private transcript|database row|dump.*table|show.*transcript|threat|stalk|harass|blackmail|extort|sextort|groom|sexual message|sexual photo|private photo|private image|send.*nude|ask.*nude|request.*nude|meet.*alone|keep.*secret|don.?t tell.*guardian|don.?t tell.*parent|off.platform|move.*chat.*off|cashapp|gift card|(?:tell|show|send|give|read|print|reveal|share|display|return|dump|expose).{0,80}(?:password|verification code|social security|ssn|passport|driver.?s license|card number|cvc|cvv|exact.*address)|(?:tell|show|send|give|read|print|reveal|share|display|return|dump|expose).{0,80}(?:service.?role|developer message|system prompt)|(?:password|verification code|social security|ssn|passport|driver.?s license|card number|cvc|cvv|exact.*address).{0,20}(?:right now|for me|to me|here|now)|(?:i am|i.?m|they.*made|forced).{0,50}unsafe at.*job|at.*job.{0,50}(trapped|won.?t let me leave)|scam|fraud|alcohol.*teen|circular saw.*alone|no supervision' or v_direct_secret_request or v_direct_prompt_extraction then
    v_level := 2;
    v_band := 'serious';
    v_category := 'trust_safety';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_quoted_or_report_context or v_benign_password_help then
    v_level := 1;
    v_band := 'concern';
    v_category := 'support';
    v_intent := 'human_handoff';
    v_action := 'required_handoff';
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
