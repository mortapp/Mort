-- accept_guardian_invite had no rate limiting on invite-code guessing.
-- The human-entered code is 8 hex characters (32 bits of entropy) and the
-- lookup is a direct hash-equality scan with no per-user throttle, so an
-- authenticated guardian-role account could brute-force any teen's invite
-- code to falsely establish a guardian link. Add a per-user rate limit that
-- also counts failed attempts, matching the check_rate_limit/
-- record_rate_limit_event pattern already used by create_guardian_invite_v2
-- and send_safe_message_v2.

create or replace function public.accept_guardian_invite(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_connection public.guardian_connections%rowtype;
  v_email text := lower(coalesce(auth.jwt()->>'email', ''));
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if public.current_profile_role() <> 'guardian' or not public.is_profile_active(auth.uid()) then
    raise exception 'user_role_not_allowed';
  end if;
  if not public.check_rate_limit('guardian_invite_accept', 10, 3600) then
    raise exception 'guardian_invite_accept_rate_limit_reached';
  end if;

  -- Record the attempt before resolving it so failed guesses (the case a
  -- brute-force relies on) count toward the limit, not just successes.
  perform public.record_rate_limit_event('guardian_invite_accept');

  update public.guardian_connections
  set guardian_id = auth.uid(),
      status = 'active',
      accepted_at = now(),
      updated_at = now()
  where invite_code_hash = digest(upper(trim(p_invite_code)), 'sha256')
    and status = 'invited'
    and guardian_id is null
    and invite_expires_at > now()
    and (invited_email is null or lower(invited_email) = v_email)
  returning * into v_connection;

  if v_connection.id is null then
    raise exception 'guardian_invite_invalid_or_expired';
  end if;

  update public.profiles set guardian_setup_status = 'linked' where id = v_connection.teen_id;
  perform public.enqueue_notification(
    v_connection.teen_id,
    'Guardian linked',
    'Guardian Mode is now linked. You remain in control of shared alerts.',
    jsonb_build_object('linkId', v_connection.id)
  );
  return v_connection.id;
end;
$$;
