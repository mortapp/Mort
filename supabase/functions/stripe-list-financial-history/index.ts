import {
  authenticate,
  requireRateLimit,
  type StripeContext,
} from "../_shared/stripe.ts";
import {
  createFinancialHistoryReadHandler,
  FinancialReadHttpError,
} from "../_shared/stripe_financial_reads.ts";

const handler = createFinancialHistoryReadHandler({
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
      "stripe_financial_history",
    );
  },
  loadHistory: async (context, input) => {
    const stripeContext = context.rawContext as StripeContext;
    const { data, error } = await stripeContext.userClient.rpc(
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

Deno.serve(handler);
