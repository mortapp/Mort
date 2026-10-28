import Stripe from "npm:stripe@22.1.1";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function respond(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function safeFailure(error: unknown) {
  const trace = crypto.randomUUID();
  const providerCode = error instanceof Stripe.errors.StripeError &&
      typeof error.code === "string" && /^[a-z0-9_]{2,80}$/.test(error.code)
    ? error.code
    : undefined;
  console.error(JSON.stringify({
    event: "stripe_assignment_payment_failed",
    trace_id: trace,
    kind: error instanceof Stripe.errors.StripeError ? "stripe" : "internal",
    provider_code: providerCode,
  }));
  return respond({ ok: false, code: "stripe_operation_failed", trace_id: trace, ...(providerCode ? { provider_code: providerCode } : {}) }, 500);
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return respond({ ok: false, code: "post_required" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const authorization = request.headers.get("Authorization") ?? "";
    const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!supabaseUrl || !anonKey || !serviceKey) return respond({ ok: false, code: "server_not_configured" }, 503);
    if (!token) return respond({ ok: false, code: "authentication_required" }, 401);
    if (Number(request.headers.get("content-length") ?? "0") > 8192) return respond({ ok: false, code: "payload_too_large" }, 413);
    const requestBody = await request.text();
    if (new TextEncoder().encode(requestBody).byteLength > 8192) return respond({ ok: false, code: "payload_too_large" }, 413);
    let body: Record<string, unknown>;
    try {
      const parsed: unknown = JSON.parse(requestBody || "{}");
      if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
        return respond({ ok: false, code: "invalid_json" }, 400);
      }
      body = parsed as Record<string, unknown>;
    } catch {
      return respond({ ok: false, code: "invalid_json" }, 400);
    }
    if (typeof body.assignment_id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(body.assignment_id)) {
      return respond({ ok: false, code: "invalid_assignment_id" }, 400);
    }
    const assignmentId = body.assignment_id;

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: authData, error: authError } = await userClient.auth.getUser(token);
    if (authError || !authData.user) return respond({ ok: false, code: "invalid_session" }, 401);
    const { data: rateAllowed, error: rateError } = await userClient.rpc("consume_my_edge_action_limit", {
      p_action: "stripe_assignment_payment_intent",
    });
    if (rateError) return respond({ ok: false, code: "rate_limit_check_failed" }, 503);
    if (rateAllowed !== true) return respond({ ok: false, code: "rate_limit_exceeded" }, 429);

    const mode = Deno.env.get("MORT_STRIPE_MODE");
    if (mode !== "sandbox" && mode !== "live") return respond({ ok: false, code: "stripe_disabled" }, 503);
    const environment = mode === "sandbox" ? "test" : "live";
    const secretKey = Deno.env.get(environment === "test" ? "STRIPE_TEST_SECRET_KEY" : "STRIPE_LIVE_SECRET_KEY");
    const publishableKey = Deno.env.get(environment === "test" ? "STRIPE_TEST_PUBLISHABLE_KEY" : "STRIPE_LIVE_PUBLISHABLE_KEY");
    const expectedSecretPrefix = environment === "test" ? "sk_test_" : "sk_live_";
    const expectedPublishablePrefix = environment === "test" ? "pk_test_" : "pk_live_";
    if (!secretKey || !publishableKey) return respond({ ok: false, code: "stripe_server_not_configured" }, 503);
    if (!secretKey.startsWith(expectedSecretPrefix) || !publishableKey.startsWith(expectedPublishablePrefix)) {
      return respond({ ok: false, code: "stripe_key_mode_mismatch" }, 503);
    }

    const { data: release, error: releaseError } = await userClient.rpc("get_release_mode_status");
    if (releaseError) return respond({ ok: false, code: "runtime_controls_unavailable" }, 503);
    if (release?.maintenance_mode === true) return respond({ ok: false, code: "maintenance_mode_active" }, 503);
    if (release?.public_marketplace_enabled !== true) return respond({ ok: false, code: "payments_disabled" }, 503);
    const { data: stripeStatus, error: stripeStatusError } = await userClient.rpc("get_stripe_runtime_status");
    if (stripeStatusError || stripeStatus?.mode !== mode || stripeStatus?.environment !== environment) {
      return respond({ ok: false, code: "stripe_runtime_mode_mismatch" }, 503);
    }
    if (stripeStatus.payments_enabled !== true || stripeStatus.job_funding_enabled !== true) {
      return respond({ ok: false, code: "stripe_job_funding_disabled" }, 503);
    }
    if (mode === "live" && stripeStatus.live_mode_enabled !== true) return respond({ ok: false, code: "stripe_live_disabled" }, 503);

    const serviceClient = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: prepared, error: prepareError } = await serviceClient.rpc(
      "stripe_server_prepare_assignment_payment",
      { p_payer_id: authData.user.id, p_assignment_id: assignmentId },
    );
    if (prepareError) throw prepareError;
    if (prepared?.ok !== true) {
      const code = typeof prepared?.code === "string" ? prepared.code : "payment_not_available";
      return respond({ ok: false, code }, code === "stripe_job_funding_disabled" ? 503 : 409);
    }

    const stripe = new Stripe(secretKey, { maxNetworkRetries: 2, timeout: 20000, telemetry: false });
    const paymentIntent = prepared.provider_payment_intent_id
      ? await stripe.paymentIntents.retrieve(prepared.provider_payment_intent_id)
      : await stripe.paymentIntents.create({
        amount: prepared.gross_amount_cents,
        currency: String(prepared.currency_code).toLowerCase(),
        payment_method_types: ["card"],
        transfer_group: `MORT_ASSIGNMENT_${assignmentId}`,
        metadata: {
          mort_assignment_ref: assignmentId,
          mort_payment_ledger_ref: prepared.ledger_id,
          mort_environment: environment,
        },
      }, { idempotencyKey: prepared.idempotency_key });
    if (!paymentIntent.client_secret) throw new Error("payment_intent_client_secret_unavailable");

    const { data: recorded, error: recordError } = await serviceClient.rpc(
      "stripe_server_record_assignment_payment_intent",
      {
        p_ledger_id: prepared.ledger_id,
        p_provider_payment_intent_id: paymentIntent.id,
        p_provider_status: paymentIntent.status,
        p_provider_created_at: new Date(paymentIntent.created * 1000).toISOString(),
      },
    );
    if (recordError) throw recordError;
    return respond({
      ok: true,
      payment_intent_id: recorded.provider_payment_intent_id,
      payment_intent_client_secret: paymentIntent.client_secret,
      publishable_key: publishableKey,
      environment,
      normalized_state: recorded.status,
      assignment_id: prepared.assignment_id,
      gross_amount_cents: prepared.gross_amount_cents,
      service_fee_cents: prepared.service_fee_cents,
      teen_net_cents: prepared.teen_net_cents,
      currency_code: prepared.currency_code,
    });
  } catch (error) {
    return safeFailure(error);
  }
});
