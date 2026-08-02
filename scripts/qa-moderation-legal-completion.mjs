import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";

import {
  assertQa,
  qaLog,
  saveJob,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-moderation-legal-completion";

await withDatabase(async (database) => {
  const controls = await database.query(`
    select
      owner_approved,
      attorney_package_approved,
      child_safety_contact_approved,
      privacy_contact_approved,
      support_contact_approved,
      play_declarations_approved,
      moderation_staffing_approved,
      incident_on_call_approved
    from private.public_release_legal_controls
    where singleton
  `);
  const control = controls.rows[0];
  for (const field of Object.keys(control ?? {})) {
    assertQa(control[field] === false, `${field} was unexpectedly approved`);
  }

  const drafts = await database.query(`
    select document.document_key, document.publication_status,
           version.publication_status version_status,
           version.effective_at, version.attorney_reviewed_at,
           version.approved_by_counsel_reference
    from public.legal_documents document
    join public.legal_document_versions version on version.document_id = document.id
    where document.document_key in (
      'mort_community_guidelines', 'mort_safety_rules', 'mort_guardian_terms'
    )
  `);
  assertQa(drafts.rowCount === 3, "separate legal drafts are missing remotely");
  for (const draft of drafts.rows) {
    assertQa(
      draft.publication_status === "draft_attorney_review" &&
        draft.version_status === "draft_attorney_review" &&
        draft.effective_at === null &&
        draft.attorney_reviewed_at === null &&
        draft.approved_by_counsel_reference === null,
      `${draft.document_key} is not fail-closed`,
    );
  }

  const jobPolicies = await database.query(`
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'jobs'
      and cmd in ('INSERT', 'UPDATE', 'DELETE')
  `);
  assertQa(
    jobPolicies.rowCount === 0,
    "authenticated clients retain a direct job mutation policy",
  );
  const auditInsertPolicy = await database.query(`
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'admin_action_logs'
      and cmd = 'INSERT'
  `);
  assertQa(
    auditInsertPolicy.rowCount === 0,
    "clients can still author moderation audit rows",
  );

  await database.query("begin");
  try {
    await database.query("savepoint before_public_open");
    let blocked = false;
    try {
      await database.query(`
        update private.runtime_feature_controls
        set public_marketplace_closed = false,
            update_reason = 'Synthetic QA must be rejected by the hard activation gate.'
        where singleton
      `);
    } catch (error) {
      blocked = String(error?.message).includes(
        "public_marketplace_activation_gate_incomplete",
      );
      await database.query("rollback to savepoint before_public_open");
    }
    assertQa(blocked, "direct database marketplace activation did not fail closed");
  } finally {
    await database.query("rollback");
  }
});
qaLog(scope, "legal controls, inactive drafts, direct-write removal, and hard activation trigger passed");

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen", identityVerified: true, isTest: true },
    { key: "adult", role: "adult", identityVerified: true, isTest: true },
    { key: "operator", role: "admin", identityVerified: false, isTest: true },
    { key: "reviewer", role: "admin", identityVerified: false, isTest: true },
  ],
  async ({ teen, adult, operator, reviewer }) => {
    try {
      await withDatabase(async (database) => {
        await database.query(
          `insert into public.admin_role_assignments(
             user_id, role, granted_by, grant_reason, expires_at
           ) values
             ($1, 'super_admin', $1, 'Synthetic QA original enforcement reviewer.', now() + interval '1 day'),
             ($2, 'incident_manager', $1, 'Synthetic QA independent appeal reviewer.', now() + interval '1 day')`,
          [operator.id, reviewer.id],
        );
      });

      const legacyGrant = await operator.client.rpc("admin_set_safety_role", {
        p_user_id: reviewer.id,
        p_role: "moderator",
        p_enabled: true,
        p_reason: "Synthetic QA verifies unbounded role grants are rejected.",
      });
      assertQa(
        !legacyGrant.error && legacyGrant.data?.code === "expiring_assignment_required",
        "legacy unbounded safety-role grant did not fail closed",
      );
      const expiringGrant = await operator.client.rpc("admin_set_safety_role_v2", {
        p_user_id: reviewer.id,
        p_role: "moderator",
        p_reason: "Synthetic QA grants a bounded content moderation role.",
        p_expires_at: new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString(),
      });
      assertQa(
        !expiringGrant.error && expiringGrant.data?.ok === true && expiringGrant.data?.expires_at,
        "bounded safety-role grant failed",
      );

      const draft = await saveJob(adult.client, {}, false);
      const jobId = draft.result?.job?.id;
      assertQa(draft.result?.ok === true && jobId, "synthetic job creation failed");

      const ordinaryModeration = await teen.client.rpc("admin_moderate_job", {
        p_job_id: jobId,
        p_action: "reject",
        p_reason_code: "policy_violation",
        p_note: "An ordinary user must never moderate a marketplace job.",
      });
      assertQa(
        !ordinaryModeration.error &&
          ordinaryModeration.data?.code === "content_moderator_required",
        "ordinary user reached job moderation",
      );
      const invalidReason = await reviewer.client.rpc("admin_moderate_job", {
        p_job_id: jobId,
        p_action: "reject",
        p_reason_code: "because_i_said_so",
        p_note: "Synthetic QA verifies the reason-code allowlist.",
      });
      assertQa(
        !invalidReason.error &&
          invalidReason.data?.code === "job_moderation_reason_code_invalid",
        "arbitrary job moderation reason was accepted",
      );

      const forgedDirectJobUpdate = await reviewer.client
        .from("jobs")
        .update({ title: "FORGED DIRECT ADMIN UPDATE" })
        .eq("id", jobId)
        .select("id");
      assertQa(
        forgedDirectJobUpdate.error || forgedDirectJobUpdate.data?.length === 0,
        "admin client directly updated a job row",
      );
      const jobDecision = await reviewer.client.rpc("admin_moderate_job", {
        p_job_id: jobId,
        p_action: "reject",
        p_reason_code: "policy_violation",
        p_note: "Synthetic QA records a coded and audited job rejection.",
      });
      assertQa(
        !jobDecision.error &&
          jobDecision.data?.ok === true &&
          jobDecision.data?.status === "rejected",
        `authorized coded job moderation failed: ${jobDecision.error?.message ?? jobDecision.data?.code ?? "unexpected response"}`,
      );

      let reviewId;
      await withDatabase(async (database) => {
        const result = await database.query(
          `insert into public.reviews(
             job_id, reviewer_id, subject_id, rating, body, moderation_status
           ) values ($1, $2, $3, 5, 'Synthetic QA review awaiting moderation.', 'pending_review')
           returning id`,
          [jobId, teen.id, adult.id],
        );
        reviewId = result.rows[0]?.id;
      });
      const forgedDirectReviewUpdate = await reviewer.client
        .from("reviews")
        .update({ moderation_status: "approved" })
        .eq("id", reviewId)
        .select("id");
      assertQa(
        forgedDirectReviewUpdate.error || forgedDirectReviewUpdate.data?.length === 0,
        "admin client directly updated a review row",
      );
      const reviewDecision = await reviewer.client.rpc("admin_moderate_review", {
        p_review_id: reviewId,
        p_action: "approve",
        p_reason_code: "content_review_completed",
        p_note: "Synthetic QA review contains no prohibited or private content.",
      });
      assertQa(
        !reviewDecision.error &&
          reviewDecision.data?.ok === true &&
          reviewDecision.data?.status === "approved",
        "authorized review moderation failed",
      );
      qaLog(scope, "coded job/review moderation, reason allowlists, and direct-write denial passed");

      const report = await teen.client.rpc("submit_safety_report_v2", {
        p_target_user_id: adult.id,
        p_target_job_id: jobId,
        p_target_message_id: null,
        p_target_review_id: reviewId,
        p_application_id: null,
        p_category: "other_urgent_concern",
        p_severity: "moderate",
        p_immediate_danger: false,
        p_details: "Synthetic QA report for restricted access logging verification.",
        p_occurred_at: null,
        p_location_type: null,
        p_desired_outcome: "Verify access logging without exposing raw evidence.",
        p_confidential_safety_feedback: false,
        p_client_request_id: randomUUID(),
      });
      assertQa(!report.error && report.data?.ok === true, "synthetic safety report failed");
      const reportId = report.data.report_id;
      const deniedDetail = await teen.client.rpc("admin_get_moderation_record", {
        p_record_type: "report",
        p_record_id: reportId,
      });
      assertQa(
        !deniedDetail.error && deniedDetail.data?.code === "incident_manager_required",
        "ordinary user opened a restricted moderation detail",
      );
      const detail = await operator.client.rpc("admin_get_moderation_record", {
        p_record_type: "report",
        p_record_id: reportId,
      });
      assertQa(!detail.error && detail.data?.ok === true, "authorized detail load failed");
      await withDatabase(async (database) => {
        const access = await database.query(
          `select count(*)::int count
           from public.private_data_access_events
           where actor_id = $1 and resource_id = $2
             and resource_type = 'moderation_report' and action = 'read'`,
          [operator.id, reportId],
        );
        assertQa(access.rows[0]?.count === 1, "moderation detail access was not logged");
      });

      const ban = await operator.client.rpc("admin_set_account_status_v2", {
        p_user_id: adult.id,
        p_status: "banned",
        p_reason_code: "policy_violation",
        p_reason: "Synthetic QA ban used only to verify independent appeal review.",
        p_expires_at: null,
      });
      assertQa(!ban.error && ban.data?.ok === true, "synthetic account ban failed");
      const appeal = await adult.client.rpc("submit_account_ban_appeal", {
        p_reason: "Synthetic QA requests an independent review of this temporary test ban.",
      });
      assertQa(
        !appeal.error && appeal.data?.ok === true && appeal.data?.access_restored === false,
        "banned user could not submit a fail-closed appeal",
      );
      const appealId = appeal.data.appeal_id;
      const crossUserRead = await teen.client
        .from("account_ban_appeals")
        .select("id")
        .eq("id", appealId);
      assertQa(
        !crossUserRead.error && crossUserRead.data?.length === 0,
        "another ordinary user read a ban appeal",
      );
      const selfClaim = await operator.client.rpc("admin_claim_account_ban_appeal", {
        p_appeal_id: appealId,
        p_reason: "The original actor must not claim this independent review.",
      });
      assertQa(
        !selfClaim.error && selfClaim.data?.code === "independent_reviewer_required",
        "original banning actor claimed the appeal",
      );
      const directRestore = await operator.client.rpc("admin_set_account_status", {
        p_user_id: adult.id,
        p_status: "active",
        p_reason: "The ordinary status endpoint must not reverse a ban.",
      });
      assertQa(
        !directRestore.error &&
          directRestore.data?.code === "ban_reversal_independent_review_required",
        "ordinary account status endpoint reversed a ban",
      );
      const claim = await reviewer.client.rpc("admin_claim_account_ban_appeal", {
        p_appeal_id: appealId,
        p_reason: "Synthetic independent reviewer accepts this bounded assignment.",
      });
      assertQa(
        !claim.error && claim.data?.ok === true && claim.data?.assignment_expires_at,
        "independent reviewer could not claim the appeal",
      );
      const reversal = await reviewer.client.rpc("admin_review_account_ban_appeal", {
        p_appeal_id: appealId,
        p_decision: "approve",
        p_reason: "Synthetic QA restores the account after independent review completed.",
      });
      assertQa(
        !reversal.error &&
          reversal.data?.ok === true &&
          reversal.data?.account_restored === true,
        "assigned independent ban reversal failed",
      );
      qaLog(scope, "access logging, ban appeal isolation, assignment expiry, and independent reversal passed");

      const readiness = await teen.client.rpc("get_public_release_readiness");
      assertQa(
        !readiness.error &&
          readiness.data?.activation_ready === false &&
          readiness.data?.legal_ready === false &&
          readiness.data?.owner_approved === false &&
          readiness.data?.moderation_staffing_approved === false &&
          Array.isArray(readiness.data?.missing_published_document_keys) &&
          readiness.data.missing_published_document_keys.includes("mort_safety_rules"),
        "safe public release readiness did not report the external gates",
      );
    } finally {
      await withDatabase(async (database) => {
        await database.query(
          "delete from public.account_ban_appeals where user_id = $1",
          [adult.id],
        );
      });
    }
  },
);

const repository = await readFile(
  new URL("../flutter_mort/lib/data/repositories/admin_repository.dart", import.meta.url),
  "utf8",
);
const queueScreen = await readFile(
  new URL("../flutter_mort/lib/features/mort_screens.dart", import.meta.url),
  "utf8",
);
assertQa(!repository.includes("updateById("), "generic client moderation write helper remains");
assertQa(
  repository.includes("admin_moderate_job") &&
    repository.includes("admin_moderate_review") &&
    queueScreen.includes("AdminBanAppealsScreen"),
  "Flutter moderation and ban-appeal wiring is incomplete",
);

console.log(`[${scope}] Moderation and legal completion QA passed.`);
