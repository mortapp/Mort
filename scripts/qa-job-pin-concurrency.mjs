import { randomUUID } from "node:crypto";

import {
  assertQa,
  confirmSafetyAgreement,
  qaLog,
  saveJob,
  serviceClient,
  updateApplicationStatus,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-job-pin-concurrency";
const qaUserIds = [];

function expectRpc(result, action) {
  assertQa(
    !result.error && result.data?.ok === true,
    `${action} failed: ${result.error?.message ?? result.data?.code ?? "unknown"}`,
  );
  return result.data;
}

function nearTermSchedule() {
  const now = new Date();
  const offsetHours = 12 - now.getUTCHours();
  return {
    schedule_type: "exact",
    starts_at: new Date(now.getTime() + 5 * 60 * 1000).toISOString(),
    ends_at: new Date(now.getTime() + 65 * 60 * 1000).toISOString(),
    timezone:
      offsetHours === 0
        ? "UTC"
        : `Etc/GMT${offsetHours > 0 ? "-" : "+"}${Math.abs(offsetHours)}`,
  };
}

async function createFundedExecution(teen, adult, title) {
  const created = await saveJob(adult.client, {
    title,
    ...nearTermSchedule(),
  });
  assertQa(created.result?.ok === true, "job publish failed");
  const submitted = expectRpc(
    await teen.client.rpc("submit_job_application", {
      p_job_id: created.result.job.id,
      p_note: "I understand this public task and its safety requirements.",
      p_availability_confirmed: true,
      p_portfolio_ids: [],
    }),
    "application submission",
  );
  const accepted = await updateApplicationStatus(adult.client, {
    applicationId: submitted.application.id,
    action: "accepted",
  });
  expectRpc(accepted, "application acceptance");
  await confirmSafetyAgreement(teen.client, adult.client, submitted.application.id);

  const contract = await serviceClient
    .from("job_contracts")
    .select("id,active_version_id,status")
    .eq("application_id", submitted.application.id)
    .single();
  assertQa(!contract.error && contract.data, "job contract unavailable");
  const version = await serviceClient
    .from("job_contract_versions")
    .select("id")
    .eq("contract_id", contract.data.id)
    .eq("version_number", 1)
    .single();
  assertQa(!version.error && version.data, "job contract version unavailable");
  const confirmation = {
    p_contract_version_id: version.data.id,
    p_affirmative_checkbox: true,
    p_confirmation_text: "I reviewed and confirm this exact job agreement.",
    p_platform: "qa",
    p_app_version: "qa-phase-6",
  };
  expectRpc(
    await teen.client.rpc("confirm_job_contract_version", confirmation),
    "teen contract confirmation",
  );
  expectRpc(
    await adult.client.rpc("confirm_job_contract_version", confirmation),
    "adult contract confirmation",
  );
  const obligation = await serviceClient
    .from("job_payment_obligations")
    .select("id,amount_cents,currency_code")
    .eq("contract_id", contract.data.id)
    .eq("contract_version_id", version.data.id)
    .single();
  assertQa(!obligation.error && obligation.data, "payment obligation unavailable");
  await withDatabase(async (database) => {
    await database.query(
      `insert into private.stripe_job_payment_intents (
         contract_id, contract_version_id, obligation_id, adult_id, teen_id,
         environment, earnings_amount_cents, service_fee_cents,
         total_amount_cents, currency_code, transfer_group, idempotency_key,
         status, funded_at, last_synchronized_at
       ) values ($1, $2, $3, $4, $5, 'test', $6, 0, $6, $7, $8, $9,
                 'funded', now(), now())`,
      [
        contract.data.id,
        version.data.id,
        obligation.data.id,
        adult.id,
        teen.id,
        obligation.data.amount_cents,
        obligation.data.currency_code,
        `MORT_JOB_${randomUUID().replaceAll("-", "")}`,
        `qa-pin-funded-${randomUUID()}`,
      ],
    );
  });
  return {
    applicationId: submitted.application.id,
    contractId: contract.data.id,
    jobId: created.result.job.id,
  };
}

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
    { key: "outsider", role: "teen" },
  ],
  async ({ teen, adult, outsider }) => {
    qaUserIds.push(teen.id, adult.id, outsider.id);
    const execution = await createFundedExecution(
      teen,
      adult,
      "QA Atomic Start Finish PIN Task",
    );
    const startGenerationId = randomUUID();
    const generatedStart = expectRpc(
      await adult.client.rpc("generate_job_start_pin", {
        p_application_id: execution.applicationId,
        p_client_request_id: startGenerationId,
      }),
      "start PIN generation",
    );
    assertQa(/^\d{6}$/.test(generatedStart.start_pin), "start PIN is not six digits");
    const generationReplay = await adult.client.rpc("generate_job_start_pin", {
      p_application_id: execution.applicationId,
      p_client_request_id: startGenerationId,
    });
    assertQa(
      !generationReplay.error &&
        generationReplay.data?.code === "pin_not_repeated_for_replay" &&
        generationReplay.data?.start_pin == null,
      "start PIN was redisclosed on request replay",
    );

    const hiddenHandshake = await teen.client
      .from("job_arrival_handshakes")
      .select("start_pin_hash,finish_pin_hash")
      .eq("application_id", execution.applicationId);
    assertQa(
      !hiddenHandshake.error && hiddenHandshake.data.length === 0,
      "participant could read PIN hashes directly",
    );
    const outsiderStatus = await outsider.client.rpc("get_job_execution_status", {
      p_application_id: execution.applicationId,
    });
    assertQa(
      !outsiderStatus.error && outsiderStatus.data?.code === "job_participant_required",
      "outsider received job execution status",
    );
    qaLog(scope, "generation is server-only, non-redisclosing, and status/hash access is scoped");

    const failedRequestId = randomUUID();
    const failed = await teen.client.rpc("confirm_job_start_pin_v2", {
      p_application_id: execution.applicationId,
      p_pin: "111111",
      p_person_matches_profile: true,
      p_client_request_id: failedRequestId,
    });
    assertQa(failed.data?.code === "start_pin_invalid", "wrong start PIN was not rejected");
    const failedReplay = await teen.client.rpc("confirm_job_start_pin_v2", {
      p_application_id: execution.applicationId,
      p_pin: "111111",
      p_person_matches_profile: true,
      p_client_request_id: failedRequestId,
    });
    assertQa(
      failedReplay.data?.code === "start_pin_invalid" && failedReplay.data?.replayed === true,
      "failed confirmation retry was not replayed safely",
    );
    const payloadMismatch = await teen.client.rpc("confirm_job_start_pin_v2", {
      p_application_id: execution.applicationId,
      p_pin: "222222",
      p_person_matches_profile: true,
      p_client_request_id: failedRequestId,
    });
    assertQa(
      payloadMismatch.data?.code === "pin_request_payload_mismatch",
      "PIN confirmation request accepted a substituted payload",
    );
    const attemptState = await serviceClient
      .from("job_arrival_handshakes")
      .select("start_pin_attempt_count")
      .eq("application_id", execution.applicationId)
      .single();
    assertQa(
      attemptState.data?.start_pin_attempt_count === 1,
      "failed retry incremented the PIN attempt count twice",
    );
    qaLog(scope, "failed attempts are retry-idempotent and payload-bound");

    const startConfirmationId = randomUUID();
    const [startOne, startTwo] = await Promise.all([
      teen.client.rpc("confirm_job_start_pin_v2", {
        p_application_id: execution.applicationId,
        p_pin: generatedStart.start_pin,
        p_person_matches_profile: true,
        p_client_request_id: startConfirmationId,
      }),
      teen.client.rpc("confirm_job_start_pin_v2", {
        p_application_id: execution.applicationId,
        p_pin: generatedStart.start_pin,
        p_person_matches_profile: true,
        p_client_request_id: startConfirmationId,
      }),
    ]);
    assertQa(
      !startOne.error && !startTwo.error &&
        startOne.data?.ok === true && startTwo.data?.ok === true &&
        [startOne.data.replayed, startTwo.data.replayed].includes(true),
      "concurrent start confirmation was not serialized and replayed",
    );
    const startEvents = await serviceClient
      .from("job_execution_events")
      .select("id,event_type,safe_metadata")
      .eq("application_id", execution.applicationId)
      .eq("event_type", "start_confirmed");
    assertQa(startEvents.data?.length === 1, "start transition produced duplicate audit events");
    assertQa(
      !JSON.stringify(startEvents.data).includes(generatedStart.start_pin),
      "start PIN leaked into audit events",
    );
    qaLog(scope, "concurrent start confirmation performs one atomic transition");

    const safetyConfig = expectRpc(
      await teen.client.rpc("get_safety_center_config"),
      "Safety Center configuration",
    );
    assertQa(
      safetyConfig.physical_intervention_available === false &&
        safetyConfig.emergency_phone_uri === "tel:911",
      "Safety Center configuration implied physical intervention or lacked local emergency routing",
    );
    const initialCheckins = await teen.client.rpc("get_my_active_job_checkins");
    assertQa(
      !initialCheckins.error && initialCheckins.data.length >= 1,
      "start PIN did not schedule active-job cadence check-ins",
    );
    const outsiderCheckins = await outsider.client.rpc("get_my_active_job_checkins");
    assertQa(
      !outsiderCheckins.error && outsiderCheckins.data.length === 0,
      "outsider could see another teen's active-job check-ins",
    );

    const completionId = randomUUID();
    const completedCheckin = expectRpc(
      await teen.client.rpc("complete_active_job_checkin", {
        p_checkin_id: initialCheckins.data[0].checkin_id,
        p_client_request_id: completionId,
      }),
      "active-job check-in completion",
    );
    const completionReplay = expectRpc(
      await teen.client.rpc("complete_active_job_checkin", {
        p_checkin_id: initialCheckins.data[0].checkin_id,
        p_client_request_id: completionId,
      }),
      "active-job check-in completion replay",
    );
    assertQa(
      completedCheckin.replayed === false && completionReplay.replayed === true,
      "active-job check-in completion was not retry-idempotent",
    );

    const scheduledId = randomUUID();
    const scheduled = expectRpc(
      await teen.client.rpc("schedule_active_job_checkin", {
        p_application_id: execution.applicationId,
        p_minutes_from_now: 60,
        p_client_request_id: scheduledId,
      }),
      "manual active-job check-in schedule",
    );
    const scheduleReplay = expectRpc(
      await teen.client.rpc("schedule_active_job_checkin", {
        p_application_id: execution.applicationId,
        p_minutes_from_now: 60,
        p_client_request_id: scheduledId,
      }),
      "manual active-job check-in schedule replay",
    );
    assertQa(
      scheduled.replayed === false && scheduleReplay.replayed === true,
      "manual check-in scheduling was not retry-idempotent",
    );
    await withDatabase((database) =>
      database.query(
        "update public.job_checkins set expected_at = now() - interval '20 minutes' where id = $1",
        [scheduled.checkin_id],
      ),
    );
    const escalated = await serviceClient.rpc("escalate_missed_job_checkins");
    assertQa(
      !escalated.error && escalated.data >= 1,
      `missed check-in worker failed: ${escalated.error?.message}`,
    );
    const missedCheckin = await serviceClient
      .from("job_checkins")
      .select("status,escalation_sent_at")
      .eq("id", scheduled.checkin_id)
      .single();
    const missedPing = await serviceClient
      .from("safety_pings")
      .select("id,note")
      .eq("teen_id", teen.id)
      .eq("job_id", execution.jobId)
      .eq("status", "missed");
    assertQa(
      missedCheckin.data?.status === "missed" &&
        missedCheckin.data?.escalation_sent_at &&
        missedPing.data?.some((ping) => /not emergency dispatch/i.test(ping.note)),
      "missed check-in did not create a bounded no-dispatch safety alert",
    );
    const lateCompletion = expectRpc(
      await teen.client.rpc("complete_active_job_checkin", {
        p_checkin_id: scheduled.checkin_id,
        p_client_request_id: randomUUID(),
      }),
      "late active-job check-in completion",
    );
    assertQa(lateCompletion.was_missed === true, "late check-in did not retain its missed state in the response");

    const terminalCheckin = expectRpc(
      await teen.client.rpc("schedule_active_job_checkin", {
        p_application_id: execution.applicationId,
        p_minutes_from_now: 60,
        p_client_request_id: randomUUID(),
      }),
      "terminal cancellation check-in schedule",
    );
    assertQa(terminalCheckin.checkin_id, "terminal cancellation check-in was not created");

    const directReport = await teen.client.from("reports").insert({
      reporter_id: teen.id,
      target_user_id: adult.id,
      reason: "qa-direct-write",
      details: "This direct write must be denied by table privileges.",
    });
    const directBlock = await teen.client.from("blocks").insert({
      blocker_id: teen.id,
      blocked_id: adult.id,
    });
    const directPing = await teen.client.from("safety_pings").insert({
      teen_id: teen.id,
      status: "ok",
    });
    assertQa(
      directReport.error && directBlock.error && directPing.error,
      "an authenticated caller retained a direct safety-table write path",
    );
    qaLog(scope, "check-ins schedule, complete, miss, escalate, isolate, and reject direct-table bypasses");

    const generatedFinish = expectRpc(
      await adult.client.rpc("generate_job_finish_pin", {
        p_application_id: execution.applicationId,
        p_client_request_id: randomUUID(),
      }),
      "finish PIN generation",
    );
    assertQa(/^\d{6}$/.test(generatedFinish.finish_pin), "finish PIN is not six digits");
    const finishConfirmationId = randomUUID();
    const [finishOne, finishTwo] = await Promise.all([
      teen.client.rpc("confirm_job_finish_pin_v2", {
        p_application_id: execution.applicationId,
        p_pin: generatedFinish.finish_pin,
        p_client_request_id: finishConfirmationId,
      }),
      teen.client.rpc("confirm_job_finish_pin_v2", {
        p_application_id: execution.applicationId,
        p_pin: generatedFinish.finish_pin,
        p_client_request_id: finishConfirmationId,
      }),
    ]);
    assertQa(
      !finishOne.error && !finishTwo.error &&
        finishOne.data?.ok === true && finishTwo.data?.ok === true &&
        finishOne.data?.money_moved === false && finishTwo.data?.money_moved === false &&
        [finishOne.data.replayed, finishTwo.data.replayed].includes(true),
      "concurrent finish confirmation was not serialized safely",
    );
    const finishEvents = await serviceClient
      .from("job_execution_events")
      .select("id,event_type,safe_metadata")
      .eq("application_id", execution.applicationId)
      .eq("event_type", "finish_confirmed");
    assertQa(finishEvents.data?.length === 1, "finish transition produced duplicate audit events");
    assertQa(
      !JSON.stringify(finishEvents.data).includes(generatedFinish.finish_pin),
      "finish PIN leaked into audit events",
    );
    const usedAgain = await teen.client.rpc("confirm_job_finish_pin_v2", {
      p_application_id: execution.applicationId,
      p_pin: generatedFinish.finish_pin,
      p_client_request_id: randomUUID(),
    });
    assertQa(
      usedAgain.data?.code === "finish_pin_already_used",
      "used finish PIN was accepted under a new request",
    );
    const pendingAfterFinish = await serviceClient
      .from("job_checkins")
      .select("id")
      .eq("application_id", execution.applicationId)
      .eq("status", "pending");
    assertQa(
      !pendingAfterFinish.error && pendingAfterFinish.data.length === 0,
      "finish PIN left pending cadence check-ins that could later false-alert",
    );
    qaLog(scope, "concurrent finish confirmation performs one transition and moves no money");

    const oldStart = await teen.client.rpc("confirm_job_start_pin", {
      p_application_id: execution.applicationId,
      p_pin: generatedStart.start_pin,
      p_person_matches_profile: true,
      p_client_request_id: randomUUID(),
    });
    const oldFinish = await teen.client.rpc("confirm_job_finish_pin", {
      p_application_id: execution.applicationId,
      p_pin: generatedFinish.finish_pin,
      p_client_request_id: randomUUID(),
    });
    const oldArrival = await adult.client.rpc("generate_job_arrival_code", {
      p_application_id: execution.applicationId,
    });
    assertQa(
      oldStart.error && oldFinish.error && oldArrival.error,
      "legacy PIN RPC remained authenticated-callable",
    );
    qaLog(scope, "legacy PIN confirmation and arrival aliases are retired");
  },
);

const remainingUsers = await withDatabase(async (database) => {
  const result = await database.query(
    "select count(*)::int as count from auth.users where id = any($1::uuid[])",
    [qaUserIds],
  );
  return result.rows[0].count;
});
assertQa(remainingUsers === 0, "one or more PIN QA auth users survived cleanup");
qaLog(scope, "verified all isolated auth fixtures were removed");

console.log(`[${scope}] PASS: hosted PIN concurrency and replay checks completed`);
