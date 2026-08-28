import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "support-human-operations";

function expectOk(result, message) {
  assertQa(!result.error, `${message}: ${result.error?.message ?? "RPC error"}`);
  assertQa(result.data?.ok === true, `${message}: ${result.data?.code ?? "not ok"}`);
  return result.data;
}

async function assignSupportRole(userId, roleKey) {
  await withDatabase((database) =>
    database.query(
      `insert into private.support_staff_assignments (
         user_id, role_key, assigned_by, reason, expires_at
       ) values (
         $1, $2,
         $1, 'Isolated Phase 8 Support operations QA assignment.',
         now() + interval '1 hour'
       )`,
      [userId, roleKey],
    ),
  );
}

async function createTicket(client, subject) {
  return expectOk(
    await client.rpc("create_support_conversation", {
      p_category: "other",
      p_subject: subject,
      p_message: "This isolated QA support request needs a human operations review.",
      p_source: "human_support",
      p_related_job_id: null,
      p_related_application_id: null,
      p_related_contract_id: null,
      p_related_dispute_id: null,
      p_client_request_id: randomUUID(),
    }),
    "support ticket creation failed",
  ).ticket;
}

await withQaUsers(
  scope,
  [
    { key: "requester", role: "teen" },
    { key: "outsider", role: "adult" },
    { key: "unprivilegedAdmin", role: "admin", identityVerified: false },
    { key: "agent", role: "admin", identityVerified: false },
    { key: "manager", role: "admin", identityVerified: false },
    { key: "safety", role: "admin", identityVerified: false },
  ],
  async ({ requester, outsider, unprivilegedAdmin, agent, manager, safety }) => {
    await assignSupportRole(agent.id, "support_agent");
    await assignSupportRole(manager.id, "support_manager");
    await assignSupportRole(safety.id, "safety_reviewer");

    const serviceStatus = expectOk(
      await requester.client.rpc("support_get_service_status"),
      "support service status failed",
    );
    assertQa(
      serviceStatus.staffing_status === "external_gate_unstaffed" &&
        serviceStatus.targets_are_commitments === false &&
        serviceStatus.emergency_service === false,
      "support status fabricated staffing, a response commitment, or emergency service",
    );
    qaLog(scope, "service status is hosted, unstaffed, non-committed, and non-emergency");

    const ordinaryTicket = await createTicket(
      requester.client,
      "QA Support ownership and notes",
    );
    const unprivilegedQueue = await unprivilegedAdmin.client.rpc(
      "support_staff_list_queue",
      { p_status: null, p_unassigned_only: false, p_limit: 20 },
    );
    assertQa(
      !unprivilegedQueue.error && unprivilegedQueue.data?.length === 0,
      "an admin without an explicit Support role received the Support queue",
    );
    const unprivilegedThread = await unprivilegedAdmin.client.rpc(
      "support_staff_get_ticket_thread",
      { p_ticket_id: ordinaryTicket.id },
    );
    assertQa(
      unprivilegedThread.data?.code === "support_staff_role_required",
      "an admin without an explicit Support role received a case thread",
    );
    qaLog(scope, "ordinary admin access is denied without an explicit Support role");

    const agentQueue = await agent.client.rpc("support_staff_list_queue", {
      p_status: null,
      p_unassigned_only: true,
      p_limit: 20,
    });
    assertQa(
      !agentQueue.error && agentQueue.data?.some((item) => item.id === ordinaryTicket.id),
      "support agent could not see the unassigned ordinary case",
    );
    const claimRequestId = randomUUID();
    const claim = expectOk(
      await agent.client.rpc("support_staff_claim_ticket", {
        p_ticket_id: ordinaryTicket.id,
        p_client_request_id: claimRequestId,
      }),
      "support claim failed",
    );
    const claimReplay = expectOk(
      await agent.client.rpc("support_staff_claim_ticket", {
        p_ticket_id: ordinaryTicket.id,
        p_client_request_id: claimRequestId,
      }),
      "support claim replay failed",
    );
    assertQa(
      claim.ticket.assigned_support_user_id === agent.id && claimReplay.replayed === true,
      "support claim was not owned and replay-safe",
    );

    const noteRequestId = randomUUID();
    const note = expectOk(
      await agent.client.rpc("support_staff_add_internal_note", {
        p_ticket_id: ordinaryTicket.id,
        p_note_kind: "handoff_summary",
        p_body: "Requester needs a factual next-step explanation; no safety or payment decision is authorized.",
        p_client_request_id: noteRequestId,
      }),
      "internal note creation failed",
    );
    const noteReplay = expectOk(
      await agent.client.rpc("support_staff_add_internal_note", {
        p_ticket_id: ordinaryTicket.id,
        p_note_kind: "handoff_summary",
        p_body: "Requester needs a factual next-step explanation; no safety or payment decision is authorized.",
        p_client_request_id: noteRequestId,
      }),
      "internal note replay failed",
    );
    const changedNote = await agent.client.rpc("support_staff_add_internal_note", {
      p_ticket_id: ordinaryTicket.id,
      p_note_kind: "handoff_summary",
      p_body: "Changed content must not replace the original private note.",
      p_client_request_id: noteRequestId,
    });
    assertQa(
      note.replayed === false &&
        noteReplay.replayed === true &&
        changedNote.data?.code === "request_payload_mismatch",
      "internal note idempotency was not payload-bound",
    );
    const requesterNotes = await requester.client.from("support_internal_notes").select("id");
    const outsiderNotes = await outsider.client.from("support_internal_notes").select("id");
    assertQa(
      (requesterNotes.error || requesterNotes.data?.length === 0) &&
        (outsiderNotes.error || outsiderNotes.data?.length === 0),
      "private internal notes leaked to a requester or unrelated user",
    );

    const staffThread = expectOk(
      await agent.client.rpc("support_staff_get_ticket_thread", {
        p_ticket_id: ordinaryTicket.id,
      }),
      "staff case thread failed",
    );
    assertQa(
      staffThread.internal_notes?.length === 1 &&
        Array.isArray(staffThread.audit_history),
      "staff thread omitted private notes or safe audit history",
    );
    const userThread = expectOk(
      await requester.client.rpc("get_my_support_ticket_thread", {
        p_ticket_id: ordinaryTicket.id,
      }),
      "requester thread failed",
    );
    assertQa(
      userThread.internal_notes === undefined && userThread.audit_history === undefined,
      "staff-only operational fields leaked through the requester RPC",
    );
    qaLog(scope, "queue ownership, private notes, audit history, replay, and isolation pass");

    const replyRequestId = randomUUID();
    const reply = expectOk(
      await agent.client.rpc("support_staff_post_reply", {
        p_ticket_id: ordinaryTicket.id,
        p_message: "A human Support QA reviewer checked this synthetic case.",
        p_client_request_id: replyRequestId,
      }),
      "staff reply failed",
    );
    const replyReplay = expectOk(
      await agent.client.rpc("support_staff_post_reply", {
        p_ticket_id: ordinaryTicket.id,
        p_message: "A human Support QA reviewer checked this synthetic case.",
        p_client_request_id: replyRequestId,
      }),
      "staff reply replay failed",
    );
    const changedReply = await agent.client.rpc("support_staff_post_reply", {
      p_ticket_id: ordinaryTicket.id,
      p_message: "Changed reply content must fail.",
      p_client_request_id: replyRequestId,
    });
    assertQa(
      reply.replayed === false &&
        replyReplay.replayed === true &&
        changedReply.data?.code === "request_payload_mismatch",
      "staff reply idempotency was not payload-bound",
    );
    expectOk(
      await agent.client.rpc("support_staff_change_status", {
        p_ticket_id: ordinaryTicket.id,
        p_status: "closed",
        p_resolution_code: "qa_review_complete",
        p_reason: "Synthetic QA review completed with no real-world outcome.",
      }),
      "support closure failed",
    );

    const appealRequestId = randomUUID();
    const appeal = expectOk(
      await requester.client.rpc("appeal_my_support_ticket", {
        p_ticket_id: ordinaryTicket.id,
        p_reason: "Please independently review the explanation in this synthetic Support case.",
        p_client_request_id: appealRequestId,
      }),
      "support appeal failed",
    );
    const appealReplay = expectOk(
      await requester.client.rpc("appeal_my_support_ticket", {
        p_ticket_id: ordinaryTicket.id,
        p_reason: "Please independently review the explanation in this synthetic Support case.",
        p_client_request_id: appealRequestId,
      }),
      "support appeal replay failed",
    );
    const changedAppeal = await requester.client.rpc("appeal_my_support_ticket", {
      p_ticket_id: ordinaryTicket.id,
      p_reason: "A changed appeal body must not replace the original request.",
      p_client_request_id: appealRequestId,
    });
    assertQa(
      appeal.ticket.case_kind === "appeal" &&
        appeal.ticket.appeal_of_ticket_id === ordinaryTicket.id &&
        appealReplay.replayed === true &&
        changedAppeal.data?.code === "request_payload_mismatch",
      "support appeal routing or replay binding failed",
    );
    qaLog(scope, "human reply labeling, closure, and user appeal routing pass");

    const urgentTicket = await createTicket(
      requester.client,
      "QA urgent Support role separation",
    );
    await withDatabase(async (database) => {
      await database.query(
        `update public.support_tickets
         set priority = 'urgent_safety', queue_key = 'trust_safety'
         where id = $1`,
        [urgentTicket.id],
      );
      await database.query(
        `update public.support_tickets
         set first_response_due_at = now() - interval '1 hour',
             urgent_escalation_due_at = now() - interval '45 minutes',
             last_user_message_at = now() - interval '25 hours'
         where id = $1`,
        [urgentTicket.id],
      );
    });
    const agentUrgent = await agent.client.rpc("support_staff_claim_ticket", {
      p_ticket_id: urgentTicket.id,
      p_client_request_id: randomUUID(),
    });
    assertQa(
      agentUrgent.data?.code === "safety_reviewer_required",
      "ordinary Support agent claimed an urgent safety case",
    );
    const safetyClaim = expectOk(
      await safety.client.rpc("support_staff_claim_ticket", {
        p_ticket_id: urgentTicket.id,
        p_client_request_id: randomUUID(),
      }),
      "safety reviewer urgent claim failed",
    );
    assertQa(
      safetyClaim.ticket.assigned_support_user_id === safety.id,
      "urgent case was not assigned to the safety reviewer",
    );
    const directWorker = await manager.client.rpc("support_process_backlog_aging", {
      p_limit: 100,
    });
    assertQa(directWorker.error, "authenticated staff invoked the service-only aging worker");
    const worker = expectOk(
      await serviceClient.rpc("support_process_backlog_aging", { p_limit: 100 }),
      "service backlog worker failed",
    );
    assertQa(worker.tickets_evaluated >= 1, "backlog worker evaluated no tickets");
    const alertCount = await withDatabase(async (database) => {
      const result = await database.query(
        `select count(*)::integer count
         from public.support_backlog_alerts
         where ticket_id = $1 and resolved_at is null`,
        [urgentTicket.id],
      );
      return result.rows[0].count;
    });
    assertQa(alertCount >= 2, "urgent overdue and aging alerts were not created");

    const dashboard = expectOk(
      await manager.client.rpc("support_staff_operations_dashboard"),
      "privacy-safe Support dashboard failed",
    );
    assertQa(
      dashboard.privacy_scope === "aggregate_counts_only" &&
        dashboard.requester_id === undefined &&
        dashboard.ticket_id === undefined,
      "Support metrics exposed per-user or per-ticket identifiers",
    );
    qaLog(scope, "urgent role separation, service-only aging, alerts, and aggregate metrics pass");
  },
);

qaLog(scope, "all hosted Support human-operations checks completed");
