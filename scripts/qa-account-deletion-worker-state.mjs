// Local-only durable regression for the account-deletion worker state machine.
// Proves one-winner concurrent claiming, service-role isolation, lock binding,
// and replay-safe terminal behavior without invoking or mutating hosted state.
import { createHash, randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !anonKey || !serviceRoleKey) {
  throw new Error("Set local Supabase URL, anon key, and service-role key.");
}
if (!/127\.0\.0\.1|localhost/.test(url)) {
  throw new Error(`Refusing non-local account-deletion worker target: ${url}`);
}

const admin = createClient(url, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const password = "LocalDeletionWorkerQa-2026!";
const email = `deletion-worker-${randomUUID()}@mort.test`;
let userId;
let requestId;

function assertQa(condition, message) {
  if (!condition) throw new Error(message);
  console.log(`PASS: ${message}`);
}

try {
  const created = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (created.error || !created.data.user) throw created.error;
  userId = created.data.user.id;

  const inserted = await admin
    .from("account_deletion_requests")
    .insert({
      user_id: userId,
      requester_fingerprint: createHash("sha256").update(userId).digest("hex"),
      source: "in_app",
      status: "requested",
      identity_confirmed_at: new Date().toISOString(),
    })
    .select("id")
    .single();
  if (inserted.error) throw inserted.error;
  requestId = inserted.data.id;

  const userClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const signedIn = await userClient.auth.signInWithPassword({ email, password });
  if (signedIn.error) throw signedIn.error;
  const unauthorized = await userClient.rpc(
    "service_claim_account_deletion_request",
    { p_request_id: requestId },
  );
  assertQa(
    Boolean(unauthorized.error) || unauthorized.data?.code === "service_role_required",
    "authenticated clients cannot claim worker jobs",
  );

  const [first, second] = await Promise.all([
    admin.rpc("service_claim_account_deletion_request", { p_request_id: requestId }),
    admin.rpc("service_claim_account_deletion_request", { p_request_id: requestId }),
  ]);
  if (first.error) throw first.error;
  if (second.error) throw second.error;
  const winners = [first.data, second.data].filter((result) => result?.ok === true);
  const losers = [first.data, second.data].filter(
    (result) => result?.code === "deletion_request_unavailable",
  );
  assertQa(
    winners.length === 1 && losers.length === 1,
    "concurrent claim has exactly one winner and one safe loser",
  );

  const lockId = winners[0].request.processor_lock_id;
  const wrongLock = await admin.rpc("service_complete_account_deletion_request", {
    p_request_id: requestId,
    p_processor_lock_id: randomUUID(),
    p_retention_summary: "local QA wrong lock",
  });
  if (wrongLock.error) throw wrongLock.error;
  assertQa(
    wrongLock.data?.ok === false && wrongLock.data?.code === "deletion_lock_mismatch",
    "malformed completion lock is denied",
  );

  const completed = await admin.rpc("service_complete_account_deletion_request", {
    p_request_id: requestId,
    p_processor_lock_id: lockId,
    p_retention_summary: "local QA completion",
  });
  if (completed.error) throw completed.error;
  assertQa(completed.data?.ok === true, "valid lock completes one logical request");

  const replay = await admin.rpc("service_complete_account_deletion_request", {
    p_request_id: requestId,
    p_processor_lock_id: lockId,
    p_retention_summary: "local QA replay",
  });
  if (replay.error) throw replay.error;
  assertQa(
    replay.data?.ok === false && replay.data?.code === "deletion_lock_mismatch",
    "completion replay cannot create a second transition",
  );

  const postCompletionClaim = await admin.rpc(
    "service_claim_account_deletion_request",
    { p_request_id: requestId },
  );
  if (postCompletionClaim.error) throw postCompletionClaim.error;
  assertQa(
    postCompletionClaim.data?.ok === false &&
      postCompletionClaim.data?.code === "deletion_request_unavailable",
    "completed request cannot be reclaimed",
  );

  console.log("\n[qa-account-deletion-worker-state] PASS: all scenarios green.");
} finally {
  if (userId) await admin.auth.admin.deleteUser(userId, false).catch(() => {});
  if (requestId) {
    await admin.from("account_deletion_requests").delete().eq("id", requestId);
  }
}
