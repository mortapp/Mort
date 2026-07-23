import { authenticate, json, options, requireRateLimit, runtime, safeError } from "../_shared/stripe.ts";

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    const context = await authenticate(request);
    await requireRateLimit(context, "stripe_connected_account_status", 20, 3600);
    const stripeRuntime = await runtime(context);
    const { data: prepared, error: prepareError } = await context.serviceClient.rpc("stripe_server_prepare_connected_account", {
      p_user_id: context.user.id,
      p_environment: stripeRuntime.environment,
    });
    if (prepareError) throw prepareError;
    if (!prepared.provider_account_id) return json({ ok: true, status: "not_started" });
    const account = await stripeRuntime.stripe.accounts.retrieve(prepared.provider_account_id);
    if (account.deleted) return json({ ok: true, status: "disconnected" });
    const due = account.requirements?.currently_due ?? [];
    const pastDue = account.requirements?.past_due ?? [];
    const transfers = account.capabilities?.transfers ?? "inactive";
    const requirementsStatus = pastDue.length > 0 ? "past_due" : due.length > 0 ? "currently_due" : account.requirements?.pending_verification?.length ? "pending_verification" : "satisfied";
    const onboardingStatus = account.details_submitted && transfers === "active" ? "complete" : pastDue.length ? "action_required" : "in_progress";
    const { error: recordError } = await context.serviceClient.rpc("stripe_server_record_connected_account_status", {
      p_provider_account_id: account.id,
      p_environment: stripeRuntime.environment,
      p_onboarding_status: onboardingStatus,
      p_details_submitted: account.details_submitted,
      p_charges_enabled: account.charges_enabled,
      p_payouts_enabled: account.payouts_enabled,
      p_transfers_capability_status: transfers === "active" ? "active" : transfers === "pending" ? "pending" : transfers === "inactive" ? "inactive" : "restricted",
      p_requirements_status: requirementsStatus,
      p_guardian_requirement_status: due.some((item) => item.includes("guardian")) || pastDue.some((item) => item.includes("guardian")) ? "provider_managed_required" : "provider_managed_unknown",
      p_disabled_reason_code: account.requirements?.disabled_reason ?? null,
      p_country: account.country?.toUpperCase() ?? null,
      p_default_currency: account.default_currency?.toUpperCase() ?? null,
    });
    if (recordError) throw recordError;
    const { data: status, error: statusError } = await context.userClient.rpc("get_my_stripe_payout_status");
    if (statusError) throw statusError;
    return json({ ok: true, ...status });
  } catch (error) {
    return safeError(error);
  }
});
