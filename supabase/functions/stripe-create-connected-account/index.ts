import Stripe from "npm:stripe@23.2.0";
import { createClient } from "npm:@supabase/supabase-js@2.110.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

class PublicError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function safeError(error: unknown) {
  if (error instanceof PublicError) return json({ ok: false, code: error.code }, error.status);
  // Never log provider messages, request bodies, keys, or profile data.
  console.error("stripe_connect_qa_request_failed", error instanceof Error ? error.name : "unknown");
  return json({ ok: false, code: "stripe_connect_request_failed" }, 502);
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new PublicError("server_not_configured", 503);
    }

    const authorization = request.headers.get("Authorization") ?? "";
    const match = authorization.match(/^Bearer\s+(.+)$/i);
    if (!match) throw new PublicError("authentication_required", 401);
    const accessToken = match[1];

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
    const { data: authData, error: authError } = await userClient.auth.getUser(accessToken);
    if (authError || !authData.user) throw new PublicError("invalid_session", 401);

    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: rateAllowed, error: rateError } = await userClient.rpc(
      "consume_my_edge_action_limit",
      { p_action: "stripe_connected_account_create" },
    );
    if (rateError) throw new PublicError("rate_limit_check_failed", 503);
    if (rateAllowed !== true) throw new PublicError("rate_limit_exceeded", 429);

    // This endpoint provisions sandbox recipient accounts only. Payment
    // collection remains disabled; the dedicated Connect controls below are
    // independently enforced by the service-only database RPC.
    if (Deno.env.get("MORT_STRIPE_MODE") !== "sandbox") {
      throw new PublicError("stripe_connect_guardian_review_required", 403);
    }
    const secretKey = Deno.env.get("STRIPE_TEST_SECRET_KEY");
    const publishableKey = Deno.env.get("STRIPE_TEST_PUBLISHABLE_KEY");
    if (!secretKey || !publishableKey) throw new PublicError("stripe_server_not_configured", 503);
    if (!secretKey.startsWith("sk_test_") || !publishableKey.startsWith("pk_test_")) {
      throw new PublicError("stripe_key_mode_mismatch", 503);
    }

    const { data: featureStatus, error: featureError } = await serviceClient.rpc(
      "get_runtime_feature_status",
    );
    if (featureError || featureStatus?.ok !== true) {
      throw new PublicError("runtime_controls_unavailable", 503);
    }
    if (featureStatus.maintenance_mode === true) {
      throw new PublicError("maintenance_mode_active", 503);
    }

    const { data: stripeStatus, error: stripeStatusError } = await userClient.rpc(
      "get_stripe_runtime_status",
    );
    if (
      stripeStatusError || stripeStatus?.mode !== "sandbox" ||
      stripeStatus?.environment !== "test"
    ) {
      throw new PublicError("stripe_runtime_mode_mismatch", 503);
    }

    const { data: prepared, error: prepareError } = await serviceClient.rpc(
      "stripe_server_prepare_connected_account",
      { p_user_id: authData.user.id, p_environment: "test" },
    );
    if (prepareError) {
      const message = String(prepareError.message ?? "");
      if (message.includes("sandbox_provider_qa_not_approved")) {
        throw new PublicError("sandbox_provider_qa_not_approved", 403);
      }
      if (message.includes("stripe_connected_onboarding_disabled")) {
        throw new PublicError("stripe_connected_onboarding_disabled", 403);
      }
      if (message.includes("sandbox_test_account_required")) {
        throw new PublicError("sandbox_test_account_required", 403);
      }
      if (message.includes("eligible_teen_required") || message.includes("teen_age_required")) {
        throw new PublicError("eligible_teen_required", 403);
      }
      throw new PublicError("connected_account_preparation_failed", 503);
    }

    if (prepared.existing && prepared.provider_account_id) {
      return json({ ok: true, created: false, status: "existing" });
    }

    const stripe = new Stripe(secretKey, {
      maxNetworkRetries: 2,
      timeout: 20_000,
      telemetry: false,
    });
    const fixtureUserId = authData.user.id;
    const account = await stripe.v2.core.accounts.create({
      contact_email: `mort-sandbox-${fixtureUserId}@example.com`,
      dashboard: "express",
      display_name: "MORT QA recipient",
      defaults: {
        currency: "usd",
        responsibilities: {
          fees_collector: "application",
          losses_collector: "application",
        },
      },
      identity: { country: "us", entity_type: "individual" },
      configuration: {
        recipient: {
          capabilities: {
            stripe_balance: { stripe_transfers: { requested: true } },
          },
        },
      },
      metadata: { mort_user_ref: fixtureUserId, mort_environment: "test" },
      include: ["configuration.recipient", "defaults", "identity", "requirements"],
    }, { idempotencyKey: `test:connected-account-v2:${fixtureUserId}` });

    const verified = account as unknown as {
      id: string;
      livemode: boolean;
      applied_configurations?: string[];
      identity?: { country?: string; entity_type?: string };
      defaults?: { currency?: string };
    };
    if (
      verified.livemode !== false ||
      !/^acct_[A-Za-z0-9]+$/.test(verified.id) ||
      !verified.applied_configurations?.includes("recipient") ||
      verified.identity?.country?.toUpperCase() !== "US" ||
      verified.identity?.entity_type !== "individual" ||
      verified.defaults?.currency?.toUpperCase() !== "USD"
    ) {
      throw new PublicError("stripe_connect_sandbox_response_mismatch", 502);
    }

    const { error: recordError } = await serviceClient.rpc(
      "stripe_server_record_connected_account",
      {
        p_user_id: fixtureUserId,
        p_environment: "test",
        p_provider_account_id: verified.id,
        p_country: "US",
        p_default_currency: "USD",
      },
    );
    if (recordError) throw new PublicError("connected_account_record_failed", 503);
    return json({ ok: true, created: true, status: "pending" });
  } catch (error) {
    return safeError(error);
  }
});
