// Adversarial concurrency test for quick_accept_job_v1 (Section 57 of the
// public-production directive): N simultaneous Teen claims on ONE
// single-worker, quick-accept-eligible job must produce EXACTLY ONE
// success; every other caller must get a clean, non-crashing denial
// (ideally 'offer_taken'), and the job must never end up double-assigned.
//
// NOT YET RUNNABLE: requires migration
// supabase/migrations/20260818200000_quick_accept_job_v1.sql to be applied
// first (blocked by the harness's own production-DDL auto-mode classifier
// this session -- see docs/CLAUDE_DIVINE_COMPLETION_PROGRESS.md). Written
// now so it's ready to run the moment the migration lands.
import { randomUUID } from "node:crypto";
import { saveJob, withQaUsers } from "./feature-qa-helpers.mjs";

const scope = "qa-quick-accept-concurrency";
const CLAIMANT_COUNT = 25;

async function run() {
  const userDefinitions = [
    { key: "adult", role: "adult" },
    ...Array.from({ length: CLAIMANT_COUNT }, (_, i) => ({
      key: `teen_${i}`,
      role: "teen",
    })),
  ];

  await withQaUsers(scope, userDefinitions, async (users) => {
    const adult = users.adult.client;

    // quick_accept_eligible is set via save_job_draft_or_publish's payload
    // (migration 20260818210000_quick_accept_job_opt_in.sql) -- public.jobs
    // has zero direct UPDATE RLS policies (confirmed empirically: writes
    // are RPC-mediated only), so a client-side .from('jobs').update(...)
    // would silently affect zero rows.
    const { result: job } = await saveJob(
      adult,
      { workers_needed: 1, quick_accept_eligible: true },
      true,
    );
    if (job?.ok !== true) {
      throw new Error(`job publish failed: ${JSON.stringify(job)}`);
    }
    const jobId = job.job.id;
    if (job.job.quick_accept_eligible !== true) {
      throw new Error(
        `job did not persist quick_accept_eligible=true: ${JSON.stringify(job.job)}`,
      );
    }

    const claimants = Array.from({ length: CLAIMANT_COUNT }, (_, i) => users[`teen_${i}`].client);

    console.log(`[${scope}] firing ${CLAIMANT_COUNT} simultaneous quick_accept_job_v1 calls...`);
    const results = await Promise.all(
      claimants.map((client) =>
        client.rpc("quick_accept_job_v1", {
          p_job_id: jobId,
          p_client_request_id: randomUUID(),
        }),
      ),
    );

    const successes = results.filter((r) => !r.error && r.data?.ok === true);
    const offerTaken = results.filter((r) => !r.error && r.data?.code === "offer_taken");
    const otherDenials = results.filter(
      (r) => !r.error && r.data?.ok === false && r.data?.code !== "offer_taken",
    );
    const transportErrors = results.filter((r) => r.error);

    console.log(`[${scope}] successes=${successes.length} offer_taken=${offerTaken.length} other_denials=${otherDenials.length} transport_errors=${transportErrors.length}`);
    if (otherDenials.length > 0) {
      console.log(`[${scope}] other denial codes: ${otherDenials.map((r) => r.data.code).join(", ")}`);
    }
    if (transportErrors.length > 0) {
      console.log(`[${scope}] transport errors: ${transportErrors.map((r) => r.error.message).slice(0, 3).join(" | ")}`);
    }

    const { data: finalJob, error: finalJobError } = await adult
      .from("jobs")
      .select("status, applications_open")
      .eq("id", jobId)
      .single();
    if (finalJobError) throw new Error(`could not re-read job: ${finalJobError.message}`);

    const failures = [];
    if (successes.length !== 1) {
      failures.push(`expected exactly 1 success, got ${successes.length}`);
    }
    if (transportErrors.length > 0) {
      failures.push(`${transportErrors.length} calls errored at the transport level instead of returning a clean denial`);
    }
    if (finalJob.status !== "assigned" || finalJob.applications_open !== false) {
      failures.push(`job ended in an inconsistent state: ${JSON.stringify(finalJob)}`);
    }

    if (failures.length > 0) {
      console.error(`[${scope}] FAIL:\n  - ${failures.join("\n  - ")}`);
      process.exitCode = 1;
    } else {
      console.log(`[${scope}] PASS: exactly one winner among ${CLAIMANT_COUNT} simultaneous claimants, job correctly assigned+closed, no transport errors`);
    }
  });
}

run().catch((error) => {
  console.error(`[${scope}] ERROR: ${error.message}`);
  process.exitCode = 1;
});
