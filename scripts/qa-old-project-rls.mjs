import { createClient } from "@supabase/supabase-js";

const oldProjectRef = "rakjydmgwwgtdislanbt";
const oldProjectUrl = `https://${oldProjectRef}.supabase.co`;
const password = process.env.MORT_REBUILD_TEST_PASSWORD;

const users = {
  teen: "teen.rebuild@mort.test",
  teen2: "teen2.rebuild@mort.test",
  adult: "adult.rebuild@mort.test",
  adult2: "adult2.rebuild@mort.test",
  guardian: "guardian.rebuild@mort.test",
  admin: "admin.rebuild@mort.test"
};

function fail(message) {
  console.error(`Old-project RLS QA failed: ${message}`);
  process.exit(1);
}

function log(message) {
  console.log(`[qa-old-project-rls] ${message}`);
}

function assertNoError(label, error) {
  if (error) fail(`${label}: ${error.message || JSON.stringify(error)}`);
}

function assertEmpty(label, data, error) {
  assertNoError(label, error);
  if ((data ?? []).length !== 0) fail(`${label}: expected no rows, got ${data.length}.`);
  log(`PASS: ${label}`);
}

function assertOne(label, data, error) {
  assertNoError(label, error);
  if ((data ?? []).length !== 1) fail(`${label}: expected one row, got ${(data ?? []).length}.`);
  log(`PASS: ${label}`);
}

function assertRejectedOrEmpty(label, data, error) {
  if (error) {
    log(`PASS: ${label}`);
    return;
  }

  if ((data ?? []).length !== 0) fail(`${label}: expected rejection or no rows, got ${data.length}.`);
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

if (process.env.MORT_QA_TARGET !== "old-project-rebuild") fail("Set MORT_QA_TARGET=old-project-rebuild.");
if (process.env.MORT_REUSE_OLD_PROJECT_REF !== oldProjectRef) fail(`Set MORT_REUSE_OLD_PROJECT_REF=${oldProjectRef}.`);
if (supabaseUrl !== oldProjectUrl) fail(`EXPO_PUBLIC_SUPABASE_URL must be ${oldProjectUrl}.`);
if (!anonKey) fail("Set EXPO_PUBLIC_SUPABASE_ANON_KEY.");
if (!serviceRoleKey) fail("Set SUPABASE_SERVICE_ROLE_KEY from the current rotated old-project key.");
if (!password || password.length < 12) fail("Set MORT_REBUILD_TEST_PASSWORD to the temporary QA password used by the old-project seeder.");

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

log(`Target old project: ${oldProjectUrl}`);

const teen = await signIn("teen");
const teen2 = await signIn("teen2");
const adult = await signIn("adult");
const adult2 = await signIn("adult2");
const guardian = await signIn("guardian");
const adminUser = await signIn("admin");

const adultJob = await latestOne(
  "find adult-owned job",
  admin.from("jobs").select("id,title,poster_id").eq("poster_id", adult.id).order("created_at", { ascending: false })
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

const teen2Before = await latestOne("find teen2 profile", admin.from("profiles").select("id,display_name").eq("id", teen2.id));

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
if (teen2After.display_name !== teen2Before.display_name) fail("teen cannot update another teen profile: display_name changed.");

const teenAdminData = await teen.client.from("admin_action_logs").select("id").eq("id", adminLog.id);
assertEmpty("teen cannot access admin action logs", teenAdminData.data, teenAdminData.error);

const adultJobBefore = adultJob.title;
const adultOtherJobUpdate = await adult2.client
  .from("jobs")
  .update({ title: "RLS SHOULD NOT UPDATE OTHER ADULT JOB" })
  .eq("id", adultJob.id)
  .select("id");
assertEmpty("adult cannot manage another adult's job", adultOtherJobUpdate.data, adultOtherJobUpdate.error);

const adultJobAfter = await latestOne("verify adult job unchanged", admin.from("jobs").select("id,title").eq("id", adultJob.id));
if (adultJobAfter.title !== adultJobBefore) fail("adult cannot manage another adult's job: title changed.");

const guardianUnrelatedTeen = await guardian.client.from("teen_profiles").select("user_id").eq("user_id", teen2.id);
assertEmpty("guardian cannot access unrelated teen", guardianUnrelatedTeen.data, guardianUnrelatedTeen.error);

for (const actor of [teen, adult, guardian]) {
  const ownThread = await actor.client.from("message_threads").select("id").eq("id", thread.id);
  assertOne(`${actor.email} can read own conversation`, ownThread.data, ownThread.error);
}

for (const actor of [teen2, adult2]) {
  const outsiderThread = await actor.client.from("message_threads").select("id").eq("id", thread.id);
  assertEmpty(`${actor.email} cannot read unrelated conversation`, outsiderThread.data, outsiderThread.error);
}

const nonAdminVerificationUpdate = await adult2.client
  .from("business_verifications")
  .update({ status: "approved" })
  .eq("id", pendingVerification.id)
  .select("id,status");
assertEmpty("non-admin cannot approve verification", nonAdminVerificationUpdate.data, nonAdminVerificationUpdate.error);

const verificationAfter = await latestOne(
  "verify adult2 verification unchanged",
  admin.from("business_verifications").select("id,status").eq("id", pendingVerification.id)
);
if (verificationAfter.status !== pendingVerification.status) fail("non-admin cannot approve verification: status changed.");

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
if (!publicDownload.error) fail("private upload paths are not public: anonymous download succeeded.");
log("PASS: private upload paths are not public");

const ownerSignedUrl = await teen.client.storage.from("proof-uploads").createSignedUrl(proof.storage_path, 60);
assertNoError("owner can create signed proof preview URL", ownerSignedUrl.error);
if (!ownerSignedUrl.data?.signedUrl) fail("owner can create signed proof preview URL: missing signedUrl.");
log("PASS: owner can create signed proof preview URL");

const adminCanReadAdminQueue = await adminUser.client.from("admin_action_logs").select("id").eq("id", adminLog.id);
assertOne("admin can read admin queue", adminCanReadAdminQueue.data, adminCanReadAdminQueue.error);

const ownAdPreferences = await teen.client
  .from("user_ad_preferences")
  .upsert({
    user_id: teen.id,
    personalized_ads_allowed: false,
    ads_consent_ready: false,
    age_restricted_ads: true
  })
  .select("user_id");
assertOne("user can upsert own ad preferences", ownAdPreferences.data, ownAdPreferences.error);

const otherAdPreferences = await teen2.client.from("user_ad_preferences").select("user_id").eq("user_id", teen.id);
assertEmpty("user cannot read another user's ad preferences", otherAdPreferences.data, otherAdPreferences.error);

const forgedEntitlement = await teen.client
  .from("monetization_entitlements_cache")
  .insert({ user_id: teen.id, entitlements: ["mort_premium"], source: "app" })
  .select("user_id");
assertRejectedOrEmpty("user cannot forge entitlement cache", forgedEntitlement.data, forgedEntitlement.error);

const paywallEvent = await teen.client.rpc("record_paywall_event", {
  p_event_type: "viewed",
  p_placement: "old-project-rls",
  p_offering_id: null,
  p_package_id: null,
  p_product_id: null,
  p_error_message: null
});
assertNoError("user can record own paywall event", paywallEvent.error);
if (!paywallEvent.data) fail("user can record own paywall event: missing id.");
log("PASS: user can record own paywall event");

const adImpression = await teen.client.rpc("record_ad_impression", {
  p_placement: "old-project-rls",
  p_ad_format: "banner",
  p_ad_unit_id: "test-ad-unit",
  p_request_non_personalized: true
});
assertNoError("user can record own ad impression", adImpression.error);
if (!adImpression.data) fail("user can record own ad impression: missing id.");
log("PASS: user can record own ad impression");

const directUsernameUpdate = await teen.client
  .from("profiles")
  .update({ username: `direct_${Date.now().toString(36)}` })
  .eq("id", teen.id)
  .select("id");
if (!directUsernameUpdate.error) fail("user cannot update username directly: expected error.");
log("PASS: user cannot update username directly");

const usernameStatus = await teen.client.rpc("get_username_change_status");
assertNoError("user can read own username change status", usernameStatus.error);
if (!usernameStatus.data?.[0]) fail("user can read own username change status: missing status row.");
log("PASS: user can read own username change status");

const nonAdminGrant = await teen.client.rpc("admin_grant_username_change_credit", {
  p_user_id: teen.id,
  p_credit_count: 1,
  p_reason: "rls-negative-check"
});
if (!nonAdminGrant.error) fail("non-admin cannot grant username credits: expected error.");
log("PASS: non-admin cannot grant username credits");

const adminGrant = await adminUser.client.rpc("admin_grant_username_change_credit", {
  p_user_id: teen.id,
  p_credit_count: 1,
  p_reason: "old-project-rls"
});
assertNoError("admin can grant username credits", adminGrant.error);
log("PASS: admin can grant username credits");

const nextUsername = `qa_${Date.now().toString(36).slice(-8)}`;
const usernameChange = await teen.client.rpc("request_username_change", {
  p_new_username: nextUsername
});
assertNoError("user can request valid username change", usernameChange.error);
if (usernameChange.data?.[0]?.username !== nextUsername) {
  fail("user can request valid username change: returned username mismatch.");
}
log("PASS: user can request valid username change");

const unsafeUsername = await teen.client.rpc("request_username_change", {
  p_new_username: "admin_support"
});
if (!unsafeUsername.error) fail("unsafe username is rejected: expected error.");
log("PASS: unsafe username is rejected");

const ownUsernameEvents = await teen.client.from("username_change_events").select("id").eq("user_id", teen.id);
assertNoError("user can read own username change history", ownUsernameEvents.error);
if ((ownUsernameEvents.data ?? []).length < 1) fail("user can read own username change history: expected at least one row.");
log("PASS: user can read own username change history");

const otherUsernameEvents = await teen2.client.from("username_change_events").select("id").eq("user_id", teen.id);
assertEmpty("user cannot read another user's username history", otherUsernameEvents.data, otherUsernameEvents.error);

const forgedCredits = await teen.client
  .from("username_change_credits")
  .upsert({ user_id: teen.id, token_credits: 99 })
  .select("user_id");
assertRejectedOrEmpty("user cannot grant themselves username credits", forgedCredits.data, forgedCredits.error);

const forgedBoostCredits = await adult.client
  .from("job_boost_credits")
  .upsert({ user_id: adult.id, available_credits: 99 })
  .select("user_id");
assertRejectedOrEmpty("user cannot grant themselves job boost credits", forgedBoostCredits.data, forgedBoostCredits.error);

const boostCreditStatus = await adult.client.rpc("get_job_boost_credit_status");
assertNoError("user can read own job boost credit status", boostCreditStatus.error);
if (!boostCreditStatus.data?.[0]) fail("user can read own job boost credit status: missing row.");
log("PASS: user can read own job boost credit status");

const directBoostInsert = await adult.client
  .from("boosted_jobs")
  .insert({ job_id: adultJob.id, purchaser_id: adult.id, revenuecat_product_id: "mort_job_boost_1", status: "pending" })
  .select("id");
assertRejectedOrEmpty("user cannot directly insert boosted job without credit RPC", directBoostInsert.data, directBoostInsert.error);

const featureUsage = await teen.client.rpc("record_feature_usage", {
  p_feature_key: "username-settings-rls",
  p_entitlement_required: null,
  p_allowed: true
});
assertNoError("user can record own feature usage", featureUsage.error);
if (!featureUsage.data) fail("user can record own feature usage: missing id.");
log("PASS: user can record own feature usage");

const nonAdminOverview = await teen.client.rpc("admin_monetization_overview");
if (!nonAdminOverview.error) fail("non-admin cannot call monetization admin overview: expected error.");
log("PASS: non-admin cannot call monetization admin overview");

const adminOverview = await adminUser.client.rpc("admin_monetization_overview");
assertNoError("admin can call monetization overview", adminOverview.error);
if (!adminOverview.data?.[0]) fail("admin can call monetization overview: missing row.");
log("PASS: admin can call monetization overview");

log("Old-project RLS QA passed.");
