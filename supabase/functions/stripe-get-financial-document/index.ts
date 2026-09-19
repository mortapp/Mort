import {
  authenticate,
  options,
  PublicError,
  requireRateLimit,
  type StripeContext,
} from "../_shared/stripe.ts";
import {
  createFinancialDocumentReadHandler,
  FinancialReadHttpError,
  type FinancialReadContext,
} from "../_shared/stripe_financial_reads.ts";

function asStripeContext(context: FinancialReadContext) {
  return context.rawContext as StripeContext;
}

const handler = createFinancialDocumentReadHandler({
  authenticate: async (request) => {
    try {
      const context = await authenticate(request);
      return {
        userId: context.user.id,
        rawContext: context,
      };
    } catch (error) {
      if (error instanceof PublicError && error.status === 401) return null;
      if (error instanceof PublicError) {
        throw new FinancialReadHttpError(error.code, error.status);
      }
      throw error;
    }
  },
  enforceRateLimit: async (context) => {
    try {
      await requireRateLimit(
        asStripeContext(context),
        "stripe_financial_document",
      );
    } catch (error) {
      if (error instanceof PublicError) {
        throw new FinancialReadHttpError(error.code, error.status);
      }
      throw error;
    }
  },
  loadDocument: async (context, receiptId) => {
    const { data, error } = await asStripeContext(context).userClient.rpc(
      "get_my_financial_document_v1",
      { p_receipt_id: receiptId },
    );
    if (error) {
      throw new FinancialReadHttpError("financial_document_unavailable", 503);
    }
    if (!data || typeof data !== "object" || Array.isArray(data)) return null;
    return data as Record<string, unknown>;
  },
});

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  return handler(request);
});
