import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";
import {
  envValue,
  mortSupabaseUrl,
  requireEnvValue,
} from "./revenuecat-common.mjs";

function fail(message) {
  console.error(`[qa-revenuecat-webhook] FAIL: ${message}`);
  process.exit(1);
}

function pass(message) {
  console.log(`[qa-revenuecat-webhook] PASS: ${message}`);
}

const supabaseUrl = envValue("EXPO_PUBLIC_SUPABASE_URL") || mortSupabaseUrl;
const serviceRoleKey = requireEnvValue("SUPABASE_SERVICE_ROLE_KEY");
const webhookAuthHeader = requireEnvValue("REVENUECAT_WEBHOOK_AUTH_HEADER");
const functionUrl = `${supabaseUrl}/functions/v1/revenuecat-webhook`;

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function postWebhook(headers, body) {
  const response = await fetch(functionUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  return { status: response.status, data };
}

async function authorizedEvent(event) {
  const response = await postWebhook(
    { Authorization: webhookAuthHeader },
    {
      api_version: "1.0",
      event: {
        id: `qa_${randomUUID()}`,
        purchased_at_ms: Date.now(),
        ...event,
      },
    },
  );
  if (response.status !== 200 || response.data?.ok !== true) {
    fail(`Authorized webhook expected 200 ok, got ${response.status}: ${JSON.stringify(response.data)}`);
  }
  return response;
}

const missingAuth = await postWebhook({}, { event: { type: "initial_purchase" } });
if (missingAuth.status !== 401) fail(`Missing auth expected 401, got ${missingAuth.status}.`);
pass("Webhook rejects missing authorization.");

const invalidAuth = await postWebhook({ Authorization: "Bearer invalid" }, { event: { type: "initial_purchase" } });
if (invalidAuth.status !== 401) fail(`Invalid auth expected 401, got ${invalidAuth.status}.`);
pass("Webhook rejects invalid authorization.");

const { data: qaProfile, error: profileError } = await admin
  .from("profiles")
  .select("id,display_name")
  .ilike("display_name", "Rebuild QA%")
  .limit(1)
  .maybeSingle();

if (profileError) fail(`QA profile lookup failed: ${profileError.message}`);

const appUserId = qaProfile?.id ?? "not-a-supabase-uuid";
const usernameProductId = qaProfile?.id ? "mort_username_change_token_1" : null;

let beforeUsernameCredits = 0;
if (qaProfile?.id) {
  const { data, error } = await admin
    .from("username_change_credits")
    .select("token_credits")
    .eq("user_id", qaProfile.id)
    .maybeSingle();
  if (error) fail(`Username credit precheck failed: ${error.message}`);
  beforeUsernameCredits = data?.token_credits ?? 0;
}

const usernameEventId = `qa_${randomUUID()}`;
const usernameEvent = await postWebhook(
  { Authorization: webhookAuthHeader },
  {
    api_version: "1.0",
    event: {
      id: usernameEventId,
      type: "non_renewing_purchase",
      app_user_id: appUserId,
      product_id: usernameProductId,
      entitlement_ids: usernameProductId ? ["mort_username_change_token"] : [],
      purchased_at_ms: Date.now(),
    },
  },
);

if (usernameEvent.status !== 200 || usernameEvent.data?.ok !== true) {
  fail(`Authorized webhook expected 200 ok, got ${usernameEvent.status}: ${JSON.stringify(usernameEvent.data)}`);
}
pass("Webhook accepts authorized test event.");

const { data: storedEvent, error: storedError } = await admin
  .from("revenuecat_events")
  .select("id,revenuecat_event_id,processed_at,processing_error")
  .eq("revenuecat_event_id", usernameEventId)
  .maybeSingle();
if (storedError) fail(`RevenueCat event lookup failed: ${storedError.message}`);
if (!storedEvent) fail("Authorized webhook did not write revenuecat_events.");
pass("Webhook writes revenuecat_events.");

if (qaProfile?.id) {
  const { data: afterUsername, error: usernameError } = await admin
    .from("username_change_credits")
    .select("token_credits")
    .eq("user_id", qaProfile.id)
    .maybeSingle();
  if (usernameError) fail(`Username credit postcheck failed: ${usernameError.message}`);
  if ((afterUsername?.token_credits ?? 0) !== beforeUsernameCredits + 1) {
    fail("Webhook did not grant exactly one username token credit to the QA profile.");
  }
  pass("Webhook grants one username token credit to QA profile only.");

  const { data: beforeBoost, error: boostPrecheckError } = await admin
    .from("job_boost_credits")
    .select("available_credits")
    .eq("user_id", qaProfile.id)
    .maybeSingle();
  if (boostPrecheckError) fail(`Job boost precheck failed: ${boostPrecheckError.message}`);
  const beforeBoostCredits = beforeBoost?.available_credits ?? 0;

  await authorizedEvent({
    type: "non_renewing_purchase",
    app_user_id: qaProfile.id,
    product_id: "mort_job_boost_1",
    entitlement_ids: ["mort_job_boost"],
  });

  const { data: afterBoost, error: boostPostcheckError } = await admin
    .from("job_boost_credits")
    .select("available_credits")
    .eq("user_id", qaProfile.id)
    .maybeSingle();
  if (boostPostcheckError) fail(`Job boost postcheck failed: ${boostPostcheckError.message}`);
  if ((afterBoost?.available_credits ?? 0) !== beforeBoostCredits + 1) {
    fail("Webhook did not grant exactly one job boost credit to the QA profile.");
  }
  pass("Webhook grants one job boost credit to QA profile only.");

  await authorizedEvent({
    type: "initial_purchase",
    app_user_id: qaProfile.id,
    product_id: "mort_plus_monthly",
    entitlement_ids: ["mort_plus", "mort_ad_free"],
    expiration_at_ms: Date.now() + 30 * 24 * 60 * 60 * 1000,
  });

  const { data: entitlementCache, error: cacheError } = await admin
    .from("monetization_entitlements_cache")
    .select("entitlements,last_revenuecat_event_id")
    .eq("user_id", qaProfile.id)
    .maybeSingle();
  if (cacheError) fail(`Entitlement cache lookup failed: ${cacheError.message}`);
  const cached = new Set(entitlementCache?.entitlements ?? []);
  if (!cached.has("mort_plus") || !cached.has("mort_ad_free")) {
    fail(`Entitlement cache missing expected Plus/ad-free values: ${JSON.stringify(entitlementCache)}`);
  }
  pass("Webhook updates backend entitlement cache.");

  const { data: subscriptionStatus, error: statusError } = await admin
    .from("user_subscription_status")
    .select("premium_active,ad_free_active")
    .eq("user_id", qaProfile.id)
    .maybeSingle();
  if (statusError) fail(`Subscription status lookup failed: ${statusError.message}`);
  if (subscriptionStatus?.premium_active !== true || subscriptionStatus?.ad_free_active !== true) {
    fail(`Subscription status did not reflect Plus/ad-free entitlement: ${JSON.stringify(subscriptionStatus)}`);
  }
  pass("Webhook updates user subscription status.");

  const duplicate = await postWebhook(
    { Authorization: webhookAuthHeader },
    {
      event: {
        id: usernameEventId,
        type: "non_renewing_purchase",
        app_user_id: appUserId,
        product_id: usernameProductId,
        entitlement_ids: ["mort_username_change_token"],
      },
    },
  );
  if (duplicate.status !== 200 || duplicate.data?.reason !== "duplicate_event") {
    fail(`Duplicate webhook expected duplicate_event, got ${duplicate.status}: ${JSON.stringify(duplicate.data)}`);
  }
  pass("Webhook duplicate event is idempotent.");
} else {
  pass("No Rebuild QA profile found; fulfillment grant test skipped and event intake used invalid app_user_id.");
}

console.log("[qa-revenuecat-webhook] RevenueCat webhook QA passed.");
