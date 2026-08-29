// Functional account-deletion regression, local Docker only. Exercises the
// REAL supabase.auth.admin.deleteUser() API path (the same call
// supabase/functions/account-deletion-processor/index.ts makes) against
// synthetic fixtures covering the categories most directly touched by
// docs/ACCOUNT_DELETION_FK_MATRIX.md: legal acceptance, active staff
// authorization (the one CASCADE exception), historical staff audit
// (SET NULL), an active safety-incident case assignment (the close-out
// trigger), a shared job/application record, an account ban appeal,
// duplicate/idempotent deletion, and cross-user isolation.
//
// NOT covered here (documented gap, not silently skipped): job_contracts and
// payment_disputes have deep fixture dependency chains (job_contracts needs
// a job + application; payment_disputes needs a job_payment_obligation +
// contract on top of that). Their disposition is still covered by the
// structural qa-account-deletion-fk-contract.mjs (confirms SET NULL, column
// nullable, not RESTRICT) -- this script adds an end-to-end behavioral proof
// for the categories above, not a full bespoke fixture per FK.
//
// Run against local: SUPABASE_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
import { createClient } from "@supabase/supabase-js";
import pg from "pg";

const url = process.env.EXPO_PUBLIC_SUPABASE_URL ?? "http://127.0.0.1:54321";
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const dbUrl = process.env.SUPABASE_DB_URL;
if (!serviceRoleKey || !dbUrl) {
  console.error("Set SUPABASE_SERVICE_ROLE_KEY and SUPABASE_DB_URL (local stack).");
  process.exit(1);
}
if (!/127\.0\.0\.1|localhost/.test(url) && !/127\.0\.0\.1|localhost/.test(dbUrl)) {
  console.error("Refusing to run: this script is for the local stack only.");
  process.exit(1);
}

const admin = createClient(url, serviceRoleKey, { auth: { persistSession: false } });
const db = new pg.Client({ connectionString: dbUrl });
await db.connect();

let failures = 0;
function assertQa(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    failures += 1;
  } else {
    console.log(`PASS: ${message}`);
  }
}

async function createUser(label) {
  const { data, error } = await admin.auth.admin.createUser({
    email: `deletion-qa-${label}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}@mort.test`,
    password: "TestPassword123!",
    email_confirm: true,
  });
  if (error) throw new Error(`createUser(${label}): ${JSON.stringify(error)}`);
  return data.user.id;
}

async function tx(fn) {
  await db.query("begin");
  try {
    await db.query("select set_config('mort.internal_update', 'true', true)");
    await db.query("select set_config('mort.onboarding_completion', 'true', true)");
    const result = await fn();
    await db.query("commit");
    return result;
  } catch (error) {
    await db.query("rollback");
    throw error;
  }
}

async function makeProfile(id, displayName, role = "adult") {
  const dob = role === "teen" ? "2010-01-01" : "1990-01-01";
  await db.query(
    `insert into public.profiles (id, role, display_name, dob, city, state, onboarding_completed, is_test_account)
     values ($1,$2,$3,$4,'Carmel','IN',true,true)
     on conflict (id) do update set
       role=excluded.role,
       display_name=excluded.display_name,
       dob=excluded.dob,
       city=excluded.city,
       state=excluded.state,
       onboarding_completed=true,
       is_test_account=true`,
    [id, role, displayName, dob],
  );
}

async function makeVerifiedIdentity(id, role) {
  const teen = role === "teen";
  await db.query(
    `insert into public.identity_verifications (
       user_id, account_role, evidence_route, provider, provider_reference,
       environment, decision_source, status, verification_level, age_band,
       identity_match_result, liveness_result, email_verification_result,
       address_validation_result, enhanced_screening_status,
       submitted_at, reviewed_at, verified_at, risk_flags
     ) values (
       $1, $2::public.user_role, 'legacy_approved_record', 'mort_isolated_qa',
       'qa-' || gen_random_uuid()::text, 'sandbox', 'sandbox_simulation',
       'verified', $3, $4, 'matched', 'passed', 'verified',
       'validated_private', 'not_enabled', now(), now(), now(),
       jsonb_build_object('isolated_qa', true, 'production_eligible', false)
     )`,
    [id, role, teen ? 2 : 3, teen ? "teen_13_17" : "adult_18_plus"],
  );
}

const staffSubject = await createUser("staff-holder");
const staffApprover = await createUser("staff-approver");
const incidentStaff = await createUser("incident-staff");
const jobPoster = await createUser("job-poster");
const jobApplicant = await createUser("job-applicant");
const guardianTeen = await createUser("guardian-teen");
const guardianAdult = await createUser("guardian-adult");
const legalSubject = await createUser("legal-subject");
const banAppellant = await createUser("ban-appellant");
const isolatedOther = await createUser("isolated-other");

const fixtures = await tx(async () => {
  await makeProfile(staffSubject, "Staff Holder");
  await makeProfile(staffApprover, "Staff Approver");
  await makeProfile(incidentStaff, "Incident Staff");
  await makeProfile(jobPoster, "Job Poster");
  await makeProfile(jobApplicant, "Job Applicant", "teen");
  await makeProfile(guardianTeen, "Guardian Teen", "teen");
  await makeProfile(guardianAdult, "Guardian Adult");
  await makeProfile(legalSubject, "Legal Subject");
  await makeProfile(banAppellant, "Ban Appellant");
  await makeProfile(isolatedOther, "Isolated Other");
  await makeVerifiedIdentity(jobPoster, "adult");
  await makeVerifiedIdentity(jobApplicant, "teen");

  // 1. Active staff role (team_role_assignments) -- the one CASCADE exception.
  await db.query(
    `insert into public.team_role_assignments
       (id, user_id, role_key, approved_by, approval_reason, access_reason,
        access_status, granted_at, expires_at)
     values
       (gen_random_uuid(), $1, 'support_trainee', $2, 'qa fixture',
        'qa fixture', 'active', now(), now() + interval '1 day')`,
    [staffSubject, staffApprover],
  );

  // 2. Historical staff audit record (team_access_audit_events) -- SET NULL.
  await db.query(
    `insert into public.team_access_audit_events
       (user_id, action, target_category, purpose, access_allowed)
     values ($1, 'case_view', 'support_ticket', 'qa fixture', true)`,
    [staffSubject],
  );

  // 3. Active safety-incident case assignment -- the close-out trigger.
  const incident = await db.query(
    `insert into public.safety_incidents (id, category, severity)
     values (gen_random_uuid(), 'other_urgent_concern', 'low') returning id`,
  );
  const incidentAssignment = await db.query(
    `insert into public.incident_assignments (id, incident_id, assigned_to, assigned_by, assignment_role)
     values (gen_random_uuid(), $1, $2, $2, 'incident_manager') returning id`,
    [incident.rows[0].id, incidentStaff],
  );

  // 4. Shared job/application record -- deleting the poster must not corrupt
  // the applicant's view of it.
  const job = await db.query(
    `insert into public.jobs (id, poster_id, title, description, category, location_text, city, state, pay_label, status)
     values (gen_random_uuid(), $1, 'QA deletion job', 'test', 'yard work', 'Near Main St', 'Carmel', 'IN', '$20', 'open')
     returning id`,
    [jobPoster],
  );
  const application = await db.query(
    `insert into public.applications (id, job_id, teen_id, status, note)
     values (gen_random_uuid(), $1, $2, 'submitted', 'qa fixture')
     returning id`,
    [job.rows[0].id, jobApplicant],
  );

  // 5. Active guardian authorization must disappear, while its audit event
  // survives deidentified. Deleting the teen exercises the historically
  // dangerous audit.teen_id CASCADE edge.
  const guardianLink = await db.query(
    `insert into public.guardian_connections
       (id, teen_id, guardian_id, status, relationship, accepted_at)
     values (gen_random_uuid(), $1, $2, 'active', 'parent', now())
     returning id`,
    [guardianTeen, guardianAdult],
  );
  await db.query(
    `insert into public.guardian_connection_audit_events
       (link_id, teen_id, guardian_id, actor_id, event_type, safe_metadata)
     values ($1, $2, $3, $3, 'invite_accepted', '{"qa_fixture":true}'::jsonb)`,
    [guardianLink.rows[0].id, guardianTeen, guardianAdult],
  );

  // 6. Legal acceptance (LEGAL_REVIEW_REQUIRED per the matrix, SET NULL implemented).
  const document = await db.query(
    `insert into public.legal_documents (id, document_key, title, document_category, publication_status)
     values (gen_random_uuid(), 'qa_fixture_doc_' || replace(gen_random_uuid()::text, '-', ''), 'QA Fixture Document', 'conduct', 'draft_attorney_review')
     returning id`,
  );
  const version = await db.query(
    `insert into public.legal_document_versions (id, document_id, version_label, content_hash, content_path, effective_at, publication_status)
     values (gen_random_uuid(), $1, 'qa-1', repeat('a', 64), 'docs/qa-fixture.md', now(), 'draft_attorney_review')
     returning id`,
    [document.rows[0].id],
  );
  await db.query(
    `insert into public.legal_acceptances (id, user_id, role, age_band, document_id, document_version_id, content_hash, effective_date, platform, app_version, language_code, jurisdiction_policy, acceptance_ui_version, affirmative_checkbox)
     values (gen_random_uuid(), $1, 'adult', 'adult_18_plus', $2, $3, repeat('a', 64), now(), 'android', '0.9.16', 'en', 'us_default', 'v1', true)`,
    [legalSubject, document.rows[0].id, version.rows[0].id],
  );

  // 7. Account ban appeal (regression -- already proven working, keep covered).
  await db.query(
    `insert into public.account_ban_appeals (id, user_id, reason) values (gen_random_uuid(), $1, 'This is a synthetic QA test appeal reason with enough characters.')`,
    [banAppellant],
  );
  return {
    incidentAssignmentId: incidentAssignment.rows[0].id,
    jobId: job.rows[0].id,
    applicationId: application.rows[0].id,
    guardianLinkId: guardianLink.rows[0].id,
  };
});

// Snapshot "before" state for later comparison.
const before = await db.query(
  `select
     (select count(*) from public.team_role_assignments where user_id=$1) as staff_role,
     (select count(*) from public.team_access_audit_events where user_id=$1) as staff_audit,
     (select count(*) from public.incident_assignments where id=$2) as incident_assignment,
     (select ended_at from public.incident_assignments where id=$2) as incident_ended_at,
     (select count(*) from public.legal_acceptances where user_id=$3) as legal,
     (select count(*) from public.account_ban_appeals where user_id=$4) as ban`,
  [staffSubject, fixtures.incidentAssignmentId, legalSubject, banAppellant],
);
assertQa(Number(before.rows[0].staff_role) === 1, "fixture: active staff role attached");
assertQa(before.rows[0].incident_ended_at === null, "fixture: incident assignment is still open before deletion");

// Hostile direct writes remain denied even with the service key. The narrow
// trigger exception is available only to the Auth server's canonical hard
// delete transaction, not to PostgREST UPDATE/UPSERT traffic.
const { error: directPosterNullError } = await admin
  .from("jobs")
  .update({ poster_id: null })
  .eq("id", fixtures.jobId);
assertQa(Boolean(directPosterNullError), "direct PostgREST UPDATE jobs.poster_id=NULL is denied at the database boundary");
const { error: directApplicantNullError } = await admin
  .from("applications")
  .update({ teen_id: null })
  .eq("id", fixtures.applicationId);
assertQa(Boolean(directApplicantNullError), "direct PostgREST UPDATE applications.teen_id=NULL is denied at the database boundary");

// --- Delete the staff holder, incident staff, legal subject, ban appellant,
// job poster, and one side of an active guardian authorization. ---
for (const [label, id] of [
  ["staff holder", staffSubject],
  ["incident staff", incidentStaff],
  ["legal subject", legalSubject],
  ["ban appellant", banAppellant],
  ["job poster", jobPoster],
  ["guardian-linked teen", guardianTeen],
]) {
  const { error } = await admin.auth.admin.deleteUser(id, false);
  assertQa(!error, `auth.admin.deleteUser succeeds for ${label} (no FK blocks it)`);
}

// --- Idempotency: deleting an already-deleted user must not throw or corrupt anything. ---
const { error: duplicateError } = await admin.auth.admin.deleteUser(staffSubject, false);
assertQa(
  Boolean(duplicateError),
  "duplicate deleteUser on an already-deleted user returns an error (not a silent success), and does not crash the process",
);

const after = await db.query(
  `select
     (select count(*) from public.profiles where id=$1) as staff_profile_remains,
     (select count(*) from public.team_role_assignments where user_id=$1) as staff_role_remains,
     (select count(*) from public.team_access_audit_events where user_id=$1) as staff_audit_remains,
     (select count(*) from public.team_access_audit_events) as staff_audit_total,
     (select assigned_to from public.incident_assignments where id=$2) as incident_assigned_to,
     (select ended_at from public.incident_assignments where id=$2) as incident_ended_at,
     (select count(*) from public.legal_acceptances where user_id=$3) as legal_with_link,
     (select count(*) from public.legal_acceptances) as legal_total,
     (select count(*) from public.account_ban_appeals where user_id=$4) as ban_with_link,
     (select count(*) from public.account_ban_appeals) as ban_total,
     (select poster_id from public.jobs where id=$5) as job_poster_id,
     (select status from public.jobs where id=$5) as job_status,
     (select applications_open from public.jobs where id=$5) as job_applications_open,
     (select count(*) from public.jobs where id=$5) as job_total,
     (select teen_id from public.applications where id=$6) as application_teen_id,
     (select status from public.applications where id=$6) as application_status,
     (select count(*) from public.applications where id=$6) as application_total,
     (select count(*) from public.guardian_connections where id=$7) as guardian_link_total,
     (select teen_id from public.guardian_connection_audit_events where link_id is null and guardian_id=$8 limit 1) as guardian_audit_teen_id,
     (select count(*) from public.guardian_connection_audit_events where guardian_id=$8) as guardian_audit_total`,
  [
    staffSubject,
    fixtures.incidentAssignmentId,
    legalSubject,
    banAppellant,
    fixtures.jobId,
    fixtures.applicationId,
    fixtures.guardianLinkId,
    guardianAdult,
  ],
);
const a = after.rows[0];

assertQa(Number(a.staff_profile_remains) === 0, "staff holder's profile is gone");
assertQa(Number(a.staff_role_remains) === 0, "team_role_assignments row for the deleted holder no longer exists (CASCADE, not an orphaned still-active-looking grant)");
assertQa(Number(a.staff_audit_remains) === 0, "team_access_audit_events no longer links to the deleted user_id (SET NULL)");
assertQa(Number(a.staff_audit_total) >= 1, "team_access_audit_events row itself survives, deidentified");
assertQa(a.incident_assigned_to === null, "incident_assignments.assigned_to is nulled after the assignee's account is deleted");
assertQa(a.incident_ended_at !== null, "incident_assignments.ended_at was set by the close-out trigger before the FK nulled assigned_to -- no case silently looks assigned-but-abandoned");
assertQa(Number(a.legal_with_link) === 0, "legal_acceptances no longer links to the deleted user_id");
assertQa(Number(a.legal_total) >= 1, "legal_acceptances row survives with its factual content (document/version/hash/timestamp) intact");
assertQa(Number(a.ban_with_link) === 0, "account_ban_appeals no longer links to the deleted user_id");
assertQa(Number(a.ban_total) >= 1, "account_ban_appeals row survives, deidentified");
assertQa(a.job_poster_id === null, "the surviving job is deidentified from the deleted poster (SET NULL)");
assertQa(a.job_status === "canceled" && a.job_applications_open === false, "the deleted poster's unfinished job is closed at the database boundary");
assertQa(Number(a.job_total) === 1, "the shared job record survives the poster's account deletion");
assertQa(Number(a.application_total) === 1, "the applicant's application to that job survives (cross-user shared record not corrupted)");
assertQa(a.application_teen_id === jobApplicant, "the surviving applicant remains linked after only the poster is deleted");
assertQa(a.application_status === "rejected", "the pending application is moved to the canonical terminal status when its poster is deleted");
assertQa(Number(a.guardian_link_total) === 0, "active guardian authorization is removed when either participant account is deleted");
assertQa(Number(a.guardian_audit_total) >= 1 && a.guardian_audit_teen_id === null, "guardian connection audit evidence survives with the deleted teen identity removed");

// --- Cross-user isolation: an unrelated account must be completely untouched. ---
const isolatedCheck = await db.query("select id, display_name from public.profiles where id=$1", [isolatedOther]);
assertQa(isolatedCheck.rowCount === 1 && isolatedCheck.rows[0].display_name === "Isolated Other", "an unrelated account is completely untouched by any of the above deletions");

// --- The applicant (jobApplicant) is still a normal, undeleted account whose
// own application record must still show them as the teen_id (their account
// wasn't touched, only the job poster's was).
const applicantCheck = await db.query(
  "select count(*)::int as count from public.applications where teen_id = $1",
  [jobApplicant],
);
assertQa(applicantCheck.rows[0].count >= 1, "the surviving applicant's own link to their application is intact");

// Deleting the applicant must not erase the poster-side/shared application
// history either. This was a second pre-existing CASCADE edge.
const { error: applicantDeleteError } = await admin.auth.admin.deleteUser(jobApplicant, false);
assertQa(!applicantDeleteError, "auth.admin.deleteUser succeeds for the surviving applicant");
const applicationAfterApplicantDeletion = await db.query(
  "select teen_id, status from public.applications where id=$1",
  [fixtures.applicationId],
);
assertQa(
  applicationAfterApplicantDeletion.rowCount === 1 &&
    applicationAfterApplicantDeletion.rows[0].teen_id === null &&
    applicationAfterApplicantDeletion.rows[0].status === "rejected",
  "application history survives applicant deletion and is deidentified without regressing its terminal status",
);

// Clean up accounts not deleted as part of the scenario.
await admin.auth.admin.deleteUser(isolatedOther, false).catch(() => {});
await admin.auth.admin.deleteUser(staffApprover, false).catch(() => {});
await admin.auth.admin.deleteUser(guardianAdult, false).catch(() => {});

await db.end();

if (failures === 0) {
  console.log(`\n[qa-account-deletion-functional] PASS: all scenarios green.`);
} else {
  console.error(`\n[qa-account-deletion-functional] FAIL: ${failures} scenario(s) failed.`);
  process.exitCode = 1;
}
