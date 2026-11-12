import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  correlationId,
  structuredLog,
  correlatedJson,
  safeErrorKind,
} from "../_shared/observability.ts";

/**
 * POST verification-provider-event
 *
 * Trusted server-side ingestion boundary for identity-verification provider
 * events (issue #50). This function is the ONLY writer of
 * private.verification_provider_results, and it refuses to treat
 * service-role access alone as evidence authenticity. Before any insert it
 * verifies, in order:
 *
 *  1. Provider key known and enabled for THIS project (tenant binding:
 *     keys are per provider + per project ref, so a key issued for one
 *     Supabase project cannot be replayed against another).
 *  2. HMAC-SHA256 signature over "<timestamp>.<raw body>" using the
 *     provider's per-project key (constant-time compare).
 *  3. Timestamp freshness (±300 s) — blocks stale and future-dated
 *     envelopes.
 *  4. Event shape: provider_event_id, case_id, user_id,
 *     verification_type, result, verified_at (all validated).
 *  5. Case binding: the case must exist in this project and match the
 *     event's subject (user_id), verification_type, provider and
 *     provider_reference.
 *  6. Allowlist: the provider must be enabled for the case's
 *     verification_type (fail closed while empty).
 *  7. Evidence freshness: verified_at within [case submission, now + 300 s]
 *     and, when set, expires_at > verified_at.
 *  8. Replay idempotency: unique (provider_key, provider_event_id) — a
 *     replayed event is acknowledged without a second insert.
 *
 * The stored evidence_sha256 is the SHA-256 of the exact raw request body
 * (UTF-8): a provenance fingerprint only. Authenticity is the verified
 * HMAC signature, not the hash.
 *
 * No PII is logged; only aggregate outcomes with a correlation id.
 *
 * Verify JWT: false — providers authenticate with the per-provider HMAC
 * key, not a Supabase user JWT.
 */

const MAX_BODY_BYTES = 64 * 1024;
const CLOCK_SKEW_SECONDS = 300;

const VERIFICATION_TYPES = new Set([
  "age",
  "identity",
  "guardian_consent",
  "school_email",
  "school_id",
  "business",
]);
const RESULTS = new Set(["verified", "rejected", "needs_review"]);

const encoder = new TextEncoder();

function hmacKeyBytes(secret: string): Uint8Array {
  return encoder.encode(secret);
}

async function hmacSha256(key: Uint8Array, message: string): Promise<string> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key as unknown as ArrayBuffer,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    encoder.encode(message) as unknown as ArrayBuffer,
  );
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function constantTimeEqualHex(left: string, right: string): boolean {
  if (!/^[0-9a-f]+$/.test(left) || !/^[0-9a-f]+$/.test(right)) return false;
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let i = 0; i < left.length; i += 1) {
    mismatch |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return mismatch === 0;
}

function parseIsoDate(value: unknown): string | null {
  if (typeof value !== "string" || value.length < 10 || value.length > 64) {
    return null;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return value;
}

function projectRefFromUrl(url: string): string | null {
  const match = url.match(/^https:\/\/([a-z]{20})\.supabase\.co\b/);
  return match ? match[1] : null;
}

interface CaseRow {
  id: string;
  user_id: string;
  verification_type: string;
  provider: string;
  provider_reference: string | null;
  submitted_at: string | null;
  created_at: string;
}

interface IngestionKeyRow {
  hmac_key: string;
  is_enabled: boolean;
}

Deno.serve(async (req) => {
  const traceId = correlationId(req);
  if (req.method !== "POST") {
    return correlatedJson({ error: "method_not_allowed" }, 405, traceId, {
      Allow: "POST",
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const projectRef = projectRefFromUrl(supabaseUrl);
  if (!projectRef) {
    structuredLog("error", "ingestion_project_ref_unresolvable", traceId, {});
    return correlatedJson({ error: "ingestion_misconfigured" }, 500, traceId);
  }
  const db = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const providerKey = req.headers.get("x-provider-key")?.trim() ?? "";
  const timestamp = req.headers.get("x-provider-timestamp")?.trim() ?? "";
  const signature = req.headers.get("x-provider-signature")?.trim().toLowerCase() ?? "";
  if (
    !providerKey || providerKey.length > 100 ||
    !signature || !/^[0-9a-f]{64}$/.test(signature)
  ) {
    return correlatedJson({ error: "invalid_provider_headers" }, 400, traceId);
  }
  const eventTime = new Date(timestamp);
  if (timestamp.length < 10 || Number.isNaN(eventTime.getTime())) {
    return correlatedJson({ error: "invalid_provider_timestamp" }, 400, traceId);
  }
  if (Math.abs(Date.now() - eventTime.getTime()) > CLOCK_SKEW_SECONDS * 1000) {
    return correlatedJson({ error: "stale_provider_timestamp" }, 400, traceId);
  }

  const rawBody = await req.text();
  if (rawBody.length === 0 || rawBody.length > MAX_BODY_BYTES) {
    return correlatedJson({ error: "invalid_body_size" }, 400, traceId);
  }

  // 1. Tenant binding + provider key lookup.
  let keyRow: IngestionKeyRow | null = null;
  try {
    const { data, error } = await db
      .from("verification_provider_ingestion_keys")
      .select("hmac_key,is_enabled")
      .eq("provider_key", providerKey)
      .eq("project_ref", projectRef)
      .limit(1);
    if (error) throw new Error("key_lookup_failed");
    keyRow = (data?.[0] as IngestionKeyRow) ?? null;
  } catch (error) {
    structuredLog("error", "ingestion_key_lookup_failed", traceId, {
      error_kind: safeErrorKind(error),
    });
    return correlatedJson({ error: "ingestion_unavailable" }, 500, traceId);
  }
  if (!keyRow || !keyRow.is_enabled) {
    structuredLog("warn", "ingestion_unknown_provider", traceId, {
      provider_known: false,
    });
    return correlatedJson({ error: "unknown_provider" }, 403, traceId);
  }

  // 2. HMAC signature over "<timestamp>.<raw body>".
  const expected = await hmacSha256(
    hmacKeyBytes(keyRow.hmac_key),
    `${timestamp}.${rawBody}`,
  );
  if (!constantTimeEqualHex(expected, signature)) {
    structuredLog("warn", "ingestion_bad_signature", traceId, {});
    return correlatedJson({ error: "invalid_signature" }, 401, traceId);
  }

  // 3. Event shape.
  let event: Record<string, unknown>;
  try {
    const parsed = JSON.parse(rawBody);
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("not_object");
    }
    event = parsed as Record<string, unknown>;
  } catch {
    return correlatedJson({ error: "invalid_json" }, 400, traceId);
  }
  const providerEventId = typeof event.provider_event_id === "string"
    ? event.provider_event_id.trim()
    : "";
  const caseId = typeof event.case_id === "string" ? event.case_id.trim() : "";
  const userId = typeof event.user_id === "string" ? event.user_id.trim() : "";
  const verificationType = typeof event.verification_type === "string"
    ? event.verification_type.trim()
    : "";
  const providerReference = typeof event.provider_reference === "string"
    ? event.provider_reference.trim()
    : null;
  const result = typeof event.result === "string" ? event.result.trim() : "";
  const verifiedAtRaw = parseIsoDate(event.verified_at);
  const expiresAtSupplied = event.expires_at !== undefined && event.expires_at !== null;
  const expiresAtRaw = expiresAtSupplied ? parseIsoDate(event.expires_at) : null;
  if (expiresAtSupplied && expiresAtRaw === null) {
    return correlatedJson({ error: "invalid_expires_at" }, 400, traceId);
  }

  const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (
    providerEventId.length < 1 || providerEventId.length > 200 ||
    !uuidRe.test(caseId) || !uuidRe.test(userId) ||
    !VERIFICATION_TYPES.has(verificationType) || !RESULTS.has(result) ||
    verifiedAtRaw === null ||
    (providerReference !== null && (providerReference.length < 1 || providerReference.length > 200))
  ) {
    return correlatedJson({ error: "invalid_event_payload" }, 400, traceId);
  }

  // 4-5. Case binding: the case must exist here and match the subject,
  // provider, reference, and verification type.
  let caseRow: CaseRow | null = null;
  try {
    const { data, error } = await db
      .from("verification_cases")
      .select(
        "id,user_id,verification_type,provider,provider_reference,submitted_at,created_at",
      )
      .eq("id", caseId)
      .limit(1);
    if (error) throw new Error("case_lookup_failed");
    caseRow = (data?.[0] as CaseRow) ?? null;
  } catch (error) {
    structuredLog("error", "ingestion_case_lookup_failed", traceId, {
      error_kind: safeErrorKind(error),
    });
    return correlatedJson({ error: "ingestion_unavailable" }, 500, traceId);
  }
  if (!caseRow) {
    structuredLog("warn", "ingestion_case_not_found", traceId, {});
    return correlatedJson({ error: "case_not_found" }, 404, traceId);
  }
  if (
    caseRow.user_id !== userId ||
    caseRow.verification_type !== verificationType ||
    caseRow.provider !== providerKey ||
    (caseRow.provider_reference ?? null) !== providerReference
  ) {
    structuredLog("warn", "ingestion_case_binding_mismatch", traceId, {});
    return correlatedJson({ error: "case_binding_mismatch" }, 422, traceId);
  }

  // 6. Allowlist: fail closed while empty.
  let allowlisted = false;
  try {
    const { data, error } = await db
      .from("verification_provider_allowlist")
      .select("provider_key")
      .eq("provider_key", providerKey)
      .eq("verification_type", verificationType)
      .eq("is_enabled", true)
      .limit(1);
    if (error) throw new Error("allowlist_lookup_failed");
    allowlisted = (data?.length ?? 0) > 0;
  } catch (error) {
    structuredLog("error", "ingestion_allowlist_lookup_failed", traceId, {
      error_kind: safeErrorKind(error),
    });
    return correlatedJson({ error: "ingestion_unavailable" }, 500, traceId);
  }
  if (!allowlisted) {
    structuredLog("warn", "ingestion_provider_not_allowlisted", traceId, {});
    return correlatedJson({ error: "provider_not_allowlisted" }, 403, traceId);
  }

  // 7. Evidence freshness: verified after submission (staleness), not
  // future-dated beyond clock skew, and expiry (when set) after verification.
  const verifiedAt = new Date(verifiedAtRaw);
  const submittedAtMs = caseRow.submitted_at
    ? new Date(caseRow.submitted_at).getTime()
    : new Date(caseRow.created_at).getTime();
  if (
    Number.isNaN(verifiedAt.getTime()) ||
    verifiedAt.getTime() < submittedAtMs ||
    verifiedAt.getTime() > Date.now() + CLOCK_SKEW_SECONDS * 1000
  ) {
    structuredLog("warn", "ingestion_evidence_stale_or_future", traceId, {
      stale: verifiedAt.getTime() < submittedAtMs,
    });
    return correlatedJson({ error: "evidence_time_invalid" }, 422, traceId);
  }
  if (expiresAtRaw !== null) {
    const expiresAt = new Date(expiresAtRaw);
    if (Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() <= verifiedAt.getTime()) {
      return correlatedJson({ error: "evidence_expiry_invalid" }, 422, traceId);
    }
  }

  // 8. Insert with replay idempotency; evidence_sha256 = SHA-256 of the
  // exact raw body (provenance fingerprint).
  const bodyDigest = await crypto.subtle.digest(
    "SHA-256",
    encoder.encode(rawBody) as unknown as ArrayBuffer,
  );
  const evidenceSha256 = Array.from(new Uint8Array(bodyDigest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  try {
    const { data, error } = await db
      .from("verification_provider_results")
      .insert({
        verification_case_id: caseId,
        user_id: userId,
        verification_type: verificationType,
        provider_key: providerKey,
        provider_reference: providerReference,
        provider_event_id: providerEventId,
        result,
        evidence_sha256: evidenceSha256,
        verified_at: verifiedAt.toISOString(),
        expires_at: expiresAtRaw === null ? null : new Date(expiresAtRaw).toISOString(),
      })
      .select("id");
    if (error) {
      // Unique violation on (provider_key, provider_event_id) is the
      // idempotent replay path: acknowledge without duplicating.
      if (error.code === "23505") {
        structuredLog("info", "ingestion_replay_ignored", traceId, {});
        return correlatedJson({ ok: true, duplicate: true }, 200, traceId);
      }
      throw new Error("insert_failed");
    }
    if (!data || data.length === 0) {
      // Insert with ignoreDuplicates semantics — treat as replay.
      structuredLog("info", "ingestion_replay_ignored", traceId, {});
      return correlatedJson({ ok: true, duplicate: true }, 200, traceId);
    }
  } catch (error) {
    structuredLog("error", "ingestion_insert_failed", traceId, {
      error_kind: safeErrorKind(error),
    });
    return correlatedJson({ error: "ingestion_unavailable" }, 500, traceId);
  }

  structuredLog("info", "ingestion_provider_event_accepted", traceId, {
    verification_type: verificationType,
    result,
  });
  return correlatedJson({ ok: true, duplicate: false }, 200, traceId);
});
