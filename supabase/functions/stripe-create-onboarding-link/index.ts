import { authenticate, json, options, readJson, requireRateLimit, runtime, safeError, validatedRedirectUrl } from "../_shared/stripe.ts";

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    const context = await authenticate(request);
    await requireRateLimit(context, "stripe_onboarding_link", 5, 3600);
    const payload = await readJson<{ return_url?: unknown; refresh_url?: unknown }>(request);
    const returnUrl = validatedRedirectUrl(payload.return_url, "return");
    const refreshUrl = validatedRedirectUrl(payload.refresh_url, "refresh");
    const stripeRuntime = await runtime(context);
    const { data: prepared, error: prepareError } = await context.serviceClient.rpc("stripe_server_prepare_connected_account", {
      p_user_id: context.user.id,
      p_environment: stripeRuntime.environment,
    });
    if (prepareError) throw prepareError;
    if (!prepared.provider_account_id) return json({ ok: false, code: "connected_account_required" }, 409);

    const link = await stripeRuntime.stripe.accountLinks.create({
      account: prepared.provider_account_id,
      return_url: returnUrl,
      refresh_url: refreshUrl,
      type: "account_onboarding",
    });
    const { error: recordError } = await context.serviceClient.rpc("stripe_server_record_onboarding_session", {
      p_user_id: context.user.id,
      p_environment: stripeRuntime.environment,
      p_provider_account_link_id: null,
      p_return_url_origin: new URL(returnUrl).origin,
      p_refresh_url_origin: new URL(refreshUrl).origin,
      p_expires_at: new Date(link.expires_at * 1000).toISOString(),
    });
    if (recordError) throw recordError;
    return json({ ok: true, onboarding_url: link.url, expires_at: new Date(link.expires_at * 1000).toISOString() });
  } catch (error) {
    return safeError(error);
  }
});
