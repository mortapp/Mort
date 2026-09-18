import {
  authenticate,
  options,
  PublicError,
  requireRateLimit,
  type StripeContext,
} from "../_shared/stripe.ts";
import {
  createFinancialHistoryReadHandler,
  FinancialReadHttpError,
  type FinancialReadContext,
} from "../_shared/stripe_financial_reads.ts";

function asStripeContext(context: FinancialReadContext) {
  return context.rawContext as StripeContext;
}

const handler = createFinancialHistoryReadHandler({
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
        "stripe_financial_history",
      );
    } catch (error) {
      if (error instanceof PublicError) {
        throw new FinancialReadHttpError(error.code, error.status);
      }
      throw error;
    }
  },
  loadHistory: async (context, input) => {
    const { data, error } = await asStripeContext(context).userClient.rpc(
      "get_my_financial_history_v1",
      {
        p_cursor: input.cursor,
        p_year: input.year,
        p_category: input.category,
        p_search: input.search,
        p_limit: input.limit,
      },
    );
    if (error) {
      throw new FinancialReadHttpError("financial_history_unavailable", 503);
    }
    if (!data || typeof data !== "object" || Array.isArray(data)) {
      return { items: [], next_cursor: null };
    }
    return data as Record<string, unknown>;
  },
});

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  return handler(request);
});
