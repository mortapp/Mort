-- Security fix: accept_guardian_invite had no rate limit on guess attempts.
--
-- Found during backend security review: invite_code is derived from
-- gen_random_bytes(8) but truncated to the first 8 hex characters
-- (upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 8))) -- 32 bits of
-- entropy, not the 64 the byte count suggests. Invite *creation*
-- (create_guardian_invite / create_guardian_invite_v2) already rate-limits
-- via the 'guardian_invite' action, but invite *acceptance* -- the actual
-- guessing surface -- called no rate-limit function at all.
--
-- First attempt at this fix (raise exception on a wrong guess, after
-- recording a rate-limit event) was written, then verified against a local
-- test harness before shipping -- and the verification caught a real bug in
-- that approach: a RAISE EXCEPTION with no enclosing PL/pgSQL EXCEPTION
-- block aborts the whole statement, which rolls back EVERY write made
-- during that call, including the just-recorded rate-limit event. Every
-- failed guess would therefore have silently un-recorded itself, so the
-- limit would never trip -- confirmed empirically: a test loop of 11 wrong
-- guesses in a row was never rate-limited under that version.
--
-- Corrected approach, matching the pattern this codebase already uses for
-- the closely analogous PIN-guessing problem (confirm_job_start_pin/_v2,
-- confirm_job_finish_pin/_v2): never RAISE for a guess-wrong/rate-limited
-- outcome, always RETURN jsonb normally, so the transaction commits and the
-- rate-limit bookkeeping persists regardless of whether the guess
-- succeeded. This changes accept_guardian_invite's return type from uuid to
-- jsonb ({ok, link_id} | {ok:false, code, message}), matching every other
-- guardian RPC in flutter_mort/lib/data/repositories/guardian_repository.dart
-- (create_guardian_invite_v2, cancel_guardian_invite, resend_guardian_invite,
-- unlink_guardian, get_guardian_policy_for_user all already return this
-- shape and are unwrapped by the same _requireSuccess() helper). The one
-- call site that previously expected a bare uuid (GuardianRepository.
-- acceptInvite) is updated in the same change to use _requireSuccess() like
-- its siblings, instead of its previous bespoke try/catch on the exception
-- message string.
--
-- 10 attempts per hour is generous for a legitimate typo-correction retry
-- and makes brute-forcing the 32-bit code space from a single account
-- practically infeasible. This does not by itself stop a distributed
-- multi-account attack; that would need account-creation-side throttling,
-- which is out of scope for this migration.
--
-- No other behavior change: role/active-profile checks, the hash
-- comparison, expiry, and email-binding checks are all unchanged.

drop function if exists public.accept_guardian_invite(text);

create function public.accept_guardian_invite(p_invite_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_connection public.guardian_connections%rowtype;
  v_email text := lower(coalesce(auth.jwt()->>'email', ''));
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if public.current_profile_role() <> 'guardian' or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;

  if not public.check_rate_limit('guardian_invite_accept', 10, 3600) then
    return jsonb_build_object(
      'ok', false,
      'code', 'guardian_invite_accept_limit_reached',
      'message', 'Too many attempts. Wait a while and try again.'
    );
  end if;
  perform public.record_rate_limit_event('guardian_invite_accept');

  update public.guardian_connections
  set guardian_id = auth.uid(),
      status = 'active',
      accepted_at = now(),
      updated_at = now()
  where invite_code_hash = extensions.digest(upper(trim(p_invite_code)), 'sha256')
    and status = 'invited'
    and guardian_id is null
    and invite_expires_at > now()
    and (invited_email is null or lower(invited_email) = v_email)
  returning * into v_connection;

  if v_connection.id is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'guardian_invite_invalid_or_expired',
      'message', 'That guardian invite code is invalid or expired.'
    );
  end if;

  update public.profiles set guardian_setup_status = 'linked' where id = v_connection.teen_id;
  perform public.enqueue_notification(
    v_connection.teen_id,
    'Guardian linked',
    'Guardian Mode is now linked. You remain in control of shared alerts.',
    jsonb_build_object('linkId', v_connection.id)
  );
  return jsonb_build_object('ok', true, 'link_id', v_connection.id);
end;
$$;

grant execute on function public.accept_guardian_invite(text) to authenticated, service_role;
