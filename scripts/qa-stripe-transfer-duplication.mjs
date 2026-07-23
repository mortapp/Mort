import { runStripeQa } from "./stripe-qa-suites.mjs";

await runStripeQa("stripe-transfer-duplication", "transfer-duplication");
