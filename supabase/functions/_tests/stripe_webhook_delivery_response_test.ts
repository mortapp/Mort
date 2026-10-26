import { webhookClaimResponse } from "../stripe-webhook/delivery_response.ts";

function assertEquals<T>(actual: T, expected: T, label: string): void {
  if (actual !== expected) {
    throw new Error(
      `${label}: expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("in-flight Stripe webhook claims return a retryable 503", () => {
  const response = webhookClaimResponse({ claimed: false, in_flight: true });
  assertEquals(response?.status, 503, "in-flight delivery status");
  assertEquals(
    response?.body.code,
    "webhook_event_in_flight",
    "in-flight delivery error code",
  );
});

Deno.test("completed Stripe webhook duplicates remain acknowledged", () => {
  const response = webhookClaimResponse({ claimed: false, duplicate: true });
  assertEquals(response?.status, 200, "completed duplicate status");
  assertEquals(response?.body.duplicate, true, "completed duplicate marker");
});

Deno.test("claimed Stripe webhook events continue into processing", () => {
  assertEquals(
    webhookClaimResponse({ claimed: true }),
    null,
    "claimed event response",
  );
});
