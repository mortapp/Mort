import { pathToFileURL } from "node:url";

const qa = "ckcxakhxqlkhppsxxjhv";
const sha = /^[0-9a-f]{40}$/;
const positiveInteger = /^[1-9]\d*$/;
const utc = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|\+00:00)$/;

function parseUtc(value) {
  if (typeof value !== "string" || !utc.test(value)) return NaN;
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) return NaN;
  // Date.parse can normalize an invalid date, e.g. February 30.
  if (new Date(timestamp).toISOString().slice(0, 19) !== value.slice(0, 19)) return NaN;
  return timestamp;
}

export function validateCurrentRunEvidence(payload, context, now = Date.now()) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("invalid_evidence_object");
  }
  if (context.projectRef !== qa || payload.project_ref !== qa ||
      payload.environment !== "test" || payload.mode !== "sandbox" ||
      payload.live_mode_detected !== false || payload.provider_e2e_executed !== true) {
    throw new Error("not_isolated_qa_sandbox_evidence");
  }
  if (!sha.test(context.commitSha ?? "") || payload.commit_sha !== context.commitSha) {
    throw new Error("commit_mismatch");
  }
  for (const [actual, expected, reason] of [
    [payload.workflow_run_id, context.runId, "run_mismatch"],
    [payload.workflow_run_attempt, context.runAttempt, "attempt_mismatch"],
  ]) {
    if (!positiveInteger.test(expected ?? "") || String(actual) !== expected) {
      throw new Error(reason);
    }
  }
  const windowStart = parseUtc(context.notBefore);
  const completed = parseUtc(payload.completed_at);
  if (!Number.isFinite(windowStart) || !Number.isFinite(completed) ||
      windowStart > now || completed < windowStart || completed > now) {
    throw new Error("completion_outside_evidence_window");
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const chunks = [];
    let size = 0;
    for await (const chunk of process.stdin) {
      size += chunk.length;
      if (size > 128 * 1024) throw new Error("evidence_too_large");
      chunks.push(chunk);
    }
    let payload;
    try {
      payload = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    } catch {
      throw new Error("invalid_evidence_json");
    }
    validateCurrentRunEvidence(payload, {
      projectRef: process.argv[2],
      commitSha: process.env.GITHUB_SHA,
      runId: process.env.GITHUB_RUN_ID,
      runAttempt: process.env.GITHUB_RUN_ATTEMPT,
      notBefore: process.env.MORT_STRIPE_EVIDENCE_NOT_BEFORE,
    });
    console.log("Current-run Stripe evidence metadata matches; no provider actions performed.");
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
