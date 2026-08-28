import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import {
  correlatedJson,
  correlationId,
  structuredLog,
} from "../_shared/observability.ts";

const maximumBodyBytes = 16 * 1024;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const allowedResourceTypes = new Set([
  "job_draft",
  "message_draft",
  "support_draft",
]);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-correlation-id",
};

const patterns: Record<string, RegExp> = {
  phone: /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/i,
  email: /\b[\w.-]+@[\w.-]+\.\w{2,}\b/i,
  payment: /\b(cashapp|venmo|paypal|zelle|\$cashtag)\b/i,
  social: /\b(snapchat|snap|insta|instagram|kik|discord|whatsapp)\b/i,
  address:
    /\b\d{1,5}\s\w+\s(st|street|ave|avenue|blvd|rd|road|dr|drive|lane|ln)\b/i,
  off_platform: /\b(call me|text me|dm me on|message me on|hit me up on)\b/i,
  threats: /\b(kill|beat up|hurt|shoot|stab|die)\b/i,
  scam: /\b(gift card|wire|western union|upfront fee|cash advance)\b/i,
  unsafe_job:
    /\b(massage|modeling|hotel room|night shift|delivery driver|driving)\b/i,
  grooming:
    /\b(don't tell your parents|keep this a secret|don't tell your guardian)\b/i,
};

Deno.serve(async (request: Request) => {
  const traceId = correlationId(request);
  const reply = (body: Record<string, unknown>, status = 200) =>
    correlatedJson(body, status, traceId, corsHeaders);

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return reply({ ok: false, code: "post_required" }, 405);
  }

  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    return reply({ ok: false, code: "payload_too_large" }, 413);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    return reply({ ok: false, code: "server_not_configured" }, 503);
  }

  const token = request.headers
    .get("Authorization")
    ?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) {
    return reply({ ok: false, code: "authentication_required" }, 401);
  }

  const userClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: auth, error: authError } = await userClient.auth.getUser(token);
  if (authError || !auth.user) {
    return reply({ ok: false, code: "invalid_session" }, 401);
  }

  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maximumBodyBytes) {
    return reply({ ok: false, code: "payload_too_large" }, 413);
  }

  let body: Record<string, unknown>;
  try {
    body = rawBody.trim() ? JSON.parse(rawBody) : {};
  } catch {
    return reply({ ok: false, code: "invalid_json" }, 400);
  }

  const content = typeof body.content === "string" ? body.content.trim() : "";
  const resourceType = typeof body.resourceType === "string"
    ? body.resourceType
    : "";
  const resourceId = typeof body.resourceId === "string" ? body.resourceId : "";
  const clientRequestId = typeof body.clientRequestId === "string"
    ? body.clientRequestId
    : "";
  if (
    !content ||
    content.length > 4000 ||
    !allowedResourceTypes.has(resourceType) ||
    !uuidPattern.test(resourceId) ||
    !uuidPattern.test(clientRequestId)
  ) {
    return reply({ ok: false, code: "invalid_request" }, 400);
  }

  const serviceClient = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const existing = await serviceClient
    .from("ai_moderation_events")
    .select("id,status,detected_flags,created_at")
    .eq("user_id", auth.user.id)
    .eq("client_request_id", clientRequestId)
    .maybeSingle();
  if (existing.error) {
    return reply({ ok: false, code: "moderation_lookup_failed" }, 503);
  }
  if (existing.data) {
    return reply({ ok: true, event: existing.data, idempotent: true });
  }

  const quota = await userClient.rpc("consume_my_edge_action_limit", {
    p_action: "ai_safety_scan",
  });
  if (quota.error) {
    return reply({ ok: false, code: "rate_limit_check_failed" }, 503);
  }
  if (quota.data !== true) {
    return reply({ ok: false, code: "rate_limit_exceeded" }, 429);
  }

  const flags = Object.entries(patterns)
    .filter(([, pattern]) => pattern.test(content))
    .map(([name]) => name);
  const insert = await serviceClient
    .from("ai_moderation_events")
    .insert({
      user_id: auth.user.id,
      resource_type: resourceType,
      resource_id: resourceId,
      content: null,
      detected_flags: flags,
      ai_provider: null,
      fallback_used: true,
      status: flags.length > 0 ? "flagged" : "clean",
      client_request_id: clientRequestId,
    })
    .select("id,status,detected_flags,created_at")
    .single();
  if (insert.error) {
    const raced = await serviceClient
      .from("ai_moderation_events")
      .select("id,status,detected_flags,created_at")
      .eq("user_id", auth.user.id)
      .eq("client_request_id", clientRequestId)
      .maybeSingle();
    if (raced.data) {
      return reply({ ok: true, event: raced.data, idempotent: true });
    }
    structuredLog("error", "ai_safety.write_failed", traceId, {
      user_id: auth.user.id,
      resource_type: resourceType,
    });
    return reply({ ok: false, code: "moderation_write_failed" }, 503);
  }

  return reply({ ok: true, event: insert.data, idempotent: false });
});
