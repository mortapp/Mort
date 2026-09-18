import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  createFinancialDocumentReadHandler,
  createFinancialHistoryReadHandler,
  FinancialReadHttpError,
  type FinancialDocumentDependencies,
  type FinancialHistoryDependencies,
} from "../_shared/stripe_financial_reads.ts";

const userId = "11111111-1111-4111-8111-111111111111";

function request(path: string, body: Record<string, unknown>) {
  return new Request("http://localhost/" + path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function documentDependencies(
  overrides: Partial<FinancialDocumentDependencies> = {},
): FinancialDocumentDependencies {
  return {
    authenticate: async () => ({ userId, rawContext: {} }),
    enforceRateLimit: async () => {},
    loadDocument: async () => ({
      id: "22222222-2222-4222-8222-222222222222",
      document_type: "ADULT_JOB_PAYMENT",
      receipt_id: "M-260917-00001",
      order_number: "0001",
      document_date: "2026-09-17",
      amount_cents: 2700,
      currency_code: "USD",
      status: "succeeded",
      masked_provider_reference: "ch_4242",
      immutable_snapshot: {
        job_title: "Front yard mowing",
        display_username: "@worker",
        provider_account_id: "acct_must_not_leak",
        customer_id: "cus_must_not_leak",
        account_handle: "@mort",
      },
      linked_document_refs: [],
      created_at: "2026-09-17T20:00:00.000Z",
      provider_payment_intent_id: "pi_must_not_leak",
    }),
    ...overrides,
  };
}

function historyDependencies(
  overrides: Partial<FinancialHistoryDependencies> = {},
): FinancialHistoryDependencies {
  return {
    authenticate: async () => ({ userId, rawContext: {} }),
    enforceRateLimit: async () => {},
    loadHistory: async () => ({
      items: [
        await documentDependencies().loadDocument(
          { userId, rawContext: {} },
          "M-260917-00001",
        ),
      ],
      next_cursor: "2026-09-17T20:00:00.000Z",
      provider_customer_id: "cus_must_not_leak",
    }),
    ...overrides,
  };
}

Deno.test("financial document requires authentication", async () => {
  const handler = createFinancialDocumentReadHandler(
    documentDependencies({ authenticate: async () => null }),
  );
  const response = await handler(
    request("stripe-get-financial-document", { receipt_id: "M-260917-00001" }),
  );
  assertEquals(response.status, 401);
  assertEquals((await response.json()).code, "authentication_required");
});

Deno.test("financial document rejects malformed receipt identifiers", async () => {
  const handler = createFinancialDocumentReadHandler(documentDependencies());
  const response = await handler(
    request("stripe-get-financial-document", { receipt_id: "../secret" }),
  );
  assertEquals(response.status, 400);
  assertEquals((await response.json()).code, "invalid_receipt_id");
});

Deno.test("financial document returns identical not-found behavior", async () => {
  const handler = createFinancialDocumentReadHandler(
    documentDependencies({ loadDocument: async () => null }),
  );
  const response = await handler(
    request("stripe-get-financial-document", { receipt_id: "M-260917-99999" }),
  );
  assertEquals(response.status, 404);
  assertEquals((await response.json()).code, "financial_document_not_found");
});

Deno.test("financial document minimizes and redacts internal provider identifiers", async () => {
  const handler = createFinancialDocumentReadHandler(documentDependencies());
  const response = await handler(
    request("stripe-get-financial-document", { receipt_id: "M-260917-00001" }),
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.ok, true);
  assert(!("provider_payment_intent_id" in body.document));
  assert(!("provider_account_id" in body.document.immutable_snapshot));
  assert(!("customer_id" in body.document.immutable_snapshot));
  assertEquals(body.document.immutable_snapshot.account_handle, "@mort");
});

Deno.test("financial history validates page bounds before querying", async () => {
  let called = false;
  const handler = createFinancialHistoryReadHandler(
    historyDependencies({
      loadHistory: async () => {
        called = true;
        return {};
      },
    }),
  );
  const response = await handler(
    request("stripe-list-financial-history", { limit: 51 }),
  );
  assertEquals(response.status, 400);
  assertEquals((await response.json()).code, "invalid_limit");
  assertEquals(called, false);
});

Deno.test("financial history validates cursors", async () => {
  const handler = createFinancialHistoryReadHandler(historyDependencies());
  const response = await handler(
    request("stripe-list-financial-history", { cursor: "not-a-date" }),
  );
  assertEquals(response.status, 400);
  assertEquals((await response.json()).code, "invalid_cursor");
});

Deno.test("financial history forwards normalized filters and minimizes rows", async () => {
  let received: unknown;
  const handler = createFinancialHistoryReadHandler(
    historyDependencies({
      loadHistory: async (_context, input) => {
        received = input;
        return historyDependencies().loadHistory(
          { userId, rawContext: {} },
          input,
        );
      },
    }),
  );
  const response = await handler(
    request("stripe-list-financial-history", {
      cursor: "2026-09-17T21:00:00.000Z",
      year: 2026,
      category: " payments ",
      search: " yard ",
      limit: 25,
    }),
  );
  assertEquals(response.status, 200);
  assertEquals(received, {
    cursor: "2026-09-17T21:00:00.000Z",
    year: 2026,
    category: "payments",
    search: "yard",
    limit: 25,
  });
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.next_cursor, "2026-09-17T20:00:00.000Z");
  assertEquals(body.items.length, 1);
  assert(!("provider_account_id" in body.items[0].immutable_snapshot));
  assert(!("provider_customer_id" in body));
});

Deno.test("financial read handler preserves explicit dependency failures", async () => {
  const handler = createFinancialHistoryReadHandler(
    historyDependencies({
      loadHistory: async () => {
        throw new FinancialReadHttpError("financial_history_unavailable", 503);
      },
    }),
  );
  const response = await handler(
    request("stripe-list-financial-history", {}),
  );
  assertEquals(response.status, 503);
  assertEquals((await response.json()).code, "financial_history_unavailable");
});
