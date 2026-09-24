import { createHash, randomUUID } from "node:crypto";
import {
  assertQa,
  qaLog,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-mort-pro-ssv";
if (process.env.MORT_QA_LOCAL_SUPABASE !== "true" ||
    process.env.EXPO_PUBLIC_SUPABASE_URL !== "http://127.0.0.1:54321") {
  throw new Error("This adversarial monetization test is local-only.");
}

function providerEvent(userId, productId, eventType) {
  const timestamp = new Date();
  const normalized = {
    event: { id: `qa_${randomUUID()}`, app_user_id: userId,
      product_id: productId, type: eventType },
  };
  return {
    p_event_id: normalized.event.id,
    p_app_user_id: userId,
    p_event_type: eventType,
    p_product_id: productId,
    p_entitlement_ids: ["mort_pro"],
    p_active_until: eventType === "initial_purchase"
      ? new Date(timestamp.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString()
      : null,
    p_event_timestamp: timestamp.toISOString(),
    p_payload_sha256: createHash("sha256").update(JSON.stringify(normalized)).digest("hex"),
    p_normalized_event: normalized,
  };
}

async function progressionState(userId) {
  return await withDatabase(async (database) => {
    const result = await database.query(
      `select coalesce(sum(xp_total), 0)::bigint as xp,
              coalesce(sum(motion_tokens_balance), 0)::bigint as tokens
       from private.progression_accounts where user_id = $1`,
      [userId],
    );
    return JSON.stringify(result.rows[0]);
  });
}

await withQaUsers(scope, [
  { key: "pro_adult", role: "adult" },
  { key: "pro_teen", role: "teen" },
], async ({ pro_adult: adult, pro_teen: teen }) => {
  const beforeProgression = await progressionState(adult.id);
  for (const user of [adult, teen]) {
    const { error } = await user.client.from("user_ad_preferences").upsert({
      user_id: user.id,
      personalized_ads_allowed: true,
      ads_consent_ready: true,
      age_restricted_ads: false,
    });
    assertQa(!error, `Could not set local ad consent fixture: ${error?.message}`);
  }
  const eligibility = async (user, placement, format) => {
    const { data, error } = await user.client.rpc("get_ad_eligibility", {
      p_placement: placement, p_ad_format: format,
    });
    assertQa(!error && data?.length === 1, `Ad eligibility failed: ${error?.message}`);
    return data[0];
  };
  assertQa((await eligibility(adult, "job_feed", "banner")).allowed, "adult banner denied");
  assertQa((await eligibility(adult, "messages", "banner")).allowed === false,
    "sensitive placement allowed");
  assertQa((await eligibility(teen, "job_feed", "banner")).request_non_personalized,
    "teen personalized ads allowed");
  qaLog(scope, "adult consent, sensitive placement, and teen ad rules hold");

  for (const product of [
    "mort_pro:weekly", "mort_pro:monthly", "mort_pro:annual", "lifetime",
  ]) {
    const purchase = providerEvent(adult.id, product,
      product === "lifetime" ? "non_renewing_purchase" : "initial_purchase");
    const { data, error } = await serviceClient.rpc(
      "process_revenuecat_provider_event", purchase,
    );
    assertQa(!error && data?.state_changed === true,
      `MORT Pro purchase did not activate: ${product} ${error?.message}`);
    const { data: status } = await serviceClient.from("user_subscription_status")
      .select("premium_active,ad_free_active")
      .eq("user_id", adult.id).single();
    assertQa(status?.premium_active && status?.ad_free_active,
      `${product} did not activate Pro and ad-free status`);
    assertQa((await eligibility(adult, "job_feed", "banner")).allowed === false,
      "Pro member received an ad");
    const replay = await serviceClient.rpc("process_revenuecat_provider_event", purchase);
    assertQa(!replay.error && replay.data?.code === "duplicate_event",
      "RevenueCat replay was not idempotent");
    const refund = providerEvent(adult.id, product, "refund");
    refund.p_event_timestamp = new Date(Date.now() + 1000).toISOString();
    const removal = await serviceClient.rpc("process_revenuecat_provider_event", refund);
    assertQa(!removal.error && removal.data?.state_changed === true,
      `MORT Pro refund did not deactivate: ${product} ${removal.error?.message}`);
    assertQa((await eligibility(adult, "job_feed", "banner")).allowed === true,
      "ad eligibility did not return after refund");
  }
  const badPlan = await serviceClient.rpc("process_revenuecat_provider_event",
    providerEvent(adult.id, "mort_pro:yearly", "initial_purchase"));
  assertQa(Boolean(badPlan.error), "inactive yearly base plan was accepted");
  assertQa(await progressionState(adult.id) === beforeProgression,
    "RevenueCat events changed XP or Motion Tokens");
  qaLog(scope, "all four Pro products activate; refunds, replay, bad plan, and progression rules hold");

  const transactionId = randomUUID().replaceAll("-", "");
  const reward = {
    p_transaction_id: transactionId,
    p_user_id: adult.id,
    p_ad_unit_id: "2747237135",
    p_rewarded_at: new Date().toISOString(),
  };
  const clientAttempt = await adult.client.rpc("process_mort_spark_ssv", reward);
  assertQa(Boolean(clientAttempt.error), "authenticated user invoked the SSV grant RPC");
  const oldAttempt = await adult.client.rpc("grant_mort_spark_reward", {
    p_client_request_id: randomUUID(),
  });
  assertQa(Boolean(oldAttempt.error), "legacy client reward RPC is still callable");
  const forgedInsert = await adult.client.from("admob_reward_events").insert({
    transaction_id: randomUUID().replaceAll("-", ""),
    user_id: adult.id,
    ad_unit_id: "2747237135",
    rewarded_at: new Date().toISOString(),
    outcome: "granted",
  });
  assertQa(Boolean(forgedInsert.error), "authenticated user inserted an SSV event");
  const grant = await serviceClient.rpc("process_mort_spark_ssv", reward);
  assertQa(!grant.error && grant.data?.code === "granted", "verified server reward failed");
  const replay = await serviceClient.rpc("process_mort_spark_ssv", reward);
  assertQa(!replay.error && replay.data?.code === "duplicate_event", "SSV replay granted again");
  const cooldown = await serviceClient.rpc("process_mort_spark_ssv", {
    ...reward, p_transaction_id: randomUUID().replaceAll("-", ""),
  });
  assertQa(!cooldown.error && cooldown.data?.code === "cooldown_active",
    "SSV cooldown was bypassed");
  const ownGrant = await adult.client.from("mort_spark_grants").select("id");
  const otherGrant = await teen.client.from("mort_spark_grants").select("id")
    .eq("user_id", adult.id);
  assertQa(!ownGrant.error && ownGrant.data?.length === 1,
    `reward owner cannot read own grant: ${ownGrant.error?.message ?? ownGrant.data?.length}`);
  assertQa(!otherGrant.error && otherGrant.data?.length === 0,
    "another user can read a reward grant");
  assertQa(await progressionState(adult.id) === beforeProgression,
    "Ad reward changed XP or Motion Tokens");
  qaLog(scope, "SSV grants are service-only, replay-safe, RLS-isolated, cosmetic, and cooldown-limited");
});
