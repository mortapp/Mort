import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-safety-action-rate-limits";

function reportParams(targetUserId, index, immediateDanger = false) {
  return {
    p_target_user_id: targetUserId,
    p_target_job_id: null,
    p_target_message_id: null,
    p_target_review_id: null,
    p_application_id: null,
    p_category: immediateDanger ? "threats" : "harassment",
    p_severity: immediateDanger ? "critical" : "moderate",
    p_immediate_danger: immediateDanger,
    p_details: `Isolated safety rate-limit QA report number ${index}.`,
    p_occurred_at: null,
    p_location_type: "online",
    p_desired_outcome: "Verify bounded safety action rate controls.",
    p_confidential_safety_feedback: immediateDanger,
    p_client_request_id: randomUUID(),
  };
}

await withQaUsers(
  scope,
  [
    { key: "reportingTeen", role: "teen" },
    { key: "pingTeen", role: "teen" },
    { key: "adult", role: "adult" },
  ],
  async ({ reportingTeen, pingTeen, adult }) => {
    const replayRequestId = randomUUID();
    const replayParams = {
      ...reportParams(adult.id, 1),
      p_client_request_id: replayRequestId,
    };
    const first = await reportingTeen.client.rpc("submit_safety_report_v2", replayParams);
    const replay = await reportingTeen.client.rpc("submit_safety_report_v2", replayParams);
    assertQa(
      !first.error &&
        first.data?.ok === true &&
        !replay.error &&
        replay.data?.replayed === true &&
        replay.data?.report_id === first.data.report_id,
      "report replay was not idempotent",
    );
    for (let index = 2; index <= 15; index += 1) {
      const result = await reportingTeen.client.rpc(
        "submit_safety_report_v2",
        reportParams(adult.id, index),
      );
      assertQa(
        !result.error && result.data?.ok === true,
        `routine report ${index} failed before the documented limit: ${result.error?.message ?? result.data?.code}`,
      );
    }
    const routineDenied = await reportingTeen.client.rpc(
      "submit_safety_report_v2",
      reportParams(adult.id, 16),
    );
    assertQa(
      !routineDenied.error && routineDenied.data?.code === "safety_report_rate_limited",
      "routine report limit did not reject the sixteenth unique daily action",
    );
    const urgentAfterRoutineLimit = await reportingTeen.client.rpc(
      "submit_safety_report_v2",
      reportParams(adult.id, 17, true),
    );
    assertQa(
      !urgentAfterRoutineLimit.error &&
        urgentAfterRoutineLimit.data?.ok === true &&
        urgentAfterRoutineLimit.data?.immediate_danger_guidance === true,
      "routine saturation suppressed an urgent safety report",
    );
    qaLog(scope, "routine report replays do not double-count and urgent reports use a separate budget");

    const firstPingRequestId = randomUUID();
    const firstPingParams = {
      p_status: "ok",
      p_note: "Routine isolated Safety Ping rate QA 1.",
      p_job_id: null,
      p_immediate_danger: false,
      p_client_request_id: firstPingRequestId,
    };
    const firstPing = await pingTeen.client.rpc("create_safety_ping_v2", firstPingParams);
    const replayPing = await pingTeen.client.rpc("create_safety_ping_v2", firstPingParams);
    assertQa(
      !firstPing.error &&
        firstPing.data?.ok === true &&
        !replayPing.error &&
        replayPing.data?.replayed === true &&
        replayPing.data?.safety_ping_id === firstPing.data.safety_ping_id,
      "Safety Ping replay was not idempotent",
    );
    for (let index = 2; index <= 12; index += 1) {
      const result = await pingTeen.client.rpc("create_safety_ping_v2", {
        ...firstPingParams,
        p_note: `Routine isolated Safety Ping rate QA ${index}.`,
        p_client_request_id: randomUUID(),
      });
      assertQa(
        !result.error && result.data?.ok === true,
        `routine Safety Ping ${index} failed before the documented limit: ${result.error?.message ?? result.data?.code}`,
      );
    }
    const routinePingDenied = await pingTeen.client.rpc("create_safety_ping_v2", {
      ...firstPingParams,
      p_note: "Routine isolated Safety Ping rate QA 13.",
      p_client_request_id: randomUUID(),
    });
    assertQa(
      !routinePingDenied.error && routinePingDenied.data?.code === "safety_ping_rate_limited",
      "routine Safety Ping limit did not reject the thirteenth unique hourly action",
    );
    const urgentPing = await pingTeen.client.rpc("create_safety_ping_v2", {
      p_status: "needs_help",
      p_note: "Synthetic urgent Safety Ping after the routine budget was exhausted.",
      p_job_id: null,
      p_immediate_danger: true,
      p_client_request_id: randomUUID(),
    });
    assertQa(
      !urgentPing.error &&
        urgentPing.data?.ok === true &&
        urgentPing.data?.physical_intervention_dispatched === false,
      "routine Safety Ping saturation suppressed urgent routing or implied dispatch",
    );
    qaLog(scope, "routine Safety Pings are bounded while urgent routing remains separate and no-dispatch");

    const blockRequestId = randomUUID();
    const block = await reportingTeen.client.rpc("block_user_v2", {
      p_blocked_id: adult.id,
      p_client_request_id: blockRequestId,
    });
    const blockReplay = await reportingTeen.client.rpc("block_user_v2", {
      p_blocked_id: adult.id,
      p_client_request_id: blockRequestId,
    });
    const blockMismatch = await reportingTeen.client.rpc("block_user_v2", {
      p_blocked_id: pingTeen.id,
      p_client_request_id: blockRequestId,
    });
    assertQa(
      !block.error &&
        block.data?.ok === true &&
        blockReplay.data?.replayed === true &&
        blockMismatch.data?.code === "safety_request_payload_mismatch",
      "block replay or payload binding failed",
    );
    const unblock = await reportingTeen.client.rpc("unblock_user", {
      p_blocked_id: adult.id,
    });
    assertQa(!unblock.error && unblock.data?.removed === true, "unblock RPC failed");

    const locationLeak = await pingTeen.client.rpc("create_safety_ping_v2", {
      p_status: "needs_help",
      p_note: "I am at 123 Main Street right now.",
      p_job_id: null,
      p_immediate_danger: false,
      p_client_request_id: randomUUID(),
    });
    assertQa(
      !locationLeak.error && locationLeak.data?.code === "exact_location_not_allowed_in_ping",
      "Safety Ping accepted an exact address in its ordinary note",
    );
    qaLog(scope, "block/unblock is payload-bound and Safety Ping notes reject exact locations");
  },
);

console.log(`[${scope}] PASS: hosted safety action rate and replay checks completed`);
