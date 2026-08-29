import { createClient } from "@supabase/supabase-js";

const currentMismatchedLiveRef = "rakjydmgwwgtdislanbt";
const password = process.env.MORT_LOCAL_TEST_PASSWORD;

const users = {
  teen: "teen.local@mort.test",
  teen2: "teen2.local@mort.test",
  adult: "adult.local@mort.test",
  adult2: "adult2.local@mort.test",
  guardian: "guardian.local@mort.test",
  admin: "admin.local@mort.test"
};

function fail(message) {
  console.error(`RLS QA failed: ${message}`);
  process.exit(1);
}

function log(message) {
  console.log(`[qa-rls] ${message}`);
}

function assertLocalUrl(value, name) {
  if (!value) fail(`Set ${name}.`);
  const url = new URL(value);
  if (!["localhost", "127.0.0.1"].includes(url.hostname)) {
    fail(`${name} must point to localhost or 127.0.0.1. Refusing target: ${url.origin}`);
  }
  if (url.hostname.includes(currentMismatchedLiveRef)) {
    fail("This points at the current mismatched live Supabase project. Use local Supabase for RLS QA.");
  }
  return url;
}

function assertNoError(label, error) {
  if (error) {
    fail(`${label}: ${error.message || JSON.stringify(error)}`);
  }
}

function assertEmpty(label, data, error) {
  assertNoError(label, error);
  if ((data ?? []).length !== 0) {
    fail(`${label}: expected no rows, got ${data.length}.`);
  }
  log(`PASS: ${label}`);
}

// Some tables deny non-owners at the GRANT layer (hard "permission denied")
// on top of RLS, rather than relying solely on RLS to silently return zero
// rows. Either outcome is a correct denial.
function assertDenied(label, data, error) {
  if (error) {
    const denied = error.code === "42501" || /permission denied|row-level security/i.test(error.message || "");
    if (!denied) fail(`${label}: ${error.message || JSON.stringify(error)}`);
    log(`PASS: ${label}`);
    return;
  }
  if ((data ?? []).length !== 0) {
    fail(`${label}: expected no rows, got ${data.length}.`);
  }
  log(`PASS: ${label}`);
}

function assertOne(label, data, error) {
  assertNoError(label, error);
  if ((data ?? []).length !== 1) {
    fail(`${label}: expected one row, got ${(data ?? []).length}.`);
  }
  log(`PASS: ${label}`);
}

async function latestOne(label, query) {
  const { data, error } = await query.limit(1);
  assertNoError(label, error);
  if (!data?.[0]) fail(`${label}: missing seeded fixture.`);
  return data[0];
}

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (process.env.MORT_QA_TARGET !== "local") {
  fail("Set MORT_QA_TARGET=local.");
}

const url = assertLocalUrl(supabaseUrl, "EXPO_PUBLIC_SUPABASE_URL");
if (!anonKey) fail("Set EXPO_PUBLIC_SUPABASE_ANON_KEY.");
if (!serviceRoleKey) fail("Set SUPABASE_SERVICE_ROLE_KEY from local Supabase status.");
if (!password || password.length < 12) fail("Set MORT_LOCAL_TEST_PASSWORD to the temporary local QA password used by the local seeder.");

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});

async function signIn(key) {
  const client = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
  const { data, error } = await client.auth.signInWithPassword({
    email: users[key],
    password
  });
  assertNoError(`sign in ${users[key]}`, error);
  if (!data.user?.id) fail(`sign in ${users[key]} did not return a user id.`);
  return { client, id: data.user.id, email: users[key] };
}

log(`Target local: ${url.origin}`);

const teen = await signIn("teen");
const teen2 = await signIn("teen2");
const adult = await signIn("adult");
const adult2 = await signIn("adult2");
const guardian = await signIn("guardian");
const adminUser = await signIn("admin");

const adultJob = await latestOne(
  "find adult-owned job",
  admin
    .from("jobs")
    .select("id,title,poster_id")
    .eq("poster_id", adult.id)
    .order("created_at", { ascending: false })
);

const application = await latestOne(
  "find teen application",
  admin
    .from("applications")
    .select("id,job_id,teen_id,guardian_id")
    .eq("teen_id", teen.id)
    .order("created_at", { ascending: false })
);

const thread = await latestOne(
  "find application thread",
  admin
    .from("message_threads")
    .select("id,application_id,teen_id,adult_id,guardian_id")
    .eq("application_id", application.id)
);

const pendingVerification = await latestOne(
  "find adult2 pending verification",
  admin
    .from("business_verifications")
    .select("id,status,adult_id")
    .eq("adult_id", adult2.id)
    .order("created_at", { ascending: false })
);

const report = await latestOne(
  "find report fixture",
  admin.from("reports").select("id,reporter_id,status").order("created_at", { ascending: false })
);

const notification = await latestOne(
  "find guardian notification",
  admin
    .from("notifications")
    .select("id,recipient_id,title")
    .eq("recipient_id", guardian.id)
    .order("created_at", { ascending: false })
);

const proof = await latestOne(
  "find proof upload fixture",
  admin
    .from("proof_uploads")
    .select("id,application_id,storage_path,uploaded_by")
    .eq("uploaded_by", teen.id)
    .order("created_at", { ascending: false })
);

const adminLog = await latestOne(
  "find admin log fixture",
  admin.from("admin_action_logs").select("id,admin_id").order("created_at", { ascending: false })
);

const teen2Before = await latestOne(
  "find teen2 profile",
  admin.from("profiles").select("id,display_name").eq("id", teen2.id)
);

const teenUpdateOther = await teen.client
  .from("profiles")
  .update({ display_name: "RLS SHOULD NOT UPDATE TEEN TWO" })
  .eq("id", teen2.id)
  .select("id");
assertEmpty("teen cannot update another teen profile", teenUpdateOther.data, teenUpdateOther.error);

const teen2After = await latestOne(
  "verify teen2 profile unchanged",
  admin.from("profiles").select("id,display_name").eq("id", teen2.id)
);
if (teen2After.display_name !== teen2Before.display_name) {
  fail("teen cannot update another teen profile: display_name changed.");
}

const teenAdminData = await teen.client.from("admin_action_logs").select("id").eq("id", adminLog.id);
assertEmpty("teen cannot access adult/admin data", teenAdminData.data, teenAdminData.error);

const adultJobBefore = adultJob.title;
const adultOtherJobUpdate = await adult2.client
  .from("jobs")
  .update({ title: "RLS SHOULD NOT UPDATE OTHER ADULT JOB" })
  .eq("id", adultJob.id)
  .select("id");
assertEmpty("adult cannot manage another adult's job", adultOtherJobUpdate.data, adultOtherJobUpdate.error);

const adultJobAfter = await latestOne(
  "verify adult job unchanged",
  admin.from("jobs").select("id,title").eq("id", adultJob.id)
);
if (adultJobAfter.title !== adultJobBefore) {
  fail("adult cannot manage another adult's job: title changed.");
}

const guardianUnrelatedTeen = await guardian.client.from("teen_profiles").select("user_id").eq("user_id", teen2.id);
assertEmpty("guardian cannot access unrelated teen", guardianUnrelatedTeen.data, guardianUnrelatedTeen.error);

for (const actor of [teen, adult]) {
  const ownThread = await actor.client.from("message_threads").select("id").eq("id", thread.id);
  assertOne(`${actor.email} can read own conversation`, ownThread.data, ownThread.error);
}

// Guardian Mode may approve/supervise the job (thread.guardian_id is set),
// but public.is_thread_participant() deliberately excludes guardian_id
// (messaging_lifecycle_privacy_and_reliability, 2026-07-30): guardians do not
// get broad access to teen/adult message content.
const guardianThread = await guardian.client.from("message_threads").select("id").eq("id", thread.id);
assertEmpty("guardian cannot read supervised teen's conversation content", guardianThread.data, guardianThread.error);

for (const actor of [teen2, adult2]) {
  const outsiderThread = await actor.client.from("message_threads").select("id").eq("id", thread.id);
  assertEmpty(`${actor.email} cannot read unrelated conversation`, outsiderThread.data, outsiderThread.error);
}

const nonAdminVerificationUpdate = await adult2.client
  .from("business_verifications")
  .update({ status: "approved" })
  .eq("id", pendingVerification.id)
  .select("id,status");
assertDenied("non-admin cannot approve verification", nonAdminVerificationUpdate.data, nonAdminVerificationUpdate.error);

const verificationAfter = await latestOne(
  "verify adult2 verification unchanged",
  admin.from("business_verifications").select("id,status").eq("id", pendingVerification.id)
);
if (verificationAfter.status !== pendingVerification.status) {
  fail("non-admin cannot approve verification: status changed.");
}

const adultReportQueue = await adult2.client.from("reports").select("id").eq("id", report.id);
assertEmpty("non-admin cannot view report admin queue", adultReportQueue.data, adultReportQueue.error);

const adultAdminLogQueue = await adult2.client.from("admin_action_logs").select("id").eq("id", adminLog.id);
assertEmpty("non-admin cannot view admin action queue", adultAdminLogQueue.data, adultAdminLogQueue.error);

const ownNotification = await guardian.client.from("notifications").select("id").eq("id", notification.id);
assertOne("user can read own notifications", ownNotification.data, ownNotification.error);

const otherNotification = await teen.client.from("notifications").select("id").eq("id", notification.id);
assertEmpty("user cannot read another user's notifications", otherNotification.data, otherNotification.error);

const publicStorage = createClient(supabaseUrl, anonKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});
const publicDownload = await publicStorage.storage.from("proof-uploads").download(proof.storage_path);
if (!publicDownload.error) {
  fail("private upload paths are not public: anonymous download succeeded.");
}
log("PASS: private upload paths are not public");

const ownerSignedUrl = await teen.client.storage.from("proof-uploads").createSignedUrl(proof.storage_path, 60);
assertNoError("owner can create signed proof preview URL", ownerSignedUrl.error);
if (!ownerSignedUrl.data?.signedUrl) {
  fail("owner can create signed proof preview URL: missing signedUrl.");
}
log("PASS: owner can create signed proof preview URL");

const adminCanReadAdminQueue = await adminUser.client.from("admin_action_logs").select("id").eq("id", adminLog.id);
assertOne("admin can read admin queue", adminCanReadAdminQueue.data, adminCanReadAdminQueue.error);

log("RLS QA passed.");
