-- Issue #50: fail-closed trusted-evidence gate for staff verification review.
--
-- Blocks positive (verified) review outcomes unless an allowlisted provider has
-- produced a verified, case-bound provider result for the same subject,
-- provider reference, and verification type, with freshness and expiry
-- constraints. Provider results are only written by the signed ingestion
-- boundary (edge function `verification-provider-event`), which verifies the
-- provider HMAC signature, project/tenant binding, event identity, case
-- binding, and freshness before inserting — service-role access alone is
-- never treated as evidence authenticity.
--
-- The production allowlist and ingestion keys are intentionally NOT seeded:
-- no positive verification can succeed until an approved provider and its
-- signing key are documented (provider/legal/security approval) and inserted
-- by an operator. This migration fails closed by design.
--
-- Exact-source guard: the live production definition of
-- public.mort_review_verification_case must match the recovered baseline
-- (md5 36df69d6a5c279bd555119a6e10dffa4) before this migration applies.
begin;

do $guard$
begin
  if md5(pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamptz)'::regprocedure))
     <> '36df69d6a5c279bd555119a6e10dffa4' then
    raise exception 'issue_50_source_mismatch:mort_review_verification_case';
  end if;
end;
$guard$;

-- ---------------------------------------------------------------------------
-- Allowlist: explicitly approved providers per verification type.
-- ---------------------------------------------------------------------------
create table if not exists private.verification_provider_allowlist (
  provider_key text not null,
  verification_type text not null
    check (verification_type in ('age','identity','guardian_consent','school_email','school_id','business')),
  is_enabled boolean not null default false,
  created_at timestamptz not null default clock_timestamp(),
  primary key (provider_key, verification_type),
  check (provider_key = btrim(provider_key) and char_length(provider_key) between 1 and 100)
);
alter table private.verification_provider_allowlist enable row level security;
revoke all on private.verification_provider_allowlist from public, anon, authenticated, service_role;
grant select on private.verification_provider_allowlist to service_role;
comment on table private.verification_provider_allowlist is
  'Issue #50: explicitly approved verification providers by case type; intentionally empty until provider/legal/security approval is documented. Empty means no positive verification can succeed (fail closed).';

-- ---------------------------------------------------------------------------
-- Provider results: immutable metadata only, written exclusively by the
-- signed ingestion boundary. No documents or raw provider payloads.
-- ---------------------------------------------------------------------------
create table if not exists private.verification_provider_results (
  id uuid primary key default extensions.gen_random_uuid(),
  verification_case_id uuid not null references public.verification_cases(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  verification_type text not null
    check (verification_type in ('age','identity','guardian_consent','school_email','school_id','business')),
  provider_key text not null,
  provider_reference text,
  provider_event_id text not null,
  result text not null check (result in ('verified','rejected','needs_review')),
  evidence_sha256 text not null check (evidence_sha256 ~ '^[0-9a-f]{64}$'),
  verified_at timestamptz,
  expires_at timestamptz,
  received_at timestamptz not null default clock_timestamp(),
  unique (provider_key, provider_event_id),
  unique (verification_case_id, provider_key, provider_reference, provider_event_id),
  check (provider_event_id = btrim(provider_event_id) and char_length(provider_event_id) between 1 and 200),
  check (provider_key = btrim(provider_key) and char_length(provider_key) between 1 and 100),
  check (provider_reference is null or (provider_reference = btrim(provider_reference) and char_length(provider_reference) between 1 and 200)),
  check ((result = 'verified' and verified_at is not null) or result <> 'verified'),
  check (expires_at is null or verified_at is null or expires_at > verified_at)
);
create index if not exists verification_provider_results_case_current_idx
  on private.verification_provider_results
  (verification_case_id, provider_key, verification_type, received_at desc);
alter table private.verification_provider_results enable row level security;
revoke all on private.verification_provider_results from public, anon, authenticated, service_role;
grant select, insert on private.verification_provider_results to service_role;
comment on table private.verification_provider_results is
  'Issue #50: immutable provider result metadata; insert only via the signed ingestion boundary after HMAC signature, tenant, case-binding, freshness, and replay verification. evidence_sha256 is the SHA-256 of the exact raw request body (UTF-8) — a provenance fingerprint, not a proof of authenticity (authenticity is the verified HMAC signature).';

-- ---------------------------------------------------------------------------
-- Ingestion signing keys: HMAC keys per provider per project (tenant
-- binding). Read only by the edge function via service role; never granted
-- to client roles. Rotation: update hmac_key + rotated_at.
-- ---------------------------------------------------------------------------
create table if not exists private.verification_provider_ingestion_keys (
  provider_key text not null,
  project_ref text not null
    check (project_ref ~ '^[a-z]{20}$'),
  hmac_key text not null
    check (char_length(hmac_key) between 32 and 512),
  is_enabled boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  rotated_at timestamptz,
  primary key (provider_key, project_ref)
);
alter table private.verification_provider_ingestion_keys enable row level security;
revoke all on private.verification_provider_ingestion_keys from public, anon, authenticated, service_role;
grant select on private.verification_provider_ingestion_keys to service_role;
comment on table private.verification_provider_ingestion_keys is
  'Issue #50: per-provider, per-project HMAC signing keys for the provider event ingestion boundary. A key is only valid for the project it was issued for (tenant binding). Not seeded by migrations; an operator inserts keys only after documented provider approval.';

-- ---------------------------------------------------------------------------
-- Gated review function. Superset of the guarded baseline:
--   * unchanged behaviour for rejected / needs_review / expired;
--   * verified additionally requires (a) DOB 13+ (existing), (b) an enabled
--     allowlist entry for the case provider + verification type, (c) a
--     verified, case-bound, fresh, unexpired provider result, and (d) a
--     review expiry that does not outlive the evidence;
--   * row lock + stale-snapshot detection so a decision cannot be applied
--     to a case that changed under review (verification_case_changed_retry).
-- ---------------------------------------------------------------------------
create or replace function public.mort_review_verification_case(
  p_case_id uuid,
  p_status public.mort_verification_status,
  p_note text default null,
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_owner uuid;
  v_snapshot public.verification_cases%rowtype;
  v_case public.verification_cases%rowtype;
  v_date_of_birth date;
  v_now timestamptz;
  v_evidence_result_id uuid;
  v_evidence_expires_at timestamptz;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized verification reviewer required';
  end if;
  if p_status not in ('verified'::public.mort_verification_status,
                      'rejected'::public.mort_verification_status,
                      'needs_review'::public.mort_verification_status,
                      'expired'::public.mort_verification_status) then
    raise exception 'Invalid review outcome';
  end if;

  -- Unlocked snapshot to discover the subject. Lock order for approvals:
  -- profile -> allowlist -> case -> provider result.
  select * into v_snapshot
  from public.verification_cases vc
  where vc.id = p_case_id;
  if not found then raise exception 'Verification case not found'; end if;
  v_owner := v_snapshot.user_id;

  if p_status = 'verified'::public.mort_verification_status then
    select profile.date_of_birth into v_date_of_birth
    from public.profiles profile
    where profile.id = v_owner
    for share;
    if not found or v_date_of_birth is null
       or extract(year from age(current_date, v_date_of_birth)) < 13 then
      raise exception 'minimum_age_verification_required';
    end if;

    -- Fail-closed provider allowlist: empty table means no approvals.
    perform provider.provider_key
    from private.verification_provider_allowlist provider
    where provider.provider_key = v_snapshot.provider
      and provider.verification_type = v_snapshot.verification_type
      and provider.is_enabled
    for share;
    if not found then
      raise exception 'trusted_verification_provider_unavailable';
    end if;
  end if;

  v_now := clock_timestamp();
  if p_expires_at is not null and p_expires_at <= v_now then
    raise exception 'verification_expiry_must_be_in_future';
  end if;

  -- Lock the case and refuse to apply a decision to changed details.
  select * into v_case
  from public.verification_cases vc
  where vc.id = p_case_id
  for update;
  if not found then raise exception 'Verification case not found'; end if;
  if v_case.user_id is distinct from v_snapshot.user_id
     or v_case.provider is distinct from v_snapshot.provider
     or v_case.verification_type is distinct from v_snapshot.verification_type
     or v_case.provider_reference is distinct from v_snapshot.provider_reference
     or v_case.status is distinct from v_snapshot.status
     or v_case.updated_at is distinct from v_snapshot.updated_at then
    raise exception 'verification_case_changed_retry';
  end if;

  if p_status = 'verified'::public.mort_verification_status then
    -- Case-bound evidence: same subject, provider, reference, and type;
    -- verified after submission, received after submission, not expired.
    select result.id, result.expires_at
      into v_evidence_result_id, v_evidence_expires_at
    from private.verification_provider_results result
    where result.verification_case_id = v_case.id
      and result.user_id = v_case.user_id
      and result.verification_type = v_case.verification_type
      and result.provider_key = v_case.provider
      and result.provider_reference is not distinct from v_case.provider_reference
      and result.result = 'verified'
      and result.verified_at <= v_now
      and result.verified_at >= coalesce(v_case.submitted_at, v_case.created_at)
      and result.received_at <= v_now
      and result.received_at >= coalesce(v_case.submitted_at, v_case.created_at)
      and (result.expires_at is null or result.expires_at > v_now)
    order by result.received_at desc
    limit 1
    for share;
    if not found then
      raise exception 'case_appropriate_provider_evidence_required';
    end if;
    -- The verification cannot outlive the provider evidence it rests on.
    if v_evidence_expires_at is not null
       and (p_expires_at is null or p_expires_at > v_evidence_expires_at) then
      raise exception 'review_expiry_exceeds_provider_evidence';
    end if;
  end if;

  update public.verification_cases
  set status=p_status, reviewer_id=v_user,
      reviewer_note=nullif(btrim(p_note),''),
      reviewed_at=v_now, expires_at=p_expires_at, updated_at=v_now
  where id=p_case_id;

  update public.profiles
  set verification_status = case p_status
        when 'verified' then 'verified'
        when 'rejected' then 'rejected'
        when 'needs_review' then 'pending'
        when 'expired' then 'expired'
      end,
      updated_at = now()
  where id = v_owner;

  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values (v_user,'verification_reviewed','verification_case',p_case_id::text,
          nullif(btrim(p_note),''),
          jsonb_build_object(
            'status', p_status,
            'provider_result_id', v_evidence_result_id,
            'provider_key', case when p_status = 'verified'::public.mort_verification_status then v_case.provider else null end
          ));
  return p_case_id;
end;
$function$;

commit;
