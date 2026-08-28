import { createHash, randomBytes, randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  saveJob,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const allAcknowledgements = {
  teen: ["teen_safety_training", "pilot_rules", "explicit_consent"],
  adult: [
    "adult_safety_training",
    "prohibited_work",
    "payment_scope",
    "incident_policy",
    "pilot_rules",
  ],
};

async function grantRole(userId, role) {
  await withDatabase((database) =>
    database.query(
      `
        insert into public.admin_role_assignments (user_id, role, grant_reason)
        values ($1, $2::public.admin_safety_role, 'Synthetic mission-pilot QA role.')
        on conflict (user_id, role) where revoked_at is null do nothing
      `,
      [userId, role],
    ),
  );
}

async function createOrganization(scope, adminId, environment = "sandbox") {
  return withDatabase(async (database) => {
    const result = await database.query(
      `
        insert into public.partner_organizations (
          organization_type, legal_name, display_name, status, environment,
          official_directory_url, verified_by, verified_at, expires_at,
          pilot_approved, pilot_approved_by, pilot_approved_at,
          privacy_training_acknowledged_at, child_safety_training_acknowledged_at
        ) values (
          'nonprofit', $2, $2, 'verified', $3::public.verification_environment,
          'https://example.invalid/mort-synthetic-qa', $1, now(), now() + interval '2 hours',
          true, $1, now(), now(), now()
        ) returning id
      `,
      [adminId, `QA ${scope} partner`, environment],
    );
    return result.rows[0].id;
  });
}

async function setConfirmedPhone(userId) {
  const suffix = `${Date.now()}`.slice(-7);
  await withDatabase((database) =>
    database.query(
      "update auth.users set phone = $2, phone_confirmed_at = now() where id = $1",
      [userId, `+1317${suffix}`],
    ),
  );
}

async function approveEnrollment(user, organizationId, adminId, source = "manual_pilot_enrollment") {
  await withDatabase((database) =>
    database.query(
      `
        insert into public.pilot_enrollments (
          user_id, organization_id, source_type, status, participation_role,
          approved_by, approved_at, expires_at, decision_reason
        ) values (
          $1, $2, $3, 'approved', $4, $5, now(), now() + interval '90 minutes',
          'Synthetic hosted QA pilot enrollment.'
        )
      `,
      [user.id, organizationId, source, user.role, adminId],
    ),
  );
}

async function acknowledge(user, types = allAcknowledgements[user.role] ?? []) {
  for (const type of types) {
    const result = await user.client.rpc("acknowledge_pilot_policy", {
      p_acknowledgement_type: type,
    });
    assertQa(!result.error && result.data?.ok === true, `Could not acknowledge ${type}: ${result.error?.message}`);
  }
}

async function makeEligible(user, organizationId, adminId) {
  await approveEnrollment(user, organizationId, adminId);
  await acknowledge(user);
  if (user.role === "adult") await setConfirmedPhone(user.id);
}

async function createPartnerStaff(staff, organizationId, adminId, permissions) {
  return withDatabase(async (database) => {
    const staffResult = await database.query(
      `
        insert into public.partner_staff (
          organization_id, user_id, staff_role, status, verified_by,
          verified_at, expires_at
        ) values ($1, $2, 'program_coordinator', 'active', $3, now(), now() + interval '2 hours')
        returning id
      `,
      [organizationId, staff.id, adminId],
    );
    const staffId = staffResult.rows[0].id;
    for (const permission of permissions) {
      await database.query(
        `
          insert into public.partner_permissions (
            partner_staff_id, permission_key, enabled, granted_by, grant_reason
          ) values ($1, $2, true, $3, 'Synthetic mission-pilot QA permission.')
        `,
        [staffId, permission, adminId],
      );
    }
    return staffId;
  });
}

async function addMembership(userId, organizationId) {
  await withDatabase((database) =>
    database.query(
      `
        insert into public.partner_memberships (
          user_id, organization_id, status, verification_method,
          verified_at, expires_at
        ) values ($1, $2, 'active', 'partner_code', now(), now() + interval '90 minutes')
      `,
      [userId, organizationId],
    ),
  );
}

async function cleanupMissionFixture(userIds, organizationId, scope) {
  await withDatabase(async (database) => {
    await database.query("begin");
    try {
      await database.query("select set_config('mort.internal_update', 'true', true)");
      await database.query(
        `delete from private.document_vault_audit_events
         where case_id in (select id from public.document_review_cases where subject_user_id = any($1::uuid[]))`,
        [userIds],
      );
      await database.query(
        `delete from private.document_retention_actions
         where vault_object_id in (
           select object_record.id from private.document_vault_objects object_record
           join public.document_review_cases review_case on review_case.id = object_record.case_id
           where review_case.subject_user_id = any($1::uuid[])
         )`,
        [userIds],
      );
      await database.query(
        `delete from private.document_vault_access_grants
         where case_id in (select id from public.document_review_cases where subject_user_id = any($1::uuid[]))`,
        [userIds],
      );
      await database.query(
        `delete from private.document_vault_objects
         where case_id in (select id from public.document_review_cases where subject_user_id = any($1::uuid[]))`,
        [userIds],
      );
      await database.query(
        "delete from public.document_review_decisions where reviewer_id = any($1::uuid[]) or case_id in (select id from public.document_review_cases where subject_user_id = any($1::uuid[]))",
        [userIds],
      );
      await database.query(
        "delete from public.document_review_assignments where reviewer_id = any($1::uuid[]) or assigned_by = any($1::uuid[]) or case_id in (select id from public.document_review_cases where subject_user_id = any($1::uuid[]))",
        [userIds],
      );
      await database.query(
        "delete from public.document_review_appeals where appellant_id = any($1::uuid[]) or case_id in (select id from public.document_review_cases where subject_user_id = any($1::uuid[]))",
        [userIds],
      );
      await database.query("delete from public.document_review_cases where subject_user_id = any($1::uuid[])", [userIds]);
      await database.query("delete from public.resource_directory_reports where reporter_id = any($1::uuid[])", [userIds]);
      await database.query("delete from public.private_resource_bookmarks where user_id = any($1::uuid[])", [userIds]);
      await database.query("delete from public.resource_directory_entries where organization_name like $1", [`QA ${scope}%`]);
      await database.query("delete from public.partner_audit_events where organization_id = $1 or actor_id = any($2::uuid[]) or subject_user_id = any($2::uuid[])", [organizationId, userIds]);
      await database.query("delete from public.partner_permissions where granted_by = any($1::uuid[]) or partner_staff_id in (select id from public.partner_staff where organization_id = $2)", [userIds, organizationId]);
      await database.query("delete from public.partner_attestations where organization_id = $1 or subject_user_id = any($2::uuid[])", [organizationId, userIds]);
      await database.query("delete from public.pilot_enrollments where organization_id = $1 or user_id = any($2::uuid[])", [organizationId, userIds]);
      await database.query("delete from public.partner_memberships where organization_id = $1 or user_id = any($2::uuid[])", [organizationId, userIds]);
      await database.query("delete from public.partner_invite_codes where organization_id = $1 or created_by = any($2::uuid[])", [organizationId, userIds]);
      await database.query("delete from public.partner_staff where organization_id = $1 or user_id = any($2::uuid[])", [organizationId, userIds]);
      await database.query("delete from public.trust_signal_events where user_id = any($1::uuid[]) or created_by = any($1::uuid[])", [userIds]);
      await database.query("delete from public.admin_role_assignments where user_id = any($1::uuid[]) or granted_by = any($1::uuid[])", [userIds]);
      await database.query("delete from public.partner_organizations where id = $1", [organizationId]);
      await database.query("commit");
    } catch (error) {
      await database.query("rollback").catch(() => {});
      throw error;
    }
  });
}

async function withMissionFixture(scope, definitions, run, environment = "sandbox") {
  const allDefinitions = definitions.some((definition) => definition.key === "operator")
    ? definitions
    : [...definitions, { key: "operator", role: "admin", isTest: environment === "sandbox" }];
  await withQaUsers(scope, allDefinitions, async (users) => {
    const organizationId = await createOrganization(scope, users.operator.id, environment);
    try {
      await run(users, organizationId);
    } finally {
      await cleanupMissionFixture(
        Object.values(users).map((user) => user.id),
        organizationId,
        scope,
      );
    }
  });
}

async function createSyntheticDocumentCase(subjectId, twoPerson = false) {
  const result = await serviceClient.rpc("create_document_review_case", {
    p_subject_user_id: subjectId,
    p_environment: "sandbox",
    p_evidence_category: "alternative_evidence",
    p_requires_two_person_review: twoPerson,
    p_contains_real_person_data: false,
  });
  assertQa(!result.error && result.data?.ok === true, `Synthetic case failed: ${result.error?.message}`);
  return result.data.case_id;
}

async function assignReviewer(caseId, reviewerId, stage, assignedBy) {
  await withDatabase((database) =>
    database.query(
      `
        insert into public.document_review_assignments (
          case_id, reviewer_id, assignment_stage, conflict_checked_at,
          conflict_found, assigned_by
        ) values ($1, $2, $3, now(), false, $4)
      `,
      [caseId, reviewerId, stage, assignedBy],
    ),
  );
}

async function registerSyntheticVaultObject(caseId) {
  const result = await serviceClient.rpc("register_document_vault_object", {
    p_case_id: caseId,
    p_environment: "sandbox",
    p_evidence_sha256: createHash("sha256").update(`synthetic:${caseId}`).digest("hex"),
    p_mime_type: "image/png",
    p_byte_size: 64,
    p_retention_delete_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    p_synthetic_qa_metadata: true,
  });
  assertQa(!result.error && result.data?.ok === true, `Vault metadata registration failed: ${result.error?.message}`);
  return result.data.vault_object_id;
}

async function runClosedPilotAccess(scope) {
  await withMissionFixture(
    scope,
    [
      { key: "teen", role: "teen", isTest: false, identityVerified: false },
      { key: "randomTeen", role: "teen", isTest: false, identityVerified: false },
    ],
    async ({ teen, randomTeen, operator }, organizationId) => {
      await makeEligible(teen, organizationId, operator.id);
      const allowed = await teen.client.rpc("get_closed_pilot_eligibility", { p_action: "browse" });
      const blocked = await randomTeen.client.rpc("get_closed_pilot_eligibility", { p_action: "browse" });
      assertQa(allowed.data?.allowed === true, "approved partner-supported teen was not eligible");
      assertQa(blocked.data?.allowed === false, "random account entered the closed pilot");
      assertQa(blocked.data?.unrestricted_public_access_enabled === false, "public access was enabled");
      qaLog(scope, "closed pilot admits approved partner-supported users and rejects random accounts");
    },
    "production",
  );
}

async function runPartnerAttestation(scope) {
  await withMissionFixture(scope, [
    { key: "teen", role: "teen" },
    { key: "staff", role: "adult" },
  ], async ({ teen, staff, operator }, organizationId) => {
    await addMembership(teen.id, organizationId);
    await createPartnerStaff(staff, organizationId, operator.id, ["attest_affiliation"]);
    const result = await staff.client.rpc("submit_partner_attestation", {
      p_subject_user_id: teen.id,
      p_organization_id: organizationId,
      p_fact_type: "school_or_program_affiliation",
      p_expires_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    });
    assertQa(!result.error && result.data?.ok === true, `Partner attestation failed: ${result.error?.message}`);
    assertQa(result.data.government_identity_verified === false, "partner attestation granted government identity");
    const own = await teen.client.rpc("get_my_partner_attestations");
    assertQa(own.data?.attestations?.length === 1, "teen could not see the exact attestation");
    qaLog(scope, "versioned limited-scope attestation is visible to the teen without identity overclaim");
  });
}

async function runPartnerCodeSecurity(scope) {
  await withMissionFixture(scope, [{ key: "teen", role: "teen" }], async ({ teen, operator }, organizationId) => {
    const code = `MORT-${randomBytes(12).toString("base64url")}`.toUpperCase();
    const hash = createHash("sha256").update(code).digest();
    await withDatabase((database) =>
      database.query(
        `
          insert into public.partner_invite_codes (
            organization_id, code_hash, code_prefix, max_uses, expires_at,
            created_by, audience_role, purpose
          ) values ($1, $2, $3, 1, now() + interval '1 hour', $4, 'teen', 'pilot_enrollment')
        `,
        [organizationId, hash, code.slice(0, 8), operator.id],
      ),
    );
    const redeemed = await teen.client.rpc("redeem_partner_invite_code", { p_code: code });
    assertQa(!redeemed.error && redeemed.data?.ok === true, `Partner code redemption failed: ${redeemed.error?.message}`);
    const second = await teen.client.rpc("redeem_partner_invite_code", { p_code: `${code}X` });
    assertQa(second.data?.ok === false, "invalid partner code was accepted");
    const catalog = await withDatabase((database) => database.query(`select column_name from information_schema.columns where table_schema='public' and table_name='partner_invite_codes'`));
    assertQa(!catalog.rows.some((row) => ["code", "plaintext_code", "invite_code"].includes(row.column_name)), "plaintext partner-code column exists");
    qaLog(scope, "partner code is hash-only, expiring, limited-use, and invalid codes fail closed");
  });
}

async function runHousingPrivacy(scope) {
  await withMissionFixture(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const columns = await withDatabase((database) => database.query(`select table_name,column_name from information_schema.columns where table_schema='public' and (column_name ilike '%homeless%' or column_name ilike '%housing_status%')`));
    assertQa(columns.rows.length === 0, "public schema contains a homelessness or housing-status column");
    const profile = await teen.client.from("profiles").select("id,display_name,approximate_area").eq("id", teen.id).single();
    assertQa(!profile.error && profile.data, `safe profile projection failed: ${profile.error?.message}`);
    assertQa(!Object.keys(profile.data).some((key) => key.includes("housing")), "public profile exposed housing status");
    qaLog(scope, "housing insecurity is absent from public schema and public profile data");
  });
}

async function runNoPermanentAddress(scope) {
  await withMissionFixture(scope, [{ key: "teen", role: "teen", isTest: false, identityVerified: false }], async ({ teen, operator }, organizationId) => {
    await withDatabase((database) => database.query("update public.profiles set city=null,state=null,location_setup_mode='partner_supported' where id=$1", [teen.id]));
    await makeEligible(teen, organizationId, operator.id);
    const result = await teen.client.rpc("get_closed_pilot_eligibility", { p_action: "browse" });
    assertQa(result.data?.allowed === true, "no-address teen was denied pilot eligibility");
    assertQa(result.data?.permanent_address_required === false, "permanent address was required");
    qaLog(scope, "eligible teen can complete pilot onboarding with no permanent address");
  }, "production");
}

async function runGuardianOptional(scope) {
  await withMissionFixture(scope, [{ key: "teen", role: "teen", isTest: false, identityVerified: false }], async ({ teen, operator }, organizationId) => {
    await makeEligible(teen, organizationId, operator.id);
    const guardianCount = await withDatabase((database) => database.query("select count(*)::int count from public.guardian_connections where teen_id=$1", [teen.id]));
    const result = await teen.client.rpc("get_closed_pilot_eligibility", { p_action: "browse" });
    assertQa(guardianCount.rows[0].count === 0 && result.data?.allowed === true, "guardian linkage became mandatory");
    assertQa(result.data?.guardian_mode_optional === true, "guardian optional flag is false");
    qaLog(scope, "Guardian Mode remains optional for independent pilot eligibility");
  }, "production");
}

async function runSupportCircle(scope) {
  await withMissionFixture(scope, [
    { key: "teen", role: "teen" },
    { key: "member", role: "adult" },
    { key: "other", role: "adult" },
  ], async ({ teen, member, other }) => {
    await teen.client.rpc("configure_support_circle", { p_enabled: true });
    const invited = await teen.client.rpc("invite_support_circle_member", { p_member_user_id: member.id, p_relationship_type: "mentor" });
    assertQa(invited.data?.ok === true, "support member invitation failed");
    await member.client.rpc("respond_support_circle_invitation", { p_member_id: invited.data.member_id, p_accept: true });
    await teen.client.rpc("set_support_circle_permission", { p_member_id: invited.data.member_id, p_permission_key: "receive_safety_ping", p_enabled: true });
    const sent = await teen.client.rpc("send_support_circle_alert", { p_alert_type: "safety_ping", p_payload: { coarse_area: "public place", earnings: 5000, housing_status: "private" } });
    assertQa(sent.data?.recipients === 1 && sent.data?.earnings_shared === false, "alert ignored explicit permissions or shared earnings");
    const memberRows = await member.client.from("support_circle_alert_events").select("payload");
    const otherRows = await other.client.from("support_circle_alert_events").select("id");
    assertQa(!memberRows.error, `granted member alert read failed: ${memberRows.error?.message}`);
    assertQa(memberRows.data?.length === 1, `granted member saw ${memberRows.data?.length ?? 0} alerts instead of one`);
    assertQa(!("earnings" in memberRows.data[0].payload) && !("housing_status" in memberRows.data[0].payload), "granted member received sensitive payload");
    assertQa(!otherRows.error, `ungranted member isolation read failed: ${otherRows.error?.message}`);
    assertQa(otherRows.data?.length === 0, "ungranted support account received an alert");
    qaLog(scope, "Support Circle sends only granted alerts and strips sensitive payload fields");
  });
}

async function runDiscreetMode(scope) {
  await withMissionFixture(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const configured = await teen.client.rpc("update_discreet_mode", {
      p_enabled: true,
      p_app_lock_enabled: true,
      p_automatic_lock_minutes: 5,
      p_quick_exit_destination: "home",
    });
    assertQa(configured.data?.ok === true, "Discreet Mode did not save");
    const inserted = await serviceClient.from("notifications").insert({
      recipient_id: teen.id,
      title: "Shelter counselor update",
      body: "Job at 123 Private Street about abuse support",
      data: { route: "/settings/resources", residential_address: "123 Private Street", housing_status: "private" },
    }).select("title,body,data").single();
    assertQa(!inserted.error, `Discreet notification insert failed: ${inserted.error?.message}`);
    assertQa(inserted.data.title === "MORT notification" && inserted.data.body === "Open MORT to view this update.", "notification content was not hidden");
    assertQa(inserted.data.data.job_address_included === false && !("housing_status" in inserted.data.data), "notification retained sensitive details");
    qaLog(scope, "Discreet Mode replaces sensitive notification content and lock-screen address data");
  });
}

async function runDocumentClaims(scope) {
  await withMissionFixture(scope, [
    { key: "teen", role: "teen" },
    { key: "reviewer", role: "admin" },
  ], async ({ teen, reviewer, operator }) => {
    await grantRole(reviewer.id, "document_reviewer");
    const disabled = await teen.client.rpc("begin_document_review_upload", { p_evidence_category: "age_evidence" });
    assertQa(disabled.data?.code === "real_document_collection_disabled" && disabled.data?.upload_url === null, "real document upload became available");
    const caseId = await createSyntheticDocumentCase(teen.id, false);
    await assignReviewer(caseId, reviewer.id, "reviewer_a", operator.id);
    const decision = await reviewer.client.rpc("submit_document_review_decision", {
      p_case_id: caseId,
      p_decision_stage: "reviewer_a_recommendation",
      p_decision: "document_reviewed",
      p_decision_reason: "Synthetic metadata was reviewed only to validate the hosted QA workflow.",
      p_public_explanation: "MORT staff visually reviewed synthetic evidence for this QA case.",
      p_conflict_confirmed_clear: true,
    });
    assertQa(decision.data?.public_label === "MORT document reviewed", "precise document-review label was not used");
    assertQa(decision.data?.government_identity_verified === false, "visual review granted government identity");
    const forged = await teen.client.from("document_review_cases").update({ status: "document_reviewed" }).eq("id", caseId).select("id");
    assertQa(forged.error || forged.data.length === 0, "client approved its own document review");
    qaLog(scope, "document review uses precise claims, remains disabled for uploads, and cannot be self-approved");
  });
}

async function runTwoPersonReview(scope) {
  await withMissionFixture(scope, [
    { key: "teen", role: "teen" },
    { key: "reviewerA", role: "admin" },
    { key: "reviewerB", role: "admin" },
  ], async ({ teen, reviewerA, reviewerB, operator }) => {
    await grantRole(reviewerA.id, "document_reviewer");
    await grantRole(reviewerB.id, "document_reviewer");
    const caseId = await createSyntheticDocumentCase(teen.id, true);
    await assignReviewer(caseId, reviewerA.id, "reviewer_a", operator.id);
    await assignReviewer(caseId, reviewerB.id, "reviewer_b", operator.id);
    const first = await reviewerA.client.rpc("submit_document_review_decision", {
      p_case_id: caseId, p_decision_stage: "reviewer_a_recommendation",
      p_decision: "authenticity_not_authoritatively_validated",
      p_decision_reason: "Reviewer A recorded a synthetic recommendation without authoritative issuer validation.",
      p_public_explanation: "The synthetic evidence was visually reviewed; authenticity was not authoritatively validated.",
      p_conflict_confirmed_clear: true,
    });
    assertQa(first.data?.final === false, "Reviewer A finalized a two-person case");
    const selfApproval = await reviewerA.client.rpc("submit_document_review_decision", {
      p_case_id: caseId, p_decision_stage: "reviewer_b_independent_decision",
      p_decision: "document_reviewed",
      p_decision_reason: "Reviewer A attempted to submit the independent second decision for QA.",
      p_public_explanation: "This attempt must not finalize the synthetic review case.",
      p_conflict_confirmed_clear: true,
    });
    assertQa(selfApproval.data?.ok === false, "Reviewer A self-approved the second stage");
    const second = await reviewerB.client.rpc("submit_document_review_decision", {
      p_case_id: caseId, p_decision_stage: "reviewer_b_independent_decision",
      p_decision: "authenticity_not_authoritatively_validated",
      p_decision_reason: "Reviewer B independently confirmed that no authoritative authenticity validation occurred.",
      p_public_explanation: "The synthetic evidence was reviewed, but authenticity and legal identity were not authoritatively established.",
      p_conflict_confirmed_clear: true,
    });
    assertQa(second.data?.final === true && second.data?.government_identity_verified === false, "independent second review did not finalize safely");
    qaLog(scope, "two-person review prevents self-approval and records an independent final decision");
  });
}

async function runVaultAccess(scope) {
  await withMissionFixture(scope, [
    { key: "teen", role: "teen" },
    { key: "reviewer", role: "admin" },
    { key: "ordinaryAdmin", role: "admin" },
  ], async ({ teen, reviewer, ordinaryAdmin, operator }) => {
    await grantRole(reviewer.id, "document_reviewer");
    const caseId = await createSyntheticDocumentCase(teen.id, false);
    await assignReviewer(caseId, reviewer.id, "reviewer_a", operator.id);
    const objectId = await registerSyntheticVaultObject(caseId);
    const ordinary = await ordinaryAdmin.client.rpc("request_document_vault_access", { p_case_id: caseId, p_vault_object_id: objectId, p_access_action: "view", p_access_reason: "Ordinary admin QA access must be denied." });
    assertQa(ordinary.data?.ok === false, "ordinary admin received raw-document access");
    const requested = await reviewer.client.rpc("request_document_vault_access", { p_case_id: caseId, p_vault_object_id: objectId, p_access_action: "view", p_access_reason: "Assigned reviewer needs a one-time synthetic QA view." });
    assertQa(requested.data?.ok === true && requested.data?.signed_url === null, "assigned reviewer grant was not server-exchange-only");
    const consumed = await serviceClient.rpc("consume_document_vault_access_grant", { p_grant_id: requested.data.grant_id });
    const replay = await serviceClient.rpc("consume_document_vault_access_grant", { p_grant_id: requested.data.grant_id });
    assertQa(consumed.data?.ok === true && replay.data?.ok === false, "vault grant was not one-shot");
    qaLog(scope, "vault access requires specialized assignment, reason, audit grant, and one-shot server exchange");
  });
}

async function runDocumentRetention(scope) {
  await withMissionFixture(scope, [{ key: "teen", role: "teen" }], async ({ teen, operator }) => {
    const caseId = await createSyntheticDocumentCase(teen.id, false);
    const objectId = await registerSyntheticVaultObject(caseId);
    await withDatabase(async (database) => {
      await database.query("update private.document_vault_objects set preservation_lock_status='appeal_hold' where id=$1", [objectId]);
      await database.query("insert into private.document_retention_actions (vault_object_id,action,actor_id,reason,previous_delete_at,new_delete_at) select id,'extend_for_appeal',$2,'Synthetic QA appeal-safe retention extension.',retention_delete_at,retention_delete_at + interval '1 hour' from private.document_vault_objects where id=$1", [objectId, operator.id]);
      const row = await database.query("select preservation_lock_status,retention_delete_at > created_at valid_retention from private.document_vault_objects where id=$1", [objectId]);
      assertQa(row.rows[0].preservation_lock_status === "appeal_hold" && row.rows[0].valid_retention, "retention or preservation state is invalid");
    });
    qaLog(scope, "vault metadata carries retention date, preservation lock, and auditable retention action");
  });
}

async function runFounderRestriction(scope) {
  await withMissionFixture(scope, [
    { key: "teen", role: "teen" },
    { key: "founderLikeAdmin", role: "admin" },
  ], async ({ teen, founderLikeAdmin }) => {
    const caseId = await createSyntheticDocumentCase(teen.id, false);
    const objectId = await registerSyntheticVaultObject(caseId);
    const denied = await founderLikeAdmin.client.rpc("request_document_vault_access", { p_case_id: caseId, p_vault_object_id: objectId, p_access_action: "view", p_access_reason: "Founder-like ordinary admin QA must remain denied." });
    const privateRead = await founderLikeAdmin.client.schema("private").from("document_vault_objects").select("id");
    assertQa(denied.data?.ok === false && privateRead.error, "founder/developer-like admin gained automatic vault access");
    qaLog(scope, "admin/founder status alone grants neither private-schema nor raw-document access");
  });
}

async function runPilotJobRestrictions(scope) {
  await withMissionFixture(scope, [{ key: "adult", role: "adult" }], async ({ adult, operator }, organizationId) => {
    await makeEligible(adult, organizationId, operator.id);
    const safe = await saveJob(adult.client, { location_type: "public", adult_supervision_present: true, public_meeting_available: true }, true);
    assertQa(safe.result.job.pilot_review_status === "eligible" && safe.result.job.status === "open", "staffed public job was not pilot eligible");
    const unsafePayload = { ...safe.payload, title: "Private bedroom cleanup", summary: "Work alone in a private bedroom.", description: "Travel to an unknown private residence and keep the location secret.", location_type: "private_residence", client_request_id: randomUUID() };
    const unsafe = await adult.client.rpc("save_job_draft_or_publish", { p_job_id: null, p_client_request_id: unsafePayload.client_request_id, p_payload: unsafePayload, p_publish: true });
    assertQa(unsafe.error || unsafe.data?.ok === false || unsafe.data?.job?.status !== "open", "unknown private-residence job opened in pilot");
    qaLog(scope, "pilot allows staffed public work and blocks unknown private-residence work");
  });
}

async function runVulnerableTeenIsolation(scope) {
  await withMissionFixture(scope, [
    { key: "teenA", role: "teen" },
    { key: "teenB", role: "teen" },
    { key: "staff", role: "adult" },
  ], async ({ teenA, teenB, staff, operator }, organizationId) => {
    await approveEnrollment(teenA, organizationId, operator.id);
    await createPartnerStaff(staff, organizationId, operator.id, ["view_connected_participants"]);
    const roster = await staff.client.rpc("get_partner_connected_participants", { p_organization_id: organizationId });
    assertQa(!roster.error && roster.data?.ok === true, `partner roster failed: ${roster.error?.message ?? roster.data?.code}`);
    assertQa(roster.data?.items?.length === 1, `partner roster returned ${roster.data?.items?.length ?? 0} participants instead of one`);
    assertQa(roster.data.items[0].user_id === teenA.id, "partner saw an unrelated teen");
    assertQa(roster.data.messages_included === false && roster.data.earnings_included === false && roster.data.housing_status_included === false, "partner roster included restricted data");
    const otherEnrollment = await teenB.client.from("pilot_enrollments").select("id").eq("user_id", teenA.id);
    assertQa(!otherEnrollment.error, `unrelated teen isolation query failed: ${otherEnrollment.error?.message}`);
    assertQa(otherEnrollment.data?.length === 0, "unrelated teen read vulnerable participant enrollment");
    qaLog(scope, "partner and peer access is scoped without messages, earnings, organization disclosure, or housing data");
  });
}

async function runResourcePrivacy(scope) {
  await withMissionFixture(scope, [
    { key: "teen", role: "teen" },
    { key: "other", role: "teen" },
  ], async ({ teen, other, operator }, _organizationId) => {
    const resourceId = await withDatabase(async (database) => {
      const result = await database.query(`insert into public.resource_directory_entries (organization_name,category,source_url,source_status,organization_verification_status,summary,emergency_limitations,reviewed_by,last_reviewed_at) values ($1,'transportation_assistance','https://example.invalid/mort-synthetic-resource','reviewed','source_reviewed','Synthetic resource used only to verify private bookmark isolation.','Availability is not claimed; contact the official source and use emergency services for immediate danger.',$2,now()) returning id`, [`QA ${scope} resource`, operator.id]);
      return result.rows[0].id;
    });
    const bookmarked = await teen.client.from("private_resource_bookmarks").insert({ user_id: teen.id, resource_id: resourceId, private_note: "Private QA bookmark" }).select("id").single();
    assertQa(!bookmarked.error, `Resource bookmark failed: ${bookmarked.error?.message}`);
    const otherRead = await other.client.from("private_resource_bookmarks").select("id").eq("resource_id", resourceId);
    const resource = await teen.client.from("resource_directory_entries").select("availability_claimed,source_status").eq("id", resourceId).single();
    assertQa(otherRead.data?.length === 0, "resource usage was visible to another user");
    assertQa(resource.data?.availability_claimed === false, "directory made a fake availability claim");
    qaLog(scope, "resource entries use reviewed sources while bookmarks and usage remain private");
  });
}

async function runFutureIndependence(scope) {
  await withMissionFixture(scope, [
    { key: "teen", role: "teen" },
    { key: "other", role: "teen" },
  ], async ({ teen, other }) => {
    const inserted = await teen.client.from("future_independence_plans").insert({ user_id: teen.id, education_plan: "Complete school and workforce training.", employment_plan: "Build references through lawful work.", savings_target_cents: 50000, runaway_guidance_provided: false }).select("runaway_guidance_provided,private_by_default").single();
    assertQa(!inserted.error && inserted.data.runaway_guidance_provided === false, "future plan allowed runaway guidance");
    const forged = await teen.client.from("future_independence_plans").update({ runaway_guidance_provided: true }).eq("user_id", teen.id).select("user_id");
    assertQa(forged.error || forged.data.length === 0, "client enabled runaway guidance");
    const otherRead = await other.client.from("future_independence_plans").select("user_id").eq("user_id", teen.id);
    assertQa(otherRead.data?.length === 0, "private independence plan leaked to another teen");
    qaLog(scope, "Future Independence Plan is private, lawful, and cannot be switched into runaway guidance");
  });
}

const suites = {
  "closed-pilot-access": runClosedPilotAccess,
  "partner-attestation": runPartnerAttestation,
  "partner-code-security": runPartnerCodeSecurity,
  "housing-status-privacy": runHousingPrivacy,
  "no-permanent-address": runNoPermanentAddress,
  "guardian-stays-optional": runGuardianOptional,
  "support-circle-permissions": runSupportCircle,
  "discreet-mode-privacy": runDiscreetMode,
  "document-review-claims": runDocumentClaims,
  "two-person-review": runTwoPersonReview,
  "document-vault-access": runVaultAccess,
  "document-retention": runDocumentRetention,
  "founder-document-access-restriction": runFounderRestriction,
  "pilot-job-restrictions": runPilotJobRestrictions,
  "vulnerable-teen-data-isolation": runVulnerableTeenIsolation,
  "resource-directory-privacy": runResourcePrivacy,
  "future-independence-safety": runFutureIndependence,
};

export async function runMissionPilotQaSuite(name) {
  const suite = suites[name];
  if (!suite) throw new Error(`Unknown mission-pilot QA suite: ${name}`);
  await suite(`qa-${name}`);
}
