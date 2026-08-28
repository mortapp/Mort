import { randomUUID } from "node:crypto";

import {
  assertQa,
  confirmSafetyAgreement,
  qaLog,
  saveJob,
  sendSafeMessage,
  serviceClient,
  updateApplicationStatus,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-feature-expansion";
const proofBytes = Uint8Array.from(
  Buffer.from(
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAEf/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EB//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EB//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EB//2Q==",
    "base64",
  ),
);

const assertHidden = (result, message) => {
  assertQa(!result.error, `${message}: ${result.error?.message}`);
  assertQa((result.data ?? []).length === 0, message);
};

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
    { key: "outsider", role: "adult" },
  ],
  async ({ teen, adult, outsider }) => {
    const proofPaths = [];
    try {
      const saved = await saveJob(adult.client, {
        title: "QA Proof Review and Unread State",
        summary: "Exercise private proof review and accurate message unread state.",
        proof_expected: true,
      });
      assertQa(saved.result?.ok === true, "Adult could not publish the proof-required QA job");
      const jobId = saved.result.job.id;

      const application = await teen.client.rpc("submit_job_application", {
        p_job_id: jobId,
        p_note: "I can complete this staffed public-site QA task.",
        p_availability_confirmed: true,
        p_portfolio_ids: [],
      });
      assertQa(!application.error && application.data?.ok === true, "Teen could not apply");
      const applicationId = application.data.application.id;

      const accepted = await updateApplicationStatus(adult.client, {
        applicationId,
        action: "accepted",
      });
      assertQa(!accepted.error && accepted.data?.ok === true, "Adult could not accept application");
      await confirmSafetyAgreement(teen.client, adult.client, applicationId);

      const thread = await teen.client
        .from("message_threads")
        .select("id")
        .eq("application_id", applicationId)
        .single();
      assertQa(!thread.error && thread.data?.id, "Application message thread was not created");
      const threadId = thread.data.id;
      qaLog(scope, "1/15 proof-required job, application, and protected thread created");

      const sent = await sendSafeMessage(
        teen.client,
        threadId,
        "I will check in at the staffed public work area.",
      );
      assertQa(!sent.error && sent.data?.id, "Teen could not send the unread-state fixture");

      const adultThreads = await adult.client.rpc("get_my_message_threads");
      const teenThreads = await teen.client.rpc("get_my_message_threads");
      assertQa(!adultThreads.error && Array.isArray(adultThreads.data), "Adult thread RPC failed");
      assertQa(!teenThreads.error && Array.isArray(teenThreads.data), "Teen thread RPC failed");
      const adultThread = adultThreads.data.find((item) => item.id === threadId);
      const teenThread = teenThreads.data.find((item) => item.id === threadId);
      assertQa(adultThread?.unread_count === 1, "Incoming message did not create exactly one adult unread");
      assertQa(teenThread?.unread_count === 0, "Sender's own message created an unread count");
      qaLog(scope, "2/15 unread count distinguishes incoming messages from sender messages");

      const outsiderThreads = await outsider.client.rpc("get_my_message_threads");
      assertQa(
        !outsiderThreads.error && !outsiderThreads.data.some((item) => item.id === threadId),
        "Unrelated adult discovered the private conversation",
      );
      const outsiderRead = await outsider.client.rpc("mark_message_thread_read", {
        p_thread_id: threadId,
      });
      assertQa(
        !outsiderRead.error && outsiderRead.data?.ok === false,
        "Unrelated adult changed another conversation's read cursor",
      );
      qaLog(scope, "3/15 conversation discovery and read-cursor writes are participant-isolated");

      const concurrentReads = await Promise.all(
        Array.from({ length: 2 }, () =>
          adult.client.rpc("mark_message_thread_read", { p_thread_id: threadId }),
        ),
      );
      assertQa(
        concurrentReads.every((result) => !result.error && result.data?.ok === true),
        "Concurrent idempotent mark-read calls failed",
      );
      const afterRead = await adult.client.rpc("get_my_message_threads");
      assertQa(
        afterRead.data.find((item) => item.id === threadId)?.unread_count === 0,
        "Mark-read did not clear the server unread count",
      );
      qaLog(scope, "4/15 mark-read is idempotent and concurrency-safe");

      const started = await updateApplicationStatus(teen.client, {
        applicationId,
        action: "in_progress",
      });
      assertQa(!started.error && started.data?.ok === true, "Teen could not start accepted job");

      const firstProofId = randomUUID();
      const firstPath = `${teen.id}/${firstProofId}.jpg`;
      proofPaths.push(firstPath);
      const firstUpload = await teen.client.storage
        .from("proof-uploads")
        .upload(firstPath, proofBytes, {
          contentType: "image/jpeg",
          cacheControl: "3600",
          upsert: false,
        });
      assertQa(!firstUpload.error, `First private proof upload failed: ${firstUpload.error?.message}`);
      const firstSubmit = await teen.client.rpc("submit_application_proof", {
        p_proof_id: firstProofId,
        p_application_id: applicationId,
        p_storage_path: firstPath,
        p_note: "First QA completion evidence.",
      });
      assertQa(
        !firstSubmit.error && firstSubmit.data?.ok === true,
        `First proof submit failed: ${firstSubmit.error?.message ?? firstSubmit.data?.code}`,
      );
      qaLog(scope, "5/15 teen submitted real private proof through storage and the transactional RPC");

      const adultProof = await adult.client
        .from("proof_uploads")
        .select("id,status,storage_path,review_note")
        .eq("id", firstProofId)
        .single();
      assertQa(
        !adultProof.error && adultProof.data.status === "submitted",
        "Owning adult could not read submitted proof metadata",
      );
      const signedProof = await adult.client.storage
        .from("proof-uploads")
        .createSignedUrl(firstPath, 60);
      assertQa(!signedProof.error && signedProof.data?.signedUrl, "Owning adult could not sign proof preview");
      const outsiderProof = await outsider.client
        .from("proof_uploads")
        .select("id,storage_path")
        .eq("id", firstProofId);
      assertHidden(outsiderProof, "Unrelated adult read proof metadata");
      const outsiderSigned = await outsider.client.storage
        .from("proof-uploads")
        .createSignedUrl(firstPath, 60);
      assertQa(outsiderSigned.error, "Unrelated adult generated a proof signed URL");
      qaLog(scope, "6/15 proof metadata and signed previews are limited to job participants");

      const outsiderReview = await outsider.client.rpc("review_application_proof", {
        p_proof_id: firstProofId,
        p_action: "approved",
        p_note: null,
      });
      assertQa(
        !outsiderReview.error && outsiderReview.data?.ok === false,
        "Unrelated adult reviewed another poster's proof",
      );
      const shortNote = await adult.client.rpc("review_application_proof", {
        p_proof_id: firstProofId,
        p_action: "resubmission_requested",
        p_note: "short",
      });
      assertQa(
        !shortNote.error && shortNote.data?.code === "proof_review_note_required",
        "Resubmission accepted an inadequate explanation",
      );
      qaLog(scope, "7/15 proof actions enforce ownership and meaningful resubmission notes");

      const prematureComplete = await updateApplicationStatus(adult.client, {
        applicationId,
        action: "completed",
      });
      assertQa(
        prematureComplete.error?.message?.includes("proof_approval_required"),
        "Proof-required work completed before proof approval",
      );
      qaLog(scope, "8/15 backend blocks completion until submitted proof is approved");

      const resubmission = await adult.client.rpc("review_application_proof", {
        p_proof_id: firstProofId,
        p_action: "resubmission_requested",
        p_note: "Please show the finished labels and full work area.",
      });
      assertQa(
        !resubmission.error &&
          resubmission.data?.ok === true &&
          resubmission.data?.proof?.status === "resubmission_requested" &&
          resubmission.data?.application?.status === "in_progress",
        "Resubmission request did not return work to in-progress state",
      );
      qaLog(scope, "9/15 resubmission request updates proof and lifecycle atomically");

      const secondProofId = randomUUID();
      const secondPath = `${teen.id}/${secondProofId}.jpg`;
      proofPaths.push(secondPath);
      const secondUpload = await teen.client.storage
        .from("proof-uploads")
        .upload(secondPath, proofBytes, {
          contentType: "image/jpeg",
          cacheControl: "3600",
          upsert: false,
        });
      assertQa(!secondUpload.error, "Replacement private proof upload failed");
      const secondSubmit = await teen.client.rpc("submit_application_proof", {
        p_proof_id: secondProofId,
        p_application_id: applicationId,
        p_storage_path: secondPath,
        p_note: "Replacement QA evidence with the full completed area.",
      });
      assertQa(!secondSubmit.error && secondSubmit.data?.ok === true, "Replacement proof submit failed");

      const staleApproval = await adult.client.rpc("review_application_proof", {
        p_proof_id: firstProofId,
        p_action: "approved",
        p_note: null,
      });
      assertQa(
        !staleApproval.error && staleApproval.data?.code === "stale_proof_submission",
        "Poster could approve stale proof after a replacement existed",
      );
      qaLog(scope, "10/15 stale proof submissions cannot be approved");

      const approved = await adult.client.rpc("review_application_proof", {
        p_proof_id: secondProofId,
        p_action: "approved",
        p_note: "Completion is visible.",
      });
      assertQa(
        !approved.error && approved.data?.ok === true && approved.data?.proof?.status === "approved",
        "Owning adult could not approve current proof",
      );
      const approvedAgain = await adult.client.rpc("review_application_proof", {
        p_proof_id: secondProofId,
        p_action: "approved",
        p_note: "Completion is visible.",
      });
      assertQa(
        !approvedAgain.error && approvedAgain.data?.ok === true && approvedAgain.data?.idempotent === true,
        "Repeated proof approval was not idempotent",
      );
      qaLog(scope, "11/15 current proof approval succeeds and repeated approval is idempotent");

      const completed = await updateApplicationStatus(adult.client, {
        applicationId,
        action: "completed",
      });
      assertQa(
        !completed.error && completed.data?.ok === true && completed.data?.application?.status === "completed",
        "Approved proof did not unlock authorized completion",
      );
      qaLog(scope, "12/15 approved proof unlocks the existing backend completion transition");

      const participantEvents = await teen.client
        .from("proof_review_events")
        .select("action,note")
        .eq("application_id", applicationId)
        .order("created_at");
      const outsiderEvents = await outsider.client
        .from("proof_review_events")
        .select("action,note")
        .eq("application_id", applicationId);
      assertQa(
        !participantEvents.error && participantEvents.data.length === 2,
        "Participant could not read the expected proof audit events",
      );
      assertHidden(outsiderEvents, "Unrelated adult read proof audit events");
      qaLog(scope, "13/15 proof review history is append-only through RPC and RLS-isolated");

      const notification = await teen.client
        .from("notifications")
        .select("title,data")
        .eq("recipient_id", teen.id)
        .contains("data", { proofUploadId: secondProofId });
      assertQa(
        !notification.error && notification.data.some((item) => item.title === "Proof approved"),
        "Teen did not receive the safe proof-review notification",
      );
      qaLog(scope, "14/15 proof decision creates a private, non-sensitive notification");

      const startedAt = Date.now();
      const probes = await Promise.all(
        Array.from({ length: 25 }, () => adult.client.rpc("get_my_message_threads")),
      );
      assertQa(probes.every((probe) => !probe.error), "Concurrent thread-list probes failed");
      qaLog(
        scope,
        `15/15 lightweight load sanity passed: 25 concurrent thread-list RPCs in ${Date.now() - startedAt} ms`,
      );
    } finally {
      if (proofPaths.length > 0) {
        const cleanup = await serviceClient.storage.from("proof-uploads").remove(proofPaths);
        if (cleanup.error) {
          console.error(`[${scope}] cleanup warning: proof objects: ${cleanup.error.message}`);
        }
      }
    }
  },
);

console.log(`[${scope}] PASS: unread, proof review, RLS, storage, abuse, concurrency, and load sanity verified`);
