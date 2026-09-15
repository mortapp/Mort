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
-- This migration has never been applied to the linked project. Two issues
-- were found during pre-deployment design review and both are fixed here,
-- rather than deploying and patching over them with another migration:
--
-- 1. The digest() call needs schema qualification. `set search_path =
--    public` (no `extensions`) means an unqualified digest() cannot resolve
--    pgcrypto, which lives in the extensions schema on Supabase -- every
--    other digest() call in this codebase is written as
--    extensions.digest(...) for the same reason.
--
-- 2. A `raise exception` on a wrong guess, after already recording a
--    rate-limit event for that guess, aborts the whole call's implicit
--    transaction -- Postgres has no way to raise an exception to the client
--    while keeping earlier writes from the SAME transaction committed. That
--    rollback would silently un-record every failed guess, so the limit
--    would never trip; verified this empirically against a local test
--    harness before writing this version: a loop of 11 wrong guesses in a
--    row was never rate-limited when the function raised on failure.
--
-- The only way to let the rate-limit bookkeeping survive a failed guess is
-- to never raise for a guess-wrong/rate-limited outcome and always RETURN
-- jsonb normally instead, so the transaction commits either way -- the same
-- pattern this codebase already uses for the closely analogous PIN-guessing
-- problem (confirm_job_start_pin/_v2, confirm_job_finish_pin/_v2) and for
-- every sibling guardian RPC (create_guardian_invite_v2, cancel_guardian_
-- invite, resend_guardian_invite, unlink_guardian, get_guardian_policy_
-- for_user all already return {ok, ...} and are unwrapped by
-- GuardianRepository's _requireSuccess() helper). This necessarily changes
-- accept_guardian_invite's return type from uuid to jsonb; the codes and
-- messages below match exactly what GuardianRepository.acceptInvite already
-- throws today for these two cases, so nothing user-visible changes, and no
-- deployed client depends on the current uuid/exception contract since this
-- migration has never shipped.
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
set search_path = public, extensions, pg_temp
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
      'code', 'guardian_invite_accept_rate_limit_reached',
      'message', 'Too many attempts. Please wait a while before trying again.'
    );
  end if;

  -- Record the attempt before resolving it so failed guesses (the case a
  -- brute-force relies on) count toward the limit, not just successes. This
  -- write only survives because every path below RETURNs instead of RAISEs.
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
