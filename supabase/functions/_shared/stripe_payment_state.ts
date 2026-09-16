export type MortPaymentState =
  | "READY"
  | "PROCESSING"
  | "REQUIRES_ACTION"
  | "PENDING"
  | "SUCCEEDED"
  | "DECLINED"
  | "FAILED"
  | "CANCELLED"
  | "UNKNOWN"
  | "PROVIDER_UNAVAILABLE"
  | "DUPLICATE_BLOCKED";

const terminalStates = new Set<MortPaymentState>([
  "SUCCEEDED",
  "DECLINED",
  "FAILED",
  "CANCELLED",
  "DUPLICATE_BLOCKED",
]);

const transitions: Record<MortPaymentState, ReadonlySet<MortPaymentState>> = {
  READY: new Set(["PROCESSING", "SUCCEEDED", "CANCELLED", "PROVIDER_UNAVAILABLE"]),
  PROCESSING: new Set([
    "REQUIRES_ACTION",
    "PENDING",
    "SUCCEEDED",
    "DECLINED",
    "FAILED",
    "CANCELLED",
    "UNKNOWN",
    "PROVIDER_UNAVAILABLE",
  ]),
  REQUIRES_ACTION: new Set([
    "PROCESSING",
    "PENDING",
    "SUCCEEDED",
    "DECLINED",
    "FAILED",
    "CANCELLED",
    "UNKNOWN",
  ]),
  PENDING: new Set(["SUCCEEDED", "DECLINED", "FAILED", "CANCELLED", "UNKNOWN"]),
  SUCCEEDED: new Set(),
  DECLINED: new Set(),
  FAILED: new Set(),
  CANCELLED: new Set(),
  UNKNOWN: new Set([
    "PROCESSING",
    "REQUIRES_ACTION",
    "PENDING",
    "SUCCEEDED",
    "DECLINED",
    "FAILED",
    "CANCELLED",
    "PROVIDER_UNAVAILABLE",
  ]),
  PROVIDER_UNAVAILABLE: new Set(["READY", "PROCESSING", "UNKNOWN"]),
  DUPLICATE_BLOCKED: new Set(),
};

export function reducePaymentState(
  current: MortPaymentState,
  observed: MortPaymentState,
): MortPaymentState {
  if (current === observed) return current;
  if (terminalStates.has(current)) {
    throw new Error("payment_state_regression");
  }
  if (!transitions[current].has(observed)) {
    throw new Error("payment_state_transition_not_allowed");
  }
  return observed;
}

export function requiresStatusBeforeRetry(state: MortPaymentState): boolean {
  return state === "UNKNOWN" || state === "PROVIDER_UNAVAILABLE";
}
