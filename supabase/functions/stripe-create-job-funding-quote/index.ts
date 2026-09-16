import {
  authenticate,
  options,
  PublicError,
  requireRateLimit,
  type StripeContext,
} from "../_shared/stripe.ts";
import {
  createFundingQuoteHandler,
  FundingQuoteHttpError,
  type FundingQuoteContext,
} from "./handler.ts";

function asStripeContext(context: FundingQuoteContext) {
  return context.rawContext as StripeContext;
}

const handler = createFundingQuoteHandler({
  authenticate: async (request) => {
    try {
      const context = await authenticate(request);
      return { userId: context.user.id, rawContext: context };
    } catch (error) {
      if (error instanceof PublicError && error.status === 401) return null;
      if (error instanceof PublicError) throw new FundingQuoteHttpError(error.code, error.status);
      throw error;
    }
  },
  enforceRateLimit: async (context) => {
    try {
      await requireRateLimit(asStripeContext(context), "stripe_job_funding_quote");
    } catch (error) {
      if (error instanceof PublicError) throw new FundingQuoteHttpError(error.code, error.status);
      throw error;
    }
  },
  createQuote: async (context, input) => {
    const { data, error } = await asStripeContext(context).serviceClient.rpc(
      "stripe_server_create_job_funding_quote_v1",
      {
        p_payer_id: context.userId,
        p_contract_id: input.contract_id,
        p_request_id: input.request_id,
      },
    );
    if (error) {
      const message = error.message ?? "";
      if (message.includes("adult_contract_party_required")) {
        throw new FundingQuoteHttpError("funding_quote_access_denied", 403);
      }
      if (message.includes("fair_pay") || message.includes("policy_missing")) {
        throw new FundingQuoteHttpError("funding_quote_policy_unavailable", 409);
      }
      if (message.includes("active_contract_required") || message.includes("fundable_")) {
        throw new FundingQuoteHttpError("funding_quote_not_available", 409);
      }
      throw new FundingQuoteHttpError("funding_quote_unavailable", 503);
    }
    return data as Record<string, unknown>;
  },
});

Deno.serve(async (request: Request) => {
  const preflight = options(request);
  if (preflight) return preflight;
  return handler(request);
});
