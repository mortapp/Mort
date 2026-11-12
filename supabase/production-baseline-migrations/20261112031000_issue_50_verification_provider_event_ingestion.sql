-- Issue #50 part 2: trusted ingestion boundary for verification provider events.
--
-- The whole boundary runs inside one SECURITY DEFINER SQL function
-- (private.ingest_verification_provider_event) so every check and the insert
-- happen atomically in one transaction. The public wrapper
-- (mort_ingest_verification_provider_event) is the only service-role-callable
-- entry point; it is revoked from every client role, so only the edge
-- function (holding the service key) can invoke it. The edge function
-- `verification-provider-event` is a thin proxy that forwards the signed
-- envelope; it performs no verification itself.
--
-- Verified in order: tenant binding (per-provider per-project key),
-- HMAC-SHA256 signature over "<timestamp>.<raw body>", timestamp freshness,
-- event shape, case binding (subject/type/provider/reference), provider
-- allowlist (fail closed), evidence freshness/expiry, and replay idempotency
-- (unique provider_key + provider_event_id). evidence_sha256 is the SHA-256
-- of the exact raw body — a provenance fingerprint, not a proof of
-- authenticity (authenticity is the verified HMAC signature).
begin;

create or replace function private.ingest_verification_provider_event(
  p_project_ref text,
  p_provider_key text,
  p_timestamp text,
  p_signature text,
  p_raw_body text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_key private.verification_provider_ingestion_keys%rowtype;
  v_expected text;
  v_event jsonb;
  v_event_id text;
  v_case_id uuid;
  v_user_id uuid;
  v_type text;
  v_reference text;
  v_result text;
  v_verified_at timestamptz;
  v_expires_at timestamptz;
  v_case public.verification_cases%rowtype;
  v_event_time timestamptz;
  v_sha text;
begin
  if p_provider_key is null or btrim(p_provider_key) = '' or char_length(p_provider_key) > 100
     or p_signature is null or p_signature !~ '^[0-9a-f]{64}$'
     or p_raw_body is null or char_length(p_raw_body) < 2 or char_length(p_raw_body) > 65536
     or p_project_ref is null or p_project_ref !~ '^[a-z]{20}$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_request');
  end if;

  begin
    v_event_time := p_timestamp::timestamptz;
  exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_provider_timestamp');
  end;
  if p_timestamp is null or char_length(btrim(p_timestamp)) < 10
     or abs(extract(epoch from (clock_timestamp() - v_event_time))) > 300 then
    return jsonb_build_object('ok', false, 'error', 'stale_provider_timestamp');
  end if;

  -- Tenant binding: the key must exist for this provider AND this project.
  select * into v_key
  from private.verification_provider_ingestion_keys keys
  where keys.provider_key = btrim(p_provider_key)
    and keys.project_ref = p_project_ref
    and keys.is_enabled;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'unknown_provider');
  end if;

  -- HMAC-SHA256 over "<timestamp>.<raw body>".
  v_expected := encode(
    extensions.hmac(
      convert_to(p_timestamp || '.' || p_raw_body, 'UTF8'),
      convert_to(v_key.hmac_key, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
  if p_signature <> v_expected then
    return jsonb_build_object('ok', false, 'error', 'invalid_signature');
  end if;

  -- Event shape.
  begin
    v_event := p_raw_body::jsonb;
  exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_json');
  end;
  v_event_id := btrim(coalesce(v_event->>'provider_event_id', ''));
  v_type := btrim(coalesce(v_event->>'verification_type', ''));
  v_result := btrim(coalesce(v_event->>'result', ''));
  v_reference := nullif(btrim(coalesce(v_event->>'provider_reference', '')), '');
  if v_event_id = '' or char_length(v_event_id) > 200
     or v_type not in ('age','identity','guardian_consent','school_email','school_id','business')
     or v_result not in ('verified','rejected','needs_review')
     or (v_reference is not null and char_length(v_reference) > 200) then
    return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
  end if;
  begin
    v_case_id := (v_event->>'case_id')::uuid;
    v_user_id := (v_event->>'user_id')::uuid;
  exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
  end;
  if v_case_id is null or v_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
  end if;
  if v_event ? 'verified_at' and jsonb_typeof(v_event->'verified_at') <> 'null' then
    begin
      v_verified_at := (v_event->>'verified_at')::timestamptz;
    exception when others then
      return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
    end;
  end if;
  if v_event ? 'expires_at' and jsonb_typeof(v_event->'expires_at') <> 'null' then
    begin
      v_expires_at := (v_event->>'expires_at')::timestamptz;
    exception when others then
      return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
    end;
  end if;
  if (v_result = 'verified' and v_verified_at is null)
     or (v_expires_at is not null and v_verified_at is null) then
    return jsonb_build_object('ok', false, 'error', 'invalid_event_payload');
  end if;

  -- Case binding: the case must exist in this project and match the
  -- event's subject, verification type, provider, and reference.
  select * into v_case
  from public.verification_cases cases
  where cases.id = v_case_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'case_not_found');
  end if;
  if v_case.user_id <> v_user_id
     or v_case.verification_type <> v_type
     or v_case.provider <> btrim(p_provider_key)
     or v_case.provider_reference is distinct from v_reference then
    return jsonb_build_object('ok', false, 'error', 'case_binding_mismatch');
  end if;

  -- Allowlist: fail closed while empty.
  if not exists (
    select 1
    from private.verification_provider_allowlist allowlist
    where allowlist.provider_key = btrim(p_provider_key)
      and allowlist.verification_type = v_type
      and allowlist.is_enabled
  ) then
    return jsonb_build_object('ok', false, 'error', 'provider_not_allowlisted');
  end if;

  -- Evidence freshness: verified after case submission (staleness), not
  -- future-dated beyond clock skew, and expiry (when set) after verification.
  if v_verified_at is not null then
    if v_verified_at < coalesce(v_case.submitted_at, v_case.created_at)
       or v_verified_at > clock_timestamp() + interval '300 seconds' then
      return jsonb_build_object('ok', false, 'error', 'evidence_time_invalid');
    end if;
  end if;
  if v_expires_at is not null and v_expires_at <= v_verified_at then
    return jsonb_build_object('ok', false, 'error', 'evidence_expiry_invalid');
  end if;

  -- Replay idempotency + provenance fingerprint of the exact raw body.
  v_sha := encode(extensions.digest(convert_to(p_raw_body, 'UTF8'), 'sha256'), 'hex');
  insert into private.verification_provider_results (
    verification_case_id, user_id, verification_type, provider_key,
    provider_reference, provider_event_id, result, evidence_sha256,
    verified_at, expires_at
  ) values (
    v_case.id, v_user_id, v_type, btrim(p_provider_key),
    v_reference, v_event_id, v_result, v_sha,
    v_verified_at, v_expires_at
  )
  on conflict (provider_key, provider_event_id) do nothing;
  if not found then
    return jsonb_build_object('ok', true, 'duplicate', true);
  end if;
  return jsonb_build_object('ok', true, 'duplicate', false);
end;
$function$;
revoke all on function private.ingest_verification_provider_event(text,text,text,text,text) from public, anon, authenticated, service_role;

-- Public wrapper: the only service-role-callable entry point (PostgREST can
-- only reach functions in exposed schemas; the logic stays in private).
create or replace function public.mort_ingest_verification_provider_event(
  p_project_ref text,
  p_provider_key text,
  p_timestamp text,
  p_signature text,
  p_raw_body text
)
returns jsonb
language sql
security definer
set search_path = ''
as $function$
  select private.ingest_verification_provider_event(
    p_project_ref, p_provider_key, p_timestamp, p_signature, p_raw_body
  );
$function$;
revoke all on function public.mort_ingest_verification_provider_event(text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.mort_ingest_verification_provider_event(text,text,text,text,text) to service_role;
comment on function public.mort_ingest_verification_provider_event(text,text,text,text,text) is
  'Issue #50: trusted ingestion boundary for verification provider events. Service-role only; verifies provider HMAC signature, tenant binding, case binding, allowlist, freshness, and replay idempotency before any insert.';

commit;
