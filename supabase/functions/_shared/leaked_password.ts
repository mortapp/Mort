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
