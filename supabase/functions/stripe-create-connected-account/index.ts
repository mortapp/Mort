import { authenticate, json, options, requireRateLimit, runtime, safeError } from "../_shared/stripe.ts";

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    const context = await authenticate(request);
    await requireRateLimit(context, "stripe_connected_account_create", 3, 3600);
    const stripeRuntime = await runtime(context);
    const { data: prepared, error: prepareError } = await context.serviceClient.rpc("stripe_server_prepare_connected_account", {
      p_user_id: context.user.id,
      p_environment: stripeRuntime.environment,
    });
    if (prepareError) throw prepareError;
    if (prepared.existing && prepared.provider_account_id) {
      return json({ ok: true, created: false, status: "existing" });
    }

    const account = await stripeRuntime.stripe.accounts.create({
      type: "express",
      capabilities: { transfers: { requested: true } },
      metadata: { mort_user_ref: context.user.id, mort_environment: stripeRuntime.environment },
    }, { idempotencyKey: `${stripeRuntime.environment}:connected-account:${context.user.id}` });

    const { error: recordError } = await context.serviceClient.rpc("stripe_server_record_connected_account", {
      p_user_id: context.user.id,
      p_environment: stripeRuntime.environment,
      p_provider_account_id: account.id,
      p_country: account.country?.toUpperCase() ?? null,
      p_default_currency: account.default_currency?.toUpperCase() ?? null,
    });
    if (recordError) throw recordError;
    return json({ ok: true, created: true, status: "pending" });
  } catch (error) {
    return safeError(error);
  }
});
