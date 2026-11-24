import type Stripe from "npm:stripe@22.1.1";
import assert from "node:assert/strict";
import {
  observe,
  targetFor,
  webhookRoutes,
} from "../stripe-webhook/observation.ts";

const ids = {
  payment: "pi_test",
  dispute: "dp_test",
  transfer: "tr_test",
  refund: "re_test",
  charge: "ch_test",
  account: "acct_test",
  payout: "po_test",
} as const;
const metadata = {
  mort_environment: "test",
  mort_quote_ref: "quote",
  mort_contract_ref: "contract",
};
const defaults = {
  paymentIntents: {
    id: ids.payment,
    livemode: false,
    amount: 834,
    amount_received: 834,
    currency: "usd",
    metadata,
    status: "succeeded",
    latest_charge: ids.charge,
  },
  charges: { id: ids.charge, livemode: false, payment_intent: ids.payment },
  transfers: {
    id: ids.transfer,
    livemode: false,
    amount: 700,
    amount_reversed: 0,
    reversed: false,
    currency: "usd",
    metadata: { mort_environment: "test", mort_payment_ref: "payment" },
    destination: ids.account,
  },
  refunds: {
    id: ids.refund,
    charge: ids.charge,
    amount: 300,
    currency: "usd",
    status: "succeeded",
  },
  disputes: {
    id: ids.dispute,
    livemode: false,
    charge: ids.charge,
    amount: 834,
    currency: "usd",
    status: "needs_response",
    reason: "fraudulent",
    evidence_details: { due_by: 1795500000 },
  },
  accounts: {
    id: ids.account,
    livemode: false,
    identity: { country: "US", entity_type: "individual" },
    defaults: { currency: "usd" },
    configuration: {
      recipient: {
        capabilities: {
          stripe_balance: {
            payouts: { status: "active", status_details: [] },
            stripe_transfers: { status: "active", status_details: [] },
          },
        },
      },
    },
    requirements: { entries: [] },
  },
  payouts: {
    id: ids.payout,
    livemode: false,
    amount: 700,
    currency: "usd",
    status: "paid",
  },
};

type Resource = keyof typeof defaults;
function provider(
  overrides: Partial<Record<Resource, Record<string, unknown>>> = {},
) {
  const calls: { name: string; args: unknown[] }[] = [];
  const values = Object.entries(defaults)
    .filter(([name]) => name !== "accounts")
    .map(([name, value]) => [name, {
      retrieve(...args: unknown[]) {
        calls.push({ name, args });
        return Promise.resolve({ ...value, ...overrides[name as Resource] });
      },
    }]);
  const account = { ...defaults.accounts, ...overrides.accounts };
  const v2 = {
    core: {
      accounts: {
        retrieve(...args: unknown[]) {
          calls.push({ name: "accountsV2", args });
          return Promise.resolve(account);
        },
      },
    },
  };
  return {
    stripe: { ...Object.fromEntries(values), v2 } as Parameters<typeof observe>[0],
    calls,
  };
}

function event(type: string, id: string, account?: string): Stripe.Event {
  return { type, account, data: { object: { id } } } as Stripe.Event;
}

for (const source of ["platform", "connect"] as const) {
  for (const [type, kind] of Object.entries(webhookRoutes[source])) {
    Deno.test(`subscribed ${source}/${type} has a defined result`, async () => {
      const target = targetFor(
        event(type, ids[kind], source === "connect" ? ids.account : undefined),
        source,
      );
      assert.ok(target);
      const overrides = type === "transfer.canceled"
        ? { transfers: { amount_reversed: 700, reversed: true } }
        : {};
      const { stripe } = provider(overrides);
      const observed = await observe(stripe, target, "test", type);
      assert.equal(observed.kind, kind === "charge" ? "recorded" : kind);
    });
  }
}

Deno.test("delayed failure uses the current successful PaymentIntent, not the webhook snapshot", async () => {
  const { stripe } = provider();
  const target = targetFor(
    event("payment_intent.payment_failed", ids.payment),
    "platform",
  )!;
  const result = await observe(
    stripe,
    target,
    "test",
    "payment_intent.payment_failed",
  );
  assert.equal(result.state, "payment_intent.succeeded");
  assert.equal(result.amount, 834);
});

Deno.test("decline, processing and cancellation normalize without marking a payment successful", async () => {
  const target = targetFor(
    event("payment_intent.payment_failed", ids.payment),
    "platform",
  )!;
  for (
    const [providerState, expected] of [
      ["requires_payment_method", "payment_failed"],
      ["processing", "processing"],
      ["canceled", "canceled"],
    ]
  ) {
    const { stripe } = provider({
      paymentIntents: {
        status: providerState,
        amount_received: 0,
        last_payment_error: { code: "card_declined" },
      },
    });
    assert.equal(
      (await observe(stripe, target, "test", `payment_intent.${expected}`))
        .state,
      `payment_intent.${expected}`,
    );
  }
});

Deno.test("rejects under-capture and cross-environment provider objects", async () => {
  const target = targetFor(
    event("payment_intent.succeeded", ids.payment),
    "platform",
  )!;
  await assert.rejects(
    () =>
      observe(
        provider({ paymentIntents: { amount_received: 800 } }).stripe,
        target,
        "test",
        "payment_intent.succeeded",
      ),
    /capture_amount_mismatch/,
  );
  await assert.rejects(
    () =>
      observe(
        provider({ paymentIntents: { livemode: true } }).stripe,
        target,
        "test",
        "payment_intent.succeeded",
      ),
    /identity_mismatch/,
  );
});

Deno.test("tracks partial transfer reversal even when Stripe's reversed flag is false", async () => {
  const target = targetFor(
    event("transfer.reversed", ids.transfer),
    "platform",
  )!;
  const { stripe } = provider({ transfers: { amount_reversed: 300 } });
  const observed = await observe(stripe, target, "test", "transfer.reversed");
  assert.equal(observed.state, "partially_reversed");
  assert.equal(observed.reversed, 300);
  assert.equal(observed.destination, ids.account);
  await assert.rejects(
    () => observe(stripe, target, "test", "transfer.canceled"),
    /requires_verified_reversal/,
  );
});

Deno.test("payout failure is read under the Connect account and keeps its safe reason", async () => {
  const { stripe, calls } = provider({
    payouts: { status: "failed", failure_code: "account_closed" },
  });
  const target = targetFor(
    event("payout.paid", ids.payout, ids.account),
    "connect",
  )!;
  const result = await observe(stripe, target, "test", "payout.paid");
  assert.equal(result.state, "failed");
  assert.equal(result.failure, "account_closed");
  assert.deepEqual(calls[0].args, [ids.payout, {}, {
    stripeAccount: ids.account,
  }]);
});

Deno.test("Accounts v2 Connect status is read from recipient capabilities and requirements", async () => {
  const target = targetFor(
    event("account.updated", ids.account, ids.account),
    "connect",
  )!;
  const active = provider();
  const activeResult = await observe(active.stripe, target, "test", "account.updated");
  assert.equal(activeResult.state, "complete");
  assert.equal(activeResult.payouts, true);
  assert.equal(activeResult.transfers, "active");
  assert.equal(activeResult.country, "US");
  assert.equal(activeResult.currency, "USD");
  assert.deepEqual(active.calls[0].args, [
    ids.account,
    { include: ["configuration.recipient", "identity", "requirements", "defaults"] },
  ]);

  const pending = provider({
    accounts: {
      requirements: {
        entries: [{
          requirement: "relationship.legal_guardian",
          description: "relationship.legal_guardian",
          minimum_deadline: { status: "pending_verification" },
        }],
      },
    },
  });
  const restricted = provider({
    accounts: {
      requirements: {
        entries: [{ requirement: "identity.individual.id_numbers.us_ssn_last_4", minimum_deadline: { status: "past_due" } }],
      },
      configuration: {
        recipient: {
          capabilities: {
            stripe_balance: {
              payouts: { status: "restricted", status_details: [{ code: "requirements_past_due" }] },
              stripe_transfers: { status: "restricted", status_details: [{ code: "requirements_past_due" }] },
            },
          },
        },
      },
    },
  });
  assert.equal(
    (await observe(pending.stripe, target, "test", "account.updated")).state,
    "in_progress",
  );
  assert.equal(
    (await observe(pending.stripe, target, "test", "account.updated")).guardian,
    "provider_managed_required",
  );
  const restrictedResult = await observe(restricted.stripe, target, "test", "account.updated");
  assert.equal(restrictedResult.state, "restricted");
  assert.equal(restrictedResult.requirements, "past_due");
  assert.equal(restrictedResult.disabled, "requirements_past_due");
});

Deno.test("Accounts v2 account.updated rejects a live account in sandbox mode", async () => {
  const target = targetFor(
    event("account.updated", ids.account, ids.account),
    "connect",
  )!;
  const { stripe } = provider({ accounts: { livemode: true } });
  await assert.rejects(
    () => observe(stripe, target, "test", "account.updated"),
    /provider_account_mismatch/,
  );
});

Deno.test("misrouted and malformed objects are rejected before a resource lookup", () => {
  assert.equal(targetFor(event("payout.failed", ids.payout), "platform"), null);
  assert.equal(
    targetFor(event("refund.failed", ids.refund, ids.account), "connect"),
    null,
  );
  assert.equal(
    targetFor(event("account.updated", "acct_other", ids.account), "connect"),
    null,
  );
  assert.equal(
    targetFor(event("payment_intent.succeeded", ids.transfer), "platform"),
    null,
  );
});
