import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  createFinancialDocumentReadHandler,
  createFinancialHistoryReadHandler,
  decodeFinancialHistoryCursor,
  encodeFinancialHistoryCursor,
  FinancialReadHttpError,
  type FinancialDocumentDependencies,
  type FinancialHistoryDependencies,
} from "../_shared/stripe_financial_reads.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const eventId = "22222222-2222-4222-8222-222222222222";
const nextEventId = "33333333-3333-4333-8333-333333333333";
const receiptId = "M-260918-00001";

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
      id: eventId,
      document_type: "ADULT_JOB_PAYMENT",
      receipt_id: receiptId,
      order_number: "0001",
      document_date: "2026-09-18",
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
      created_at: "2026-09-18T12:00:00.000Z",
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
      items: [{
        event_id: eventId,
        event_kind: "payment_attempt",
        event_type: "job_funding",
        title: "Job funding attempt",
        display_subtitle: null,
        occurred_at: "2026-09-18T12:00:00.000Z",
        status: "DECLINED",
        amount_cents: 2700,
        currency_code: "USD",
        receipt_id: null,
        order_number: null,
        no_receipt: true,
        document_type: null,
        safe_code: "card_declined",
        provider_payment_intent_id: "pi_must_not_leak",
        provider_customer_id: "cus_must_not_leak",
      }],
      next_cursor_at: "2026-09-18T11:59:59.000Z",
      next_cursor_id: nextEventId,
      provider_account_id: "acct_must_not_leak",
    }),
    ...overrides,
  };
}

Deno.test("financial document requires authentication", async () => {
  const handler = createFinancialDocumentReadHandler(
    documentDependencies({ authenticate: async () => null }),
  );
  const response = await handler(
    request("stripe-get-financial-document", { receipt_id: receiptId }),
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
    request("stripe-get-financial-document", { receipt_id: "M-260918-99999" }),
  );
  assertEquals(response.status, 404);
  assertEquals((await response.json()).code, "financial_document_not_found");
});

Deno.test("financial document minimizes internal provider identifiers", async () => {
  const handler = createFinancialDocumentReadHandler(documentDependencies());
  const response = await handler(
    request("stripe-get-financial-document", { receipt_id: receiptId }),
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.ok, true);
  assert(!("provider_payment_intent_id" in body.document));
  assert(!("provider_account_id" in body.document.immutable_snapshot));
  assert(!("customer_id" in body.document.immutable_snapshot));
  assertEquals(body.document.immutable_snapshot.account_handle, "@mort");
});

Deno.test("financial history cursor is opaque and round trips timestamp plus id", () => {
  const cursor = encodeFinancialHistoryCursor(
    "2026-09-18T12:00:00.000Z",
    eventId,
  );
  assert(!cursor.includes("2026-09-18"));
  assertEquals(decodeFinancialHistoryCursor(cursor), {
    cursorAt: "2026-09-18T12:00:00.000Z",
    cursorId: eventId,
  });
});

Deno.test("financial history rejects malformed cursors", async () => {
  const handler = createFinancialHistoryReadHandler(historyDependencies());
  const response = await handler(
    request("stripe-list-financial-history", { cursor: "not-a-valid-cursor" }),
  );
  assertEquals(response.status, 400);
  assertEquals((await response.json()).code, "invalid_cursor");
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

Deno.test("financial history forwards stable cursor parts and minimizes rows", async () => {
  let received: unknown;
  const cursor = encodeFinancialHistoryCursor(
    "2026-09-18T12:00:01.000Z",
    nextEventId,
  );
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
      cursor,
      year: 2026,
      category: " failed ",
      search: " yard ",
      limit: 25,
    }),
  );
  assertEquals(response.status, 200);
  assertEquals(received, {
    cursorAt: "2026-09-18T12:00:01.000Z",
    cursorId: nextEventId,
    year: 2026,
    category: "failed",
    search: "yard",
    limit: 25,
  });
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.items.length, 1);
  assertEquals(body.items[0].no_receipt, true);
  assert(!("provider_payment_intent_id" in body.items[0]));
  assert(!("provider_customer_id" in body.items[0]));
  assert(!("provider_account_id" in body));
  assertEquals(decodeFinancialHistoryCursor(body.next_cursor), {
    cursorAt: "2026-09-18T11:59:59.000Z",
    cursorId: nextEventId,
  });
});

Deno.test("financial history preserves explicit dependency failures", async () => {
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
