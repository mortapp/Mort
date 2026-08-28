import { runStripeQa } from "./stripe-qa-suites.mjs";

await runStripeQa("stripe-payment-idempotency", "payment-idempotency");
