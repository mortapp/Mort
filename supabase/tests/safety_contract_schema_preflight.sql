-- Read-only preflight for the 202611 safety-contract drafts.
-- Run only against an explicitly isolated local/staging database through
-- scripts/qa-safety-contract-schema-preflight.mjs.

DO $$
DECLARE
  required_relation text;
  required_column record;
BEGIN
  FOREACH required_relation IN ARRAY ARRAY[
    'public.jobs',
    'public.profiles',
    'public.job_applications',
    'public.job_assignments',
    'public.job_safety_agreements',
    'public.mort_release_control',
    'public.verification_cases',
    'public.guardian_links',
    'auth.users',
    'public.conversations',
    'public.conversation_members',
    'public.messages',
    'public.user_blocks'
  ] LOOP
    IF to_regclass(required_relation) IS NULL THEN
      RAISE EXCEPTION 'safety-contract preflight missing relation: %', required_relation;
    END IF;
  END LOOP;

  FOR required_column IN
    SELECT * FROM (VALUES
      ('public.jobs', 'id'),
      ('public.jobs', 'poster_id'),
      ('public.jobs', 'location_text'),
      ('public.jobs', 'city'),
      ('public.jobs', 'region'),
      ('public.jobs', 'location_type'),
      ('public.job_applications', 'id'),
      ('public.job_applications', 'job_id'),
      ('public.job_applications', 'applicant_id'),
      ('public.job_assignments', 'application_id'),
      ('public.job_assignments', 'job_id'),
      ('public.job_assignments', 'teen_user_id'),
      ('public.job_assignments', 'status'),
      ('public.job_safety_agreements', 'application_id'),
      ('public.job_safety_agreements', 'job_id'),
      ('public.job_safety_agreements', 'status'),
      ('public.job_safety_agreements', 'agreement_version'),
      ('public.job_safety_agreements', 'teen_confirmed_version'),
      ('public.job_safety_agreements', 'adult_confirmed_version'),
      ('public.mort_release_control', 'is_primary'),
      ('public.mort_release_control', 'maintenance_mode'),
      ('public.mort_release_control', 'public_marketplace_enabled'),
      ('public.verification_cases', 'user_id'),
      ('public.verification_cases', 'verification_type'),
      ('public.verification_cases', 'status'),
      ('public.verification_cases', 'expires_at'),
      ('public.guardian_links', 'id'),
      ('public.guardian_links', 'teen_user_id'),
      ('public.guardian_links', 'status'),
      ('public.conversations', 'id'),
      ('public.conversations', 'status'),
      ('public.conversation_members', 'conversation_id'),
      ('public.conversation_members', 'user_id'),
      ('public.messages', 'conversation_id'),
      ('public.messages', 'sender_id'),
      ('public.messages', 'body'),
      ('public.messages', 'moderation_status'),
      ('public.user_blocks', 'blocker_id'),
      ('public.user_blocks', 'blocked_id')
    ) AS expected(table_name, column_name)
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = split_part(required_column.table_name, '.', 1)
        AND table_name = split_part(required_column.table_name, '.', 2)
        AND column_name = required_column.column_name
    ) THEN
      RAISE EXCEPTION 'safety-contract preflight missing column: %.%', required_column.table_name, required_column.column_name;
    END IF;
  END LOOP;

  IF to_regprocedure('private.refresh_job_safety_agreement(uuid)') IS NULL THEN
    RAISE EXCEPTION 'safety-contract preflight missing private.refresh_job_safety_agreement(uuid)';
  END IF;
  IF to_regprocedure('public.save_job_draft_or_publish(uuid,uuid,jsonb,boolean)') IS NULL THEN
    RAISE EXCEPTION 'safety-contract preflight missing public.save_job_draft_or_publish(uuid,uuid,jsonb,boolean)';
  END IF;
  IF to_regprocedure('public.mort_send_message(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'safety-contract preflight missing public.mort_send_message(uuid,text)';
  END IF;
  IF to_regprocedure('public.get_my_account_trust_profile()') IS NULL THEN
    RAISE EXCEPTION 'safety-contract preflight missing public.get_my_account_trust_profile()';
  END IF;
  IF to_regprocedure('public.get_marketplace_trust_eligibility(text,uuid)') IS NULL THEN
    RAISE EXCEPTION 'safety-contract preflight missing public.get_marketplace_trust_eligibility(text,uuid)';
  END IF;
  IF to_regprocedure('public.request_school_email_affiliation(text)') IS NULL THEN
    RAISE EXCEPTION 'safety-contract preflight missing public.request_school_email_affiliation(text)';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.job_safety_agreements'::regclass
      AND pg_get_constraintdef(oid) ILIKE '%reconfirmation_required%'
  ) THEN
    RAISE EXCEPTION 'safety-contract preflight missing reconfirmation_required agreement status';
  END IF;
END;
$$;

SELECT 'safety-contract schema preflight: PASS' AS result;
