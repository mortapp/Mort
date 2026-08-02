import { createClient } from '@supabase/supabase-js';
import { createHash } from 'node:crypto';
import pg from 'pg';

const projectUrl = 'https://rakjydmgwwgtdislanbt.supabase.co';
const required = (name) => {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};

if (required('EXPO_PUBLIC_SUPABASE_URL') !== projectUrl) {
  throw new Error('Play review fixtures must target rakjydmgwwgtdislanbt.');
}
const teenPassword = required('PLAY_REVIEW_TEEN_PASSWORD');
const adultPassword = required('PLAY_REVIEW_ADULT_PASSWORD');
if (teenPassword.length < 16 || adultPassword.length < 16) {
  throw new Error('Play review passwords do not meet the fixture minimum.');
}

function suffixedEmail(email, suffix) {
  const at = email.lastIndexOf('@');
  if (at < 1) throw new Error('Play review email configuration is invalid.');
  return `${email.slice(0, at)}+${suffix}${email.slice(at)}`;
}

const definitions = [
  { key: 'teen', email: required('PLAY_REVIEW_TEEN_EMAIL'), password: teenPassword, role: 'teen', name: 'Play Review Teen', dob: '2010-10-12' },
  { key: 'adult', email: required('PLAY_REVIEW_ADULT_EMAIL'), password: adultPassword, role: 'adult', name: 'Play Review Adult', dob: '1989-04-18' },
  { key: 'guardian', email: suffixedEmail(required('PLAY_REVIEW_ADULT_EMAIL'), 'guardian'), password: adultPassword, role: 'guardian', name: 'Play Review Guardian', dob: '1984-08-21' },
  { key: 'demo', email: suffixedEmail(required('PLAY_REVIEW_ADULT_EMAIL'), 'blocked-demo'), password: adultPassword, role: 'adult', name: 'Blocked Demo Account', dob: '1990-02-14' },
];

const supabase = createClient(projectUrl, required('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: { persistSession: false, autoRefreshToken: false },
});
const database = new pg.Client({
  host: 'db.rakjydmgwwgtdislanbt.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: required('SUPABASE_DB_PASSWORD'),
  ssl: { rejectUnauthorized: false },
});

async function findUser(email) {
  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 100 });
    if (error) throw error;
    const found = data.users.find((user) => user.email?.toLowerCase() === email.toLowerCase());
    if (found) return found;
    if (data.users.length < 100) return null;
  }
  return null;
}

async function ensureUser(definition) {
  const existing = await findUser(definition.email);
  if (existing) {
    const { data, error } = await supabase.auth.admin.updateUserById(existing.id, {
      password: definition.password,
      email_confirm: true,
      user_metadata: { display_name: definition.name, play_review_fixture: true, play_review_environment: 'play_review' },
    });
    if (error) throw error;
    return data.user;
  }
  const { data, error } = await supabase.auth.admin.createUser({
    email: definition.email,
    password: definition.password,
    email_confirm: true,
    user_metadata: { display_name: definition.name, play_review_fixture: true, play_review_environment: 'play_review' },
  });
  if (error) throw error;
  return data.user;
}

const users = {};
for (const definition of definitions) users[definition.key] = await ensureUser(definition);

await database.connect();
try {
  await database.query('begin');
  await database.query("select set_config('mort.internal_update', 'true', true)");
  await database.query("select set_config('mort.onboarding_completion', 'true', true)");

  for (const definition of definitions) {
    await database.query(
      `insert into public.profiles (
         id, role, display_name, dob, city, state, onboarding_completed,
         verification_status, is_test_account, approximate_area
       ) values ($1, $2::public.user_role, $3, $4::date, 'Testville', 'IN', true,
         case when $2 in ('teen', 'adult') then 'approved'::public.verification_status else 'not_started'::public.verification_status end,
         true, 'Synthetic Play review area')
       on conflict (id) do update set
         role = excluded.role, display_name = excluded.display_name, dob = excluded.dob,
         city = excluded.city, state = excluded.state, onboarding_completed = true,
         verification_status = excluded.verification_status, is_test_account = true,
         approximate_area = excluded.approximate_area,
         account_status = 'active', blocked_until = null`,
      [users[definition.key].id, definition.role, definition.name, definition.dob],
    );
  }

  for (const definition of definitions.filter(({ key }) => key === 'teen' || key === 'adult')) {
    const user = users[definition.key];
    const current = await database.query(
      `select id from public.identity_verifications
       where user_id = $1 and environment = 'sandbox' and status = 'verified'
       and expires_at > now() order by verified_at desc limit 1`,
      [user.id],
    );
    if (current.rowCount === 0) {
      const teen = definition.role === 'teen';
      await database.query(
        `insert into public.identity_verifications (
           user_id, account_role, evidence_route, provider, provider_reference,
           environment, decision_source, status, verification_level, age_band,
           identity_match_result, liveness_result, email_verification_result,
           address_validation_result, enhanced_screening_status,
           submitted_at, reviewed_at, verified_at, expires_at, risk_flags
         ) values (
           $1, $2::public.user_role, 'legacy_approved_record',
           'mort_play_review_fixture', 'play-review-' || gen_random_uuid()::text,
           'sandbox', 'sandbox_simulation', 'verified', $3, $4,
           'matched', 'passed', 'verified', $5, 'not_enabled',
           now(), now(), now(), now() + interval '60 days',
           jsonb_build_object(
             'isolated_qa', true,
             'play_review_fixture', true,
             'documents_collected', false,
             'production_eligible', false
           )
         )`,
        [user.id, definition.role, teen ? 2 : 3, teen ? 'teen_13_17' : 'adult_18_plus', teen ? 'not_required' : 'validated_private'],
      );
    }
  }

  await database.query(
    `insert into public.teen_profiles (user_id, guardian_approval_required, bio, skills)
     values ($1, true, 'Synthetic Play review profile. No real minor.', array['yard help','organization'])
     on conflict (user_id) do update set guardian_approval_required = true,
       bio = excluded.bio, skills = excluded.skills`,
    [users.teen.id],
  );
  await database.query(
    `insert into public.adult_profiles (user_id, business_name, business_type, verification_notes)
     values ($1, 'Play Review Home Help', 'Synthetic closed-pilot organization', 'Synthetic reviewer fixture; not identity verified.')
     on conflict (user_id) do update set business_name = excluded.business_name,
       business_type = excluded.business_type, verification_notes = excluded.verification_notes`,
    [users.adult.id],
  );
  await database.query(
    `insert into public.guardian_profiles (user_id, emergency_contact_name)
     values ($1, 'Synthetic Review Contact')
     on conflict (user_id) do update set emergency_contact_name = excluded.emergency_contact_name`,
    [users.guardian.id],
  );

  await database.query(
    `insert into public.guardian_connections (teen_id, guardian_id, status, relationship, accepted_at)
     values ($1, $2, 'active', 'Synthetic reviewer guardian', now())
     on conflict (teen_id, guardian_id) where guardian_id is not null and status = 'active'
     do update set relationship = excluded.relationship, accepted_at = excluded.accepted_at`,
    [users.teen.id, users.guardian.id],
  );

  const organizationResult = await database.query(
    `select id from public.partner_organizations
     where display_name = 'MORT Play Review Partner' and environment = 'sandbox'
     order by created_at limit 1`,
  );
  let organizationId = organizationResult.rows[0]?.id;
  if (!organizationId) {
    const inserted = await database.query(
      `insert into public.partner_organizations (
         organization_type, legal_name, display_name, status, environment,
         verified_by, verified_at, expires_at, pilot_approved,
         pilot_approved_by, pilot_approved_at,
         privacy_training_acknowledged_at,
         child_safety_training_acknowledged_at
       ) values (
         'community_center', 'Synthetic MORT Play Review Partner',
         'MORT Play Review Partner', 'verified', 'sandbox',
         $1, now(), now() + interval '180 days', true,
         $1, now(), now(), now()
       ) returning id`,
      [users.adult.id],
    );
    organizationId = inserted.rows[0].id;
  } else {
    await database.query(
      `update public.partner_organizations set
         status = 'verified', verified_by = $2, verified_at = now(),
         expires_at = now() + interval '180 days', pilot_approved = true,
         pilot_approved_by = $2, pilot_approved_at = now(),
         privacy_training_acknowledged_at = now(),
         child_safety_training_acknowledged_at = now()
       where id = $1`,
      [organizationId, users.adult.id],
    );
  }

  const staffResult = await database.query(
    `select id from public.partner_staff
     where organization_id = $1 and user_id = $2
     order by created_at limit 1`,
    [organizationId, users.adult.id],
  );
  let staffId = staffResult.rows[0]?.id;
  if (!staffId) {
    const inserted = await database.query(
      `insert into public.partner_staff (
         organization_id, user_id, staff_role, status, verified_by,
         verified_at, expires_at
       ) values (
         $1, $2, 'organization_admin', 'active', $2, now(),
         now() + interval '180 days'
       ) returning id`,
      [organizationId, users.adult.id],
    );
    staffId = inserted.rows[0].id;
  } else {
    await database.query(
      `update public.partner_staff set
         staff_role = 'organization_admin', status = 'active',
         verified_by = $2, verified_at = now(),
         expires_at = now() + interval '180 days', revoked_at = null
       where id = $1`,
      [staffId, users.adult.id],
    );
  }

  for (const permission of [
    'view_connected_participants',
    'attest_person_appeared',
    'attest_affiliation',
    'attest_age_band',
    'attest_program_participation',
    'manage_partner_invites',
  ]) {
    await database.query(
      `insert into public.partner_permissions (
         partner_staff_id, permission_key, enabled, granted_by, grant_reason
       ) values ($1, $2, true, $3,
         'Synthetic Play review permission for isolated reviewer QA.')
       on conflict (partner_staff_id, permission_key) do update set
         enabled = true, revoked_at = null,
         grant_reason = excluded.grant_reason`,
      [staffId, permission, users.adult.id],
    );
  }

  for (const participant of [
    { id: users.teen.id, role: 'teen' },
    { id: users.adult.id, role: 'adult' },
  ]) {
    const existingEnrollment = await database.query(
      `select id from public.pilot_enrollments
       where user_id = $1 and status = 'approved' and revoked_at is null
       order by created_at desc limit 1`,
      [participant.id],
    );
    if (existingEnrollment.rowCount === 0) {
      await database.query(
        `insert into public.pilot_enrollments (
           user_id, organization_id, source_type, status, participation_role,
           approved_by, approved_at, expires_at, decision_reason
         ) values (
           $1, $2, 'manual_pilot_enrollment', 'approved', $3,
           $4, now(), now() + interval '120 days',
           'Synthetic isolated Play review enrollment.'
         )`,
        [participant.id, organizationId, participant.role, users.adult.id],
      );
    } else {
      await database.query(
        `update public.pilot_enrollments set
           organization_id = $2, expires_at = now() + interval '120 days',
           decision_reason = 'Synthetic isolated Play review enrollment.'
         where id = $1`,
        [existingEnrollment.rows[0].id, organizationId],
      );
    }
  }

  const acknowledgementTypes = {
    teen: ['teen_safety_training', 'prohibited_work', 'payment_scope', 'incident_policy', 'pilot_rules', 'explicit_consent'],
    adult: ['adult_safety_training', 'prohibited_work', 'payment_scope', 'incident_policy', 'pilot_rules', 'explicit_consent'],
  };
  for (const [role, types] of Object.entries(acknowledgementTypes)) {
    const userId = users[role].id;
    for (const type of types) {
      await database.query(
        `insert into public.pilot_participant_acknowledgements (
           user_id, acknowledgement_type, policy_version
         ) values ($1, $2, 1)
         on conflict (user_id, acknowledgement_type, policy_version)
         do update set acknowledged_at = now(), revoked_at = null`,
        [userId, type],
      );
    }
  }

  const jobResult = await database.query(
    `select id from public.jobs
     where poster_id = $1 and is_test = true and title = 'Play Review Yard Organizing'
     order by created_at desc limit 1`,
    [users.adult.id],
  );
  let jobId = jobResult.rows[0]?.id;
  if (!jobId) {
    const inserted = await database.query(
      `insert into public.jobs (
         poster_id, title, description, category, location_text, city, state,
         pay_label, teen_min_age, teen_max_age, requires_guardian_approval,
         status, is_test, created_by_qa, environment_tag, applications_open,
         who_will_be_present, public_meeting_available, daylight_only,
         adult_supervision_present, safety_notes
       ) values (
         $1, 'Play Review Yard Organizing',
         'Sort lightweight garden supplies for 45 minutes.',
         'yard help', 'Public community garden meeting area', 'Testville', 'IN',
         '$30 payment preference after completion - no processing', 13, 17, true,
         'open', true, true, 'qa', true,
         'Approved pilot staff', true, true, true,
         'No private address, power tools, or residence entry is involved.'
       ) returning id`,
      [users.adult.id],
    );
    jobId = inserted.rows[0].id;
  }
  await database.query(
    `update public.jobs set
       pilot_organization_id = $2,
       pilot_location_class = 'community_center',
       pilot_staffed_or_visible = true,
       pilot_review_status = 'eligible',
       pilot_restriction_reasons = '{}',
       pilot_policy_version = 1,
       pilot_reviewed_by = $3,
       pilot_reviewed_at = now(),
       is_test = true,
       environment_tag = 'qa',
       status = 'open',
       applications_open = true,
       description = 'Sort lightweight garden supplies for 45 minutes.',
       location_text = 'Public community garden meeting area',
       who_will_be_present = 'Approved pilot staff',
       safety_notes = 'No private address, power tools, or residence entry is involved.'
     where id = $1`,
    [jobId, organizationId, users.adult.id],
  );

  const applicationResult = await database.query(
    `select id from public.applications where job_id = $1 and teen_id = $2 limit 1`,
    [jobId, users.teen.id],
  );
  let applicationId = applicationResult.rows[0]?.id;
  if (!applicationId) {
    const inserted = await database.query(
      `insert into public.applications (
         job_id, teen_id, guardian_id, status, note, availability_confirmed
       ) values ($1, $2, $3, 'accepted',
         'Available during the flexible schedule shown.', true)
       returning id`,
      [jobId, users.teen.id, users.guardian.id],
    );
    applicationId = inserted.rows[0].id;
  }
  await database.query(
    `update public.applications set
       status = 'accepted',
       note = 'Available during the flexible schedule shown.',
       availability_confirmed = true
     where id = $1`,
    [applicationId],
  );

  const threadResult = await database.query(
    `select id from public.message_threads where application_id = $1 limit 1`,
    [applicationId],
  );
  let threadId = threadResult.rows[0]?.id;
  if (!threadId) {
    const inserted = await database.query(
      `insert into public.message_threads (job_id, application_id, teen_id, adult_id, guardian_id)
       values ($1, $2, $3, $4, $5) returning id`,
      [jobId, applicationId, users.teen.id, users.adult.id, users.guardian.id],
    );
    threadId = inserted.rows[0].id;
  }

  const messageCount = await database.query(
    `select count(*)::int as count from public.messages
     where thread_id = $1 and body like 'Synthetic Play review:%'`,
    [threadId],
  );
  if (messageCount.rows[0].count === 0) {
    await database.query(
      `insert into public.messages (thread_id, sender_id, body, scanner_status)
       values
       ($1, $2, 'Synthetic Play review: I can arrive during the listed daylight window.', 'clean'),
       ($1, $3, 'Synthetic Play review: Thanks. Keep all updates in this job thread.', 'clean')`,
      [threadId, users.teen.id, users.adult.id],
    );
  }

  const contractResult = await database.query(
    `select id, active_version_id from public.job_contracts
     where application_id = $1 limit 1`,
    [applicationId],
  );
  let contractId = contractResult.rows[0]?.id;
  let contractVersionId = contractResult.rows[0]?.active_version_id;
  if (!contractId) {
    const inserted = await database.query(
      `insert into public.job_contracts (
         job_id, application_id, teen_id, adult_id, status,
         classification_status, activated_at
       ) values (
         $1, $2, $3, $4, 'active',
         'possible_independent_service_relationship', now()
       ) returning id`,
      [jobId, applicationId, users.teen.id, users.adult.id],
    );
    contractId = inserted.rows[0].id;
  }
  if (!contractVersionId) {
    const termsSnapshot = {
      synthetic_review: true,
      scope: 'Sort lightweight synthetic garden supplies for 45 minutes.',
      payment_processing: false,
      safety_guarantee: false,
    };
    const contentHash = createHash('sha256')
      .update(JSON.stringify(termsSnapshot))
      .digest('hex');
    const inserted = await database.query(
      `insert into public.job_contract_versions (
         contract_id, version_number, source, status,
         teen_public_identifier, adult_public_identifier, agreed_scope,
         excluded_work, location_type, exact_location_release_state,
         service_date, start_window, expected_end_window,
         amount_type, fixed_total_cents, payment_preference,
         payment_due_rule, equipment, hazards, expected_people_present,
         supervision, proof_requirements, completion_requirements,
         cancellation_terms, material_change_process, dispute_process,
         safety_agreement_version, terms_snapshot, content_hash,
         created_by, activated_at
       ) values (
         $1, 1, 'application_acceptance', 'active',
         'Play Review Teen', 'Play Review Adult',
         'Sort lightweight synthetic garden supplies for 45 minutes.',
         array['power tools','ladders','driving','private residence entry'],
         'staffed_community_project', 'not_released', current_date,
         now() - interval '2 hours', now() - interval '1 hour',
         'fixed', 3000, 'arranged outside MORT',
         'Due after mutually confirmed completion.',
         'No equipment required.', 'No known synthetic hazards.',
         'Synthetic adult reviewer only.', 'Staffed public test setting.',
         'Optional non-invasive synthetic proof.',
         'Both parties confirm the listed scope.',
         'Either party may stop safely before work begins.',
         'Material changes require both parties to accept a new version.',
         'Use the private MORT dispute workflow; MORT does not decide legal liability.',
         'play-review-v1', $2::jsonb, $3, $4, now()
       ) returning id`,
      [contractId, JSON.stringify(termsSnapshot), contentHash, users.adult.id],
    );
    contractVersionId = inserted.rows[0].id;
    await database.query(
      `update public.job_contracts set
         active_version_id = $2, status = 'active', activated_at = now()
       where id = $1`,
      [contractId, contractVersionId],
    );
    for (const party of [
      { id: users.teen.id, role: 'teen', text: 'I accept this synthetic teen contract.' },
      { id: users.adult.id, role: 'adult', text: 'I accept this synthetic adult contract.' },
    ]) {
      await database.query(
        `insert into public.job_contract_acceptances (
           contract_id, contract_version_id, user_id, party_role,
           content_hash, affirmative_checkbox, confirmation_text,
           platform, app_version
         ) values ($1, $2, $3, $4, $5, true, $6,
           'play_review_fixture', '0.9.1')
         on conflict (contract_version_id, user_id) do nothing`,
        [contractId, contractVersionId, party.id, party.role, contentHash, party.text],
      );
    }
  }

  const safetyTerms = {
    synthetic_review: true,
    job_context_only: true,
    public_staffed_location: true,
    emergency_service: false,
  };
  const safetyHash = createHash('sha256')
    .update(JSON.stringify(safetyTerms))
    .digest('hex');
  await database.query(
    `insert into public.job_safety_agreements (
       application_id, job_id, teen_id, adult_id, agreement_version,
       terms_snapshot, material_terms_hash, status,
       teen_confirmed_at, adult_confirmed_at,
       teen_confirmed_version, adult_confirmed_version
     ) values (
       $1, $2, $3, $4, 1, $5::jsonb, $6, 'confirmed',
       now() - interval '3 hours', now() - interval '3 hours', 1, 1
     ) on conflict (application_id) do update set
       terms_snapshot = excluded.terms_snapshot,
       material_terms_hash = excluded.material_terms_hash,
       status = 'confirmed', teen_confirmed_at = excluded.teen_confirmed_at,
       adult_confirmed_at = excluded.adult_confirmed_at,
       teen_confirmed_version = 1, adult_confirmed_version = 1`,
    [applicationId, jobId, users.teen.id, users.adult.id, JSON.stringify(safetyTerms), safetyHash],
  );

  await database.query(
    `insert into public.job_arrival_handshakes (
       application_id, job_id, teen_id, adult_id, checkin_at,
       teen_identity_match_confirmed, adult_identity_match_confirmed,
       teen_checkout_at, adult_checkout_at
     ) values (
       $1, $2, $3, $4, now() - interval '2 hours',
       true, true, now() - interval '1 hour', now() - interval '1 hour'
     ) on conflict (application_id) do update set
       checkin_at = excluded.checkin_at,
       teen_identity_match_confirmed = true,
       adult_identity_match_confirmed = true,
       teen_checkout_at = excluded.teen_checkout_at,
       adult_checkout_at = excluded.adult_checkout_at`,
    [applicationId, jobId, users.teen.id, users.adult.id],
  );

  const completionCount = await database.query(
    `select count(*)::int as count from public.job_completion_assertions
     where contract_id = $1 and statement like 'Synthetic Play review:%'`,
    [contractId],
  );
  if (completionCount.rows[0].count === 0) {
    await database.query(
      `insert into public.job_completion_assertions (
         contract_id, contract_version_id, asserted_by, assertion_role,
         assertion_type, task_checklist, start_timestamp,
         completion_timestamp, location_type_confirmation,
         approved_scope_confirmation, statement
       ) values
       ($1, $2, $3, 'teen', 'worker_completed',
        '[{"task":"Synthetic organizing","completed":true}]'::jsonb,
        now() - interval '2 hours', now() - interval '1 hour',
        'staffed_community_project', true,
        'Synthetic Play review: worker completion claim.'),
       ($1, $2, $4, 'adult', 'adult_acknowledged',
        '[{"task":"Synthetic organizing","completed":true}]'::jsonb,
        now() - interval '2 hours', now() - interval '1 hour',
        'staffed_community_project', true,
        'Synthetic Play review: adult completion confirmation.')`,
      [contractId, contractVersionId, users.teen.id, users.adult.id],
    );
  }

  const obligationResult = await database.query(
    `select id from public.job_payment_obligations
     where contract_version_id = $1 limit 1`,
    [contractVersionId],
  );
  let obligationId = obligationResult.rows[0]?.id;
  if (!obligationId) {
    const inserted = await database.query(
      `insert into public.job_payment_obligations (
         contract_id, contract_version_id, obligated_poster_id, worker_id,
         amount_cents, payment_preference, due_rule, due_at, status,
         became_due_at, disputed_at
       ) values (
         $1, $2, $3, $4, 3000, 'arranged outside MORT',
         'Due after mutually confirmed completion.', now() - interval '30 minutes',
         'disputed', now() - interval '1 hour', now() - interval '20 minutes'
       ) returning id`,
      [contractId, contractVersionId, users.adult.id, users.teen.id],
    );
    obligationId = inserted.rows[0].id;
  }
  await database.query(
    `insert into public.payment_disputes (
       obligation_id, contract_id, opened_by, worker_id, poster_id,
       worker_statement, poster_statement
     ) values (
       $1, $2, $3, $3, $4,
       'Synthetic Play review: payment has not been marked received.',
       'Synthetic Play review: poster response is pending review.'
     ) on conflict (obligation_id) do update set
       worker_statement = excluded.worker_statement,
       poster_statement = excluded.poster_statement`,
    [obligationId, contractId, users.teen.id, users.adult.id],
  );
  await database.query(
    `update public.job_contracts set status = 'disputed' where id = $1`,
    [contractId],
  );

  await database.query(
    `insert into public.blocks (blocker_id, blocked_id)
     values ($1, $2) on conflict (blocker_id, blocked_id) do nothing`,
    [users.teen.id, users.demo.id],
  );
  const reportMarker = 'Synthetic Play review: block and report demonstration.';
  const reportCount = await database.query(
    `select count(*)::int as count from public.reports
     where reporter_id = $1 and target_user_id = $2 and details = $3`,
    [users.teen.id, users.demo.id, reportMarker],
  );
  if (reportCount.rows[0].count === 0) {
    await database.query(
      `insert into public.reports (
         reporter_id, target_user_id, reason, details, category, severity,
         immediate_danger, desired_outcome
       ) values (
         $1, $2, 'Synthetic review demonstration', $3,
         'other_urgent_concern', 'moderate', false,
         'Demonstrate the private moderation route only.'
       )`,
      [users.teen.id, users.demo.id, reportMarker],
    );
  }

  const deletionCount = await database.query(
    `select count(*)::int as count from public.account_deletion_requests
     where user_id = $1 and status in ('requested', 'processing')`,
    [users.demo.id],
  );
  if (deletionCount.rows[0].count === 0) {
    const fingerprint = createHash('sha256')
      .update(`play-review-deletion:${users.demo.id}`)
      .digest('hex');
    await database.query(
      `insert into public.account_deletion_requests (
         user_id, requester_fingerprint, source, status,
         identity_confirmed_at, retention_summary
       ) values (
         $1, $2, 'in_app', 'requested', now(),
         'Synthetic review request only; no real personal data.'
       )`,
      [users.demo.id, fingerprint],
    );
  }

  await database.query('commit');
} catch (error) {
  await database.query('rollback').catch(() => {});
  throw error;
} finally {
  await database.end();
}

process.stdout.write('Play review tenant created or verified: isolated teen/adult access, synthetic partner organization, job, application, conversation, contract, safety agreement, arrival/completion history, payment disagreement, report, block, and deletion-request demonstration.\n');
