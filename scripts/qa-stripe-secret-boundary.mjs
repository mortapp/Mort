import { runStripeQa } from "./stripe-qa-suites.mjs";

await runStripeQa("stripe-secret-boundary", "secret-boundary");
