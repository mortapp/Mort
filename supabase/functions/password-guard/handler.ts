// password-guard: the only supported way to set a password on MORT.
//
//   POST { action: "signup", email, password, date_of_birth, display_name?, redirect_to? }
//     (no JWT; verify_jwt = false)
//   POST { action: "update_password", password, nonce? }
//     (Authorization: Bearer <user access token>, incl. recovery sessions)
//
// Enforces the MORT password policy and the HIBP leaked-password check
// (fails CLOSED when HIBP is unavailable), then forwards the request to
// Supabase Auth with the anon/publishable key (never the service role) and a
// single-use attestation in user metadata. Database triggers reject any
// password write that does not carry a valid attestation, so calling the
// Auth API directly cannot bypass this function.

import {
  checkLeakedPassword,
  readBoundedJson,
} from "../_shared/leaked_password.ts";
import { evaluatePasswordPolicy } from "../_shared/password_policy.ts";
import { signupDateOfBirthError } from "./signup_date_of_birth.ts";
import {
  assertAttestationSecret,
  ATTESTATION_METADATA_KEY,
  mintAttestation,
  stripAttestation,
} from "../_shared/password_attestation.ts";

export interface PasswordGuardConfig {
  supabaseUrl: string;
  anonKey: string;
  attestationSecret: string | undefined;
  hibpRangeUrl?: string;
  fetchImpl?: typeof fetch;
  rateLimitPerMinute?: number;
  globalSignupLimitPerHour?: number;
  emailSignupLimitPerHour?: number;
  ipSignupLimitPerHour?: number;
  consumeSignupQuota?: (
    bucketKey: string,
    limit: number,
    windowSeconds: number,
  ) => Promise<boolean>;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const MAX_BODY_BYTES = 4 * 1024;
const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,190}\.[^\s@]{2,63}$/;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

class Limiter {
  #hits = new Map<string, { start: number; count: number }>();
  constructor(private max: number) {}
  limited(key: string): boolean {
    const now = Date.now();
    const e = this.#hits.get(key);
    if (!e || now - e.start >= 60_000) {
      if (this.#hits.size > 10_000) this.#hits.clear();
      this.#hits.set(key, { start: now, count: 1 });
      return false;
    }
    e.count += 1;
    return e.count > this.max;
  }
}

export function createPasswordGuardHandler(config: PasswordGuardConfig) {
  const fetchImpl = config.fetchImpl ?? fetch;
  const authUrl = `${config.supabaseUrl.replace(/\/+$/, "")}/auth/v1`;
  const limiter = new Limiter(config.rateLimitPerMinute ?? 10);

  async function sha256Hex(value: string): Promise<string> {
    const digest = await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(value),
    );
    return Array.from(
      new Uint8Array(digest),
      (byte) => byte.toString(16).padStart(2, "0"),
    ).join("");
  }

  async function guardPassword(
    password: unknown,
    email: string | null,
  ): Promise<Response | null> {
    const policy = evaluatePasswordPolicy(password, email);
    if (!policy.ok) return json({ ok: false, code: policy.code }, 422);
    const leaked = await checkLeakedPassword(password as string, {
      rangeUrl: config.hibpRangeUrl,
      fetchImpl,
    });
    if (leaked.status === "leaked") {
      return json({ ok: false, code: "leaked_password_compromised" }, 422);
    }
    if (leaked.status === "unavailable") {
      return json(
        { ok: false, code: "leaked_password_check_unavailable" },
        503,
      );
    }
    return null;
  }

  async function relay(response: Response): Promise<Response> {
    const text = await response.text();
    let body: unknown;
    try {
      body = text ? JSON.parse(text) : {};
    } catch {
      body = { ok: false, code: "auth_unexpected_response" };
    }
    if (response.ok) {
      return json({ ok: true, auth: stripAttestation(body) }, 200);
    }
    const b = (body ?? {}) as Record<string, unknown>;
    return json({
      ok: false,
      code: typeof b.error_code === "string"
        ? b.error_code
        : "auth_request_failed",
      auth_status: response.status,
      message: typeof b.msg === "string"
        ? b.msg
        : (typeof b.message === "string" ? b.message : undefined),
    }, response.status >= 500 ? 502 : response.status);
  }

  return async function handler(request: Request): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return json({ ok: false, code: "post_required" }, 405);
    }

    let secret: string;
    try {
      secret = assertAttestationSecret(config.attestationSecret);
    } catch {
      return json({ ok: false, code: "password_guard_unconfigured" }, 503);
    }

    let body: Record<string, unknown>;
    try {
      body = await readBoundedJson(request, MAX_BODY_BYTES);
    } catch (error) {
      const code =
        error instanceof Error && error.message === "payload_too_large"
          ? "payload_too_large"
          : "invalid_request";
      return json(
        { ok: false, code },
        code === "payload_too_large" ? 413 : 400,
      );
    }

    const clientIp =
      (request.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() ||
      "unknown";
    const action = body.action;

    if (action === "signup") {
      const email = typeof body.email === "string" ? body.email.trim() : "";
      if (!EMAIL_RE.test(email) || email.length > 254) {
        return json({ ok: false, code: "email_invalid" }, 400);
      }
      const dob = typeof body.date_of_birth === "string"
        ? body.date_of_birth.trim()
        : "";
      const dobError = signupDateOfBirthError(dob);
      if (dobError) {
        return json(
          { ok: false, code: dobError, field: "date_of_birth" },
          400,
        );
      }
      const displayName = typeof body.display_name === "string"
        ? body.display_name.trim().slice(0, 80)
        : "";
      const redirectTo =
        typeof body.redirect_to === "string" && body.redirect_to.length <= 512
          ? body.redirect_to
          : "";
      const rejected = await guardPassword(body.password, email);
      if (rejected) return rejected;

      // Auth sees this function's egress IP. A database-backed quota is shared across isolates.
      if (!config.consumeSignupQuota) {
        return json({ ok: false, code: "rate_limiter_unavailable" }, 503);
      }
      const ipDigest = await sha256Hex(clientIp);
      const emailDigest = await sha256Hex(email.toLowerCase());
      try {
        const quotas = [
          ["signup:global", config.globalSignupLimitPerHour ?? 20],
          ["signup:ip:" + ipDigest, config.ipSignupLimitPerHour ?? 10],
          ["signup:email:" + emailDigest, config.emailSignupLimitPerHour ?? 5],
        ] as const;
        for (const [key, limit] of quotas) {
          if (!await config.consumeSignupQuota(key, limit, 3600)) {
            return json({ ok: false, code: "rate_limited" }, 429);
          }
        }
      } catch {
        return json({ ok: false, code: "rate_limiter_unavailable" }, 503);
      }

      const attestation = await mintAttestation(secret, "signup", email);
      const data: Record<string, unknown> = {
        date_of_birth: dob,
        [ATTESTATION_METADATA_KEY]: attestation,
      };
      if (displayName) data.display_name = displayName;
      const role = typeof body.role === "string" ? body.role : "";
      if (["teen", "adult", "guardian"].includes(role)) data.role = role;
      const url = `${authUrl}/signup${
        redirectTo ? `?redirect_to=${encodeURIComponent(redirectTo)}` : ""
      }`;
      const response = await fetchImpl(url, {
        method: "POST",
        headers: { apikey: config.anonKey, "Content-Type": "application/json" },
        body: JSON.stringify({ email, password: body.password, data }),
      });
      return relay(response);
    }

    if (action === "update_password") {
      const token = (request.headers.get("authorization") ?? "").replace(
        /^Bearer\s+/i,
        "",
      ).trim();
      if (!token || token === config.anonKey) {
        return json({ ok: false, code: "authentication_required" }, 401);
      }
      const userResponse = await fetchImpl(`${authUrl}/user`, {
        headers: { apikey: config.anonKey, Authorization: `Bearer ${token}` },
      });
      if (!userResponse.ok) {
        await userResponse.body?.cancel().catch(() => undefined);
        return json({ ok: false, code: "authentication_required" }, 401);
      }
      const user = await userResponse.json() as { id?: string; email?: string };
      if (typeof user.id !== "string") {
        return json({ ok: false, code: "authentication_required" }, 401);
      }
      if (
        limiter.limited(`user:${user.id}`) || limiter.limited(`ip:${clientIp}`)
      ) {
        return json({ ok: false, code: "rate_limited" }, 429);
      }
      const rejected = await guardPassword(body.password, user.email ?? null);
      if (rejected) return rejected;

      const attestation = await mintAttestation(
        secret,
        "update_password",
        user.id,
      );
      const update: Record<string, unknown> = {
        password: body.password,
        data: { [ATTESTATION_METADATA_KEY]: attestation },
      };
      if (typeof body.nonce === "string" && body.nonce.length <= 32) {
        update.nonce = body.nonce;
      }
      const response = await fetchImpl(`${authUrl}/user`, {
        method: "PUT",
        headers: {
          apikey: config.anonKey,
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(update),
      });
      return relay(response);
    }

    return json({ ok: false, code: "action_invalid" }, 400);
  };
}
