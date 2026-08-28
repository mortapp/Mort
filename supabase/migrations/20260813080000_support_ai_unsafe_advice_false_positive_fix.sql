-- Support AI false positive fix for "unsafe at job" advice questions (2026-08-13).
--
-- Issue: "What should I do if I feel unsafe at a job?" returned level=2 (serious)
-- instead of level=1 or 0 (benign). The pattern 'unsafe at.*job' is too broad
-- and catches legitimate support/advice questions about job safety.
--
-- Analysis: The intent was to catch personal crisis statements like:
-- - "I am unsafe at the job"
-- - "They made me feel unsafe at the job"
-- - "I'm unsafe at the job and need help"
--
-- But the pattern also catches general advice questions:
-- - "What should I do if I feel unsafe at a job?"
-- - "How to handle feeling unsafe at a job?"
--
-- Fix: Only flag as level-2 when "unsafe at job" appears in a context indicating
-- the person is currently in danger at a job (present tense, personal, specific).
-- General questions about job safety (lacking "i am", "i'm", "trapped", "they",
-- "won't let") remain benign.

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
begin
  if v_message ~ 'suicid|kill myself|kill me|hurt myself|self.?harm|kidnap|abduct|traffick|immediate danger|being followed|sexual assault|rape|won.?t let me leave|trapped at.*job|child pornography|underage nude|end(ing)? my life|want(ing)? to die|no reason to live|i do not want to live|i do not want to be alive|i am in immediate danger|there is a (gun|knife|weapon)|someone.*has a weapon|someone.*pulled.*knife|a person.*weapon|pulled out.*knife.*threat|knife.*pulled.*threat' then
    v_level := 3;
    v_band := 'urgent';
    v_category := 'immediate_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  elsif v_message ~ 'ignore.*instruction|disregard.*guideline|override.*instruction|bypass.*guideline|forget.*instruction|forget everything above|ignore everything above|ignore all previous instruction|developer mode|no restriction|new system message|reveal.*system prompt|reveal.*developer message|show.*system prompt|show.*developer message|repeat.*instruction|translate.*system prompt|print.*developer message|summarize.*rule|system prompt|developer message|service.role|service.?role|as the system administrator|as an admin|i am.*(mort )?(staff|developer|admin)|this is an authorized override|show me another user|show me.*other.*user|another user|other user|someone else.*message|private transcript|database row|dump.*table|show.*transcript|threat|stalk|harass|blackmail|extort|sextort|groom|sexual message|sexual photo|private photo|private image|send.*nude|ask.*nude|request.*nude|meet.*alone|keep.*secret|don.?t tell.*guardian|don.?t tell.*parent|off.platform|move.*chat.*off|cashapp|gift card|verification code|password|social security|ssn|passport|driver.?s license|card number|cvc|cvv|exact.*address|(i am|i.?m|they.*made|forced).{0,50}unsafe at.*job|at.*job.{0,50}(trapped|won.?t let me leave)|scam|fraud|alcohol.*teen|circular saw.*alone|no supervision' then
    v_level := 2;
    v_band := 'serious';
    v_category := 'trust_safety';
    v_intent := 'report_or_privacy';
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
