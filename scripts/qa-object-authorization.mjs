import { randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import {
  assertQa, qaLog, saveJob, sendSafeMessage, serviceClient, supabaseUrl,
  withDatabase, withQaUsers,
} from "./feature-qa-helpers.mjs";

// This adversarial suite creates disposable actors only on the named MORT stack.
const api = new URL(supabaseUrl);
const database = new URL(process.env.SUPABASE_DB_URL || "invalid:");
assertQa(process.env.MORT_QA_LOCAL_SUPABASE === "true" &&
  api.hostname === "127.0.0.1" && api.port === "54321" &&
  database.hostname === "127.0.0.1" && database.port === "54322",
"Object authorization QA requires the local MORT API 54321 and database 54322.");
assertQa(execFileSync("docker", ["inspect", "--format",
  '{{ index .Config.Labels "com.supabase.cli.project" }}', "supabase_db_mort-mobile"],
{ encoding: "utf8" }).trim() === "mort-mobile", "Local MORT container identity mismatch.");

const scope = "qa-object-authorization";
const failures = [];
function check(condition, label) {
  if (condition) qaLog(scope, label);
  else { failures.push(label); console.error(`[${scope}] FAIL: ${label}`); }
}
function denied(result) { return Boolean(result.error) || result.data?.length === 0; }
function ok(result, label) {
  assertQa(!result.error && result.data?.ok === true,
    `${label}: ${result.error?.message || JSON.stringify(result.data)}`);
  return result.data;
}

await withQaUsers(scope, [
  { key: "teen", role: "teen" }, { key: "outsider", role: "teen" },
  { key: "adult", role: "adult" }, { key: "otherAdult", role: "adult" },
  { key: "normalTeen", role: "teen", isTest: false },
], async ({ teen, outsider, adult, otherAdult, normalTeen }) => {
  const draft = await saveJob(adult.client, { title: "QA private object draft" }, false);
  assertQa(draft.result?.ok === true, "draft creation failed");
  const hiddenId = draft.result.job.id;
  const hidden = await outsider.client.from("jobs").select("id").eq("id", hiddenId);
  check(denied(hidden), "unrelated user cannot read private draft through table RLS");
  const hiddenEligibility = await outsider.client.rpc("get_pilot_job_eligibility", { p_job_id: hiddenId });
  check(Boolean(hiddenEligibility.error) || hiddenEligibility.data?.ok === false,
    "eligibility RPC cannot disclose another user's private draft");
  const ownEligibility = await adult.client.rpc("get_pilot_job_eligibility", { p_job_id: hiddenId });
  check(!ownEligibility.error && ownEligibility.data?.job_id === hiddenId,
    "poster can inspect own draft eligibility");

  const published = await saveJob(adult.client, { title: "QA object authorization job" });
  assertQa(published.result?.ok === true, "job publish failed");
  const jobId = published.result.job.id;
  ok(await adult.client.rpc("save_job_private_location", {
    p_job_id: jobId, p_latitude: 39.78, p_longitude: -86.16,
  }), "synthetic private location creation");
  check(denied(await normalTeen.client.from("jobs").select("id").eq("id", jobId)),
    "normal account cannot read the isolated QA job");
  const distances = await normalTeen.client.rpc("get_nearby_job_distances_v1", {
    p_job_ids: [jobId], p_latitude: 39.7, p_longitude: -86.1,
  });
  check(Boolean(distances.error) || !(distances.data?.distances || []).some(row => row.job_id === jobId),
    "distance RPC cannot reveal location-derived data for an invisible job");
  const ownDistances = await teen.client.rpc("get_nearby_job_distances_v1", {
    p_job_ids: [jobId], p_latitude: 39.7, p_longitude: -86.1,
  });
  check(!ownDistances.error && ownDistances.data?.distances?.some(row => row.job_id === jobId),
    "verified marketplace user retains distance lookup for visible jobs");
  await withDatabase(db => db.query("update public.jobs set pilot_review_status='blocked' where id=$1", [jobId]));
  check(denied(await teen.client.from("jobs").select("id").eq("id", jobId)),
    "pilot-restricted job is hidden by the restrictive job policy");
  const restrictedDistances = await teen.client.rpc("get_nearby_job_distances_v1", {
    p_job_ids: [jobId], p_latitude: 39.7, p_longitude: -86.1,
  });
  check(Boolean(restrictedDistances.error) || !(restrictedDistances.data?.distances || []).some(row => row.job_id === jobId),
    "distance RPC honors the restrictive pilot visibility gate");
  await withDatabase(db => db.query("update public.jobs set pilot_review_status='eligible' where id=$1", [jobId]));
  const eligible = await teen.client.rpc("get_pilot_job_eligibility", { p_job_id: jobId });
  check(!eligible.error && eligible.data?.job_id === jobId,
    "eligible marketplace user can inspect a visible job");
  const application = ok(await teen.client.rpc("submit_job_application", {
    p_job_id: jobId, p_note: "Synthetic object authorization fixture.",
    p_availability_confirmed: true, p_portfolio_ids: [],
  }), "application creation").application;
  const loaded = await teen.client.from("message_threads").select("*")
    .eq("application_id", application.id).single();
  assertQa(!loaded.error && loaded.data, "server-created thread missing");
  const thread = loaded.data;
  const sent = await sendSafeMessage(teen.client, thread.id,
    "This private synthetic message belongs to the original participants.");
  assertQa(!sent.error && sent.data?.id, "synthetic message creation failed");
  const message = sent.data;
  check(denied(await outsider.client.from("messages").select("id").eq("id", message.id)),
    "outsider cannot read original thread message");

  // Each attempt is reset using the service fixture path so probes are independent.
  for (const [label, patch] of [
    ["adult participant", { adult_id: otherAdult.id }],
    ["teen participant", { teen_id: outsider.id }],
    ["job parent", { job_id: hiddenId }],
    ["application parent", { application_id: null }],
    ["lifecycle", { lifecycle_status: "read_only", closure_reason: "forged closure" }],
  ]) {
    const changed = await teen.client.from("message_threads").update(patch)
      .eq("id", thread.id).select("id");
    check(denied(changed), `client cannot rewrite thread ${label}`);
    if (label === "adult participant") {
      check(denied(await otherAdult.client.from("messages").select("id").eq("id", message.id)),
        "participant substitution cannot expose historical private messages");
    }
    const restore = await serviceClient.from("message_threads").update({
      job_id: thread.job_id, application_id: thread.application_id,
      teen_id: thread.teen_id, adult_id: thread.adult_id,
      lifecycle_status: thread.lifecycle_status, closure_reason: thread.closure_reason,
    }).eq("id", thread.id);
    assertQa(!restore.error, "synthetic thread restore failed");
  }
  const injected = await teen.client.from("message_threads").insert({
    job_id: hiddenId, application_id: null, teen_id: teen.id, adult_id: otherAdult.id,
  }).select("id");
  check(denied(injected), "client cannot create arbitrary thread participants or parents");
  const stillReadable = await adult.client.from("messages").select("id").eq("id", message.id);
  check(!stillReadable.error && stillReadable.data?.length === 1,
    "original participant retains message access after denied mutations");

  // Synthetic completed work establishes a valid reference request control.
  await withDatabase(async (db) => {
    await db.query("update public.applications set status='completed' where id=$1", [application.id]);
  });
  const selfApprovedInsert = await teen.client.from("work_reference_requests").insert({
    requester_id: teen.id, application_id: application.id, requested_from: adult.id,
    status: "provided", reference_text: "Forged preapproved request written by the worker.",
  }).select("id");
  check(denied(selfApprovedInsert), "request creation cannot include a forged recipient response");
  if (!selfApprovedInsert.error && selfApprovedInsert.data?.length) {
    await withDatabase(db => db.query("delete from public.work_reference_requests where id=$1", [selfApprovedInsert.data[0].id]));
  }
  const reference = await teen.client.from("work_reference_requests").insert({
    requester_id: teen.id, application_id: application.id, requested_from: adult.id,
  }).select("*").single();
  assertQa(!reference.error && reference.data?.id,
    `legitimate reference creation failed: ${reference.error?.message}`);
  const ref = reference.data;
  const selfApprove = await teen.client.from("work_reference_requests").update({
    status: "provided", reference_text: "Forged approval written by the requesting worker.",
    responded_at: new Date().toISOString(),
  }).eq("id", ref.id).select("id");
  check(denied(selfApprove), "requester cannot provide or self-approve their own reference");
  await withDatabase(db => db.query(
    "update public.work_reference_requests set status='pending',reference_text=null,responded_at=null where id=$1", [ref.id]));
  for (const [label, actor, patch] of [
    ["recipient", teen, { requested_from: otherAdult.id }],
    ["requester", adult, { requester_id: outsider.id }],
    ["application", teen, { application_id: randomUUID() }],
    ["record ID", teen, { id: randomUUID() }],
  ]) {
    const changed = await actor.client.from("work_reference_requests").update(patch)
      .eq("id", ref.id).select("id");
    check(denied(changed), `reference ${label} cannot be reassigned by a participant`);
    await withDatabase((db) => db.query(
      "update public.work_reference_requests set requester_id=$2,requested_from=$3 where id=$1",
      [ref.id, teen.id, adult.id]));
  }
  const foreignUpdate = await outsider.client.from("work_reference_requests")
    .update({ status: "withdrawn" }).eq("id", ref.id).select("id");
  check(denied(foreignUpdate), "outsider cannot update another participant's work reference");
  const foreignDelete = await outsider.client.from("work_reference_requests")
    .delete().eq("id", ref.id).select("id");
  check(denied(foreignDelete), "outsider cannot delete another participant's work reference");
  const badRecipient = await teen.client.from("work_reference_requests").insert({
    requester_id: teen.id, application_id: application.id, requested_from: otherAdult.id,
  }).select("id");
  check(denied(badRecipient), "reference recipient must be the completed job poster");
  check(denied(await outsider.client.from("work_reference_requests").select("id").eq("id", ref.id)),
    "outsider cannot read another participant's work reference");
  const respond = await adult.client.from("work_reference_requests").update({
    status: "provided", reference_text: "Synthetic worker followed the agreed safe job instructions.",
    responded_at: new Date().toISOString(),
  }).eq("id", ref.id).select("id");
  check(!respond.error && respond.data?.length === 1, "original reference recipient can respond");
  const recipientEdit = await adult.client.from("work_reference_requests").update({
    reference_text: "Synthetic recipient clarified their own safe work reference response.",
  }).eq("id", ref.id).select("id");
  check(!recipientEdit.error && recipientEdit.data?.length === 1,
    "original reference recipient can edit their own response before withdrawal");
  const editResponse = await teen.client.from("work_reference_requests").update({
    reference_text: "Worker rewrote the recipient's completed reference response.",
  }).eq("id", ref.id).select("id");
  check(denied(editResponse), "requester cannot edit the recipient's response");
  const withdraw = await teen.client.from("work_reference_requests").update({ status: "withdrawn" })
    .eq("id", ref.id).select("id");
  check(!withdraw.error && withdraw.data?.length === 1, "original reference requester can withdraw");
  const revive = await adult.client.from("work_reference_requests").update({ status: "provided" })
    .eq("id", ref.id).select("id");
  check(denied(revive), "recipient cannot revive a withdrawn reference request");
});

assertQa(failures.length === 0, `${failures.length} object authorization checks failed: ${failures.join("; ")}`);
qaLog(scope, "all object ownership, parent, participant, and legitimate-control checks passed");
