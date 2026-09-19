export type FinancialReadContext = {
  userId: string;
  rawContext: unknown;
};

export type FinancialHistoryInput = {
  cursorAt: string | null;
  cursorId: string | null;
  year: number | null;
  category: string | null;
  search: string | null;
  limit: number;
};

export type FinancialDocumentDependencies = {
  authenticate(request: Request): Promise<FinancialReadContext | null>;
  enforceRateLimit(context: FinancialReadContext): Promise<void>;
  loadDocument(
    context: FinancialReadContext,
    receiptId: string,
  ): Promise<Record<string, unknown> | null>;
};

export type FinancialHistoryDependencies = {
  authenticate(request: Request): Promise<FinancialReadContext | null>;
  enforceRateLimit(context: FinancialReadContext): Promise<void>;
  loadHistory(
    context: FinancialReadContext,
    input: FinancialHistoryInput,
  ): Promise<Record<string, unknown> | null>;
};

export class FinancialReadHttpError extends Error {
  constructor(public readonly code: string, public readonly status: number) {
    super(code);
  }
}

const maximumBodyBytes = 32 * 1024;
const receiptPattern = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const sensitiveKeyPattern =
  /^(?:provider|customer|connected_account|bank_account|identity|secret|token)(?:_|$)|(?:provider|customer|connected_account)_id$/i;

const documentKeys = [
  "id",
  "document_type",
  "receipt_id",
  "order_number",
  "document_date",
  "amount_cents",
  "currency_code",
  "status",
  "masked_provider_reference",
  "immutable_snapshot",
  "linked_document_refs",
  "created_at",
] as const;

const historyEventKeys = [
  "event_id",
  "event_kind",
  "event_type",
  "title",
  "display_subtitle",
  "occurred_at",
  "status",
  "amount_cents",
  "currency_code",
  "receipt_id",
  "order_number",
  "no_receipt",
  "document_type",
  "safe_code",
] as const;

export function encodeFinancialHistoryCursor(
  occurredAt: string,
  eventId: string,
) {
  if (Number.isNaN(Date.parse(occurredAt)) || !uuidPattern.test(eventId)) {
    throw new FinancialReadHttpError("invalid_cursor", 400);
  }
  return btoa(JSON.stringify([occurredAt, eventId]))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/g, "");
}

export function decodeFinancialHistoryCursor(value: string | null) {
  if (!value) return { cursorAt: null, cursorId: null };
  try {
    const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
    const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
    const decoded = JSON.parse(atob(padded));
    if (
      !Array.isArray(decoded) ||
      decoded.length !== 2 ||
      typeof decoded[0] !== "string" ||
      typeof decoded[1] !== "string" ||
      Number.isNaN(Date.parse(decoded[0])) ||
      !uuidPattern.test(decoded[1])
    ) {
      throw new Error("invalid");
    }
    return { cursorAt: decoded[0], cursorId: decoded[1] };
  } catch {
    throw new FinancialReadHttpError("invalid_cursor", 400);
  }
}

function minimizeHistoryEvent(source: Record<string, unknown>) {
  const result: Record<string, unknown> = {};
  for (const key of historyEventKeys) {
    if (Object.hasOwn(source, key)) result[key] = source[key];
  }
  return result;
}

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

async function readPayload(request: Request) {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    throw new FinancialReadHttpError("payload_too_large", 413);
  }
  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maximumBodyBytes) {
    throw new FinancialReadHttpError("payload_too_large", 413);
  }
  try {
    return (rawBody.trim() ? JSON.parse(rawBody) : {}) as Record<string, unknown>;
  } catch {
    throw new FinancialReadHttpError("invalid_json", 400);
  }
}

function optionalText(
  value: unknown,
  field: string,
  maximumLength: number,
): string | null {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value !== "string") {
    throw new FinancialReadHttpError("invalid_" + field, 400);
  }
  const normalized = value.trim();
  if (
    normalized.length === 0 ||
    normalized.length > maximumLength ||
    /[\u0000-\u001f\u007f]/.test(normalized)
  ) {
    throw new FinancialReadHttpError("invalid_" + field, 400);
  }
  return normalized;
}

function sanitizeValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sanitizeValue);
  if (!value || typeof value !== "object") return value;

  const result: Record<string, unknown> = {};
  for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
    if (sensitiveKeyPattern.test(key)) continue;
    result[key] = sanitizeValue(nested);
  }
  return result;
}

function minimizeDocument(source: Record<string, unknown>) {
  const result: Record<string, unknown> = {};
  for (const key of documentKeys) {
    if (!Object.hasOwn(source, key)) continue;
    result[key] = key === "immutable_snapshot"
      ? sanitizeValue(source[key])
      : source[key];
  }
  return result;
}

function errorResponse(error: unknown, fallbackCode: string) {
  if (error instanceof FinancialReadHttpError) {
    return json({ ok: false, code: error.code }, error.status);
  }
  return json({ ok: false, code: fallbackCode }, 500);
}

export function createFinancialDocumentReadHandler(
  dependencies: FinancialDocumentDependencies,
) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response("ok");
    if (request.method !== "POST") {
      return json({ ok: false, code: "post_required" }, 405);
    }

    try {
      const context = await dependencies.authenticate(request);
      if (!context) {
        throw new FinancialReadHttpError("authentication_required", 401);
      }
      await dependencies.enforceRateLimit(context);
      const payload = await readPayload(request);
      const receiptId = optionalText(payload.receipt_id, "receipt_id", 64);
      if (!receiptId || !receiptPattern.test(receiptId)) {
        throw new FinancialReadHttpError("invalid_receipt_id", 400);
      }

      const document = await dependencies.loadDocument(context, receiptId);
      if (!document) {
        throw new FinancialReadHttpError("financial_document_not_found", 404);
      }
      return json({ ok: true, document: minimizeDocument(document) });
    } catch (error) {
      return errorResponse(error, "financial_document_failed");
    }
  };
}

export function createFinancialHistoryReadHandler(
  dependencies: FinancialHistoryDependencies,
) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response("ok");
    if (request.method !== "POST") {
      return json({ ok: false, code: "post_required" }, 405);
    }

    try {
      const context = await dependencies.authenticate(request);
      if (!context) {
        throw new FinancialReadHttpError("authentication_required", 401);
      }
      await dependencies.enforceRateLimit(context);
      const payload = await readPayload(request);

      const cursor = optionalText(payload.cursor, "cursor", 256);
      const { cursorAt, cursorId } = decodeFinancialHistoryCursor(cursor);

      let year: number | null = null;
      if (payload.year !== null && payload.year !== undefined) {
        if (
          typeof payload.year !== "number" ||
          !Number.isInteger(payload.year) ||
          payload.year < 2000 ||
          payload.year > 2100
        ) {
          throw new FinancialReadHttpError("invalid_year", 400);
        }
        year = payload.year;
      }

      const category = optionalText(payload.category, "category", 48);
      const search = optionalText(payload.search, "search", 80);
      const rawLimit = payload.limit ?? 50;
      if (
        typeof rawLimit !== "number" ||
        !Number.isInteger(rawLimit) ||
        rawLimit < 1 ||
        rawLimit > 50
      ) {
        throw new FinancialReadHttpError("invalid_limit", 400);
      }

      const history = await dependencies.loadHistory(context, {
        cursorAt,
        cursorId,
        year,
        category,
        search,
        limit: rawLimit,
      });
      const items = Array.isArray(history?.items)
        ? history.items
            .filter((item): item is Record<string, unknown> =>
              Boolean(item) && typeof item === "object" && !Array.isArray(item)
            )
            .map(minimizeHistoryEvent)
        : [];
      const nextCursorAt =
        typeof history?.next_cursor_at === "string"
          ? history.next_cursor_at
          : null;
      const nextCursorId =
        typeof history?.next_cursor_id === "string"
          ? history.next_cursor_id
          : null;
      const nextCursor =
        nextCursorAt && nextCursorId
          ? encodeFinancialHistoryCursor(nextCursorAt, nextCursorId)
          : null;

      return json({
        ok: true,
        items,
        next_cursor: nextCursor,
      });
    } catch (error) {
      return errorResponse(error, "financial_history_failed");
    }
  };
}
