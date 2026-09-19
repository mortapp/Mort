import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  createPaymentStatusHandler,
  PaymentStatusHttpError,
  type PaymentStatusDependencies,
} from "../stripe-get-job-payment-status/handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const paymentIntentId = "pi_1234567890";

function request(body: Record<string, unknown>) {
  return new Request("http://localhost/stripe-get-job-payment-status", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function dependencies(
  overrides: Partial<PaymentStatusDependencies> = {},
): PaymentStatusDependencies {
  let reads = 0;
  return {
    authenticate: async () => ({ userId, rawContext: {} }),
    enforceRateLimit: async () => {},
    loadAuthorizedState: async () => {
      reads += 1;
      return {
        payment_intent_id: paymentIntentId,
        state: reads === 1 ? "UNKNOWN" : "SUCCEEDED",
        legacy_status: reads === 1 ? "processing" : "funded",
        provider_confirmed_at:
          reads === 1 ? null : "2026-09-18T03:30:00.000Z",
        last_reconciled_at: "2026-09-18T03:30:00.000Z",
        provider_customer_id: "cus_must_not_leak",
      };
    },
    reconcile: async () => {},
    ...overrides,
  };
}

Deno.test("payment status requires authentication", async () => {
  const handler = createPaymentStatusHandler(
    dependencies({ authenticate: async () => null }),
  );
  const response = await handler(
    request({ provider_payment_intent_id: paymentIntentId }),
  );
  assertEquals(response.status, 401);
  assertEquals((await response.json()).code, "authentication_required");
});

Deno.test("payment status validates provider payment intent ids", async () => {
  const handler = createPaymentStatusHandler(dependencies());
  const response = await handler(
    request({ provider_payment_intent_id: "../pi_bad" }),
  );
  assertEquals(response.status, 400);
  assertEquals(
    (await response.json()).code,
    "invalid_provider_payment_intent_id",
  );
});

Deno.test("payment status authorizes before provider reconciliation", async () => {
  let reconciled = false;
  const handler = createPaymentStatusHandler(
    dependencies({
      loadAuthorizedState: async () => null,
      reconcile: async () => {
        reconciled = true;
      },
    }),
  );
  const response = await handler(
    request({ provider_payment_intent_id: paymentIntentId }),
  );
  assertEquals(response.status, 404);
  assertEquals((await response.json()).code, "payment_status_not_found");
  assertEquals(reconciled, false);
});

Deno.test("payment status reconciles then returns minimized monotonic state", async () => {
  let reconciled = false;
  const handler = createPaymentStatusHandler(
    dependencies({
      reconcile: async () => {
        reconciled = true;
      },
    }),
  );
  const response = await handler(
    request({ provider_payment_intent_id: paymentIntentId }),
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.state, "SUCCEEDED");
  assertEquals(body.legacy_status, "funded");
  assertEquals(reconciled, true);
  assert(!("payment_intent_id" in body));
  assert(!("provider_customer_id" in body));
});

Deno.test("payment status preserves explicit reconciliation failures", async () => {
  const handler = createPaymentStatusHandler(
    dependencies({
      reconcile: async () => {
        throw new PaymentStatusHttpError("provider_payment_facts_mismatch", 409);
      },
    }),
  );
  const response = await handler(
    request({ provider_payment_intent_id: paymentIntentId }),
  );
  assertEquals(response.status, 409);
  assertEquals(
    (await response.json()).code,
    "provider_payment_facts_mismatch",
  );
});
