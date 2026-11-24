export async function sha1Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-1",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
}

export function parseHibpRangeResponse(
  body: string,
  expectedSuffix: string,
): { valid: boolean; leaked: boolean } {
  if (!/^[0-9A-F]{35}$/i.test(expectedSuffix)) {
    return { valid: false, leaked: false };
  }

  let leaked = false;
  for (const rawLine of body.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line) continue;
    const [candidateSuffix, count, ...extra] = line.split(":");
    if (
      extra.length !== 0 ||
      !/^[0-9A-F]{35}$/i.test(candidateSuffix ?? "") ||
      !/^\d+$/.test(count ?? "")
    ) {
      return { valid: false, leaked: false };
    }
    if (
      candidateSuffix.toUpperCase() === expectedSuffix.toUpperCase() &&
      Number(count) > 0
    ) {
      leaked = true;
    }
  }

  return { valid: true, leaked };
}


export async function readBoundedJson(
  request: Request,
  maximumBodyBytes: number,
): Promise<Record<string, unknown>> {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    throw new Error("payload_too_large");
  }
  if (!request.body) throw new Error("request_body_required");

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maximumBodyBytes) {
        await reader.cancel().catch(() => undefined);
        throw new Error("payload_too_large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  const value: unknown = JSON.parse(
    new TextDecoder("utf-8", { fatal: true }).decode(bytes),
  );
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_json");
  }
  return value as Record<string, unknown>;
}

export type LeakedPasswordResult =
  | { status: "clear" }
  | { status: "leaked" }
  | { status: "unavailable"; reason: string };

/**
 * HIBP k-anonymity range lookup. Only the first five hex characters of the
 * SHA-1 leave this process. Any network, HTTP, timeout, or parse failure is
 * reported as "unavailable" so callers can fail closed.
 */
export async function checkLeakedPassword(
  password: string,
  options: {
    rangeUrl?: string;
    timeoutMs?: number;
    fetchImpl?: typeof fetch;
  } = {},
): Promise<LeakedPasswordResult> {
  const rangeUrl = options.rangeUrl ?? "https://api.pwnedpasswords.com/range/";
  const fetchImpl = options.fetchImpl ?? fetch;
  const hash = await sha1Hex(password);
  const prefix = hash.slice(0, 5);
  const suffix = hash.slice(5);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), options.timeoutMs ?? 4000);
  try {
    const response = await fetchImpl(`${rangeUrl}${prefix}`, {
      headers: { "Add-Padding": "true", "User-Agent": "mort-password-guard" },
      signal: controller.signal,
    });
    if (!response.ok) {
      await response.body?.cancel().catch(() => undefined);
      return { status: "unavailable", reason: `http_${response.status}` };
    }
    const body = await response.text();
    if (body.length > 2_000_000) return { status: "unavailable", reason: "oversized" };
    const parsed = parseHibpRangeResponse(body, suffix);
    if (!parsed.valid) return { status: "unavailable", reason: "malformed" };
    return parsed.leaked ? { status: "leaked" } : { status: "clear" };
  } catch (_error) {
    return { status: "unavailable", reason: "network" };
  } finally {
    clearTimeout(timer);
  }
}
