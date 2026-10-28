import Stripe from "npm:stripe@22.1.1";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

const corsHeaders = { "Content-Type": "application/json" };
const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  const traceId = crypto.randomUUID();
  let serviceClient: any = null;
  let environment: string | null = null;
  let eventId: string | null = null;
  let leaseToken: string | null = null;
  try {
    if (Number(request.headers.get("content-length") ?? "0") > 1048576) return json({ ok: false, code: "payload_too_large" }, 413);
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).byteLength > 1048576) return json({ ok: false, code: "payload_too_large" }, 413);
    const mode = Deno.env.get("MORT_STRIPE_MODE");
    if (mode !== "sandbox" && mode !== "live") return json({ ok: false, code: "stripe_disabled" }, 503);
    environment = mode === "sandbox" ? "test" : "live";
    const secretKey = Deno.env.get(environment === "test" ? "STRIPE_TEST_SECRET_KEY" : "STRIPE_LIVE_SECRET_KEY");
    const webhookSecret = Deno.env.get(environment === "test" ? "STRIPE_TEST_WEBHOOK_SECRET" : "STRIPE_LIVE_WEBHOOK_SECRET");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!secretKey || !webhookSecret || !supabaseUrl || !serviceKey) return json({ ok: false, code: "stripe_webhook_not_configured" }, 503);
    if (!secretKey.startsWith(environment === "test" ? "sk_test_" : "sk_live_") || !webhookSecret.startsWith("whsec_")) {
      return json({ ok: false, code: "stripe_key_mode_mismatch" }, 503);
    }
    const signature = request.headers.get("stripe-signature");
    if (!signature) return json({ ok: false, code: "stripe_signature_required" }, 400);
    const stripe = new Stripe(secretKey, { maxNetworkRetries: 2, timeout: 20000, telemetry: false });
    const event = await stripe.webhooks.constructEventAsync(rawBody, signature, webhookSecret);
    eventId = event.id;
    if (event.livemode !== (environment === "live")) return json({ ok: false, code: "stripe_event_mode_mismatch" }, 400);
    serviceClient = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } }) as any;
    const { data: claim, error: claimError } = await serviceClient.rpc("stripe_server_claim_webhook_event", {
      p_environment: environment,
      p_provider_event_id: event.id,
      p_event_type: event.type,
      p_provider_created_at: new Date(event.created * 1000).toISOString(),
      p_payload_sha256: await sha256(rawBody),
    });
    if (claimError) throw claimError;
    if (claim?.claimed !== true) return json({ ok: true, duplicate: claim?.duplicate === true, in_flight: claim?.in_flight === true });
    leaseToken = claim.lease_token;

    const supported = new Set([
      "payment_intent.created",
      "payment_intent.amount_capturable_updated",
      "payment_intent.processing",
      "payment_intent.requires_action",
      "payment_intent.payment_failed",
      "payment_intent.canceled",
      "payment_intent.succeeded",
    ]);
    if (!supported.has(event.type)) {
      const { error } = await serviceClient.rpc("stripe_server_finish_webhook_event", {
        p_environment: environment,
        p_provider_event_id: event.id,
        p_lease_token: leaseToken,
        p_disposition: "ignored",
        p_safe_failure_code: null,
      });
      if (error) throw error;
      return json({ ok: true, ignored: true });
    }

    const eventIntent = event.data.object as Stripe.PaymentIntent;
    const ledgerId = eventIntent.metadata?.mort_payment_ledger_ref;
    if (!ledgerId || !uuidPattern.test(ledgerId)) {
      const { error } = await serviceClient.rpc("stripe_server_finish_webhook_event", {
        p_environment: environment,
        p_provider_event_id: event.id,
        p_lease_token: leaseToken,
        p_disposition: "ignored",
        p_safe_failure_code: null,
      });
      if (error) throw error;
      return json({ ok: true, ignored: true });
    }
    const latest = await stripe.paymentIntents.retrieve(eventIntent.id);
    if (latest.livemode !== (environment === "live")) throw new Error("stripe_event_mode_mismatch");
    const { error: applyError } = await serviceClient.rpc("stripe_server_apply_assignment_payment_webhook", {
      p_environment: environment,
      p_provider_event_id: event.id,
      p_lease_token: leaseToken,
      p_ledger_id: ledgerId,
      p_provider_payment_intent_id: latest.id,
      p_provider_status: latest.status,
      p_amount_cents: latest.amount,
      p_currency_code: latest.currency,
      p_event_created_at: new Date(event.created * 1000).toISOString(),
    });
    if (applyError) throw applyError;
    const { error: finishError } = await serviceClient.rpc("stripe_server_finish_webhook_event", {
      p_environment: environment,
      p_provider_event_id: event.id,
      p_lease_token: leaseToken,
      p_disposition: "processed",
      p_safe_failure_code: null,
    });
    if (finishError) throw finishError;
    return json({ ok: true, processed: true });
  } catch (error) {
    console.error(JSON.stringify({ event: "stripe_assignment_webhook_failed", trace_id: traceId }));
    if (serviceClient && environment && eventId && leaseToken) {
      await serviceClient.rpc("stripe_server_finish_webhook_event", {
        p_environment: environment,
        p_provider_event_id: eventId,
        p_lease_token: leaseToken,
        p_disposition: "failed",
        p_safe_failure_code: "webhook_processing_failed",
      });
    }
    return json({ ok: false, code: "stripe_webhook_processing_failed", trace_id: traceId }, 500);
  }
});
