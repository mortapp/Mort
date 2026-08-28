import { createHash, randomUUID } from "node:crypto";
import {
  assertQa,
  qaLog,
  serviceClient,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-revenuecat-atomic";

function hash(value) {
  return createHash("sha256").update(value).digest("hex");
}

function providerEvent({
  eventId,
  userId,
  eventType,
  productId,
  eventTimestamp,
  activeUntil = null,
  payloadVariant = "original",
}) {
  const entitlements = {
    mort_username_change_token_1: ["mort_username_change_token"],
    mort_guardian_plus_monthly: ["mort_guardian_plus"],
  }[productId] ?? [];
  const normalized = {
    api_version: "1.0",
    event: {
      id: eventId,
      type: eventType,
      app_user_id: userId,
      product_id: productId,
      entitlement_ids: entitlements,
      event_timestamp_ms: eventTimestamp.getTime(),
      active_until: activeUntil?.toISOString() ?? null,
      payload_variant: payloadVariant,
    },
  };
  return {
    p_event_id: eventId,
    p_app_user_id: userId,
    p_event_type: eventType,
    p_product_id: productId,
    p_entitlement_ids: entitlements,
    p_active_until: activeUntil?.toISOString() ?? null,
    p_event_timestamp: eventTimestamp.toISOString(),
    p_payload_sha256: hash(JSON.stringify(normalized)),
    p_normalized_event: normalized,
  };
}

async function invoke(params) {
  const { data, error } = await serviceClient.rpc(
    "process_revenuecat_provider_event",
    params,
  );
  if (error) throw new Error(`RevenueCat RPC failed: ${error.message}`);
  return data;
}

await withQaUsers(
  scope,
  [{ key: "revenuecat_adult", role: "adult" }],
  async ({ revenuecat_adult: adult }) => {
    const eventIds = [];
    try {
      const creditEventId = `qa_${randomUUID()}`;
      eventIds.push(creditEventId);
      const creditEvent = providerEvent({
        eventId: creditEventId,
        userId: adult.id,
        eventType: "non_renewing_purchase",
        productId: "mort_username_change_token_1",
        eventTimestamp: new Date(),
      });

      const concurrent = await Promise.all(
        Array.from({ length: 6 }, () => invoke(creditEvent)),
      );
      assertQa(
        concurrent.filter((result) => result.processed === true).length === 1,
        "Exactly one concurrent delivery must process.",
      );
      assertQa(
        concurrent.filter((result) => result.code === "duplicate_event").length === 5,
        "Concurrent duplicate deliveries must be idempotent.",
      );
      const { data: credits, error: creditError } = await serviceClient
        .from("username_change_credits")
        .select("token_credits")
        .eq("user_id", adult.id)
        .single();
      if (creditError) throw creditError;
      assertQa(credits.token_credits === 1, "Replay must grant exactly one credit.");
      qaLog(scope, "concurrent replay grants exactly one consumable credit");

      const mismatched = {
        ...creditEvent,
        p_payload_sha256: hash(`${creditEvent.p_payload_sha256}:changed`),
      };
      const mismatchResult = await invoke(mismatched);
      assertQa(
        mismatchResult.ok === false &&
          mismatchResult.code === "duplicate_payload_mismatch",
        "Same event id with a different payload must be rejected.",
      );
      qaLog(scope, "same-id payload substitution is rejected");

      const now = Date.now();
      const purchaseId = `qa_${randomUUID()}`;
      const staleExpirationId = `qa_${randomUUID()}`;
      const currentExpirationId = `qa_${randomUUID()}`;
      eventIds.push(purchaseId, staleExpirationId, currentExpirationId);

      await invoke(providerEvent({
        eventId: purchaseId,
        userId: adult.id,
        eventType: "initial_purchase",
        productId: "mort_guardian_plus_monthly",
        eventTimestamp: new Date(now),
        activeUntil: new Date(now + 30 * 24 * 60 * 60 * 1000),
      }));
      await invoke(providerEvent({
        eventId: staleExpirationId,
        userId: adult.id,
        eventType: "expiration",
        productId: "mort_guardian_plus_monthly",
        eventTimestamp: new Date(now - 60 * 60 * 1000),
      }));

      const { data: activeState, error: activeError } = await serviceClient
        .from("revenuecat_product_states")
        .select("active,last_event_id")
        .eq("user_id", adult.id)
        .eq("product_id", "mort_guardian_plus_monthly")
        .single();
      if (activeError) throw activeError;
      assertQa(
        activeState.active === true && activeState.last_event_id === purchaseId,
        "An older expiration must not overwrite newer purchase state.",
      );
      qaLog(scope, "out-of-order older events cannot regress product state");

      await invoke(providerEvent({
        eventId: currentExpirationId,
        userId: adult.id,
        eventType: "expiration",
        productId: "mort_guardian_plus_monthly",
        eventTimestamp: new Date(now + 1000),
      }));
      const { data: inactiveState, error: inactiveError } = await serviceClient
        .from("revenuecat_product_states")
        .select("active,last_event_id")
        .eq("user_id", adult.id)
        .eq("product_id", "mort_guardian_plus_monthly")
        .single();
      if (inactiveError) throw inactiveError;
      assertQa(
        inactiveState.active === false &&
          inactiveState.last_event_id === currentExpirationId,
        "A newer expiration must revoke product state.",
      );
      qaLog(scope, "newer revocation updates the entitlement cache");

      const { error: callerError } = await adult.client.rpc(
        "process_revenuecat_provider_event",
        creditEvent,
      );
      assertQa(
        callerError != null,
        "Authenticated mobile callers must not execute provider fulfillment.",
      );
      const { error: writeError } = await adult.client
        .from("revenuecat_product_states")
        .update({ active: true })
        .eq("user_id", adult.id);
      assertQa(writeError != null, "Mobile callers must not mutate provider state.");
      qaLog(scope, "provider fulfillment and state writes are server-only");
    } finally {
      await serviceClient
        .from("purchase_audit_logs")
        .delete()
        .eq("user_id", adult.id);
      await serviceClient
        .from("revenuecat_events")
        .delete()
        .in("revenuecat_event_id", eventIds);
    }
  },
);

console.log(`[${scope}] RevenueCat atomic fulfillment QA passed.`);
