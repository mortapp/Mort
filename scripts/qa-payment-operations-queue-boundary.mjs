import { runSupportExecutionPaymentQa } from "./support-execution-payment-qa-suites.mjs";

await runSupportExecutionPaymentQa(
  "qa-payment-operations-queue-boundary",
  "payment-operations-queue-boundary",
);
