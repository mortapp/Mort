import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import {
  constantTimeEqual,
  correlatedJson,
  correlationId,
  structuredLog,
} from "../_shared/observability.ts";

type RevenueCatPayload = {
  api_version?: unknown;
  event?: Record<string, unknown>;
  [key: string]: unknown;
};

type NormalizedEvent = {
  eventId: string;
  appUserId: string | null;
  eventType: string;
  productId: string | null;
  entitlementIds: string[];
  activeUntil: string | null;
  eventTimestamp: string;
  eventTimestampMs: number;
};

class WebhookError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}

const maximumBodyBytes = 128 * 1024;
const eventIdPattern = /^[A-Za-z0-9._:-]{8,200}$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const eventTypes = new Set([
  "billing_issue",
  "cancellation",
  "expiration",
  "initial_purchase",
  "invoice_issuance",
  "non_renewing_purchase",
  "product_change",
  "refund",
  "renewal",
  "revocation",
  "subscription_extended",
  "subscription_paused",
  "temporary_entitlement_grant",
  "temporary_entitlement_grant_expired",
  "test",
  "transfer",
  "uncancellation",
  "virtual_currency_transaction",
]);
const productEntitlements: Readonly<Record<string, readonly string[]>> = Object.freeze({
  mort_plus_monthly: ["mort_plus", "mort_ad_free"],
  mort_plus_yearly: ["mort_plus", "mort_ad_free"],
  mort_plus_lifetime: ["mort_plus", "mort_ad_free", "mort_lifetime"],
  mort_ad_free_lifetime: ["mort_ad_free"],
  mort_username_change_token_1: ["mort_username_change_token"],
  mort_profile_style_pack: ["mort_profile_style_pack"],
  mort_adult_pro_monthly: ["mort_adult_pro"],
  mort_guardian_plus_monthly: ["mort_guardian_plus"],
  mort_job_boost_1: ["mort_job_boost"],
});

Deno.serve(async (request: Request) => {
  const traceId = correlationId(request);
  if (request.method !== "POST") {
    return correlatedJson({ ok: false, code: "post_required" }, 405, traceId);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const expectedAuthorization = Deno.env.get("REVENUECAT_WEBHOOK_AUTH_HEADER");
    if (!supabaseUrl || !serviceRoleKey || !expectedAuthorization) {
      throw new WebhookError("revenuecat_not_configured", 503);
    }

    const suppliedAuthorization = request.headers.get("authorization") ?? "";
    if (!constantTimeEqual(expectedAuthorization, suppliedAuthorization)) {
      structuredLog("warn", "revenuecat.authorization_rejected", traceId);
      throw new WebhookError("webhook_authorization_required", 401);
    }

    const rawBody = await readBody(request);
    const payload = parsePayload(rawBody);
    const event = normalizeEvent(payload);
    const payloadSha256 = await sha256(rawBody);
    const normalizedPayload = {
      api_version: stringValue(payload.api_version) || null,
      event: {
        id: event.eventId,
        type: event.eventType,
        app_user_id: event.appUserId,
        product_id: event.productId,
        entitlement_ids: event.entitlementIds,
        event_timestamp_ms: event.eventTimestampMs,
        active_until: event.activeUntil,
      },
    };

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await supabase.rpc("process_revenuecat_provider_event", {
      p_event_id: event.eventId,
      p_app_user_id: event.appUserId,
      p_event_type: event.eventType,
      p_product_id: event.productId,
      p_entitlement_ids: event.entitlementIds,
      p_active_until: event.activeUntil,
      p_event_timestamp: event.eventTimestamp,
      p_payload_sha256: payloadSha256,
      p_normalized_event: normalizedPayload,
    });

    if (error) {
      structuredLog("error", "revenuecat.database_failure", traceId, {
        providerEventId: event.eventId,
        databaseCode: error.code,
      });
      throw new WebhookError("provider_event_processing_failed", 503);
    }

    const result = asResult(data);
    if (result.code === "duplicate_payload_mismatch") {
      structuredLog("warn", "revenuecat.replay_payload_mismatch", traceId, {
        providerEventId: event.eventId,
      });
      return correlatedJson({ ok: false, code: result.code }, 409, traceId);
    }

    structuredLog("info", "revenuecat.event_handled", traceId, {
      providerEventId: event.eventId,
      eventType: event.eventType,
      productId: event.productId,
      processed: result.processed,
      resultCode: result.code,
    });
    return correlatedJson({
      ok: result.ok,
      processed: result.processed,
      code: result.code,
    }, 200, traceId);
  } catch (error) {
    if (error instanceof WebhookError) {
      return correlatedJson({ ok: false, code: error.code }, error.status, traceId);
    }
    structuredLog("error", "revenuecat.unhandled_failure", traceId, {
      kind: error instanceof Error ? error.name : "unknown",
    });
    return correlatedJson({ ok: false, code: "revenuecat_webhook_failed" }, 500, traceId);
  }
});

async function readBody(request: Request) {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    throw new WebhookError("payload_too_large", 413);
  }
  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maximumBodyBytes) {
    throw new WebhookError("payload_too_large", 413);
  }
  return rawBody;
}

function parsePayload(rawBody: string): RevenueCatPayload {
  let value: unknown;
  try {
    value = JSON.parse(rawBody);
  } catch {
    throw new WebhookError("invalid_json", 400);
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new WebhookError("invalid_payload", 400);
  }
  return value as RevenueCatPayload;
}

function normalizeEvent(payload: RevenueCatPayload): NormalizedEvent {
  const source = payload.event;
  if (!source || typeof source !== "object" || Array.isArray(source)) {
    throw new WebhookError("event_required", 400);
  }

  const eventId = stringValue(source.id ?? source.event_id);
  if (!eventIdPattern.test(eventId)) throw new WebhookError("invalid_event_id", 400);

  const eventType = stringValue(source.type ?? source.event_type).toLowerCase();
  if (!eventTypes.has(eventType)) throw new WebhookError("unsupported_event_type", 400);

  const productIdValue = stringValue(source.product_id ?? source.product_identifier);
  const productId = productIdValue || null;
  if (productId && !(productId in productEntitlements)) {
    throw new WebhookError("unsupported_product", 400);
  }

  const appUserIdValue = stringValue(source.app_user_id ?? source.original_app_user_id);
  const appUserId = uuidPattern.test(appUserIdValue) ? appUserIdValue : null;
  const entitlementIds = productId ? [...productEntitlements[productId]] : [];
  const eventTimestampMs = integerTimestamp(
    source.event_timestamp_ms ?? source.purchased_at_ms,
    "event_timestamp",
  );
  const expirationTimestampMs = optionalIntegerTimestamp(
    source.expiration_at_ms ?? source.expires_at_ms ?? source.period_end_at_ms,
    "expiration_timestamp",
  );

  return {
    eventId,
    appUserId,
    eventType,
    productId,
    entitlementIds,
    activeUntil: expirationTimestampMs == null
      ? null
      : new Date(expirationTimestampMs).toISOString(),
    eventTimestamp: new Date(eventTimestampMs).toISOString(),
    eventTimestampMs,
  };
}

function integerTimestamp(value: unknown, field: string) {
  const parsed = numberValue(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new WebhookError(`invalid_${field}`, 400);
  }
  return parsed;
}

function optionalIntegerTimestamp(value: unknown, field: string) {
  if (value == null || value === "") return null;
  return integerTimestamp(value, field);
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : Number.NaN;
  }
  return Number.NaN;
}

function asResult(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new WebhookError("invalid_processing_result", 503);
  }
  const result = value as Record<string, unknown>;
  const code = stringValue(result.code);
  if (!code || typeof result.ok !== "boolean" || typeof result.processed !== "boolean") {
    throw new WebhookError("invalid_processing_result", 503);
  }
  return { ok: result.ok, processed: result.processed, code };
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
