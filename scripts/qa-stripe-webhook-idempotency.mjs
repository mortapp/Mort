import { runStripeQa } from "./stripe-qa-suites.mjs";

await runStripeQa("stripe-webhook-idempotency", "webhook-idempotency");
