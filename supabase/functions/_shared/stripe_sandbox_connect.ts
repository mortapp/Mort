import { PublicError, type StripeRuntime } from "./stripe.ts";

type ConnectRuntime = Pick<StripeRuntime, "mode" | "environment" | "stripe">;
const isAccountId = (id: string) => /^acct_[A-Za-z0-9]+$/.test(id);

export function requireSandboxConnect(runtime: ConnectRuntime) {
  if (runtime.mode !== "sandbox" || runtime.environment !== "test") {
    throw new PublicError("stripe_connect_guardian_review_required", 403);
  }
}

export async function createSandboxConnectAccount(
  runtime: ConnectRuntime,
  fixtureUserId: string,
) {
  requireSandboxConnect(runtime);
  if (!/^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/.test(fixtureUserId)) {
    throw new PublicError("stripe_connect_sandbox_fixture_required", 403);
  }
  // The caller has passed the DB's synthetic-profile and Connect approval checks.
  // No profile email, birth date, identity information or representative consent leaves MORT.
  const account = await runtime.stripe.v2.core.accounts.create({
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
  const country = account.identity?.country?.toUpperCase();
  const currency = account.defaults?.currency?.toUpperCase();
  if (
    account.livemode !== false || !isAccountId(account.id) ||
    !account.applied_configurations?.includes("recipient") ||
    country !== "US" || currency !== "USD" || account.identity?.entity_type !== "individual"
  ) {
    throw new PublicError("stripe_connect_sandbox_response_mismatch", 502);
  }
  return { id: account.id, country, currency };
}

export async function createSandboxConnectLink(
  runtime: ConnectRuntime,
  accountId: string,
  returnUrl: string,
  refreshUrl: string,
) {
  requireSandboxConnect(runtime);
  if (!isAccountId(accountId)) {
    throw new PublicError("stripe_connect_sandbox_fixture_required", 403);
  }
  const link = await runtime.stripe.v2.core.accountLinks.create({
    account: accountId,
    use_case: {
      type: "account_onboarding",
      account_onboarding: {
        configurations: ["recipient"],
        refresh_url: refreshUrl,
        return_url: returnUrl,
      },
    },
  });
  const expires = Date.parse(link.expires_at);
  let url: URL | undefined;
  try {
    url = new URL(link.url);
  } catch {
    // Reject missing or malformed provider URLs below.
  }
  if (
    link.livemode !== false || link.account !== accountId ||
    !Number.isFinite(expires) || expires <= Date.now() ||
    url?.origin !== "https://connect.stripe.com" || url.username || url.password
  ) {
    throw new PublicError("stripe_connect_sandbox_response_mismatch", 502);
  }
  return { url: link.url, expiresAt: new Date(expires).toISOString() };
}
