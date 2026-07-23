import { randomUUID } from "node:crypto";

import {
  assertQa,
  confirmSafetyAgreement,
  qaLog,
  removeQaModerationEvent,
  saveJob,
  serviceClient,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-job-applications";

await withQaUsers(
  scope,
  [
    { key: "adult", role: "adult" },
    { key: "otherAdult", role: "adult" },
    { key: "teen", role: "teen" },
    { key: "otherTeen", role: "teen" },
  ],
  async ({ adult, otherAdult, teen, otherTeen }) => {
    const job = await saveJob(adult.client, {
      title: "QA Feature Application Lifecycle",
      summary: "A safe QA job for real application transition checks.",
    });
    assertQa(job.result?.ok === true, "application QA job did not publish");

    const directInsert = await teen.client
      .from("applications")
      .insert({ job_id: job.result.job.id, teen_id: teen.id, status: "adult_review" })
      .select("id");
    assertQa(directInsert.error || directInsert.data.length === 0, "direct application insert bypassed the RPC");
    qaLog(scope, "direct application inserts are closed by RLS");

    const eligibility = await teen.client.rpc("get_job_application_eligibility", {
      p_job_id: job.result.job.id,
    });
    assertQa(!eligibility.error && eligibility.data?.eligible === true, `eligible teen was rejected: ${JSON.stringify(eligibility.data)}`);

    const submitted = await teen.client.rpc("submit_job_application", {
      p_job_id: job.result.job.id,
      p_note: "I am available and have completed similar organizing work.",
      p_availability_confirmed: true,
      p_portfolio_ids: [],
    });
    assertQa(!submitted.error && submitted.data?.ok === true, `application RPC failed: ${submitted.error?.message}`);
    assertQa(submitted.data.application.status === "adult_review", "optional guardian application has wrong status");
    assertQa(submitted.data.application.availability_confirmed === true, "availability confirmation was not stored");
    qaLog(scope, "structured RPC inserts an eligible application without the old RETURNING/RLS failure");

    const duplicate = await teen.client.rpc("submit_job_application", {
      p_job_id: job.result.job.id,
      p_note: "Duplicate attempt",
      p_availability_confirmed: true,
      p_portfolio_ids: [],
    });
    assertQa(!duplicate.error && duplicate.data?.ok === false, "duplicate application unexpectedly succeeded");
    assertQa(duplicate.data.code === "application_already_exists", `duplicate returned ${duplicate.data.code}`);

    const unrelatedAccept = await otherAdult.client.rpc("update_application_status_v2", {
      p_application_id: submitted.data.application.id,
      p_action: "accepted",
    });
    assertQa(!unrelatedAccept.error && unrelatedAccept.data?.ok === false, "unrelated adult accepted application");

    for (const [action, expected] of [
      ["viewed", "viewed"],
      ["accepted", "accepted"],
    ]) {
      const result = await adult.client.rpc("update_application_status_v2", {
        p_application_id: submitted.data.application.id,
        p_action: action,
      });
      assertQa(!result.error && result.data?.ok === true, `${action} failed`);
      assertQa(result.data.application.status === expected, `${action} produced ${result.data.application.status}`);
    }
    qaLog(scope, "poster can mark viewed and accept while unrelated adult cannot");

    await confirmSafetyAgreement(teen.client, adult.client, submitted.data.application.id);
    qaLog(scope, "both participants confirmed the current mutual Safety Agreement");

    const assignedEligibility = await otherTeen.client.rpc("get_job_application_eligibility", {
      p_job_id: job.result.job.id,
    });
    assertQa(
      ["job_already_assigned", "job_not_open"].includes(assignedEligibility.data?.code),
      `assigned job returned ${assignedEligibility.data?.code}`,
    );

    const started = await teen.client.rpc("update_application_status_v2", {
      p_application_id: submitted.data.application.id,
      p_action: "in_progress",
    });
    assertQa(started.data?.ok === true && started.data.application.status === "in_progress", "teen could not start accepted job");

    const bypassedProof = await teen.client.rpc("update_application_status_v2", {
      p_application_id: submitted.data.application.id,
      p_action: "proof_submitted",
    });
    assertQa(
      !bypassedProof.error &&
        bypassedProof.data?.ok === false &&
        bypassedProof.data?.code === "invalid_application_transition",
      "legacy status RPC bypassed real proof submission",
    );

    const proofId = randomUUID();
    const proofPath = `${teen.id}/${proofId}.jpg`;
    const proofBytes = Buffer.from(
      "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAEf/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EB//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EB//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EB//2Q==",
      "base64",
    );
    try {
      const stored = await teen.client.storage
        .from("proof-uploads")
        .upload(proofPath, proofBytes, { contentType: "image/jpeg", upsert: false });
      assertQa(!stored.error, `proof object upload failed: ${stored.error?.message}`);

      const unrelatedProof = await otherTeen.client.rpc("submit_application_proof", {
        p_proof_id: proofId,
        p_application_id: submitted.data.application.id,
        p_storage_path: proofPath,
        p_note: "Unrelated attempt",
      });
      assertQa(
        !unrelatedProof.error && unrelatedProof.data?.ok === false,
        "unrelated teen attached another teen's proof object",
      );

      const proof = await teen.client.rpc("submit_application_proof", {
        p_proof_id: proofId,
        p_application_id: submitted.data.application.id,
        p_storage_path: proofPath,
        p_note: "The organized shelves and labeled cart are visible.",
      });
      assertQa(!proof.error && proof.data?.ok === true, `proof RPC failed: ${proof.error?.message}`);
      assertQa(proof.data.application.status === "proof_submitted", "proof did not update application status");
      assertQa(proof.data.job.status === "proof_submitted", "proof did not update job status");
      assertQa(proof.data.idempotent === false, "first proof call was incorrectly marked as a retry");

      const retry = await teen.client.rpc("submit_application_proof", {
        p_proof_id: proofId,
        p_application_id: submitted.data.application.id,
        p_storage_path: proofPath,
        p_note: "Retry after an ambiguous client response.",
      });
      assertQa(!retry.error && retry.data?.ok === true && retry.data.idempotent === true, "proof retry was not idempotent");

      const teenProof = await teen.client.from("proof_uploads").select("id").eq("id", proofId);
      const adultProof = await adult.client.from("proof_uploads").select("id").eq("id", proofId);
      const unrelatedRead = await otherTeen.client.from("proof_uploads").select("id").eq("id", proofId);
      assertQa(teenProof.data?.length === 1, "teen cannot read their submitted proof record");
      assertQa(adultProof.data?.length === 1, "job poster cannot read submitted proof record");
      assertQa(unrelatedRead.data?.length === 0, "unrelated teen can read proof record");

      const attachedDelete = await teen.client.storage.from("proof-uploads").remove([proofPath]);
      assertQa(attachedDelete.error || attachedDelete.data.length === 0, "teen deleted attached proof evidence");
      qaLog(scope, "real private proof upload is idempotent, participant-visible, and evidence-preserving");
    } finally {
      await serviceClient.storage.from("proof-uploads").remove([proofPath]);
    }

    const completed = await adult.client.rpc("update_application_status_v2", {
      p_application_id: submitted.data.application.id,
      p_action: "completed",
    });
    assertQa(completed.data?.ok === true && completed.data.application.status === "completed", "adult completion failed");
    assertQa(completed.data.job.status === "completed", "job did not complete with application");

    const events = await teen.client
      .from("application_status_events")
      .select("to_status")
      .eq("application_id", submitted.data.application.id)
      .order("created_at");
    const statuses = events.data?.map((event) => event.to_status) ?? [];
    for (const expected of ["adult_review", "viewed", "accepted", "in_progress", "proof_submitted", "completed"]) {
      assertQa(statuses.includes(expected), `timeline is missing ${expected}`);
    }
    qaLog(scope, "submitted, viewed, accepted, started, proof, and completion timeline is real");

    const closedJob = await saveJob(adult.client, {
      title: "QA Feature Closed Applications",
      summary: "A QA job that closes before a teen can apply.",
    });
    const closed = await adult.client.rpc("manage_job", {
      p_job_id: closedJob.result.job.id,
      p_action: "close_applications",
    });
    assertQa(closed.data?.ok === true, "could not close applications");
    const closedEligibility = await otherTeen.client.rpc("get_job_application_eligibility", {
      p_job_id: closedJob.result.job.id,
    });
    assertQa(closedEligibility.data?.code === "job_not_open", "closed job accepted eligibility");
    qaLog(scope, "closed jobs reject new applications with a structured code");

    const prohibitedRoofJob = await saveJob(otherAdult.client, {
      title: "QA Unsafe Roof Work",
      summary: "A QA roof repair job that the teen safety scanner must reject.",
    });
    assertQa(
      prohibitedRoofJob.result?.ok === false && prohibitedRoofJob.result?.code === "unsafe_job_content",
      `prohibited roof fixture returned ${prohibitedRoofJob.result?.code ?? "unknown_error"}`,
    );
    await removeQaModerationEvent(prohibitedRoofJob.clientRequestId, otherAdult.id);

    const proofRequiredJob = await saveJob(otherAdult.client, {
      title: "QA Feature Proof Required Completion",
      summary: "A QA job that must not complete until real proof is attached.",
      proof_expected: true,
    });
    assertQa(
      proofRequiredJob.result?.ok === true,
      `proof-required fixture job returned ${proofRequiredJob.result?.code ?? "unknown_error"}`,
    );
    const proofRequiredApplication = await otherTeen.client.rpc("submit_job_application", {
      p_job_id: proofRequiredJob.result.job.id,
      p_note: "Available for the proof-required transition check.",
      p_availability_confirmed: true,
      p_portfolio_ids: [],
    });
    assertQa(proofRequiredApplication.data?.ok === true, "proof-required fixture application failed");
    const proofRequiredApplicationId = proofRequiredApplication.data.application.id;
    const proofRequiredAccept = await otherAdult.client.rpc("update_application_status_v2", {
      p_application_id: proofRequiredApplicationId,
      p_action: "accepted",
    });
    assertQa(proofRequiredAccept.data?.ok === true, "proof-required fixture acceptance failed");
    await confirmSafetyAgreement(otherTeen.client, otherAdult.client, proofRequiredApplicationId);
    const proofRequiredStart = await otherTeen.client.rpc("update_application_status_v2", {
      p_application_id: proofRequiredApplicationId,
      p_action: "in_progress",
    });
    assertQa(proofRequiredStart.data?.ok === true, "proof-required fixture could not start");
    const prematureCompletion = await otherAdult.client.rpc("update_application_status_v2", {
      p_application_id: proofRequiredApplicationId,
      p_action: "completed",
    });
    assertQa(
      !prematureCompletion.error &&
        prematureCompletion.data?.ok === false &&
        prematureCompletion.data?.code === "proof_required",
      `premature completion returned ${prematureCompletion.data?.code}`,
    );
    qaLog(scope, "scanner allows proof wording, still blocks roof work, and preserves proof-required completion");
  },
);
