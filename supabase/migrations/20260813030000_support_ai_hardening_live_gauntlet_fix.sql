-- Forward-only classification repair for the live hosted gauntlet.
--
-- The previously applied migration remains untouched. This migration corrects the
-- live SQL classifier to match the hardened support-runtime policy and the
-- gauntlet's attack surface without rewriting historical database state.

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
  if v_message ~ 'suicid|kill myself|kill me|hurt myself|self.?harm|kidnap|abduct|traffick|immediate danger|being followed|sexual assault|rape|won.?t let me leave|trapped at.*job|child pornography|underage nude|end(ing)? my life|want(ing)? to die|no reason to live|i do not want to live|i do not want to be alive|i am in immediate danger|there is a (gun|knife|weapon)|someone.*pulled.*knife|a person.*weapon' then
    v_level := 3;
    v_band := 'urgent';
    v_category := 'immediate_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  elsif v_message ~ 'ignore.*instruction|disregard.*guideline|override.*instruction|bypass.*guideline|forget.*instruction|forget everything above|ignore everything above|ignore all previous instruction|developer mode|no restriction|new system message|reveal.*system prompt|reveal.*developer message|show.*system prompt|show.*developer message|repeat.*instruction|translate.*system prompt|print.*developer message|summarize.*rule|system prompt|developer message|service.role|service.?role|another user|other user|someone else.*message|private transcript|database row|dump.*table|show.*transcript|threat|stalk|harass|blackmail|extort|sextort|groom|sexual message|sexual photo|private photo|private image|send.*nude|ask.*nude|request.*nude|meet.*alone|keep.*secret|don.?t tell.*guardian|don.?t tell.*parent|off.platform|move.*chat.*off|cashapp|gift card|verification code|password|social security|ssn|passport|driver.?s license|card number|cvc|cvv|exact.*address|unsafe at.*job|scam|fraud|alcohol.*teen|circular saw.*alone|no supervision' then
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

create or replace function public.support_classify_intent(p_message text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.support_classify_message(p_message);
$$;

revoke all on function private.support_classify_message(text) from public, anon, authenticated;
grant execute on function private.support_classify_message(text) to service_role;
revoke all on function public.support_classify_intent(text) from public, anon, authenticated;
grant execute on function public.support_classify_intent(text) to service_role, authenticated, anon;
