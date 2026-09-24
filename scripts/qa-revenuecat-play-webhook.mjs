import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import { mortSupabaseUrl, requireEnvValue } from "./revenuecat-common.mjs";

const authorization = requireEnvValue("REVENUECAT_PLAY_WEBHOOK_AUTH_HEADER");
const serviceRoleKey = requireEnvValue("SUPABASE_SERVICE_ROLE_KEY");
const url = `${mortSupabaseUrl}/functions/v1/revenuecat-webhook`;
const admin = createClient(mortSupabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function assert(condition, message) {
  if (!condition) throw new Error(`[qa-revenuecat-play-webhook] ${message}`);
}

async function post(headers, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
  return { status: response.status, data: await response.json() };
}

const missingAuth = await post({}, { event: { type: "test" } });
assert(missingAuth.status === 401, `Missing authorization returned ${missingAuth.status}.`);

const appUserId = randomUUID();
const { data: profile, error: profileError } = await admin
  .from("profiles").select("id").eq("id", appUserId).maybeSingle();
assert(!profileError && !profile, "Synthetic App User ID unexpectedly exists.");

const eventId = `qa_play_${randomUUID()}`;
const payload = {
  api_version: "1.0",
  event: {
    id: eventId,
    type: "initial_purchase",
    app_user_id: appUserId,
    product_id: "mort_pro:weekly",
    entitlement_ids: ["mort_pro"],
    event_timestamp_ms: Date.now(),
    expiration_at_ms: Date.now() + 7 * 24 * 60 * 60 * 1000,
  },
};
const accepted = await post({ Authorization: authorization }, payload);
assert(accepted.status === 200 && accepted.data?.ok === true,
  `Synthetic Play event failed: ${accepted.status} ${JSON.stringify(accepted.data)}`);

const { data: stored, error: storedError } = await admin
  .from("revenuecat_events")
  .select("revenuecat_event_id,app_user_id,processing_error")
  .eq("revenuecat_event_id", eventId)
  .maybeSingle();
assert(!storedError && stored?.revenuecat_event_id === eventId,
  "Synthetic Play event was not recorded.");
assert(stored.app_user_id === null,
  "Synthetic Play event unexpectedly linked to a real profile.");

const replay = await post({ Authorization: authorization }, payload);
assert(replay.status === 200 && replay.data?.code === "duplicate_event",
  `Play event replay was not idempotent: ${replay.status} ${JSON.stringify(replay.data)}`);

console.log("[qa-revenuecat-play-webhook] PASS: rejects unauthenticated calls, records a synthetic Pro event without a user grant, and deduplicates replay.");
