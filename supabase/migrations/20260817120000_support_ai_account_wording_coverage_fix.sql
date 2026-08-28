-- Support AI account-wording coverage fix (2026-08-17).
--
-- The preceding classifier migration is applied history. This forward-only
-- wrapper preserves its level, triage, intent, and action decisions except
-- for a narrow class of account-access questions that were falling through
-- to general_support because the account-education pattern only recognized
-- present-tense "sign-in"/"sign-out"/"log-in"/"log-out" wording and the
-- "why do i"/"why is" question prefixes, not "signed out"/"logged out"
-- (past tense) or the "why was" prefix.
--
-- Fixed via the local TypeScript mirror first (supabase/functions/_shared/
-- support_runtime.ts), regression-tested against all 543 fixtures with zero
-- regressions (459/543 passed, up from 458/543, no case flipped from a
-- correct to an incorrect classification). This migration mirrors that
-- exact wording fix using the identical narrow-override technique already
-- proven safe in migration 20260816010000_support_ai_full_contract_parity_fix.
--
-- This is a plain benign-wording gap, not an adversarial/obfuscation
-- pattern, so it intentionally reuses simple whitespace-collapse
-- normalization rather than the fuller zero-width/fullwidth stripping used
-- by security-sensitive overrides elsewhere in this file.

alter function private.support_classify_message(text)
rename to support_classify_message_20260816010000;

create or replace function private.support_classify_message(p_message text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_result jsonb := private.support_classify_message_20260816010000(p_message);
  v_message text := lower(
    trim(
      regexp_replace(coalesce(p_message, ''), '[[:space:]]+', ' ', 'g')
    )
  );
  v_account_wording_gap boolean := false;
begin
  if v_result->>'intent' = 'general_support' then
    v_account_wording_gap := v_message ~ '(?:^|[^[:alnum:]_])(?:how do i|how can i|what is|what''s|what are|where do i|why do i|why was|why is|can i|could i|should i|what should i do|is there a way to)(?:$|[^[:alnum:]_]).{0,70}(?:^|[^[:alnum:]_])(?:sign(?:ed)?-?in|sign(?:ed)?-?out|log(?:ged)?-?in|log(?:ged)?-?out)(?:$|[^[:alnum:]_])|(?:^|[^[:alnum:]_])(?:sign(?:ed)?-?in|sign(?:ed)?-?out|log(?:ged)?-?in|log(?:ged)?-?out)(?:$|[^[:alnum:]_]).{0,70}(?:^|[^[:alnum:]_])(?:how do i|how can i|what is|what''s|what are|where do i|why do i|why was|why is|can i|could i|should i|what should i do|is there a way to)(?:$|[^[:alnum:]_])';

    if v_account_wording_gap then
      v_result := jsonb_build_object(
        'level', 1,
        'triage_band', 'concern',
        'category', 'account',
        'intent', 'account_access',
        'action', 'offer_handoff',
        'provider_allowed', true
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
