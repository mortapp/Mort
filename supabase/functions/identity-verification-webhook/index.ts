import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import { validateWebhookEnvelope } from "./contract.mjs";

const maximumBodyBytes = 128 * 1024;

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);

  const mode = Deno.env.get("IDENTITY_VERIFICATION_MODE") ?? "disabled";
  if (mode !== "production") {
    return json({ ok: false, code: "identity_verification_disabled" }, 503);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const webhookSecret = Deno.env.get("IDENTITY_VERIFICATION_WEBHOOK_SECRET");
  const provider = Deno.env.get("IDENTITY_VERIFICATION_PROVIDER");
  if (!supabaseUrl || !serviceRoleKey || !webhookSecret || !provider) {
    return json({ ok: false, code: "provider_not_configured" }, 503);
  }

  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    return json({ ok: false, code: "payload_too_large" }, 413);
  }
  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maximumBodyBytes) {
    return json({ ok: false, code: "payload_too_large" }, 413);
  }

  const envelope = await validateWebhookEnvelope({
    rawBody,
    headers: request.headers,
    secret: webhookSecret,
    expectedProvider: provider,
  });
  if (!envelope.ok) {
    const status = envelope.code === "signature_missing" || envelope.code === "signature_invalid" ? 401 : 400;
    return json(envelope, status);
  }

  const payload = envelope.payload;
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await supabase.rpc("process_identity_verification_provider_result", {
    p_event_id: envelope.eventId,
    p_provider: payload.provider,
    p_environment: payload.environment,
    p_provider_reference: payload.provider_reference,
    p_user_id: payload.account_id,
    p_result_status: payload.result_status,
    p_age_band: payload.age_band,
    p_verification_level: payload.verification_level,
    p_expires_at: payload.expires_at ?? null,
    p_event_timestamp: envelope.eventTimestamp,
    p_payload_sha256: envelope.payloadSha256,
    p_signature_verified: true,
  });

  if (error) {
    console.error("identity-verification-webhook database failure", {
      eventId: envelope.eventId,
      provider,
      code: error.code,
    });
    return json({ ok: false, code: "provider_result_processing_failed" }, 500);
  }
  if (data?.ok !== true) {
    const status = data?.code === "provider_webhook_replay" ? 409
      : data?.code === "production_verification_not_ready" ? 503
      : 400;
    return json({ ok: false, code: data?.code ?? "provider_result_rejected" }, status);
  }

  console.info("identity-verification-webhook processed", {
    eventId: envelope.eventId,
    provider,
    verificationId: data.verification_id,
  });
  return json({ ok: true, event_id: envelope.eventId }, 200);
});

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}
