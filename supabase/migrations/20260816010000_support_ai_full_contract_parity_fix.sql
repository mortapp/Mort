-- Support AI full classification-contract parity fix (2026-08-16).
--
-- The preceding classifier migration is applied history. This forward-only
-- wrapper preserves its level, triage, intent, and action decisions while
-- correcting the two remaining mirror fields: provider access for sensitive
-- disclosure and the category for a reported security concern.

alter function private.support_classify_message(text)
rename to support_classify_message_20260813110000;

create or replace function private.support_classify_message(p_message text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_result jsonb := private.support_classify_message_20260813110000(p_message);
  v_message text := lower(
    trim(
      regexp_replace(
        translate(
          regexp_replace(
            replace(coalesce(p_message, ''), '　', ' '),
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
  v_quoted_security_payload boolean := false;
  v_quoted_guidance_request boolean := false;
  v_reported_security_concern boolean := false;
begin
  if v_result->>'category' = 'sensitive_data_disclosure' then
    v_result := jsonb_set(v_result, '{provider_allowed}', 'false'::jsonb);
  end if;

  if v_result->>'category' = 'quoted_hostile_content' then
    v_quoted_security_payload := v_message ~ '(?:someone|a user|a stranger|a message|this message|i saw|i received|i found|friend|review|comment|post|conversation).{0,45}(?:said|asked|quoted|wrote|sent|shared|pasted|posted|contained|containing|with the words).{0,30}["''].{0,140}["'']';
    v_quoted_guidance_request := v_message ~ '(?:report|block|flag|handle|guidance|what should i do|is (?:that|this) (?:suspicious|a scam|a problem|malicious)|safety concern)';
    v_reported_security_concern := v_message ~ '(?:someone|a user|a stranger|a message|this message|they).{0,55}(?:asked|requested|wanted|told|sent|wrote).{0,70}(?:password|verification code|pin|cvv|cvc|card number|home address|api key|service-role key|system prompt|developer message)';

    if not v_quoted_security_payload
        and v_reported_security_concern
        and v_quoted_guidance_request then
      v_result := jsonb_set(
        v_result,
        '{category}',
        to_jsonb('reported_security_concern'::text)
      );
    end if;
  end if;

  return v_result;
end;
$$;

revoke all on function private.support_classify_message(text)
from public, anon, authenticated;
grant execute on function private.support_classify_message(text)
to service_role;
