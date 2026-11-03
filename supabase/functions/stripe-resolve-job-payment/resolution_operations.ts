export type ProviderOperationStatus =
  | "not_required"
  | "pending"
  | "succeeded"
  | "failed"
  | "unknown";

export type ResolutionOperationInput = {
  transferAmountCents: number;
  refundAmountCents: number;
  createTransfer: () => Promise<{ id: string }>;
  createRefund: () => Promise<{ id: string; status: string | null }>;
  recordOperation: (
    operation: "transfer" | "refund",
    status: Exclude<ProviderOperationStatus, "not_required">,
    providerObjectId: string | null,
    safeFailureCode: string | null,
  ) => Promise<void>;
  finalize: (
    input: {
      transferId: string | null;
      refundId: string | null;
      providerStatus: "succeeded" | "processing";
      safeFailureCode: string | null;
    },
  ) => Promise<{ status: string }>;
};

export type ResolutionOperationResult = {
  transferStatus: ProviderOperationStatus;
  refundStatus: ProviderOperationStatus;
  resolutionStatus: string;
  providerOperationPerformed: boolean;
};

export async function executeResolutionOperations(
  input: ResolutionOperationInput,
): Promise<ResolutionOperationResult> {
  let transferStatus: ProviderOperationStatus = input.transferAmountCents > 0
    ? "unknown"
    : "not_required";
  let refundStatus: ProviderOperationStatus = input.refundAmountCents > 0
    ? "unknown"
    : "not_required";
  let transferId: string | null = null;
  let refundId: string | null = null;
  let failureCode: string | null = null;
  let providerOperationPerformed = false;

  if (input.transferAmountCents > 0) {
    let transfer: { id: string } | null = null;
    await input.recordOperation("transfer", "pending", null, null);
    try {
      providerOperationPerformed = true;
      transfer = await input.createTransfer();
    } catch {
      transferStatus = "unknown";
      failureCode = "transfer_outcome_unknown";
      await input.recordOperation(
        "transfer",
        transferStatus,
        null,
        failureCode,
      );
      const resolution = await input.finalize({
        transferId,
        refundId,
        providerStatus: "processing",
        safeFailureCode: failureCode,
      });
      return {
        transferStatus,
        refundStatus,
        resolutionStatus: resolution.status,
        providerOperationPerformed,
      };
    }
    transferId = transfer.id;
    transferStatus = "succeeded";
    await input.recordOperation("transfer", transferStatus, transferId, null);
  }

  if (input.refundAmountCents > 0) {
    let refund: { id: string; status: string | null } | null = null;
    await input.recordOperation("refund", "pending", null, null);
    try {
      providerOperationPerformed = true;
      refund = await input.createRefund();
    } catch {
      refundStatus = "unknown";
      failureCode = "refund_outcome_unknown";
      await input.recordOperation(
        "refund",
        refundStatus,
        refundId,
        failureCode,
      );
    }
    if (refund) {
      refundId = refund.id;
      refundStatus = mapRefundStatus(refund.status);
      await input.recordOperation(
        "refund",
        refundStatus === "not_required" ? "unknown" : refundStatus,
        refundId,
        refundStatus === "failed" ? "refund_failed" : null,
      );
    }
  }

  const allRequiredOperationsSucceeded =
    (transferStatus === "not_required" || transferStatus === "succeeded") &&
    (refundStatus === "not_required" || refundStatus === "succeeded");
  const resolution = await input.finalize({
    transferId,
    refundId,
    providerStatus: allRequiredOperationsSucceeded ? "succeeded" : "processing",
    safeFailureCode: failureCode ??
      (refundStatus === "failed" ? "refund_failed" : null),
  });
  return {
    transferStatus,
    refundStatus,
    resolutionStatus: resolution.status,
    providerOperationPerformed,
  };
}

function mapRefundStatus(status: string | null): ProviderOperationStatus {
  switch (status) {
    case "succeeded":
      return "succeeded";
    case "failed":
    case "canceled":
      return "failed";
    case "pending":
      return "pending";
    default:
      return "unknown";
  }
}
