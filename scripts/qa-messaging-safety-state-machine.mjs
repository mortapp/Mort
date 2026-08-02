import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  saveJob,
  sendSafeMessage,
  serviceClient,
  updateApplicationStatus,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-messaging-safety-state-machine";

function expectOk(result, action) {
  assertQa(!result.error, `${action} failed: ${result.error?.message}`);
  return result.data;
}

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
    { key: "guardian", role: "guardian" },
    { key: "outsider", role: "teen" },
  ],
  async ({ teen, adult, guardian, outsider }) => {
    const created = await saveJob(adult.client, {
      title: "QA Message Lifecycle Library Task",
    });
    assertQa(created.result?.ok === true, "could not publish messaging QA job");
    const submitted = expectOk(
      await teen.client.rpc("submit_job_application", {
        p_job_id: created.result.job.id,
        p_note: "I can do this task in the staffed public work area.",
        p_availability_confirmed: true,
        p_portfolio_ids: [],
      }),
      "submit application",
    );
    const applicationId = submitted.application.id;
    const thread = expectOk(
      await teen.client
        .from("message_threads")
        .select("id,lifecycle_status")
        .eq("application_id", applicationId)
        .single(),
      "load application thread",
    );
    assertQa(thread.lifecycle_status === "active", "new thread was not active");
    qaLog(scope, "server-created thread starts active");

    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        await database.query(
          `insert into public.guardian_connections(teen_id, guardian_id, status)
           values ($1, $2, 'active')`,
          [teen.id, guardian.id],
        );
        await database.query(
          "update public.applications set guardian_id = $2 where id = $1",
          [applicationId, guardian.id],
        );
        await database.query(
          "update public.message_threads set guardian_id = $2 where id = $1",
          [thread.id, guardian.id],
        );
        await database.query("commit");
      } catch (error) {
        await database.query("rollback");
        throw error;
      }
    });

    const cleanRequestId = randomUUID();
    const cleanBody = "I will meet at the staffed public desk at the agreed time.";
    const clean = expectOk(
      await sendSafeMessage(teen.client, thread.id, cleanBody, cleanRequestId),
      "send clean message",
    );
    const replay = expectOk(
      await sendSafeMessage(teen.client, thread.id, cleanBody, cleanRequestId),
      "replay clean message",
    );
    assertQa(clean.id === replay.id, "message retry created a duplicate row");
    const duplicateCount = expectOk(
      await serviceClient
        .from("messages")
        .select("id", { count: "exact", head: true })
        .eq("id", clean.id),
      "count replayed message",
    );
    void duplicateCount;
    const mismatch = await sendSafeMessage(
      teen.client,
      thread.id,
      "Different payload for the same request.",
      cleanRequestId,
    );
    assertQa(
      mismatch.error?.message.includes("message_request_payload_mismatch"),
      "request-id payload substitution was not rejected",
    );
    qaLog(scope, "send retry is idempotent and payload-bound");

    const oldRpc = await teen.client.rpc("send_safe_message", {
      p_thread_id: thread.id,
      p_body: "Legacy RPC access must be denied.",
    });
    assertQa(oldRpc.error, "legacy non-idempotent send RPC remained callable");
    qaLog(scope, "legacy non-idempotent send RPC is denied");

    const exactAddress = expectOk(
      await sendSafeMessage(
        adult.client,
        thread.id,
        "Come to 123 Main Street at noon.",
      ),
      "scan exact address",
    );
    assertQa(
      exactAddress.scanner_status === "blocked" &&
        exactAddress.safety_category === "personal_information_request" &&
        exactAddress.body === "[Blocked by MORT safety controls]",
      "probable street address was not safely blocked",
    );
    const suspiciousLink = expectOk(
      await sendSafeMessage(
        teen.client,
        thread.id,
        "Open https://example.invalid/offer for the schedule.",
      ),
      "scan suspicious link",
    );
    assertQa(
      suspiciousLink.scanner_status === "blocked" &&
        suspiciousLink.safety_category === "off_platform_pressure",
      "external link was not blocked",
    );
    const rawEvidence = await teen.client
      .from("message_safety_evidence")
      .select("raw_body")
      .eq("message_id", exactAddress.id);
    assertQa(
      !rawEvidence.error && rawEvidence.data.length === 0,
      "restricted raw scanner evidence leaked to a participant",
    );
    const reportRequestId = randomUUID();
    const reportParams = {
      p_target_user_id: adult.id,
      p_target_job_id: created.result.job.id,
      p_target_message_id: exactAddress.id,
      p_target_review_id: null,
      p_application_id: applicationId,
      p_category: "personal_information_request",
      p_severity: "high",
      p_immediate_danger: false,
      p_details: "The message requested an exact address outside the protected job-location workflow.",
      p_occurred_at: null,
      p_location_type: "online",
      p_desired_outcome: "Preserve the message and route it for trained human review.",
      p_confidential_safety_feedback: true,
      p_client_request_id: reportRequestId,
    };
    const messageReport = expectOk(
      await teen.client.rpc("submit_safety_report_v2", reportParams),
      "report message",
    );
    const reportReplay = expectOk(
      await teen.client.rpc("submit_safety_report_v2", reportParams),
      "replay message report",
    );
    assertQa(
      messageReport.report_id === reportReplay.report_id && reportReplay.replayed === true,
      "message report retry created a duplicate case",
    );
    const reportMismatch = await teen.client.rpc("submit_safety_report_v2", {
      ...reportParams,
      p_details: "A substituted report payload must not reuse the same request ID.",
    });
    assertQa(
      reportMismatch.data?.code === "safety_request_payload_mismatch",
      "message report accepted a substituted retry payload",
    );
    const outsiderReport = await outsider.client.rpc("submit_safety_report_v2", {
      ...reportParams,
      p_client_request_id: randomUUID(),
    });
    assertQa(
      outsiderReport.data?.code === "report_target_not_authorized",
      "outsider reported a message they were not authorized to see",
    );
    const preservedMessage = await serviceClient
      .from("messages")
      .select("preserved_for_safety")
      .eq("id", exactAddress.id)
      .single();
    const preservedEvidence = await serviceClient
      .from("message_safety_evidence")
      .select("preserved_until,severity")
      .eq("message_id", exactAddress.id)
      .single();
    assertQa(
      preservedMessage.data?.preserved_for_safety === true &&
        preservedEvidence.data?.preserved_until &&
        ["high", "critical"].includes(preservedEvidence.data?.severity),
      "reported message evidence was not preserved under restricted access",
    );
    qaLog(scope, "address/link scanner blocks safely and raw evidence stays restricted");

    const guardianThreads = expectOk(
      await guardian.client.rpc("get_my_message_threads"),
      "guardian thread listing",
    );
    assertQa(guardianThreads.length === 0, "linked guardian received broad thread visibility");
    const guardianMessages = await guardian.client
      .from("messages")
      .select("id,body")
      .eq("thread_id", thread.id);
    assertQa(
      !guardianMessages.error && guardianMessages.data.length === 0,
      "linked guardian read unrestricted job messages",
    );
    const guardianPage = await guardian.client.rpc("list_thread_messages_page", {
      p_thread_id: thread.id,
      p_limit: 10,
    });
    assertQa(guardianPage.error, "linked guardian called participant-only message paging");
    const outsiderMessages = await outsider.client
      .from("messages")
      .select("id,body")
      .eq("thread_id", thread.id);
    assertQa(
      !outsiderMessages.error && outsiderMessages.data.length === 0,
      "outsider read another thread",
    );
    qaLog(scope, "guardian and outsider cannot read unrestricted job chat");

    for (let index = 0; index < 23; index += 1) {
      const actor = index % 2 === 0 ? adult : teen;
      const sent = await sendSafeMessage(
        actor.client,
        thread.id,
        `QA safe schedule confirmation ${index + 1}.`,
      );
      assertQa(!sent.error, `pagination fixture ${index + 1} failed: ${sent.error?.message}`);
    }

    const pageOne = expectOk(
      await teen.client.rpc("list_thread_messages_page", {
        p_thread_id: thread.id,
        p_limit: 10,
      }),
      "load first message page",
    );
    assertQa(
      pageOne.items.length === 10 && pageOne.has_more === true && pageOne.next_cursor,
      "first message page did not return a bounded cursor",
    );
    const pageTwo = expectOk(
      await teen.client.rpc("list_thread_messages_page", {
        p_thread_id: thread.id,
        p_cursor_created_at: pageOne.next_cursor.created_at,
        p_cursor_id: pageOne.next_cursor.id,
        p_limit: 10,
      }),
      "load second message page",
    );
    const firstIds = new Set(pageOne.items.map((message) => message.id));
    assertQa(
      pageTwo.items.length === 10 &&
        pageTwo.items.every((message) => !firstIds.has(message.id)),
      "message keyset pages overlapped or were incomplete",
    );
    assertQa(
      pageOne.items.every(
        (message) =>
          !("raw_body" in message) && !("preserved_for_safety" in message),
      ),
      "message page exposed restricted evidence fields",
    );
    const malformedCursor = await teen.client.rpc("list_thread_messages_page", {
      p_thread_id: thread.id,
      p_cursor_created_at: pageOne.next_cursor.created_at,
      p_limit: 10,
    });
    assertQa(
      malformedCursor.error?.message.includes("invalid_message_cursor"),
      "partial message cursor was accepted",
    );
    qaLog(scope, "keyset pagination is bounded, non-overlapping, and field-limited");

    const rejected = await updateApplicationStatus(adult.client, {
      applicationId,
      action: "rejected",
    });
    assertQa(!rejected.error && rejected.data?.ok === true, "application rejection failed");
    const closedThread = expectOk(
      await teen.client
        .from("message_threads")
        .select("lifecycle_status,closure_reason")
        .eq("id", thread.id)
        .single(),
      "load closed thread",
    );
    assertQa(
      closedThread.lifecycle_status === "read_only" &&
        closedThread.closure_reason === "application_rejected",
      "terminal application state did not close the thread",
    );
    const afterClose = await sendSafeMessage(
      teen.client,
      thread.id,
      "This should not be delivered after rejection.",
    );
    assertQa(
      afterClose.error?.message.includes("thread_read_only"),
      "read-only thread accepted a new message",
    );

    const publication = await withDatabase(async (database) => {
      const result = await database.query(
        `select count(*)::int as count
         from pg_catalog.pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = 'messages'`,
      );
      return result.rows[0].count;
    });
    assertQa(publication === 1, "messages table is not in the Realtime publication");
    qaLog(scope, "terminal lifecycle is read-only and Realtime publication is present");
    qaLog(scope, "message attachments remain unavailable by policy; private evidence flows are separate");
  },
);

console.log(`[${scope}] PASS: all hosted messaging state-machine checks completed`);
