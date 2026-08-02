import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import {
  constantTimeEqual,
  correlatedJson,
  correlationId,
  safeErrorKind,
  structuredLog,
} from "../_shared/observability.ts";

type JsonObject = Record<string, unknown>;

type PushRequest = {
  notificationId?: string;
  userId?: string;
  notificationType?: string;
  title?: string;
  body?: string;
  data?: JsonObject;
  batchSize?: number;
};

type ClaimedTarget = {
  token_id: string;
  registration_token: string;
  platform: "android" | "ios";
};

type ClaimedEvent = {
  id: string;
  recipient_id: string;
  notification_type: NotificationType;
  sensitivity: "standard" | "sensitive" | "urgent";
  safe_data: JsonObject;
  targets: ClaimedTarget[];
};

type DeliveryResult = {
  token_id: string;
  outcome: "sent" | "transient_failure" | "permanent_failure" | "invalid_token";
  error_code?: string;
  provider_message_id?: string;
  latency_ms: number;
};

const notificationTypes = [
  "application_update",
  "job_update",
  "schedule_change",
  "new_message",
  "start_time_reminder",
  "checkin_reminder",
  "completion_reminder",
  "support_ticket_update",
  "safety_alert",
  "guardian_update",
  "verification_update",
  "dispute_update",
  "account_security_alert",
  "general_update",
] as const;
type NotificationType = typeof notificationTypes[number];

const genericCopy: Record<NotificationType, { title: string; body: string }> = {
  application_update: { title: "Application update", body: "Open MORT to review an application update." },
  job_update: { title: "Job update", body: "Open MORT to review a job update." },
  schedule_change: { title: "Schedule update", body: "Open MORT to review a schedule change." },
  new_message: { title: "New message", body: "Open MORT to read your new message." },
  start_time_reminder: { title: "Work reminder", body: "Open MORT to review your upcoming job." },
  checkin_reminder: { title: "Check-in reminder", body: "Open MORT to complete your safety check-in." },
  completion_reminder: { title: "Completion reminder", body: "Open MORT to review the job completion step." },
  support_ticket_update: { title: "Support update", body: "Open MORT to review your Support case." },
  safety_alert: { title: "Safety alert", body: "Open MORT now for a safety update." },
  guardian_update: { title: "Guardian Mode update", body: "Open MORT to review an authorized Guardian Mode update." },
  verification_update: { title: "Verification update", body: "Open MORT to review your verification status." },
  dispute_update: { title: "Dispute update", body: "Open MORT to review a private dispute update." },
  account_security_alert: { title: "Account security alert", body: "Open MORT now to review your account security." },
  general_update: { title: "MORT update", body: "Open MORT for details." },
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const invokeSecret = Deno.env.get("SEND_PUSH_INVOKE_SECRET");
const fcmProjectId = Deno.env.get("FCM_PROJECT_ID");
const fcmServiceAccountEmail = Deno.env.get("FCM_SERVICE_ACCOUNT_EMAIL");
const fcmServiceAccountPrivateKey = Deno.env.get("FCM_SERVICE_ACCOUNT_PRIVATE_KEY");

if (!supabaseUrl || !serviceRoleKey || !invokeSecret) {
  throw new Error(
    "SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and SEND_PUSH_INVOKE_SECRET must be configured as Edge Function secrets.",
  );
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const maximumBodyBytes = 32 * 1024;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
let cachedAccessToken: { value: string; expiresAt: number } | null = null;

Deno.serve(async (request) => {
  const traceId = correlationId(request);
  if (request.method !== "POST") {
    return correlatedJson({ ok: false, code: "post_required" }, 405, traceId);
  }
  const suppliedSecret = request.headers.get("x-mort-push-secret") ?? "";
  if (!constantTimeEqual(invokeSecret, suppliedSecret)) {
    structuredLog("warn", "push.authorization_rejected", traceId);
    return correlatedJson({ ok: false, code: "push_authorization_required" }, 401, traceId);
  }

  try {
    const payload = await readPayload(request);
    validatePayload(payload);
    const notificationId = await ensureQueuedEvent(payload);
    const batchSize = notificationId ? 1 : Math.min(Math.max(payload.batchSize ?? 25, 1), 100);
    const result = await processQueue(batchSize, notificationId);
    structuredLog("info", "push.batch_processed", traceId, {
      provider: "fcm",
      enabled: result.remotePushEnabled,
      processed: result.processed,
      sent: result.sent,
      failed: result.failed,
    });
    return correlatedJson({ ok: true, ...result }, 200, traceId);
  } catch (error) {
    const kind = safeErrorKind(error);
    structuredLog("error", "push.request_failed", traceId, { kind });
    const code = error instanceof PushInputError ? error.code : "push_delivery_failed";
    const status = error instanceof PushInputError ? error.status : 500;
    return correlatedJson({ ok: false, code }, status, traceId);
  }
});

async function readPayload(request: Request): Promise<PushRequest> {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    throw new PushInputError("payload_too_large", 413);
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maximumBodyBytes) {
    throw new PushInputError("payload_too_large", 413);
  }
  if (!text.trim()) return {};
  try {
    const value = JSON.parse(text);
    if (!isRecord(value)) throw new PushInputError("invalid_json_object", 400);
    return value as PushRequest;
  } catch (error) {
    if (error instanceof PushInputError) throw error;
    throw new PushInputError("invalid_json", 400);
  }
}

function validatePayload(payload: PushRequest) {
  if (payload.notificationId && !uuidPattern.test(payload.notificationId)) {
    throw new PushInputError("invalid_notification_id", 400);
  }
  if (payload.userId && !uuidPattern.test(payload.userId)) {
    throw new PushInputError("invalid_user_id", 400);
  }
  if (payload.notificationType && !notificationTypes.includes(payload.notificationType as NotificationType)) {
    throw new PushInputError("invalid_notification_type", 400);
  }
  if (payload.batchSize != null &&
      (!Number.isInteger(payload.batchSize) || payload.batchSize < 1 || payload.batchSize > 100)) {
    throw new PushInputError("invalid_batch_size", 400);
  }
  if (payload.userId && (!payload.title || !payload.body)) {
    throw new PushInputError("notification_content_required", 400);
  }
  if ((payload.title?.length ?? 0) > 120 || (payload.body?.length ?? 0) > 1000) {
    throw new PushInputError("notification_content_too_long", 400);
  }
  if (payload.data != null && !isRecord(payload.data)) {
    throw new PushInputError("invalid_notification_data", 400);
  }
}

async function ensureQueuedEvent(payload: PushRequest) {
  if (payload.notificationId) return payload.notificationId;
  if (!payload.userId) return null;
  const notificationType = (payload.notificationType ?? "general_update") as NotificationType;
  const { data, error } = await supabase.from("notification_events").insert({
    recipient_id: payload.userId,
    title: sanitizeInAppText(payload.title!, 120),
    body: sanitizeInAppText(payload.body!, 1000),
    data: payload.data ?? {},
    notification_type: notificationType,
  }).select("id").single();
  if (error || !data?.id) throw new PushInputError("notification_queue_failed", 503);
  return data.id as string;
}

async function processQueue(batchSize: number, notificationId: string | null) {
  const runtime = await rpc("service_get_push_runtime");
  if (runtime.remote_push_enabled !== true) {
    return {
      provider: "fcm",
      remotePushEnabled: false,
      code: "remote_push_disabled",
      processed: 0,
      sent: 0,
      failed: 0,
    };
  }
  assertFcmSecrets();
  const claimed = await rpc("service_claim_push_events", {
    p_limit: batchSize,
    p_notification_id: notificationId,
  });
  const events = Array.isArray(claimed.events) ? claimed.events as ClaimedEvent[] : [];
  let sent = 0;
  let failed = 0;
  for (const event of events) {
    const results: DeliveryResult[] = [];
    for (const target of event.targets) {
      results.push(await sendFcm(event, target));
    }
    const completion = await rpc("service_complete_push_event", {
      p_event_id: event.id,
      p_results: results,
    });
    if (Number(completion.sent ?? 0) > 0) sent += 1;
    else failed += 1;
  }
  return {
    provider: "fcm",
    remotePushEnabled: true,
    processed: events.length,
    sent,
    failed,
  };
}

async function sendFcm(event: ClaimedEvent, target: ClaimedTarget): Promise<DeliveryResult> {
  const startedAt = Date.now();
  const copy = genericCopy[event.notification_type] ?? genericCopy.general_update;
  const token = await accessToken();
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(fcmProjectId!)}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: target.registration_token,
          notification: copy,
          data: stringData(event.safe_data),
          android: {
            priority: event.sensitivity === "urgent" ? "HIGH" : "NORMAL",
            notification: { visibility: "PRIVATE" },
          },
          apns: {
            headers: { "apns-priority": event.sensitivity === "urgent" ? "10" : "5" },
            payload: { aps: { "thread-id": "mort-updates" } },
          },
        },
      }),
    },
  );
  const body = await response.json().catch(() => ({}));
  const latencyMs = Math.min(Date.now() - startedAt, 120000);
  if (response.ok && isRecord(body) && typeof body.name === "string") {
    return {
      token_id: target.token_id,
      outcome: "sent",
      provider_message_id: body.name,
      latency_ms: latencyMs,
    };
  }
  const providerCode = fcmErrorCode(body);
  if (providerCode === "unregistered" || providerCode === "invalid_argument") {
    return {
      token_id: target.token_id,
      outcome: "invalid_token",
      error_code: providerCode,
      latency_ms: latencyMs,
    };
  }
  if (response.status === 429 || response.status >= 500) {
    return {
      token_id: target.token_id,
      outcome: "transient_failure",
      error_code: providerCode,
      latency_ms: latencyMs,
    };
  }
  return {
    token_id: target.token_id,
    outcome: "permanent_failure",
    error_code: providerCode,
    latency_ms: latencyMs,
  };
}

async function accessToken() {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.value;
  }
  assertFcmSecrets();
  const assertion = await signedServiceAccountJwt(now);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || !isRecord(body) || typeof body.access_token !== "string") {
    throw new PushInputError("fcm_oauth_rejected", 503);
  }
  const expiresIn = typeof body.expires_in === "number" ? body.expires_in : 3600;
  cachedAccessToken = { value: body.access_token, expiresAt: now + expiresIn };
  return cachedAccessToken.value;
}

async function signedServiceAccountJwt(now: number) {
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: fcmServiceAccountEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const privateKey = fcmServiceAccountPrivateKey!.replace(/\\n/g, "\n");
  const der = pemToBytes(privateKey);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64UrlBytes(new Uint8Array(signature))}`;
}

function assertFcmSecrets() {
  if (!fcmProjectId || !fcmServiceAccountEmail || !fcmServiceAccountPrivateKey) {
    throw new PushInputError("fcm_provider_unconfigured", 503);
  }
}

async function rpc(name: string, params: JsonObject = {}) {
  const { data, error } = await supabase.rpc(name, params);
  if (error || !isRecord(data) || data.ok !== true) {
    throw new PushInputError("push_backend_unavailable", 503);
  }
  return data;
}

function fcmErrorCode(body: unknown) {
  if (!isRecord(body) || !isRecord(body.error)) return "fcm_request_rejected";
  const details = Array.isArray(body.error.details) ? body.error.details : [];
  for (const detail of details) {
    if (isRecord(detail) && typeof detail.errorCode === "string") {
      return safeCode(detail.errorCode);
    }
  }
  return typeof body.error.status === "string"
    ? safeCode(body.error.status)
    : "fcm_request_rejected";
}

function stringData(data: JsonObject) {
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (typeof value === "string" && value.length <= 128) result[key] = value;
  }
  return result;
}

function sanitizeInAppText(value: string, maxLength: number) {
  return value.replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function safeCode(value: string) {
  const normalized = value.toLowerCase().replace(/[^a-z0-9_]/g, "_").slice(0, 64);
  return /^[a-z][a-z0-9_]{2,63}$/.test(normalized)
    ? normalized
    : "fcm_request_rejected";
}

function pemToBytes(pem: string) {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  try {
    return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
  } catch (_) {
    throw new PushInputError("fcm_private_key_invalid", 503);
  }
}

function base64Url(value: string) {
  return base64UrlBytes(new TextEncoder().encode(value));
}

function base64UrlBytes(value: Uint8Array) {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function isRecord(value: unknown): value is JsonObject {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

class PushInputError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}
