-- MORT Verify email challenge hardening.
-- Authenticated clients no longer verify raw codes directly in Postgres.
-- The Edge Function computes an HMAC digest server-side and calls this
-- service-role-only verifier, so a database leak does not make 8-digit
-- challenge codes cheaply brute-forceable offline.

create or replace function public.service_mort_verify_verify_email_code(
  p_user_id uuid,
  p_session_id uuid,
  p_code_digest text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session private.mort_verify_sessions%rowtype;
  v_challenge private.mort_verify_email_challenges%rowtype;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'service_role_required');
  end if;

  if p_user_id is null
     or p_session_id is null
     or p_code_digest is null
     or p_code_digest !~ '^[A-Fa-f0-9]{64}$' then
    return jsonb_build_object('ok', false, 'code', 'invalid_verification_code');
  end if;

  select * into v_session
  from private.mort_verify_sessions session
  where session.id = p_session_id
    and session.user_id = p_user_id
    and session.status = 'email_pending'
    and session.expires_at > now()
  for update;

  if v_session.id is null then
    return jsonb_build_object('ok', false, 'code', 'session_not_available');
  end if;

  select * into v_challenge
  from private.mort_verify_email_challenges challenge
  where challenge.session_id = p_session_id
    and challenge.user_id = p_user_id
    and challenge.consumed_at is null
    and challenge.delivery_status = 'sent'
  order by challenge.created_at desc
  limit 1
  for update;

  if v_challenge.id is null or v_challenge.expires_at <= now() then
    return jsonb_build_object('ok', false, 'code', 'verification_code_expired');
  end if;

  if v_challenge.attempts >= 5 then
    return jsonb_build_object(
      'ok', false, 'code', 'verification_code_attempts_exhausted'
    );
  end if;

  if lower(p_code_digest) <> lower(v_challenge.code_hash) then
    update private.mort_verify_email_challenges
    set attempts = attempts + 1
    where id = v_challenge.id;

    return jsonb_build_object('ok', false, 'code', 'verification_code_invalid');
  end if;

  update private.mort_verify_email_challenges
  set consumed_at = now(),
      delivery_status = 'consumed'
  where id = v_challenge.id;

  update private.mort_verify_sessions
  set school_email_verified_at = now(),
      status = 'school_id_required',
      updated_at = now()
  where id = p_session_id;

  update public.identity_verifications
  set email_verification_result = 'school_email_verified',
      status = 'additional_information_required',
      updated_at = now()
  where id = v_session.identity_verification_id;

  insert into private.mort_verify_audit_events(
    session_id,user_id,actor_id,action,safe_metadata
  ) values (
    p_session_id,p_user_id,p_user_id,'school_email_verified',
    jsonb_build_object('challenge_id', v_challenge.id)
  );

  return jsonb_build_object(
    'ok', true,
    'status', 'school_id_required',
    'school_email_verified', true,
    'next_step', 'school_id'
  );
end;
$$;

revoke all on function public.service_mort_verify_verify_email_code(
  uuid,uuid,text
)
from public, anon, authenticated;
grant execute on function public.service_mort_verify_verify_email_code(
  uuid,uuid,text
)
to service_role;

-- Retire the original authenticated raw-code verifier. It remains defined for
-- migration compatibility but is no longer client-executable.
revoke all on function public.verify_mort_school_email_code(uuid,text)
from public, anon, authenticated;
