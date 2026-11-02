-- Fixture-free assertions for the proposal drafts after local compilation.
-- These verify source predicates and real anonymous/no-claim denial paths;
-- they do not prove authenticated role workflows or concurrency behavior.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT extensions.plan(19);

SELECT extensions.ok(
  position('result.expires_at is null or result.expires_at > v_now' in pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure)) > 0,
  'verification approval rejects expired provider evidence'
);
SELECT extensions.ok(
  position('result.result = ''verified''' in pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure)) > 0
  AND position('result.received_at >= coalesce(v_case.submitted_at, v_case.created_at)' in pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure)) > 0,
  'approval requires a successful result received for the current case'
);
SELECT extensions.ok(
  position('v_case.user_id is distinct from v_case_snapshot.user_id' in pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure)) > 0
  AND position('v_case.provider_reference is distinct from v_case_snapshot.provider_reference' in pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure)) > 0,
  'verification review rejects a changed or stale case snapshot'
);
SELECT extensions.ok(
  position('result.verification_case_id = v_case.id' in pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure)) > 0
  AND position('result.user_id = v_case.user_id' in pg_get_functiondef('public.mort_review_verification_case(uuid,public.mort_verification_status,text,timestamp with time zone)'::regprocedure)) > 0,
  'provider evidence is bound to the current case and subject IDs'
);
SELECT extensions.ok(
  position('verification_type = ''age''' in pg_get_functiondef('public.get_job_application_eligibility(uuid)'::regprocedure)) > 0
  AND position('vc.expires_at is null or vc.expires_at > v_now' in pg_get_functiondef('public.get_job_application_eligibility(uuid)'::regprocedure)) > 0,
  'application eligibility requires non-revoked, unexpired age verification'
);
SELECT extensions.ok(
  position('verification_type = ''school_id''' in pg_get_functiondef('public.get_job_application_eligibility(uuid)'::regprocedure)) > 0
  AND position('verification_type = ''school_email''' in pg_get_functiondef('public.get_job_application_eligibility(uuid)'::regprocedure)) > 0
  AND position('school_id_verification_required' in pg_get_functiondef('public.get_job_application_eligibility(uuid)'::regprocedure)) > 0
  AND position('school_email_verification_required' in pg_get_functiondef('public.get_job_application_eligibility(uuid)'::regprocedure)) > 0,
  'eligibility enforces both active production school verification tracks'
);
SELECT extensions.ok(
  position('vc.status = ''verified''::public.mort_verification_status' in pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure)) > 0
  AND position('vc.expires_at is null or vc.expires_at > v_now' in pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure)) > 0,
  'acceptance rejects revoked or expired verification states'
);
SELECT extensions.ok(
  position('v_app.status not in (' in pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure)) > 0
  AND position('''submitted''::public.mort_application_status' in pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure)) > 0
  AND position('''shortlisted''::public.mort_application_status' in pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure)) > 0,
  'duplicate or already accepted application cannot be accepted again'
);
SELECT extensions.ok(
  position('gl.status = ''active''' in pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure)) > 0
  AND position('gl.teen_consent_at is not null' in pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure)) > 0
  AND position('gl.guardian_consent_at is not null' in pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure)) > 0,
  'Guardian-required jobs need an active, dual-consented Guardian link'
);
SELECT extensions.ok(
  position('existing_checkin.request_interval_minutes <> p_minutes_from_now' in pg_get_functiondef('public.schedule_active_job_checkin(uuid,integer,uuid)'::regprocedure)) > 0
  AND position('''ok'', true, ''replayed'', true' in pg_get_functiondef('public.schedule_active_job_checkin(uuid,integer,uuid)'::regprocedure)) > 0,
  'scheduled check-in retry is payload-bound and matching retries replay'
);
SELECT extensions.ok(
  position('existing_checkin.request_interval_minutes <> p_minutes_from_now' in pg_get_functiondef('public.schedule_active_job_checkin(uuid,integer,uuid)'::regprocedure)) > 0
  AND position('''code'', ''idempotency_key_reused''' in pg_get_functiondef('public.schedule_active_job_checkin(uuid,integer,uuid)'::regprocedure)) > 0,
  'scheduled check-in retry rejects a mismatched interval'
);
SELECT extensions.ok(
  position('checkin.completion_request_id = p_client_request_id' in pg_get_functiondef('public.complete_active_job_checkin(uuid,uuid)'::regprocedure)) > 0
  AND position('''ok'', true, ''replayed'', true, ''payload_verified'', true' in pg_get_functiondef('public.complete_active_job_checkin(uuid,uuid)'::regprocedure)) > 0,
  'matching completion request ID replays the completed result'
);
SELECT extensions.ok(
  position('if checkin.completion_request_id is not null then' in pg_get_functiondef('public.complete_active_job_checkin(uuid,uuid)'::regprocedure)) > 0
  AND position('''ok'', false, ''code'', ''idempotency_key_reused''' in pg_get_functiondef('public.complete_active_job_checkin(uuid,uuid)'::regprocedure)) > 0,
  'mismatched completion request ID is rejected for newly bound rows'
);
SELECT extensions.ok(
  position('pg_try_advisory_xact_lock' in pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure)) > 0
  AND position('job_acceptance_in_progress_retry' in pg_get_functiondef('public.mort_accept_job_application(uuid)'::regprocedure)) > 0,
  'competing acceptances use a fail-fast per-job transaction lock'
);

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"role":"authenticated"}';
SELECT extensions.is(
  public.get_job_application_eligibility(NULL::uuid),
  jsonb_build_object('eligible',false,'code','authentication_required','message','Sign in to apply.','guardian_required_for_this_job',false,'guardian_linked',false),
  'eligibility RPC denies a no-claim caller'
);
SELECT extensions.throws_ok(
  'SELECT public.mort_accept_job_application(NULL::uuid)',
  'P0001', 'Authentication required', 'acceptance RPC denies a no-claim caller'
);
SELECT extensions.throws_ok(
  'SELECT public.mort_review_verification_case(NULL::uuid,NULL::public.mort_verification_status,NULL,NULL)',
  'P0001', 'Authorized verification reviewer required', 'verification review denies a no-claim caller'
);
SELECT extensions.is(
  public.schedule_active_job_checkin(NULL::uuid,15,extensions.gen_random_uuid()),
  jsonb_build_object('ok',false,'code','authentication_required'),
  'check-in scheduling denies a no-claim caller'
);
SELECT extensions.is(
  public.complete_active_job_checkin(NULL::uuid,extensions.gen_random_uuid()),
  jsonb_build_object('ok',false,'code','authentication_required'),
  'check-in completion denies a no-claim caller'
);

RESET ROLE;
SELECT * FROM extensions.finish();
ROLLBACK;
