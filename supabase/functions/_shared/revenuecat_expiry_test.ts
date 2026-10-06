import { revenueCatActiveUntil } from "./revenuecat_expiry.ts";

const paid = Date.UTC(2026, 9, 6);
const grace = paid + 86_400_000;
function equal(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, received ${actual}`);
  }
}

Deno.test("billing issue preserves provider-confirmed grace beyond paid expiry", () => {
  equal(
    revenueCatActiveUntil("billing_issue", paid, grace),
    new Date(grace).toISOString(),
  );
});
Deno.test("shorter grace does not shorten the paid period", () => {
  equal(
    revenueCatActiveUntil("billing_issue", grace, paid),
    new Date(grace).toISOString(),
  );
});
Deno.test("other event types cannot extend access through a grace field", () => {
  for (
    const type of [
      "renewal",
      "cancellation",
      "expiration",
      "revocation",
      "product_change",
    ]
  ) {
    equal(
      revenueCatActiveUntil(type, paid, grace),
      new Date(paid).toISOString(),
    );
  }
});
Deno.test("absent grace retains expiration including lifetime null", () => {
  equal(
    revenueCatActiveUntil("billing_issue", paid, null),
    new Date(paid).toISOString(),
  );
  equal(revenueCatActiveUntil("non_renewing_purchase", null, grace), null);
  equal(
    revenueCatActiveUntil("billing_issue", null, grace),
    new Date(grace).toISOString(),
  );
});
