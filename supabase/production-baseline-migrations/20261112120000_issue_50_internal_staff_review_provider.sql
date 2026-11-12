-- Issue #50 follow-up: operator-approved internal staff-review provider.
--
-- Product decision (Mort, 2026-11-12): MORT's verification model is staff
-- review of uploaded documents (school ID / government ID). The internal
-- document-review process is the approved provider for those verification
-- types. This migration:
--   1. Allowlists provider 'mort_staff_review' for school_id + identity
--      (the only types submit_my_verification_evidence_v1 creates).
--   2. Adds mort_record_staff_document_review: a staff-only RPC that records
--      an explicit, case-bound, immutable document-review attestation into
--      private.verification_provider_results -- only after verifying the
--      reviewer is staff, the case is undecided, the case's provider is
--      'mort_staff_review', the allowlist still enables it, and the evidence
--      document actually exists in the verification-evidence bucket.
--   3. mort_review_verification_case is NOT modified: a 'verified' outcome
--      still requires a case-bound, fresh provider result from an allowlisted
--      provider. Staff approval alone still cannot verify -- the explicit
--      document-review attestation is the evidence.
--
-- Other provider keys (including legacy 'self_reported' cases) remain
-- fail-closed. External providers can be added later via the signed
-- ingestion boundary without changes here.
begin;

do $guard$
begin
  if position('verification_provider_allowlist' in
      pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamptz)'::regprocedure)) = 0 then
    raise exception 'issue_50_gate_missing:mort_review_verification_case';
  end if;
end;
$guard$;

-- 1. Operator approval: internal staff document review as the provider for
--    school_id and identity cases.
insert into private.verification_provider_allowlist (provider_key, verification_type, is_enabled)
values
  ('mort_staff_review', 'school_id', true),
  ('mort_staff_review', 'identity', true)
on conflict (provider_key, verification_type) do nothing;

-- 2. Staff document-review attestation RPC.
create or replace function public.mort_record_staff_document_review(
  p_case_id uuid,
  p_decision text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_case public.verification_cases%rowtype;
  v_sha text;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'authorized_reviewer_required');
  end if;
  if p_decision is null or p_decision not in ('verified','rejected') then
    return jsonb_build_object('ok', false, 'code', 'invalid_decision');
  end if;

  select * into v_case
  from public.verification_cases vc
  where vc.id = p_case_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'case_not_found');
  end if;
  if v_case.provider is distinct from 'mort_staff_review' then
    return jsonb_build_object('ok', false, 'code', 'not_staff_review_case');
  end if;
  if v_case.status not in ('pending','needs_review') then
    return jsonb_build_object('ok', false, 'code', 'case_already_decided');
  end if;
  if v_case.evidence_path is null then
    return jsonb_build_object('ok', false, 'code', 'no_evidence_document');
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'verification-evidence'
      and o.name = v_case.evidence_path
  ) then
    return jsonb_build_object('ok', false, 'code', 'evidence_document_missing');
  end if;
  if not exists (
    select 1 from private.verification_provider_allowlist a
    where a.provider_key = 'mort_staff_review'
      and a.verification_type = v_case.verification_type
      and a.is_enabled
  ) then
    return jsonb_build_object('ok', false, 'code', 'provider_not_allowlisted');
  end if;

  v_sha := encode(extensions.digest(convert_to(
    v_case.id::text || '|' || v_case.evidence_path || '|' || v_user::text || '|' || p_decision,
    'UTF8'), 'sha256'), 'hex');

  insert into private.verification_provider_results (
    verification_case_id, user_id, verification_type, provider_key,
    provider_reference, provider_event_id, result, evidence_sha256,
    verified_at, expires_at
  ) values (
    v_case.id, v_case.user_id, v_case.verification_type, 'mort_staff_review',
    v_case.provider_reference,
    'staff-' || v_case.id::text || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS'),
    p_decision, v_sha,
    case when p_decision = 'verified' then clock_timestamp() else null end,
    null
  );

  insert into public.admin_audit_log (actor_id, action, target_type, target_id, reason, metadata)
  values (v_user, 'staff_document_review_recorded', 'verification_case', v_case.id::text,
          nullif(btrim(coalesce(p_note, '')), ''),
          jsonb_build_object(
            'decision', p_decision,
            'verification_type', v_case.verification_type,
            'evidence_path', v_case.evidence_path,
            'provider_key', 'mort_staff_review'));

  return jsonb_build_object('ok', true, 'decision', p_decision);
end;
$function$;
revoke all on function public.mort_record_staff_document_review(uuid,text,text) from public, anon, authenticated;
grant execute on function public.mort_record_staff_document_review(uuid,text,text) to authenticated;
comment on function public.mort_record_staff_document_review(uuid,text,text) is
  'Issue #50: staff-only attestation that the reviewer examined the case''s uploaded evidence document and reached a decision. Records an immutable, case-bound provider result for the internal mort_staff_review provider; mort_review_verification_case still requires this evidence before any verified outcome.';

commit;
