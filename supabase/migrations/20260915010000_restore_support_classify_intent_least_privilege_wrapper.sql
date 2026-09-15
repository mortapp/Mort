-- Least-privilege fix for the live qa-support-chatbot intent-classify break,
-- superseding the abandoned one-hop grant approach (was
-- 20260915000000_fix_support_classify_intent_privilege_gap.sql, deleted
-- before deployment -- never applied to the hosted project).
--
-- ROOT CAUSE, traced through migration history (not guessed):
--
-- The original foundation (20260729195632_mort_support_chatbot_foundation.sql)
-- and its one refinement (20260729212722_mort_support_safety_priority_hardening.sql)
-- both defined public.support_classify_intent as `security definer`, with a
-- real body: an explicit auth.uid()/is_profile_active() check, an explicit
-- 3-2000 character length validation, a private.support_take_rate_limit(...)
-- call (itself `security definer`, granted to no one but this wrapper by
-- design), and only then a delegation to private.support_classify_message.
-- That inner function has been `security invoker` since it was first created
-- -- by design, not by accident -- because the ONE deliberate elevation point
-- in this chain was always meant to be the public wrapper: a `security
-- definer` caller elevates the effective role for everything it calls,
-- invoker or not, so the wrapper being definer was sufficient to let the
-- whole chain run with the wrapper owner's privileges without granting
-- authenticated/anon direct execute on any of the private helpers.
--
-- 20260813030000_support_ai_hardening_live_gauntlet_fix.sql -- a migration
-- focused on hardening the CLASSIFICATION LOGIC against a live red-team
-- gauntlet (per its own description: "corrects the live SQL classifier to
-- match the hardened support-runtime policy and the gauntlet's attack
-- surface") -- rewrote the public wrapper down to a bare
-- `select private.support_classify_message(p_message);` and, evidently as an
-- unintended side effect of that simplification, dropped it from `security
-- definer` to `security invoker` and silently removed the auth check, length
-- validation, and rate-limit call along with it. Nothing in that migration's
-- own comments describes an intentional privilege-model change -- the stated
-- goal was entirely about classifier robustness, not the wrapper's security
-- posture. From that point on, the private chain (now 4 versioned functions
-- deep: support_classify_message -> _20260816010000 -> _20260813110000 ->
-- _20260813101000, all service_role-only, none security definer) had no
-- remaining path to run with elevated privilege, so every real authenticated
-- or anon caller of the documented public entry point has been hitting a
-- Postgres permission-denied error inside the wrapper ever since -- silently,
-- because the TypeScript edge-function layer maps any non-ok RPC result to a
-- generic support_classification_unavailable response.
--
-- FIX (Option A of a three-option least-privilege comparison; see
-- MORT_FINAL100_CONTINUATION_2026-09-14.md for the full A/B/C writeup):
-- restore public.support_classify_intent to the original `security definer`
-- posture with its original auth/validation/rate-limit body, unchanged
-- except for delegating to the CURRENT (much more capable, still
-- versioned-chain) private.support_classify_message rather than the 2026-07
-- classifier. This is not a new design: it is the exact architecture that
-- shipped and ran in production for the two weeks before 20260813030000,
-- restored on top of everything the classification-logic hardening passes
-- have added since. All four private chain functions and the rate-limit
-- helper remain service_role-only -- this migration grants no new direct
-- execute privilege to authenticated or anon on any of them. The public
-- wrapper's own existing grants (service_role, authenticated, anon) are
-- left exactly as they already are; anon callers fail closed at the
-- `authentication_required` check exactly as the original design always
-- intended (auth.uid() is null for an anon caller), which is a clean,
-- expected application response rather than the raw permission-denied error
-- anon currently receives -- a net improvement, not a new allowance.

create or replace function public.support_classify_intent(p_message text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 3 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_message');
  end if;
  if not private.support_take_rate_limit(auth.uid(), 'intent', 60, 600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;
  return jsonb_build_object('ok', true, 'classification', private.support_classify_message(p_message));
end;
$$;
