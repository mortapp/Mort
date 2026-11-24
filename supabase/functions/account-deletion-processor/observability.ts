export type SafeLogFields = Record<
  string,
  string | number | boolean | null | undefined
>;

export function correlationId(request: Request) {
  const supplied = request.headers.get("x-correlation-id")?.trim() ?? "";
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(supplied)
    ? supplied.toLowerCase()
    : crypto.randomUUID();
}

export function structuredLog(
  level: "info" | "warn" | "error",
  event: string,
  traceId: string,
  fields: SafeLogFields = {},
) {
  const safeEvent = /^[a-z0-9_.-]{2,80}$/.test(event)
    ? event
    : "invalid_log_event";
  const record = JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    event: safeEvent,
    correlation_id: traceId,
    ...Object.fromEntries(
      Object.entries(fields).filter(([, value]) => value !== undefined),
    ),
  });
  if (level === "error") console.error(record);
  else if (level === "warn") console.warn(record);
  else console.info(record);
}

export function correlatedJson(
  body: Record<string, unknown>,
  status: number,
  traceId: string,
  headers: HeadersInit = {},
) {
  return new Response(JSON.stringify({ ...body, correlation_id: traceId }), {
    status,
    headers: {
      ...headers,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "x-correlation-id": traceId,
    },
  });
}

export function safeErrorKind(error: unknown) {
  if (error instanceof DOMException && error.name === "TimeoutError") {
    return "timeout";
  }
  if (error instanceof TypeError) return "type_error";
  if (error instanceof Error && /^[A-Za-z][A-Za-z0-9]{1,79}$/.test(error.name)) {
    return error.name.toLowerCase();
  }
  return "unknown";
}

export function constantTimeEqual(left: string, right: string) {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  let mismatch = leftBytes.length ^ rightBytes.length;
  const length = Math.max(leftBytes.length, rightBytes.length);
  for (let index = 0; index < length; index += 1) {
    mismatch |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return mismatch === 0;
}
