-- Follow-up support AI runtime fix: normalize obfuscated prompt payloads and
-- block prompt-boundary override attempts before the provider is allowed to run.
--
-- This is intentionally a forward-only migration: the already-applied historical
-- follow-up migration remains untouched and must not be rewritten. This file adds
-- the incremental SQL required to bring the Postgres classifier in line with the
-- hardened TypeScript runtime while preserving the earlier production safety
-- decisions and human-handoff paths.

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
        regexp_replace(
          replace(v_raw, '　', ' '),
          E'[\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF]',
          '',
          'g'
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
  if v_message ~ '(suicid|kill myself|kill me|hurt myself|self.?harm|i do not want to live anymore|want to end my life|not worth living|immediate danger|being followed right now|rape|sexual assault|trapped at the job|someone at the location has a (gun|knife|weapon)|a person pulled out a (gun|knife|weapon)|there is a (gun|knife|weapon)|threaten.*(gun|knife|weapon))' then
    v_level := 3;
    v_band := 'urgent';
    v_category := 'immediate_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  elsif v_message ~ '(ignore.*(previous instructions|all previous instructions|everything above|all instructions)|forget.*(everything above|previous instructions)|for this reply only|developer mode|new system message|override.*(instruction|guideline)|bypass.*(instruction|guideline)|reveal.*(system prompt|developer message)|show.*(system prompt|developer message)|print.*(developer message|system prompt)|repeat.*instructions|translate.*system prompt|system prompt|developer message|service-role|service role|as an admin|authorized override|another user|other user|private transcript|dump.*table|profiles table|show.*transcript)' then
    v_level := 2;
    v_band := 'serious';
    v_category := 'trust_safety';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_message ~ '(password|cvv|cvc|verification code|finish code|start code|social security|ssn|passport|driver.?s license|card number|exact home address|exact address|private photo|private message|account password)' then
    v_level := 2;
    v_band := 'serious';
    v_category := 'secret_extraction';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_message ~ '(another user|someone else.*(messages|transcript|session)|other user''s|show me.*(another user|other user)|return all database rows|profiles table|private transcript)' then
    v_level := 2;
    v_band := 'serious';
    v_category := 'cross_user_data_request';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_message ~ '(don''t tell.*(guardian|parent)|keep this a secret|without telling anyone|alcohol.*teen|circular saw.*alone|alone with no supervision|no supervision)' then
    v_level := 2;
    v_band := 'serious';
    v_category := 'guardian_bypass';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_message ~ '(human|real person|support agent|talk to a person|report|block|unsafe|privacy|delete.*account|refund|dispute|identity|login|sign.?in|account access)' then
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

revoke all on function private.support_classify_message(text) from public, anon, authenticated;
grant execute on function private.support_classify_message(text) to service_role;
