import {
  assertQa,
  qaLog,
  saveJob,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-saved-jobs";

await withQaUsers(
  scope,
  [
    { key: "adult", role: "adult" },
    { key: "teen", role: "teen" },
    { key: "otherTeen", role: "teen" },
  ],
  async ({ adult, teen, otherTeen }) => {
    const job = await saveJob(adult.client, {
      title: "QA Feature Saved Job",
      summary: "A staffed public job for saved job persistence and RLS.",
    });
    assertQa(job.result?.ok === true, "saved-jobs fixture did not publish");

    const [role, testStatus, visibleJob] = await Promise.all([
      teen.client.rpc("current_profile_role"),
      teen.client.rpc("current_profile_is_test"),
      teen.client.from("jobs").select("id,status,is_test").eq("id", job.result.job.id).single(),
    ]);
    assertQa(!role.error && role.data === "teen", `saved-jobs actor role is invalid: ${role.error?.message ?? role.data}`);
    assertQa(!testStatus.error && testStatus.data === true, `saved-jobs actor test status is invalid: ${testStatus.error?.message ?? testStatus.data}`);
    assertQa(
      !visibleJob.error && visibleJob.data?.status === "open" && visibleJob.data?.is_test === true,
      `saved-jobs fixture is not visible and open: ${visibleJob.error?.message ?? JSON.stringify(visibleJob.data)}`,
    );

    for (let attempt = 0; attempt < 2; attempt += 1) {
      const saved = await teen.client
        .from("saved_jobs")
        .upsert({ user_id: teen.id, job_id: job.result.job.id })
        .select("user_id,job_id");
      assertQa(!saved.error && saved.data.length === 1, `save attempt ${attempt + 1} failed: ${saved.error?.message}`);
    }
    const ownSaved = await teen.client
      .from("saved_jobs")
      .select("job_id,jobs(id,title,status,is_test)")
      .eq("job_id", job.result.job.id);
    assertQa(!ownSaved.error && ownSaved.data.length === 1, "saved job was not persisted");
    assertQa(ownSaved.data[0].jobs?.id === job.result.job.id, "saved job relation was not visible");
    qaLog(scope, "save is persistent and idempotent for one teen/job pair");

    const otherRead = await otherTeen.client
      .from("saved_jobs")
      .select("job_id")
      .eq("user_id", teen.id);
    assertQa(!otherRead.error && otherRead.data.length === 0, "another teen read saved jobs");
    const otherDelete = await otherTeen.client
      .from("saved_jobs")
      .delete()
      .eq("user_id", teen.id)
      .eq("job_id", job.result.job.id)
      .select("job_id");
    assertQa(otherDelete.error || otherDelete.data.length === 0, "another teen removed a saved job");
    qaLog(scope, "saved job rows are isolated by user RLS");

    const canceled = await adult.client.rpc("manage_job", {
      p_job_id: job.result.job.id,
      p_action: "cancel",
    });
    assertQa(canceled.data?.ok === true && canceled.data.job.status === "canceled", "fixture job did not cancel");
    const unavailableSaved = await teen.client.rpc("list_my_saved_jobs");
    assertQa(!unavailableSaved.error, "saved canceled job disappeared before the teen could remove it");
    const unavailableJob = unavailableSaved.data.find((item) => item.id === job.result.job.id);
    assertQa(
      unavailableJob?.status === "canceled",
      `saved job did not expose current unavailable status: ${JSON.stringify(unavailableJob)}`,
    );
    const unrelatedSaved = await otherTeen.client.rpc("list_my_saved_jobs");
    assertQa(
      !unrelatedSaved.error && !unrelatedSaved.data.some((item) => item.id === job.result.job.id),
      "owner-scoped saved-jobs RPC exposed another teen's row",
    );
    qaLog(scope, "saved jobs retain current canceled/closed status for cleanup");

    const removed = await teen.client
      .from("saved_jobs")
      .delete()
      .eq("user_id", teen.id)
      .eq("job_id", job.result.job.id)
      .select("job_id");
    assertQa(!removed.error && removed.data.length === 1, "owner could not unsave unavailable job");
    qaLog(scope, "owner can unsave an unavailable job");
  },
);
