import Stripe from "npm:stripe@22.1.1";
import { PublicError } from "../_shared/stripe.ts";
import {
  createSandboxConnectAccount,
  createSandboxConnectLink,
} from "../_shared/stripe_sandbox_connect.ts";

const fixture = "00000000-0000-4000-8000-000000000123";
const fakeConnectAccountId = (suffix: string) => ["acct", "_", suffix].join("");
const recipient = fakeConnectAccountId("00000000000000");
const returnUrl = "https://mort-web.vercel.app/stripe/return";
const refreshUrl = "https://mort-web.vercel.app/stripe/refresh";

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

function stub(reply: Record<string, unknown>) {
  const requests: {
    path: string;
    method: string;
    body: Record<string, unknown>;
    idempotency: string | null;
  }[] = [];
  const stripe = new Stripe(["sk_test", "_synthetic_test_key"].join(""), {
    maxNetworkRetries: 0,
    httpClient: Stripe.createFetchHttpClient(async (input, options) => {
      const req = new Request(input, options);
      requests.push({
        path: new URL(req.url).pathname,
        method: req.method,
        body: await req.json(),
        idempotency: req.headers.get("Idempotency-Key"),
      });
      return Response.json(reply);
    }),
  });
  return {
    runtime: { mode: "sandbox" as const, environment: "test" as const, stripe },
    requests,
  };
}

Deno.test("approved synthetic profile provisions an idempotent test-mode Accounts v2 recipient", async () => {
  const { runtime, requests } = stub({
    id: recipient,
    livemode: false,
    applied_configurations: ["recipient"],
    identity: { country: "us", entity_type: "individual" },
    defaults: { currency: "usd" },
  });
  equal(await createSandboxConnectAccount(runtime, fixture), {
    id: recipient,
    country: "US",
    currency: "USD",
  });
  const request = requests[0];
  equal([request.method, request.path], ["POST", "/v2/core/accounts"]);
  equal(request.idempotency, `test:connected-account-v2:${fixture}`);
  equal(request.body.configuration, {
    recipient: {
      capabilities: {
        stripe_balance: { stripe_transfers: { requested: true } },
      },
    },
  });
  equal(request.body.dashboard, "express");
  equal(request.body.display_name, "MORT QA recipient");
  equal(request.body.contact_email, `mort-sandbox-${fixture}@example.com`);
  equal(request.body.defaults, {
    currency: "usd",
    responsibilities: {
      fees_collector: "application",
      losses_collector: "application",
    },
  });
  equal(request.body.identity, { country: "us", entity_type: "individual" });
  equal(request.body.include, ["configuration.recipient", "defaults", "identity", "requirements"]);
});

Deno.test("recipient onboarding returns a single-use sandbox link for the requested account", async () => {
  const expires = new Date(Date.now() + 60_000).toISOString();
  const url = "https://connect.stripe.com/setup/s/syntheticFixture";
  const { runtime, requests } = stub({
    account: recipient,
    expires_at: expires,
    livemode: false,
    url,
  });
  equal(
    await createSandboxConnectLink(runtime, recipient, returnUrl, refreshUrl),
    {
      url,
      expiresAt: expires,
    },
  );
  equal([requests[0].method, requests[0].path], [
    "POST",
    "/v2/core/account_links",
  ]);
  equal(requests[0].body, {
    account: recipient,
    use_case: {
      type: "account_onboarding",
      account_onboarding: {
        refresh_url: refreshUrl,
        return_url: returnUrl,
      },
    },
  });
});

Deno.test("live profile provisioning and link creation stop before contacting Stripe", async () => {
  const { runtime, requests } = stub({});
  const live = {
    ...runtime,
    mode: "live" as const,
    environment: "live" as const,
  };
  for (
    const action of [
      () => createSandboxConnectAccount(live, fixture),
      () => createSandboxConnectLink(live, recipient, returnUrl, refreshUrl),
    ]
  ) {
    try {
      await action();
      throw new Error("Expected live onboarding to be blocked");
    } catch (error) {
      equal(
        error instanceof PublicError && error.message,
        "stripe_connect_guardian_review_required",
      );
    }
  }
  equal(requests.length, 0);
});

Deno.test("sandbox onboarding rejects a provider response for a different recipient", async () => {
  const { runtime } = stub({
    account: fakeConnectAccountId("11111111111111"),
    expires_at: new Date(Date.now() + 60_000).toISOString(),
    livemode: false,
    url: "https://connect.stripe.com/setup/s/syntheticFixture",
  });
  try {
    await createSandboxConnectLink(runtime, recipient, returnUrl, refreshUrl);
    throw new Error("Expected recipient mismatch to be blocked");
  } catch (error) {
    equal(
      error instanceof PublicError && error.message,
      "stripe_connect_sandbox_response_mismatch",
    );
  }
});
