import { randomUUID } from "node:crypto";
import {
  assertQa,
  manageJob,
  qaLog,
  saveJob,
  serviceClient,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-job-lifecycle";

await withQaUsers(
  scope,
  [
    { key: "adult", role: "adult" },
    { key: "otherAdult", role: "adult" },
    { key: "qaTeen", role: "teen" },
    { key: "normalTeen", role: "teen", isTest: false },
  ],
  async ({ adult, otherAdult, qaTeen, normalTeen }) => {
    const requestId = randomUUID();
    const draft = await saveJob(
      adult.client,
      {
        client_request_id: requestId,
        title: "QA Feature Flexible Draft",
        summary: "A resumable draft for a safe public organizing job.",
      },
      false,
    );
    assertQa(draft.result?.ok === true, "draft RPC did not return success");
    assertQa(draft.result.job.status === "draft", "save as draft did not persist draft status");

    const retry = await saveJob(
      adult.client,
      {
        client_request_id: requestId,
        title: "QA Feature Flexible Draft",
        summary: "A resumable draft for a safe public organizing job.",
      },
      false,
    );
    assertQa(retry.result.job.id === draft.result.job.id, "idempotent draft retry created another id");
    const count = await serviceClient
      .from("jobs")
      .select("id", { count: "exact", head: true })
      .eq("poster_id", adult.id)
      .eq("client_request_id", requestId);
    assertQa(count.count === 1, `idempotent retry created ${count.count} rows`);
    qaLog(scope, "draft save and repeat submission create exactly one job row");

    const published = await saveJob(
      adult.client,
      {
        job_id: draft.result.job.id,
        client_request_id: requestId,
        title: "QA Feature Flexible Draft",
        summary: "A resumable draft for a safe public organizing job.",
      },
      true,
    );
    assertQa(published.result?.ok === true && published.result.job.status === "open", "draft did not publish");
    assertQa(published.result.job.schedule_type === "flexible", "flexible schedule was not preserved");
    assertQa(published.result.job.starts_at === null, "flexible job unexpectedly gained a start time");
    qaLog(scope, "draft resumes and publishes with an intentional flexible schedule");

    const normalVisibility = await normalTeen.client
      .from("jobs")
      .select("id")
      .eq("id", published.result.job.id);
    assertQa(!normalVisibility.error && normalVisibility.data.length === 0, "normal account could see QA job");
    const qaVisibility = await qaTeen.client
      .from("jobs")
      .select("id")
      .eq("id", published.result.job.id);
    assertQa(!qaVisibility.error && qaVisibility.data.length === 1, "QA teen could not see isolated QA job");
    qaLog(scope, "production account cannot see QA job while QA account can");

    const otherManage = await manageJob(otherAdult.client, {
      jobId: published.result.job.id,
      action: "pause",
    });
    assertQa(!otherManage.error && otherManage.data?.ok === false, "unrelated adult managed another poster's job");
    const directUpdate = await otherAdult.client
      .from("jobs")
      .update({ title: "UNAUTHORIZED CHANGE" })
      .eq("id", published.result.job.id)
      .select("id");
    assertQa(directUpdate.error || directUpdate.data.length === 0, "direct job update bypassed RPC ownership checks");
    qaLog(scope, "unrelated adults cannot update or manage another owner's job");

    for (const [action, expectedStatus] of [
      ["pause", "paused"],
      ["resume", "open"],
    ]) {
      const transition = await manageJob(adult.client, {
        jobId: published.result.job.id,
        action,
      });
      assertQa(!transition.error && transition.data?.ok === true, `${action} failed`);
      assertQa(transition.data.job.status === expectedStatus, `${action} produced ${transition.data.job.status}`);
    }

    const close = await manageJob(adult.client, {
      jobId: published.result.job.id,
      action: "close_applications",
    });
    assertQa(
      !close.error && close.data?.ok === true && close.data.job.applications_open === false,
      `close applications failed: ${close.error?.message ?? JSON.stringify(close.data)}`,
    );

    const duplicate = await manageJob(adult.client, {
      jobId: published.result.job.id,
      action: "duplicate",
    });
    assertQa(!duplicate.error && duplicate.data?.ok === true, "duplicate job failed");
    assertQa(duplicate.data.job.status === "draft", "duplicate was not a draft");
    assertQa(duplicate.data.job.starts_at === null, "duplicate retained an old exact schedule");
    assertQa(duplicate.data.job.requires_guardian_approval === false, "duplicate retained guardian approval");
    qaLog(scope, "duplicate creates a safe draft without schedule, applicants, or guardian carryover");

    const deleted = await manageJob(adult.client, {
      jobId: duplicate.data.job.id,
      action: "delete_draft",
    });
    assertQa(deleted.data?.ok === true && deleted.data.deleted === true, "delete draft failed");

    const past = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const rejectedPast = await saveJob(adult.client, {
      title: "QA Feature Past Schedule",
      summary: "This exact-date QA job must be rejected by server validation.",
      schedule_type: "exact",
      starts_at: past,
    });
    assertQa(rejectedPast.result?.ok === false, "past job unexpectedly published");
    assertQa(rejectedPast.result.code === "job_start_time_passed", `past job returned ${rejectedPast.result.code}`);

    const teenPost = await qaTeen.client.rpc("save_job_draft_or_publish", {
      p_job_id: null,
      p_client_request_id: randomUUID(),
      p_payload: published.payload,
      p_publish: true,
    });
    assertQa(!teenPost.error && teenPost.data?.code === "user_role_not_allowed", "teen account could post jobs");

    const events = await adult.client
      .from("job_status_events")
      .select("to_status")
      .eq("job_id", published.result.job.id)
      .order("created_at");
    assertQa(!events.error && events.data.length >= 3, "job status history was not recorded");
    qaLog(scope, "job lifecycle transitions and status history are persisted");
  },
);
