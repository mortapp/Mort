import { runStripeQa } from "./stripe-qa-suites.mjs";

await runStripeQa("stripe-payment-amount-forgery", "payment-amount-forgery");
