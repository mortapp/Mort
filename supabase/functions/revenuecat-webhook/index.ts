import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

type RevenueCatWebhookPayload = {
  api_version?: string;
  event?: Record<string, unknown>;
  [key: string]: unknown;
};

type NormalizedRevenueCatEvent = {
  eventId: string | null;
  appUserId: string | null;
  eventType: string;
  productId: string | null;
  entitlementIds: string[];
  activeUntil: string | null;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const expectedAuthorization = Deno.env.get("REVENUECAT_WEBHOOK_AUTH_HEADER");

if (!supabaseUrl || !serviceRoleKey || !expectedAuthorization) {
  throw new Error(
    "SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and REVENUECAT_WEBHOOK_AUTH_HEADER must be configured as Edge Function secrets.",
  );
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

const productEntitlements: Record<string, string[]> = {
  mort_plus_monthly: ["mort_plus", "mort_ad_free"],
  mort_plus_yearly: ["mort_plus", "mort_ad_free"],
  mort_plus_lifetime: ["mort_plus", "mort_ad_free", "mort_lifetime"],
  mort_ad_free_lifetime: ["mort_ad_free"],
  mort_adult_pro_monthly: ["mort_adult_pro"],
  mort_guardian_plus_monthly: ["mort_guardian_plus"],
  mort_profile_style_pack: ["mort_profile_style_pack"],
  mort_username_change_token_1: ["mort_username_change_token"],
  mort_job_boost_1: ["mort_job_boost"],
};

const removalEventTypes = new Set([
  "expiration",
  "refund",
  "revocation",
  "temporary_entitlement_grant_expired",
]);

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "POST required" }, 405);
  }

  if (request.headers.get("authorization") !== expectedAuthorization) {
    return json({ error: "Unauthorized RevenueCat webhook." }, 401);
  }

  let payload: RevenueCatWebhookPayload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "Request body must be valid JSON." }, 400);
  }

  const event = normalizeEvent(payload);
  if (!event.eventType) {
    return json({ error: "RevenueCat event type is required." }, 400);
  }

  try {
    const result = await processEvent(event, payload);
    console.info("revenuecat-webhook processed event", {
      eventId: event.eventId,
      eventType: event.eventType,
      productId: event.productId,
      processed: result.processed,
    });
    return json({ ok: true, ...result });
  } catch (error) {
    console.error("revenuecat-webhook failed", {
      eventId: event.eventId,
      eventType: event.eventType,
      error: error instanceof Error ? error.message : String(error),
    });
    return json({ error: "RevenueCat webhook processing failed." }, 500);
  }
});

async function processEvent(
  event: NormalizedRevenueCatEvent,
  payload: RevenueCatWebhookPayload,
) {
  if (event.eventId) {
    const { data: existing, error } = await supabase
      .from("revenuecat_events")
      .select("id,processed_at")
      .eq("revenuecat_event_id", event.eventId)
      .maybeSingle();

    if (error) throw error;
    if (existing?.processed_at) {
      return { processed: false, reason: "duplicate_event" };
    }
  }

  const validUserId = isUuid(event.appUserId) ? event.appUserId : null;
  const insertPayload = {
    revenuecat_event_id: event.eventId,
    app_user_id: validUserId,
    event_type: event.eventType,
    product_id: event.productId,
    entitlement_ids: event.entitlementIds,
    raw_event: payload,
    processing_error: validUserId ? null : "RevenueCat app_user_id was not a Supabase UUID.",
  };

  const { data: storedEvent, error: storeError } = await supabase
    .from("revenuecat_events")
    .upsert(insertPayload, {
      onConflict: "revenuecat_event_id",
      ignoreDuplicates: false,
    })
    .select("id")
    .single();

  if (storeError) throw storeError;

  if (!validUserId) {
    await markProcessed(storedEvent.id, "RevenueCat app_user_id was not a Supabase UUID.");
    return { processed: false, reason: "invalid_app_user_id" };
  }

  const mappedEntitlements = entitlementsFor(event);
  const isRemoval = removalEventTypes.has(event.eventType);

  await updateEntitlementCache({
    userId: validUserId,
    eventId: event.eventId,
    productId: event.productId,
    entitlements: mappedEntitlements,
    activeUntil: event.activeUntil,
    remove: isRemoval,
  });

  if (!isRemoval) {
    if (event.productId === "mort_username_change_token_1") {
      await grantUsernameToken(validUserId, event.eventId);
    }
    if (event.productId === "mort_job_boost_1") {
      await grantJobBoostCredit(validUserId, event.eventId);
    }
    if (event.productId === "mort_profile_style_pack") {
      await grantProfileStylePack(validUserId);
    }
  }

  await auditPurchase(validUserId, event, mappedEntitlements, isRemoval);
  await markProcessed(storedEvent.id, null);

  return {
    processed: true,
    eventType: event.eventType,
    productId: event.productId,
    entitlementCount: mappedEntitlements.length,
  };
}

function normalizeEvent(payload: RevenueCatWebhookPayload): NormalizedRevenueCatEvent {
  const source = payload.event ?? payload;
  const eventType = stringValue(source.type ?? source.event_type).toLowerCase();
  const productId = stringValue(source.product_id ?? source.product_identifier);
  const appUserId = stringValue(source.app_user_id ?? source.original_app_user_id);
  const entitlementIds = arrayValue(source.entitlement_ids ?? source.entitlements)
    .map((value) => String(value).trim())
    .filter(Boolean);
  const eventId = stringValue(source.id ?? source.event_id);
  const expirationMs = numberValue(
    source.expiration_at_ms ?? source.expires_at_ms ?? source.period_end_at_ms,
  );

  return {
    eventId: eventId || crypto.randomUUID(),
    appUserId: appUserId || null,
    eventType,
    productId: productId || null,
    entitlementIds,
    activeUntil: expirationMs ? new Date(expirationMs).toISOString() : null,
  };
}

function entitlementsFor(event: NormalizedRevenueCatEvent) {
  const entitlements = new Set<string>(event.entitlementIds);
  if (event.productId && productEntitlements[event.productId]) {
    productEntitlements[event.productId].forEach((entitlement) => entitlements.add(entitlement));
  }
  return [...entitlements].filter(Boolean);
}

async function updateEntitlementCache(input: {
  userId: string;
  eventId: string | null;
  productId: string | null;
  entitlements: string[];
  activeUntil: string | null;
  remove: boolean;
}) {
  const { data: existing, error } = await supabase
    .from("monetization_entitlements_cache")
    .select("entitlements")
    .eq("user_id", input.userId)
    .maybeSingle();

  if (error) throw error;

  const next = new Set<string>((existing?.entitlements ?? []) as string[]);
  for (const entitlement of input.entitlements) {
    if (input.remove) {
      next.delete(entitlement);
    } else {
      next.add(entitlement);
    }
  }

  const entitlements = [...next].sort();
  const now = new Date().toISOString();

  const { error: cacheError } = await supabase.from("monetization_entitlements_cache").upsert({
    user_id: input.userId,
    entitlements,
    active_until: input.activeUntil,
    source: "revenuecat",
    last_revenuecat_event_id: input.eventId,
    refreshed_at: now,
    updated_at: now,
  }, { onConflict: "user_id" });

  if (cacheError) throw cacheError;

  const { error: statusError } = await supabase.from("user_subscription_status").upsert({
    user_id: input.userId,
    premium_active: entitlements.includes("mort_plus") || entitlements.includes("mort_lifetime"),
    ad_free_active: entitlements.includes("mort_ad_free") || entitlements.includes("mort_plus") ||
      entitlements.includes("mort_lifetime"),
    adult_pro_active: entitlements.includes("mort_adult_pro"),
    business_boost_active: false,
    guardian_plus_active: entitlements.includes("mort_guardian_plus"),
    current_product_id: input.productId,
    current_period_ends_at: input.activeUntil,
    source: "revenuecat",
    updated_at: now,
  }, { onConflict: "user_id" });

  if (statusError) throw statusError;
}

async function grantUsernameToken(userId: string, eventId: string | null) {
  const { data: existing, error } = await supabase
    .from("username_change_credits")
    .select("token_credits")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw error;

  const nextCredits = ((existing?.token_credits as number | undefined) ?? 0) + 1;
  const { error: upsertError } = await supabase.from("username_change_credits").upsert({
    user_id: userId,
    token_credits: nextCredits,
  }, { onConflict: "user_id" });

  if (upsertError) throw upsertError;

  await supabase.from("purchase_audit_logs").insert({
    user_id: userId,
    source: "revenuecat",
    action: "username_change_token_granted",
    product_id: "mort_username_change_token_1",
    details: { revenuecat_event_id: eventId },
  });
}

async function grantJobBoostCredit(userId: string, eventId: string | null) {
  const { data: existing, error } = await supabase
    .from("job_boost_credits")
    .select("available_credits")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw error;

  const nextCredits = ((existing?.available_credits as number | undefined) ?? 0) + 1;
  const { error: upsertError } = await supabase.from("job_boost_credits").upsert({
    user_id: userId,
    available_credits: nextCredits,
    last_revenuecat_event_id: eventId,
  }, { onConflict: "user_id" });

  if (upsertError) throw upsertError;

  await supabase.from("purchase_audit_logs").insert({
    user_id: userId,
    source: "revenuecat",
    action: "job_boost_credit_granted",
    product_id: "mort_job_boost_1",
    details: { revenuecat_event_id: eventId },
  });
}

async function grantProfileStylePack(userId: string) {
  const { error } = await supabase.from("profile_theme_unlocks").upsert({
    user_id: userId,
    theme_key: "mort_profile_style_pack",
    source: "revenuecat",
  }, { onConflict: "user_id,theme_key" });

  if (error) throw error;
}

async function auditPurchase(
  userId: string,
  event: NormalizedRevenueCatEvent,
  entitlements: string[],
  removal: boolean,
) {
  const { error } = await supabase.from("purchase_audit_logs").insert({
    user_id: userId,
    source: "revenuecat",
    action: removal ? "revenuecat_entitlement_removed" : "revenuecat_event_processed",
    product_id: event.productId,
    entitlement_id: entitlements[0] ?? null,
    details: {
      revenuecat_event_id: event.eventId,
      event_type: event.eventType,
      entitlements,
    },
  });

  if (error) throw error;
}

async function markProcessed(eventRowId: string, errorMessage: string | null) {
  const { error } = await supabase
    .from("revenuecat_events")
    .update({
      processed_at: new Date().toISOString(),
      processing_error: errorMessage,
    })
    .eq("id", eventRowId);

  if (error) throw error;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function arrayValue(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  if (typeof value === "string" && value.trim()) return [value];
  return [];
}

function isUuid(value: string | null): value is string {
  return Boolean(
    value?.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i),
  );
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}
