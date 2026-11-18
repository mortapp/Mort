import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { stripeProviderErrorHttpStatus } from "../_shared/stripe.ts";

Deno.test("transient Stripe provider errors remain retryable", () => {
  assertEquals(stripeProviderErrorHttpStatus("StripeConnectionError"), 503);
  assertEquals(stripeProviderErrorHttpStatus("StripeAPIError"), 503);
  assertEquals(stripeProviderErrorHttpStatus("StripeRateLimitError"), 503);
  assertEquals(stripeProviderErrorHttpStatus("StripeInvalidRequestError", 429), 503);
  assertEquals(stripeProviderErrorHttpStatus("StripeAPIError", 500), 503);
});

Deno.test("permanent Stripe request errors and card declines are not mislabeled transient", () => {
  assertEquals(stripeProviderErrorHttpStatus("StripeInvalidRequestError", 400), 400);
  assertEquals(stripeProviderErrorHttpStatus("StripeCardError", 402), 402);
  assertEquals(stripeProviderErrorHttpStatus("StripeAuthenticationError", 401), 503);
});
