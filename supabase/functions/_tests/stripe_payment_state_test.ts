import {
  reducePaymentState,
  requiresStatusBeforeRetry,
  type MortPaymentState,
} from "../_shared/stripe_payment_state.ts";

const expectThrows = (callback: () => unknown, message: string) => {
  try {
    callback();
  } catch (error) {
    if (error instanceof Error && error.message === message) return;
  }
  throw new Error(`expected ${message}`);
};

const legal: Array<[MortPaymentState, MortPaymentState, MortPaymentState]> = [
  ["READY", "PROCESSING", "PROCESSING"],
  ["PROCESSING", "REQUIRES_ACTION", "REQUIRES_ACTION"],
  ["PROCESSING", "SUCCEEDED", "SUCCEEDED"],
  ["READY", "SUCCEEDED", "SUCCEEDED"],
  ["PENDING", "FAILED", "FAILED"],
  ["UNKNOWN", "SUCCEEDED", "SUCCEEDED"],
  ["PROVIDER_UNAVAILABLE", "READY", "READY"],
];

for (const [current, observed, expected] of legal) {
  if (reducePaymentState(current, observed) !== expected) {
    throw new Error(`${current} -> ${observed} did not reduce to ${expected}`);
  }
}

for (const [current, observed] of [
  ["SUCCEEDED", "FAILED"],
  ["PENDING", "READY"],
] as Array<[MortPaymentState, MortPaymentState]>) {
  expectThrows(
    () => reducePaymentState(current, observed),
    current === "SUCCEEDED"
      ? "payment_state_regression"
      : "payment_state_transition_not_allowed",
  );
}

if (!requiresStatusBeforeRetry("UNKNOWN") || !requiresStatusBeforeRetry("PROVIDER_UNAVAILABLE")) {
  throw new Error("ambiguous/provider unavailable states require reconciliation");
}
if (requiresStatusBeforeRetry("PROCESSING")) {
  throw new Error("processing should not require the unknown-state retry gate");
}

console.log("stripe_payment_state_test: PASS");
