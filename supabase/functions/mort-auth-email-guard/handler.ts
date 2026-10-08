import { Admission } from "../_shared/auth_email_guard/admission.ts";
import {
  canonicalId,
  parseContinue,
  parsePasswordEnvelope,
  validPassword,
} from "../_shared/auth_email_guard/parser.ts";
import {
  codeDigest,
  makeSecret,
  secretDigest,
} from "../_shared/auth_email_guard/crypto.ts";
import { busy, publicFailure } from "../_shared/auth_email_guard/redaction.ts";
import { GuardBusy } from "../_shared/auth_email_guard/store.ts";
export type GuardDeps = {
  mode: "disabled" | "local_fixture";
  // Supplied only by the owned ingress process, never derived from HTTP headers.
  sourceHash: string;
  admission: Admission;
  allowedOrigins: string[];
  codeKey: CryptoKey;
  store: {
    consume(
      input: Record<string, unknown>,
      material: Record<string, unknown>,
      signal: AbortSignal,
    ): Promise<Record<string, unknown>>;
    reserve(
      input: Record<string, unknown>,
      signal: AbortSignal,
    ): Promise<Record<string, unknown>>;
  };
  dispatch(
    operation: Record<string, unknown>,
    password: string,
    signal: AbortSignal,
  ): Promise<"committed" | "pending" | "fenced">;
};
async function body(
  request: Request,
  signal: AbortSignal,
): Promise<Uint8Array> {
  if (
    !request.body || Number(request.headers.get("content-length") ?? 0) > 16384
  ) throw new Error("Invalid input");
  const reader = request.body.getReader(), parts: Uint8Array[] = [];
  let size = 0;
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
      size += value.length;
      if (size > 16384) throw new Error("Invalid input");
      parts.push(value);
    }
    const raw = new Uint8Array(size);
    let offset = 0;
    for (const p of parts) {
      raw.set(p, offset);
      offset += p.length;
    }
    return raw;
  } finally {
    signal.removeEventListener("abort", abort);
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}
export async function handleEmailGuard(
  request: Request,
  deps: GuardDeps,
): Promise<Response> {
  const started = performance.now(), origin = request.headers.get("origin");
  const headers: Record<string, string> = {
    "content-type": "application/json",
    "cache-control": "no-store",
    "referrer-policy": "no-referrer",
    "x-content-type-options": "nosniff",
    "vary": "Origin",
  };
  if (origin && deps.allowedOrigins.includes(origin)) {
    headers["access-control-allow-origin"] = origin;
  }
  const response = (status: number, data: unknown) =>
    new Response(JSON.stringify(data), {
      status,
      headers: {
        ...headers,
        ...(status === 429 ? { "retry-after": "1" } : {}),
      },
    });
  const failure = async () => {
    const remaining = 350 - (performance.now() - started);
    if (remaining > 0) await new Promise((r) => setTimeout(r, remaining));
    return response(400, publicFailure());
  };
  if (
    deps.mode !== "local_fixture" || !/^[0-9a-f]{64}$/.test(deps.sourceHash)
  ) return response(503, publicFailure());
  const url = new URL(request.url);
  if (origin && !deps.allowedOrigins.includes(origin)) {
    return response(403, publicFailure());
  }
  if (!["/continue", "/password"].includes(url.pathname)) {
    return response(404, publicFailure());
  }
  if (request.method === "OPTIONS" && origin) {
    return new Response(null, {
      status: 204,
      headers: {
        ...headers,
        "access-control-allow-methods": "POST",
        "access-control-allow-headers": "content-type",
        "access-control-max-age": "0",
      },
    });
  }
  if (request.method !== "POST") return response(405, publicFailure());
  const ticket = deps.admission.acquire(deps.sourceHash);
  if (!ticket) return response(429, busy());
  const execute = async () => {
    const controller = new AbortController();
    let abortReject: () => void = () => {};
    const deadline = new Promise<never>((_, reject) => {
      abortReject = () => reject(new GuardBusy());
      controller.signal.addEventListener("abort", abortReject, { once: true });
    });
    const timer = setTimeout(() => controller.abort(), 250);
    let result: Record<string, unknown> = { ok: false },
      capability: string | undefined,
      password: string | undefined;
    try {
      const work = async () => {
        const raw = await body(request, controller.signal);
        if (url.pathname === "/continue") {
          const input = parseContinue(raw);
          if (!ticket.bind(input.itemId)) throw new GuardBusy();
          const credentialDigest = input.kind === "code"
            ? await codeDigest(input.credential, input.itemId, deps.codeKey)
            : await secretDigest(input.credential);
          capability = makeSecret();
          controller.signal.throwIfAborted();
          return await deps.store.consume(
            {
              itemId: input.itemId,
              kind: input.kind,
              credentialDigest,
              verifierHash: input.verifierHash,
            },
            { capabilityDigest: await secretDigest(capability) },
            controller.signal,
          );
        }
        const input = parsePasswordEnvelope(raw);
        password = input.password;
        controller.signal.throwIfAborted();
        return await deps.store.reserve({
          capabilityDigest: await secretDigest(input.capability),
          verifierHash: await secretDigest(input.verifier),
          passwordValid: validPassword(password),
          operationId: crypto.randomUUID(),
        }, controller.signal);
      };
      result = await Promise.race([work(), deadline]);
      controller.signal.throwIfAborted();
    } catch (error) {
      if (error instanceof GuardBusy || controller.signal.aborted) {
        return response(429, busy());
      }
      return failure();
    } finally {
      clearTimeout(timer);
      controller.signal.removeEventListener("abort", abortReject);
    }
    if (result.ok !== true) {
      if (url.pathname === "/password" && result.policy === true) {
        return response(400, {
          ok: false,
          message: "Choose a password that meets the requirements.",
        });
      }
      return failure();
    }
    if (url.pathname === "/continue") {
      if (
        !capability ||
        !["confirmation", "recovery"].includes(String(result.purpose)) ||
        typeof result.maskedRecipient !== "string" ||
        !/^.{1}\*\*\*@[^@\s]{1,253}$/.test(result.maskedRecipient) ||
        ![result.familyExpiresAt, result.capabilityExpiresAt].every((x) =>
          typeof x === "string" && Number.isFinite(Date.parse(x))
        )
      ) return failure();
      return response(200, {
        ok: true,
        capability,
        purpose: result.purpose,
        maskedRecipient: result.maskedRecipient,
        familyExpiresAt: result.familyExpiresAt,
        capabilityExpiresAt: result.capabilityExpiresAt,
      });
    }
    try {
      canonicalId(result.operationId);
      canonicalId(result.accountId);
      if (
        !password || !validPassword(password) ||
        !["confirmation", "recovery"].includes(String(result.purpose)) ||
        typeof result.expiresAt !== "string" ||
        Date.parse(result.expiresAt) <= Date.now()
      ) return failure();
      const signal = AbortSignal.timeout(
        Math.max(1, Math.min(10000, Date.parse(result.expiresAt) - Date.now())),
      );
      const outcome = await deps.dispatch(result, password, signal);
      if (outcome === "committed") {
        return response(200, {
          ok: true,
          message: "Password updated. Return to MORT to sign in.",
        });
      }
      // Unknown outcomes leave the one-use grant reserved; no reopen or rebind.
      return failure();
    } catch {
      return failure();
    } finally {
      password = undefined;
    }
  };
  try {
    if (
      url.search ||
      request.headers.get("content-type")?.split(";")[0].trim() !==
        "application/json"
    ) return await failure();
    return await execute();
  } finally {
    ticket.release();
  }
}
