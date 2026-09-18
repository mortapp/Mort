import {
  authenticate,
  requireRateLimit,
  type StripeContext,
} from "../_shared/stripe.ts";
import {
  createFinancialDocumentReadHandler,
  FinancialReadHttpError,
} from "../_shared/stripe_financial_reads.ts";

const handler = createFinancialDocumentReadHandler({
  authenticate: async (request) => {
    const context = await authenticate(request);
    return {
      userId: context.user.id,
      rawContext: context,
    };
  },
  enforceRateLimit: async (context) => {
    await requireRateLimit(
      context.rawContext as StripeContext,
      "stripe_financial_document",
    );
  },
  loadDocument: async (context, receiptId) => {
    const stripeContext = context.rawContext as StripeContext;
    const { data, error } = await stripeContext.userClient.rpc(
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

Deno.serve(handler);
