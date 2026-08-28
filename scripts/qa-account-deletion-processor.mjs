import { createHash, randomBytes, randomUUID } from "node:crypto";
import pg from "pg";
import { createClient } from "@supabase/supabase-js";

const projectRef = "rakjydmgwwgtdislanbt";
const url = `https://${projectRef}.supabase.co`;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const workerSecret = process.env.ACCOUNT_DELETION_WORKER_SECRET;
const dbPassword = process.env.SUPABASE_DB_PASSWORD;

if (!serviceRoleKey || !workerSecret || !dbPassword) {
  throw new Error("Deletion QA requires server-only environment variables.");
}

const admin = createClient(url, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const database = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password: dbPassword,
  ssl: { rejectUnauthorized: false },
});

const email = `deletion-qa-${randomUUID()}@mortapp.test`;
const password = `${randomBytes(24).toString("base64url")}Aa1!`;
const storagePath = `deletion-qa/${randomUUID()}.jpg`;
const storageBucket = "profile-avatars";
let userId;
let requestId;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

await database.connect();
try {
  const existingQaUsers = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (existingQaUsers.error) throw existingQaUsers.error;
  for (const user of existingQaUsers.data.users) {
    if (user.user_metadata?.qa_scope === "account_deletion_processor") {
      await admin.auth.admin.deleteUser(user.id, false);
    }
  }

  const unauthorized = await fetch(`${url}/functions/v1/account-deletion-processor`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
  assert(unauthorized.status === 401, "Worker accepted a request without its server secret.");
  console.log("[qa-account-deletion-processor] PASS: unauthorized invocation rejected");

  const created = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { qa_scope: "account_deletion_processor" },
  });
  if (created.error || !created.data.user) throw created.error ?? new Error("QA user creation failed.");
  userId = created.data.user.id;

  const profile = await admin.from("profiles").select("id").eq("id", userId).maybeSingle();
  if (profile.error) throw profile.error;
  assert(profile.data?.id === userId, "Auth profile trigger did not create the QA profile.");

  const uploaded = await admin.storage
    .from(storageBucket)
    .upload(storagePath, Uint8Array.from([255, 216, 255, 217]), {
      contentType: "image/jpeg",
      upsert: false,
    });
  if (uploaded.error) throw uploaded.error;
  await database.query(
    "update storage.objects set owner_id=$1 where bucket_id=$2 and name=$3",
    [userId, storageBucket, storagePath],
  );

  const fingerprint = createHash("sha256").update(userId).digest("hex");
  const inserted = await admin
    .from("account_deletion_requests")
    .insert({
      user_id: userId,
      requester_fingerprint: fingerprint,
      source: "in_app",
      status: "requested",
      identity_confirmed_at: new Date().toISOString(),
    })
    .select("id")
    .single();
  if (inserted.error) throw inserted.error;
  requestId = inserted.data.id;

  const response = await fetch(`${url}/functions/v1/account-deletion-processor`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-mort-deletion-secret": workerSecret,
    },
    body: JSON.stringify({ requestId }),
  });
  const result = await response.json();
  if (response.status !== 200 || result.ok !== true || result.processed !== 1) {
    const failedState = await admin
      .from("account_deletion_requests")
      .select("status,last_error_code,attempt_count")
      .eq("id", requestId)
      .maybeSingle();
    throw new Error(
      `Worker did not complete the QA deletion (status=${response.status}, code=${result.code ?? "none"}, state=${failedState.data?.status ?? "none"}, worker_code=${failedState.data?.last_error_code ?? "none"}).`,
    );
  }
  assert(
    result.processed === 1,
    "Worker did not report one processed request.",
  );
  assert(result.removedStorageObjects === 1, "Worker did not report the owned storage deletion.");

  const authLookup = await admin.auth.admin.getUserById(userId);
  assert(authLookup.error || !authLookup.data.user, "Deleted QA user can still be loaded from Auth.");
  const deletedProfile = await admin.from("profiles").select("id").eq("id", userId).maybeSingle();
  assert(!deletedProfile.error && deletedProfile.data == null, "Deleted QA profile remains.");
  const request = await admin
    .from("account_deletion_requests")
    .select("status,user_id,last_error_code,retention_summary")
    .eq("id", requestId)
    .single();
  if (request.error) throw request.error;
  assert(request.data.status === "completed", "Deletion request did not reach completed state.");
  assert(request.data.user_id == null, "Deletion audit still directly identifies the deleted profile.");
  assert(request.data.last_error_code == null, "Completed deletion retained an error code.");
  const storageCount = await database.query(
    "select count(*)::integer count from storage.objects where bucket_id=$1 and name=$2",
    [storageBucket, storagePath],
  );
  assert(storageCount.rows[0].count === 0, "Owned storage object remains after deletion.");
  console.log("[qa-account-deletion-processor] PASS: Auth, profile, session boundary, storage, and request state completed");
} finally {
  if (userId) {
    try {
      await admin.storage.from(storageBucket).remove([storagePath]);
    } catch {
      // Continue to Auth cleanup even when the fixture upload did not exist.
    }
    try {
      await admin.auth.admin.deleteUser(userId, false);
    } catch {
      // The successful worker already removed the Auth user.
    }
  }
  if (requestId) {
    await admin.from("account_deletion_requests").delete().eq("id", requestId);
  }
  await database.end();
}
