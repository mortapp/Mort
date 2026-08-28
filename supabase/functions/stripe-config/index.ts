import { authenticate, json, options, runtime, safeError } from "../_shared/stripe.ts";

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    const context = await authenticate(request);
    const stripeRuntime = await runtime(context);
    const { data, error } = await context.userClient.rpc("get_stripe_runtime_status");
    if (error) throw error;
    return json({
      ok: true,
      mode: stripeRuntime.mode,
      environment: stripeRuntime.environment,
      publishable_key: stripeRuntime.publishableKey,
      payments_enabled: data.payments_enabled === true,
      connected_onboarding_enabled: data.connected_onboarding_enabled === true,
      job_funding_enabled: data.job_funding_enabled === true,
      provider: "stripe",
    });
  } catch (error) {
    return safeError(error);
  }
});
