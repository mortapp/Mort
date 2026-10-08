import { Webhook } from "standardwebhooks";
import { parseHook } from "../_shared/auth_email_guard/parser.ts";
import {
  codeDigest,
  makeCode,
  makeSecret,
  secretDigest,
} from "../_shared/auth_email_guard/crypto.ts";
import { encryptEnvelope } from "../_shared/auth_email_guard/outbox.ts";
import {
  envelopeBinding,
  type EnvelopeContext,
} from "../_shared/auth_email_guard/mail.ts";
export type HookDeps = {
  mode: "disabled" | "local_fixture";
  signingSecret: Uint8Array;
  encryptionKey: CryptoKey;
  codeKey: CryptoKey;
  resolveTrustedSource(
    eventDigest: string,
    accountId: string,
    signal: AbortSignal,
  ): Promise<string | null>;
  store: {
    context(
      accountId: string,
      recipientHash: string,
      signal: AbortSignal,
    ): Promise<Record<string, number> | null>;
    issue(
      event: Record<string, unknown>,
      material: Record<string, unknown>,
      signal: AbortSignal,
    ): Promise<{ ok: boolean }>;
  };
};
const response = (status: number) =>
  new Response(
    JSON.stringify(
      status === 200 ? {} : {
        error: {
          http_code: status,
          message: "MORT email request unavailable.",
        },
      },
    ),
    {
      status,
      headers: {
        "content-type": "application/json",
        "cache-control": "no-store",
        "referrer-policy": "no-referrer",
      },
    },
  );
async function boundedBody(
  request: Request,
  signal: AbortSignal,
): Promise<Uint8Array> {
  if (
    !request.body || Number(request.headers.get("content-length") ?? 0) > 16384
  ) throw new Error("Unavailable");
  const reader = request.body.getReader();
  const parts: Uint8Array[] = [];
  let total = 0;
  const abort = () => {
    void reader.cancel().catch(() => {});
  };
  signal.addEventListener("abort", abort, { once: true });
  try {
    while (true) {
      signal.throwIfAborted();
      const { done, value } = await reader.read();
      signal.throwIfAborted();
      if (done) break;
      total += value.length;
      if (total > 16384) throw new Error("Unavailable");
      parts.push(value);
    }
    const bytes = new Uint8Array(total);
    let at = 0;
    for (const part of parts) {
      bytes.set(part, at);
      at += part.length;
    }
    return bytes;
  } finally {
    signal.removeEventListener("abort", abort);
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}
export async function handleEmailHook(
  request: Request,
  deps: HookDeps,
): Promise<Response> {
  if (deps.mode !== "local_fixture") return response(503);
  if (
    request.method !== "POST" || new URL(request.url).search ||
    request.headers.get("content-type")?.split(";")[0].trim() !==
      "application/json"
  ) return response(400);
  const controller = new AbortController(),
    timer = setTimeout(() => controller.abort(), 3000);
  let abortReject: () => void = () => {};
  const deadline = new Promise<never>((_, reject) => {
    abortReject = () => reject(new Error("Unavailable"));
    controller.signal.addEventListener("abort", abortReject, { once: true });
  });
  const work = async () => {
    const headers = {
      "webhook-id": request.headers.get("webhook-id") ?? "",
      "webhook-timestamp": request.headers.get("webhook-timestamp") ?? "",
      "webhook-signature": request.headers.get("webhook-signature") ?? "",
    };
    if (
      !/^[A-Za-z0-9_-]{1,128}$/.test(headers["webhook-id"]) ||
      !/^\d{10}$/.test(headers["webhook-timestamp"]) ||
      headers["webhook-signature"].length > 2048
    ) throw new Error("Unavailable");
    const signedAt = Number(headers["webhook-timestamp"]),
      now = Math.floor(Date.now() / 1000);
    if (signedAt < now - 300 || signedAt > now + 30) {
      throw new Error("Unavailable");
    }
    const bytes = await boundedBody(request, controller.signal);
    const raw = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    new Webhook(deps.signingSecret, { format: "raw" }).verify(raw, headers, {
      jsonParse: false,
    });
    const event = parseHook(bytes),
      eventDigest = await secretDigest(headers["webhook-id"]);
    const sourceHash = await deps.resolveTrustedSource(
      eventDigest,
      event.accountId,
      controller.signal,
    );
    if (!sourceHash || !/^[0-9a-f]{64}$/.test(sourceHash)) {
      throw new Error("Unavailable");
    }
    const recipientHash = await secretDigest(event.recipient),
      context = await deps.store.context(
        event.accountId,
        recipientHash,
        controller.signal,
      );
    if (!context) throw new Error("Unavailable");
    const itemId = crypto.randomUUID(),
      familyId = crypto.randomUUID(),
      code = makeCode(),
      linkSecret = makeSecret();
    const bound = {
      accountId: event.accountId,
      purpose: event.purpose,
      recipientHash,
      sourceHash,
      ...context,
    };
    const encryptedEnvelope = await encryptEnvelope(
      new TextEncoder().encode(
        JSON.stringify({ recipient: event.recipient, code, linkSecret }),
      ),
      envelopeBinding({ ...bound, itemId } as EnvelopeContext),
      deps.encryptionKey,
    );
    const material = {
      ...context,
      familyId,
      itemId,
      codeDigest: await codeDigest(code, itemId, deps.codeKey),
      linkDigest: await secretDigest(linkSecret),
      encryptedEnvelope,
    };
    controller.signal.throwIfAborted();
    const result = await deps.store.issue(
      {
        ...bound,
        eventDigest,
        bodyDigest: await secretDigest(raw),
        signedAt: new Date(signedAt * 1000).toISOString(),
      },
      material,
      controller.signal,
    );
    controller.signal.throwIfAborted();
    return response(result.ok ? 200 : 400);
  };
  try {
    return await Promise.race([work(), deadline]);
  } catch {
    return response(400);
  } finally {
    clearTimeout(timer);
    controller.signal.removeEventListener("abort", abortReject);
  }
}
