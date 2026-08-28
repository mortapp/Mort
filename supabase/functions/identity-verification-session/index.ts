import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import {
  normalizeProviderHandoff,
  safeProviderFailure,
} from "./contract.mjs";

const maximumBodyBytes = 8 * 1024;
const maximumProviderResponseBytes = 32 * 1024;
const requestTimeoutMs = 15_000;

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  if ((Deno.env.get("IDENTITY_VERIFICATION_MODE") ?? "disabled") !== "production") {
    return json({ ok: false, code: "identity_verification_disabled" }, 503);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const provider = Deno.env.get("IDENTITY_VERIFICATION_PROVIDER")?.trim();
  const brokerUrl = Deno.env.get("IDENTITY_VERIFICATION_SESSION_ENDPOINT")?.trim();
  const brokerSecret = Deno.env.get("IDENTITY_VERIFICATION_SESSION_SECRET")?.trim();
  const allowedHosts = (Deno.env.get("IDENTITY_VERIFICATION_HANDOFF_HOSTS") ?? "")
    .split(",").map((value) => value.trim()).filter(Boolean);
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !provider || !brokerUrl || !brokerSecret || allowedHosts.length === 0) {
    return json({ ok: false, code: "provider_not_configured" }, 503);
  }
  let brokerUri: URL;
  try {
    brokerUri = new URL(brokerUrl);
  } catch {
    return json({ ok: false, code: "provider_not_configured" }, 503);
  }
  if (brokerUri.protocol !== "https:") {
    return json({ ok: false, code: "provider_not_configured" }, 503);
  }

  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) {
    return json({ ok: false, code: "authentication_required" }, 401);
  }
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    return json({ ok: false, code: "payload_too_large" }, 413);
  }
  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maximumBodyBytes) {
    return json({ ok: false, code: "payload_too_large" }, 413);
  }
  let body: { client_request_id?: string };
  try {
    body = JSON.parse(rawBody || "{}");
  } catch {
    return json({ ok: false, code: "payload_invalid" }, 400);
  }
  if (!isUuid(body.client_request_id)) {
    return json({ ok: false, code: "client_request_id_required" }, 400);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return json({ ok: false, code: "authentication_required" }, 401);
  }
  const { data: requestData, error: requestError } = await userClient.rpc(
    "request_identity_verification_session_v2",
    { p_client_request_id: body.client_request_id },
  );
  if (requestError || requestData?.ok !== true) {
    return json({ ok: false, code: requestData?.code ?? "provider_session_not_authorized" }, 400);
  }

  const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let providerResponse: Response;
  try {
    providerResponse = await fetch(brokerUri, {
      method: "POST",
      signal: AbortSignal.timeout(requestTimeoutMs),
      headers: {
        "Authorization": `Bearer ${brokerSecret}`,
        "Content-Type": "application/json",
        "Idempotency-Key": body.client_request_id,
        "X-MORT-Provider": provider,
      },
      body: JSON.stringify({
        provider,
        session_request_id: requestData.session_request_id,
        verification_id: requestData.verification_id,
        workflow_reference: requestData.workflow_reference,
      }),
    });
  } catch {
    await failSession(serviceClient, requestData.session_request_id, "provider_unavailable");
    return json({ ok: false, code: "provider_unavailable" }, 503);
  }
  const responseText = await providerResponse.text();
  if (new TextEncoder().encode(responseText).byteLength > maximumProviderResponseBytes) {
    await failSession(serviceClient, requestData.session_request_id, "unknown_failure");
    return json({ ok: false, code: "provider_response_invalid" }, 502);
  }
  if (!providerResponse.ok) {
    const code = safeProviderFailure(providerResponse.status);
    await failSession(serviceClient, requestData.session_request_id, code);
    return json({ ok: false, code }, providerResponse.status === 429 ? 429 : 502);
  }
  let providerValue: unknown;
  try {
    providerValue = JSON.parse(responseText);
  } catch {
    await failSession(serviceClient, requestData.session_request_id, "unknown_failure");
    return json({ ok: false, code: "provider_response_invalid" }, 502);
  }
  const handoff = normalizeProviderHandoff({
    value: providerValue,
    expectedProvider: provider,
    allowedHosts,
  });
  if (!handoff.ok) {
    await failSession(serviceClient, requestData.session_request_id, "unknown_failure");
    return json({ ok: false, code: handoff.code }, 502);
  }
  const fingerprint = await sha256Hex(handoff.handoffUrl);
  const { data: completed, error: completeError } = await serviceClient.rpc(
    "complete_identity_verification_handoff_v2",
    {
      p_session_request_id: requestData.session_request_id,
      p_provider_reference: handoff.providerReference,
      p_handoff_fingerprint: fingerprint,
      p_handoff_expires_at: handoff.handoffExpiresAt,
      p_provider_status: handoff.status,
    },
  );
  if (completeError || completed?.ok !== true) {
    return json({ ok: false, code: completed?.code ?? "provider_handoff_persistence_failed" }, 500);
  }

  return json({
    ok: true,
    session_request_id: requestData.session_request_id,
    environment: "production",
    provider,
    status: handoff.status,
    handoff_url: handoff.handoffUrl,
    handoff_expires_at: handoff.handoffExpiresAt,
    documents_collected_by_mort: false,
  }, 200);
});

async function failSession(client: ReturnType<typeof createClient>, sessionId: string, code: string) {
  await client.rpc("fail_identity_verification_handoff_v2", {
    p_session_request_id: sessionId,
    p_failure_code: code,
  });
}

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("").toUpperCase();
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}
