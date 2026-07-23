import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import {
  constantTimeEqual,
  correlatedJson,
  correlationId,
  safeErrorKind,
  structuredLog,
} from "../_shared/observability.ts";

type PushRequest = {
  notificationId?: string;
  userId?: string;
  title?: string;
  body?: string;
  data?: Record<string, unknown>;
  batchSize?: number;
};

type NotificationEvent = {
  id: string;
  recipient_id: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
};

type ExpoPushResult = {
  data?: Array<{ status?: string; message?: string; details?: { error?: string } }>;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const invokeSecret = Deno.env.get("SEND_PUSH_INVOKE_SECRET");

if (!supabaseUrl || !serviceRoleKey || !invokeSecret) {
  throw new Error("SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and SEND_PUSH_INVOKE_SECRET must be configured as Edge Function secrets.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});

const maximumBodyBytes = 32 * 1024;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (request) => {
  const traceId = correlationId(request);
  if (request.method !== "POST") {
    return correlatedJson({ ok: false, code: "post_required" }, 405, traceId);
  }

  const suppliedSecret = request.headers.get("x-mort-push-secret") ?? "";
  if (!constantTimeEqual(invokeSecret, suppliedSecret)) {
    structuredLog("warn", "push.authorization_rejected", traceId);
    return correlatedJson(
      { ok: false, code: "push_authorization_required" },
      401,
      traceId,
    );
  }

  try {
    const payload = await readPayload(request);
    validatePayload(payload);
    if (payload.notificationId || payload.userId) {
      const result = await processSingle(payload);
      structuredLog("info", "push.single_processed", traceId, {
        delivered: true,
      });
      return correlatedJson({ ok: true, processed: 1, result }, 200, traceId);
    }

    const results = await processPendingQueue(Math.min(Math.max(payload.batchSize ?? 25, 1), 100));
    const sent = results.filter((result) => result.status === "sent").length;
    const failed = results.filter((result) => result.status === "failed").length;
    structuredLog("info", "push.batch_processed", traceId, {
      processed: results.length,
      sent,
      failed,
    });
    return correlatedJson({
      ok: true,
      processed: results.length,
      sent,
      failed,
      results,
    }, 200, traceId);
  } catch (error) {
    const kind = safeErrorKind(error);
    structuredLog("error", "push.request_failed", traceId, { kind });
    const code = error instanceof PushInputError
      ? error.code
      : "push_delivery_failed";
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
    const parsed = JSON.parse(text);
    if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new PushInputError("invalid_json_object", 400);
    }
    return parsed as PushRequest;
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
  if (payload.title != null && typeof payload.title !== "string") {
    throw new PushInputError("invalid_title", 400);
  }
  if (payload.body != null && typeof payload.body !== "string") {
    throw new PushInputError("invalid_body", 400);
  }
  if (payload.batchSize != null &&
      (!Number.isInteger(payload.batchSize) || payload.batchSize < 1 || payload.batchSize > 100)) {
    throw new PushInputError("invalid_batch_size", 400);
  }
}

async function processPendingQueue(batchSize: number) {
  const { data, error } = await supabase
    .from("notification_events")
    .select("id,recipient_id,title,body,data")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(batchSize);

  if (error) throw error;

  const events = (data ?? []) as NotificationEvent[];
  const results = [];
  for (const event of events) {
    results.push(await sendEvent(event));
  }

  return results;
}

async function processSingle(payload: PushRequest) {
  if (payload.notificationId) {
    const { data, error } = await supabase
      .from("notification_events")
      .select("id,recipient_id,title,body,data")
      .eq("id", payload.notificationId)
      .single();

    if (error) throw error;
    return sendEvent(data as NotificationEvent);
  }

  if (!payload.userId || !payload.title || !payload.body) {
    throw new PushInputError("notification_target_required", 400);
  }

  return sendToRecipient({
    recipientId: payload.userId,
    title: sanitizePushText(payload.title, "MORT update", 80),
    body: sanitizePushText(payload.body, "Open MORT for details.", 140),
    data: payload.data ?? {}
  });
}

async function sendEvent(event: NotificationEvent) {
  try {
    const result = await sendToRecipient({
      recipientId: event.recipient_id,
      title: sanitizePushText(event.title, "MORT update", 80),
      body: sanitizePushText(event.body, "Open MORT for details.", 140),
      data: event.data ?? {}
    });

    await supabase
      .from("notification_events")
      .update({ status: "sent", sent_at: new Date().toISOString(), last_error: null })
      .eq("id", event.id);

    return { id: event.id, status: "sent", result };
  } catch (error) {
    const code = error instanceof PushInputError
      ? error.code
      : "push_delivery_failed";
    await supabase.from("notification_events").update({ status: "failed", last_error: code }).eq("id", event.id);
    return { id: event.id, status: "failed", error: code };
  }
}

async function sendToRecipient(input: { recipientId: string; title: string; body: string; data: Record<string, unknown> }) {
  const { data: tokens, error: tokenError } = await supabase
    .from("push_tokens")
    .select("id,expo_push_token")
    .eq("user_id", input.recipientId)
    .eq("is_active", true);

  if (tokenError) throw tokenError;

  const activeTokens = tokens ?? [];
  if (activeTokens.length === 0) {
    const { data: profile } = await supabase.from("profiles").select("expo_push_token").eq("id", input.recipientId).maybeSingle();
    if (profile?.expo_push_token) {
      activeTokens.push({ id: null, expo_push_token: profile.expo_push_token });
    }
  }

  if (activeTokens.length === 0) {
    throw new PushInputError("push_token_unavailable", 409);
  }

  const validTokens = activeTokens.filter((token) =>
    /^(ExponentPushToken|ExpoPushToken)\[[A-Za-z0-9_-]{10,200}\]$/.test(token.expo_push_token)
  );
  if (validTokens.length === 0) {
    throw new PushInputError("push_token_invalid", 409);
  }

  const expoResponse = await fetch("https://exp.host/--/api/v2/push/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json"
    },
    body: JSON.stringify(
      validTokens.map((token) => ({
        to: token.expo_push_token,
        title: input.title,
        body: input.body,
        data: input.data
      }))
    )
  });

  const expoBody = (await expoResponse.json()) as ExpoPushResult;
  if (!expoResponse.ok) {
    throw new PushInputError("expo_push_rejected", 502);
  }

  await deactivateInvalidTokens(validTokens, expoBody);
  return expoBody;
}

function sanitizePushText(value: string, fallback: string, maxLength: number) {
  const text = value.replace(/\s+/g, " ").trim();
  if (!text) return fallback;

  if (
    text.match(/(\+?1[-.\s]?)?(\(?[0-9]{3}\)?[-.\s]?)?[0-9]{3}[-.\s]?[0-9]{4}/) ||
    text.match(/[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i)
  ) {
    return fallback;
  }

  return text.slice(0, maxLength);
}

async function deactivateInvalidTokens(tokens: Array<{ id: string | null; expo_push_token: string }>, expoBody: ExpoPushResult) {
  const results = expoBody.data ?? [];

  for (let index = 0; index < results.length; index += 1) {
    const result = results[index];
    const token = tokens[index];
    if (!token?.id) continue;

    if (result.details?.error === "DeviceNotRegistered") {
      await supabase
        .from("push_tokens")
        .update({ is_active: false, last_error: "DeviceNotRegistered" })
        .eq("id", token.id);
    } else if (result.status === "error") {
      const providerCode = typeof result.details?.error === "string" &&
          /^[A-Za-z][A-Za-z0-9]{0,63}$/.test(result.details.error)
        ? result.details.error
        : "expo_push_error";
      await supabase
        .from("push_tokens")
        .update({ last_error: providerCode })
        .eq("id", token.id);
    }
  }
}

class PushInputError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}
