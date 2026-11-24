import { authenticate, json, options, requireRateLimit, runtime, safeError } from "../_shared/stripe.ts";
import { requireSandboxConnect } from "../_shared/stripe_sandbox_connect.ts";

type V2Requirement = {
  description?: string;
  minimum_deadline?: { status?: string };
};

type V2RecipientAccount = {
  id: string;
  livemode: boolean;
  identity?: { country?: string };
  defaults?: { currency?: string };
  configuration?: {
    recipient?: {
      capabilities?: {
        stripe_balance?: {
          stripe_transfers?: { status?: string };
          payouts?: { status?: string };
        };
      };
    };
  };
  requirements?: { entries?: V2Requirement[] };
};

function capabilityStatus(value: string | undefined) {
  if (value === "active" || value === "pending" || value === "inactive") return value;
  if (value === "restricted" || value === "rejected") return "restricted";
  return "inactive";
}

function requirementsStatus(entries: V2Requirement[]) {
  const statuses = entries.map((entry) => entry.minimum_deadline?.status);
  if (statuses.includes("past_due")) return "past_due";
  if (statuses.includes("currently_due")) return "currently_due";
  if (statuses.includes("pending_verification")) return "pending_verification";
  if (statuses.includes("eventually_due")) return "eventually_due";
  return "satisfied";
}

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
  try {
    const context = await authenticate(request);
    await requireRateLimit(context, "stripe_connected_account_status");
    // Reading Connect onboarding state must remain possible while payment
    // collection is disabled. The database RPC still enforces the sandbox
    // provider approval and connected-onboarding controls.
    const stripeRuntime = await runtime(context, false, true);
    requireSandboxConnect(stripeRuntime);

    const { data: prepared, error: prepareError } = await context.serviceClient.rpc(
      "stripe_server_prepare_connected_account",
      { p_user_id: context.user.id, p_environment: stripeRuntime.environment },
    );
    if (prepareError) throw prepareError;
    if (!prepared.provider_account_id) return json({ ok: true, status: "not_started" });

    const account = await stripeRuntime.stripe.v2.core.accounts.retrieve(
      prepared.provider_account_id,
      { include: ["configuration.recipient", "identity", "requirements", "defaults"] },
    ) as unknown as V2RecipientAccount;

    if (account.id !== prepared.provider_account_id || account.livemode !== false) {
      return json({ ok: false, code: "stripe_connect_sandbox_response_mismatch" }, 502);
    }

    const entries = account.requirements?.entries ?? [];
    const requirementState = requirementsStatus(entries);
    const transfers = capabilityStatus(
      account.configuration?.recipient?.capabilities?.stripe_balance?.stripe_transfers?.status,
    );
    const payouts = capabilityStatus(
      account.configuration?.recipient?.capabilities?.stripe_balance?.payouts?.status,
    );
    const onboardingStatus =
      transfers === "restricted" || payouts === "restricted"
        ? "restricted"
        : requirementState === "past_due" || requirementState === "currently_due"
        ? "action_required"
        : transfers === "active" && payouts === "active"
        ? "complete"
        : "in_progress";

    const { error: recordError } = await context.serviceClient.rpc(
      "stripe_server_record_connected_account_status",
      {
        p_provider_account_id: account.id,
        p_environment: stripeRuntime.environment,
        p_onboarding_status: onboardingStatus,
        p_details_submitted: !["currently_due", "past_due"].includes(requirementState),
        p_charges_enabled: false,
        p_payouts_enabled: payouts === "active",
        p_transfers_capability_status: transfers,
        p_requirements_status: requirementState,
        p_guardian_requirement_status: entries.some((entry) =>
          /guardian/i.test(entry.description ?? "")
        ) ? "provider_managed_required" : "provider_managed_unknown",
        p_disabled_reason_code: requirementState === "past_due"
          ? "requirements_past_due"
          : transfers === "restricted" || payouts === "restricted"
          ? "recipient_capability_restricted"
          : null,
        p_country: account.identity?.country?.toUpperCase() ?? null,
        p_default_currency: account.defaults?.currency?.toUpperCase() ?? null,
      },
    );
    if (recordError) throw recordError;

    const { data: status, error: statusError } = await context.userClient.rpc(
      "get_my_stripe_payout_status",
    );
    if (statusError) throw statusError;
    return json({ ok: true, ...status });
  } catch (error) {
    return safeError(error);
  }
});
