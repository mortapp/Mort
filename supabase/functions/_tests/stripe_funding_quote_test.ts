import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  createFundingQuoteHandler,
  FundingQuoteHttpError,
  type FundingQuoteDependencies,
} from "../stripe-create-job-funding-quote/handler.ts";

const adultId = "11111111-1111-4111-8111-111111111111";
const contractId = "22222222-2222-4222-8222-222222222222";
const requestId = "33333333-3333-4333-8333-333333333333";

function request(body: Record<string, unknown>) {
  return new Request("http://localhost/stripe-create-job-funding-quote", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function dependencies(overrides: Partial<FundingQuoteDependencies> = {}): FundingQuoteDependencies {
  return {
    authenticate: async () => ({ userId: adultId, rawContext: {} }),
    enforceRateLimit: async () => {},
    createQuote: async () => ({
      ok: true,
      quote_id: "44444444-4444-4444-8444-444444444444",
      base_pay_cents: 2500,
      service_fee_cents: 200,
      authoritative_total_cents: 2700,
      currency_code: "USD",
      expires_at: "2026-09-16T12:15:00.000Z",
      policy_version: "sandbox-2026-09-16-v1",
      fair_pay_decision: "GREEN",
      connected_account_readiness: "READY_FOR_TRANSFER",
      provider_account_id: "acct_must_not_leak",
      internal_request_hash: "must_not_leak",
    }),
    ...overrides,
  };
}

Deno.test("funding quote requires authentication", async () => {
  const handler = createFundingQuoteHandler(dependencies({ authenticate: async () => null }));
  const response = await handler(request({ contract_id: contractId, request_id: requestId }));
  assertEquals(response.status, 401);
  assertEquals((await response.json()).code, "authentication_required");
});

Deno.test("funding quote validates UUID inputs", async () => {
  const handler = createFundingQuoteHandler(dependencies());
  const response = await handler(request({ contract_id: "not-a-uuid", request_id: requestId }));
  assertEquals(response.status, 400);
  assertEquals((await response.json()).code, "invalid_contract_id");
});

Deno.test("funding quote maps cross-adult denial without leaking database details", async () => {
  const handler = createFundingQuoteHandler(dependencies({
    createQuote: async () => {
      throw new FundingQuoteHttpError("funding_quote_access_denied", 403);
    },
  }));
  const response = await handler(request({ contract_id: contractId, request_id: requestId }));
  assertEquals(response.status, 403);
  assertEquals(await response.json(), { ok: false, code: "funding_quote_access_denied" });
});

Deno.test("funding quote returns only the minimized server-authoritative DTO", async () => {
  let received: Record<string, string> | undefined;
  const handler = createFundingQuoteHandler(dependencies({
    createQuote: async (_context, input) => {
      received = input;
      return dependencies().createQuote({ userId: adultId, rawContext: {} }, input);
    },
  }));
  const response = await handler(request({
    contract_id: contractId,
    request_id: requestId,
    base_pay_cents: 1,
    service_fee_cents: 0,
    authoritative_total_cents: 1,
    policy_version: "forged",
  }));
  assertEquals(response.status, 200);
  assertEquals(received, { payer_id: adultId, contract_id: contractId, request_id: requestId });
  const body = await response.json();
  assertEquals(body.authoritative_total_cents, 2700);
  assertEquals(body.policy_version, "sandbox-2026-09-16-v1");
  assert(!("provider_account_id" in body));
  assert(!("internal_request_hash" in body));
  assert(!("base_pay_cents" in received!));
  assert(!("service_fee_cents" in received!));
});
