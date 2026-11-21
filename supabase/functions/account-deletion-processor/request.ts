const maxBodyBytes = 4096;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type DeletionRequest =
  | { ok: true; requestId: string | null }
  | { ok: false; status: 400 | 413; code: string };

export async function readDeletionRequest(
  request: Request,
): Promise<DeletionRequest> {
  const oversized = {
    ok: false,
    status: 413,
    code: "payload_too_large",
  } as const;
  if (Number(request.headers.get("content-length") ?? "0") > maxBodyBytes) {
    return oversized;
  }
  const reader = request.body?.getReader();
  if (!reader) return { ok: true, requestId: null };

  const decoder = new TextDecoder("utf-8", { fatal: true });
  let text = "";
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBodyBytes) return oversized;
      text += decoder.decode(value, { stream: true });
    }
    text += decoder.decode();
  } catch {
    return { ok: false, status: 400, code: "invalid_json" };
  } finally {
    // Best effort only: cleanup cannot turn a client rejection into a retry.
    void reader.cancel().catch(() => {});
    reader.releaseLock();
  }

  if (!text.trim()) return { ok: true, requestId: null };
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { ok: false, status: 400, code: "invalid_json" };
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return { ok: false, status: 400, code: "invalid_json_object" };
  }

  const input = parsed as Record<string, unknown>;
  // A typo in a targeted request must not silently claim the next queued item.
  if (Object.keys(input).some((key) => key !== "requestId")) {
    return { ok: false, status: 400, code: "unexpected_request_field" };
  }
  const id = input.requestId;
  if (id === undefined) return { ok: true, requestId: null };
  if (typeof id !== "string" || !uuidPattern.test(id)) {
    return { ok: false, status: 400, code: "invalid_request_id" };
  }
  return { ok: true, requestId: id };
}
