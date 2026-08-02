import { randomUUID } from "node:crypto";

import {
  assertQa,
  manageJob,
  qaLog,
  saveJob,
  updateApplicationStatus,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-marketplace-state-machine";

function feed(client, overrides = {}) {
  return client.rpc("list_open_jobs_page", {
    p_keyword: "",
    p_category: null,
    p_minimum_pay_cents: null,
    p_payment_type: null,
    p_schedule_type: null,
    p_verification_requirement: null,
    p_requires_guardian_approval: null,
    p_work_environment: null,
    p_city: "Indianapolis",
    p_state: "IN",
    p_transportation_methods: ["walking", "bicycle"],
    p_sort: "newest",
    p_cursor_value: null,
    p_cursor_id: null,
    p_limit: 1,
    ...overrides,
  });
}

await withQaUsers(
  scope,
  [
    { key: "adult", role: "adult" },
    { key: "otherAdult", role: "adult" },
    { key: "teen", role: "teen" },
    { key: "normalTeen", role: "teen", isTest: false },
  ],
  async ({ adult, otherAdult, teen, normalTeen }) => {
    const preferences = await teen.client.rpc(
      "save_my_transportation_preferences",
      {
        p_methods: ["walking", "bicycle"],
        p_max_distance_miles: 5,
        p_max_travel_minutes: 30,
        p_walking_distance_only: false,
        p_guardian_transportation_possible: false,
        p_client_request_id: randomUUID(),
      },
    );
    assertQa(
      !preferences.error && preferences.data?.ok === true,
      `transportation setup failed: ${preferences.error?.message ?? preferences.data?.code}`,
    );

    const alpha = await saveJob(adult.client, {
      title: "QA Pagination Alpha Job",
      summary: "A safe first job for stable marketplace paging checks.",
      acceptable_transportation_methods: ["walking", "bicycle"],
      transportation_considerations: "Use the public entrance near the library.",
      adult_job_amount_cents: 2100,
    });
    const beta = await saveJob(adult.client, {
      title: "QA Pagination Beta Job",
      summary: "A safe second job for stable marketplace paging checks.",
      acceptable_transportation_methods: ["walking"],
      transportation_considerations: "The general downtown area has sidewalks.",
      adult_job_amount_cents: 2300,
    });
    assertQa(alpha.result?.ok === true && beta.result?.ok === true, "paging fixtures did not publish");

    const first = await feed(teen.client);
    assertQa(!first.error && first.data?.ok === true, `first feed page failed: ${first.error?.message}`);
    assertQa(first.data.items.length === 1 && first.data.has_more === true, "first feed page shape is invalid");
    assertQa(first.data.next_cursor?.value && first.data.next_cursor?.id, "first feed page has no cursor");
    assertQa(first.data.distance_calculated === false, "feed claimed to calculate distance");
    const firstItem = first.data.items[0];
    for (const privateField of ["client_request_id", "zip_code", "special_instructions", "safety_scan_reasons"]) {
      assertQa(!(privateField in firstItem), `feed exposed ${privateField}`);
    }
    assertQa(firstItem.distance_status === "unavailable", "job item claimed a distance result");
    assertQa(firstItem.transportation_match === true, "saved travel method match was not explained");
    assertQa(
      firstItem.match_explanation.includes("Distance is not calculated"),
      "feed item omitted the distance fallback explanation",
    );

    const second = await feed(teen.client, {
      p_cursor_value: first.data.next_cursor.value,
      p_cursor_id: first.data.next_cursor.id,
    });
    assertQa(!second.error && second.data?.ok === true, `second feed page failed: ${second.error?.message}`);
    assertQa(second.data.items.length === 1, "second feed page did not return one row");
    assertQa(second.data.items[0].id !== firstItem.id, "keyset page repeated the previous row");
    qaLog(scope, "server keyset pagination is stable and exposes only general-area matching data");

    const filtered = await feed(teen.client, {
      p_keyword: "pagination alpha",
      p_limit: 20,
    });
    assertQa(
      !filtered.error && filtered.data?.items.length === 1 && filtered.data.items[0].id === alpha.result.job.id,
      "server keyword filter returned the wrong jobs",
    );
    const invalidCursor = await feed(teen.client, {
      p_cursor_value: "not-a-time",
      p_cursor_id: randomUUID(),
    });
    assertQa(
      !invalidCursor.error && invalidCursor.data?.code === "invalid_job_feed_cursor",
      "malformed feed cursor was accepted",
    );
    const productionIsolation = await feed(normalTeen.client, { p_limit: 20 });
    assertQa(
      !productionIsolation.error && productionIsolation.data?.items.length === 0,
      "production account saw isolated QA marketplace jobs",
    );
    qaLog(scope, "feed filters, cursor rejection, and QA/production isolation are server enforced");

    const legacyManage = await adult.client.rpc("manage_job", {
      p_job_id: alpha.result.job.id,
      p_action: "pause",
    });
    assertQa(legacyManage.error, "authenticated client retained the old reasonless management RPC");

    const unrelated = await manageJob(otherAdult.client, {
      jobId: alpha.result.job.id,
      action: "pause",
    });
    assertQa(
      !unrelated.error && unrelated.data?.code === "unknown_permission_failure",
      "unrelated adult managed another poster's job",
    );

    const missingReason = await manageJob(adult.client, {
      jobId: alpha.result.job.id,
      action: "cancel",
      reason: "short",
    });
    assertQa(
      !missingReason.error && missingReason.data?.code === "job_cancellation_reason_required",
      "job cancellation accepted a missing or short reason",
    );

    const pauseRequest = randomUUID();
    const paused = await manageJob(adult.client, {
      jobId: alpha.result.job.id,
      action: "pause",
      clientRequestId: pauseRequest,
      expectedUpdatedAt: alpha.result.job.updated_at,
    });
    assertQa(!paused.error && paused.data?.job?.status === "paused", "valid pause failed");
    const replayedPause = await manageJob(adult.client, {
      jobId: alpha.result.job.id,
      action: "pause",
      clientRequestId: pauseRequest,
      expectedUpdatedAt: alpha.result.job.updated_at,
    });
    assertQa(
      !replayedPause.error && replayedPause.data?.ok === true && replayedPause.data.replayed === true,
      "repeated management request was not idempotent",
    );

    const staleResume = await manageJob(adult.client, {
      jobId: alpha.result.job.id,
      action: "resume",
      expectedUpdatedAt: alpha.result.job.updated_at,
    });
    assertQa(
      !staleResume.error && staleResume.data?.code === "stale_job_state",
      "stale job mutation was accepted",
    );
    const resumed = await manageJob(adult.client, {
      jobId: alpha.result.job.id,
      action: "resume",
      expectedUpdatedAt: paused.data.job.updated_at,
    });
    assertQa(!resumed.error && resumed.data?.job?.status === "open", "valid resume failed");
    const closed = await manageJob(adult.client, {
      jobId: alpha.result.job.id,
      action: "close_applications",
      expectedUpdatedAt: resumed.data.job.updated_at,
    });
    assertQa(closed.data?.job?.applications_open === false, "close applications failed");
    const reopened = await manageJob(adult.client, {
      jobId: alpha.result.job.id,
      action: "reopen_applications",
      expectedUpdatedAt: closed.data.job.updated_at,
    });
    assertQa(reopened.data?.job?.applications_open === true, "reopen applications failed");
    qaLog(scope, "ownership, cancellation reason, idempotency, and optimistic concurrency are enforced");

    const duplicated = await manageJob(adult.client, {
      jobId: alpha.result.job.id,
      action: "duplicate",
      expectedUpdatedAt: reopened.data.job.updated_at,
    });
    assertQa(!duplicated.error && duplicated.data?.job?.status === "draft", "job duplicate failed");
    assertQa(
      duplicated.data.job.adult_job_amount_cents === alpha.result.job.adult_job_amount_cents,
      "duplicate dropped the poster's offered amount",
    );
    assertQa(
      JSON.stringify(duplicated.data.job.acceptable_transportation_methods) ===
        JSON.stringify(alpha.result.job.acceptable_transportation_methods),
      "duplicate dropped transportation methods",
    );
    const deleted = await manageJob(adult.client, {
      jobId: duplicated.data.job.id,
      action: "delete_draft",
      expectedUpdatedAt: duplicated.data.job.updated_at,
    });
    assertQa(deleted.data?.deleted === true, "duplicated draft did not delete");
    qaLog(scope, "duplicate preserves compensation and travel fields while resetting to a draft");

    const assignedJob = await saveJob(adult.client, {
      title: "QA Assigned Cancellation Job",
      summary: "A safe job for assigned-application cancellation consistency.",
    });
    const application = await teen.client.rpc("submit_job_application", {
      p_job_id: assignedJob.result.job.id,
      p_note: "I am available for this staffed public job.",
      p_availability_confirmed: true,
      p_portfolio_ids: [],
    });
    assertQa(!application.error && application.data?.ok === true, "assigned fixture application failed");
    const legacyApplicationTransition = await adult.client.rpc(
      "update_application_status_v2",
      {
        p_application_id: application.data.application.id,
        p_action: "accepted",
      },
    );
    assertQa(
      legacyApplicationTransition.error,
      "authenticated client retained the non-idempotent application RPC",
    );
    const acceptRequest = randomUUID();
    const accepted = await updateApplicationStatus(adult.client, {
      applicationId: application.data.application.id,
      action: "accepted",
      clientRequestId: acceptRequest,
      expectedUpdatedAt: application.data.application.updated_at,
    });
    assertQa(!accepted.error && accepted.data?.ok === true, "assigned fixture acceptance failed");
    const replayedAccept = await updateApplicationStatus(adult.client, {
      applicationId: application.data.application.id,
      action: "accepted",
      clientRequestId: acceptRequest,
      expectedUpdatedAt: application.data.application.updated_at,
    });
    assertQa(
      !replayedAccept.error && replayedAccept.data?.ok === true && replayedAccept.data.replayed === true,
      "application transition retry was not idempotent",
    );
    const staleApplication = await updateApplicationStatus(adult.client, {
      applicationId: application.data.application.id,
      action: "viewed",
      expectedUpdatedAt: application.data.application.updated_at,
    });
    assertQa(
      !staleApplication.error && staleApplication.data?.code === "stale_application_state",
      "stale application mutation was accepted",
    );
    qaLog(scope, "application transitions reject stale writes and replay the same request safely");
    const canceled = await manageJob(adult.client, {
      jobId: assignedJob.result.job.id,
      action: "cancel",
      reason: "The schedule changed and the poster can no longer host this job.",
      expectedUpdatedAt: accepted.data.job.updated_at,
    });
    assertQa(canceled.data?.job?.status === "canceled", "assigned job cancellation failed");
    const canceledApplication = await teen.client
      .from("applications")
      .select("status")
      .eq("id", application.data.application.id)
      .single();
    assertQa(
      !canceledApplication.error && canceledApplication.data.status === "canceled",
      "assigned application was left accepted after job cancellation",
    );
    const teenAudit = await teen.client
      .from("job_management_requests")
      .select("action,reason,succeeded")
      .eq("job_id", assignedJob.result.job.id)
      .eq("action", "cancel")
      .single();
    assertQa(
      !teenAudit.error && teenAudit.data?.succeeded === true && teenAudit.data.reason?.length >= 10,
      "teen participant could not read the cancellation audit reason",
    );
    qaLog(scope, "assigned cancellation updates the application and exposes an auditable reason to the teen");

    const exactDraft = await saveJob(
      adult.client,
      {
        title: "QA Exact Address Rejection",
        summary: "A draft used to verify exact-address publication blocking.",
        location_text: "123 Main Street",
      },
      false,
    );
    const exactPublish = await adult.client.rpc("save_job_draft_or_publish", {
      p_job_id: exactDraft.result.job.id,
      p_client_request_id: exactDraft.clientRequestId,
      p_payload: exactDraft.payload,
      p_publish: true,
    });
    assertQa(
      exactPublish.error?.message?.includes("exact_address_not_allowed"),
      "server accepted a probable exact street address for publication",
    );
    qaLog(scope, "server rejects probable exact street addresses while drafts remain resumable");
  },
);
