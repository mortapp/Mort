export type FundingQuoteContext = {
  userId: string;
  rawContext: unknown;
};

export type FundingQuoteInput = {
  payer_id: string;
  contract_id: string;
  request_id: string;
};

export type FundingQuoteDependencies = {
  authenticate(request: Request): Promise<FundingQuoteContext | null>;
  enforceRateLimit(context: FundingQuoteContext): Promise<void>;
  createQuote(
    context: FundingQuoteContext,
    input: FundingQuoteInput,
  ): Promise<Record<string, unknown>>;
};

export class FundingQuoteHttpError extends Error {
  constructor(public readonly code: string, public readonly status: number) {
    super(code);
  }
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const maximumBodyBytes = 32 * 1024;
const responseKeys = [
  "ok",
  "quote_id",
  "contract_id",
  "contract_version_id",
  "obligation_id",
  "base_pay_cents",
  "service_fee_cents",
  "authoritative_total_cents",
  "currency_code",
  "financial_policy_version_id",
  "policy_version",
  "fair_pay_policy_version_id",
  "fair_pay_decision",
  "connected_account_readiness",
  "payment_eligibility",
  "provider_availability",
  "state",
  "created_at",
  "expires_at",
  "consumed_at",
  "idempotent",
] as const;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

function requiredUuid(value: unknown, field: string) {
  if (typeof value !== "string" || !uuidPattern.test(value)) {
    throw new FundingQuoteHttpError(`invalid_${field}`, 400);
  }
  return value;
}

function minimizeQuote(source: Record<string, unknown>) {
  const result: Record<string, unknown> = {};
  for (const key of responseKeys) {
    if (Object.hasOwn(source, key)) result[key] = source[key];
  }
  return result;
}

export function createFundingQuoteHandler(dependencies: FundingQuoteDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response("ok");
    if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);
    try {
      const context = await dependencies.authenticate(request);
      if (!context) throw new FundingQuoteHttpError("authentication_required", 401);
      await dependencies.enforceRateLimit(context);
      const declaredLength = Number(request.headers.get("content-length") ?? "0");
      if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
        throw new FundingQuoteHttpError("payload_too_large", 413);
      }
      let payload: Record<string, unknown>;
      try {
        const rawBody = await request.text();
        if (new TextEncoder().encode(rawBody).byteLength > maximumBodyBytes) {
          throw new FundingQuoteHttpError("payload_too_large", 413);
        }
        payload = rawBody.trim() ? JSON.parse(rawBody) : {};
      } catch (error) {
        if (error instanceof FundingQuoteHttpError) throw error;
        throw new FundingQuoteHttpError("invalid_json", 400);
      }
      const contractId = requiredUuid(payload.contract_id, "contract_id");
      const requestId = requiredUuid(payload.request_id, "request_id");
      const quote = await dependencies.createQuote(context, {
        payer_id: context.userId,
        contract_id: contractId,
        request_id: requestId,
      });
      return json(minimizeQuote(quote));
    } catch (error) {
      if (error instanceof FundingQuoteHttpError) {
        return json({ ok: false, code: error.code }, error.status);
      }
      return json({ ok: false, code: "funding_quote_failed" }, 500);
    }
  };
}
