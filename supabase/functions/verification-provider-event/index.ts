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
 * Thin proxy for the trusted ingestion boundary
 * (private.ingest_verification_provider_event, exposed to service role as
 * public.mort_ingest_verification_provider_event — issue #50).
 *
 * The edge function forwards the signed envelope to the SQL boundary,
 * which atomically verifies, in one transaction: provider key + project
 * tenant binding, HMAC-SHA256 signature over "<timestamp>.<raw body>",
 * timestamp freshness, event shape, case binding (subject / verification
 * type / provider / reference), provider allowlist (fail closed),
 * evidence freshness and expiry, and replay idempotency — and only then
 * inserts into private.verification_provider_results. Service-role access
 * alone is never treated as evidence authenticity.
 *
 * The raw body is forwarded byte-for-byte so the SQL-side HMAC check and
 * the stored evidence_sha256 (SHA-256 of the exact raw body) see exactly
 * what the provider sent.
 *
 * No PII is logged; only aggregate outcomes with a correlation id.
 *
 * Verify JWT: false — providers authenticate with the per-provider HMAC
 * key, not a Supabase user JWT.
 */

const MAX_BODY_BYTES = 64 * 1024;

const STATUS_BY_ERROR: Record<string, number> = {
  invalid_request: 400,
  invalid_provider_timestamp: 400,
  stale_provider_timestamp: 400,
  invalid_json: 400,
  invalid_event_payload: 400,
  unknown_provider: 403,
  provider_not_allowlisted: 403,
  invalid_signature: 401,
  case_not_found: 404,
  case_binding_mismatch: 422,
  evidence_time_invalid: 422,
  evidence_expiry_invalid: 422,
};

function projectRefFromUrl(url: string): string | null {
  const match = url.match(/^https:\/\/([a-z]{20})\.supabase\.co\b/);
  return match ? match[1] : null;
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
  const signature = req.headers.get("x-provider-signature")?.trim() ?? "";
  if (!providerKey || !timestamp || !signature) {
    return correlatedJson({ error: "invalid_provider_headers" }, 400, traceId);
  }

  const rawBody = await req.text();
  if (rawBody.length === 0 || rawBody.length > MAX_BODY_BYTES) {
    return correlatedJson({ error: "invalid_body_size" }, 400, traceId);
  }

  let outcome: Record<string, unknown>;
  try {
    const { data, error } = await db.rpc("mort_ingest_verification_provider_event", {
      p_project_ref: projectRef,
      p_provider_key: providerKey,
      p_timestamp: timestamp,
      p_signature: signature,
      p_raw_body: rawBody,
    });
    if (error) throw new Error("rpc_failed");
    outcome = (data ?? {}) as Record<string, unknown>;
  } catch (error) {
    structuredLog("error", "ingestion_boundary_unavailable", traceId, {
      error_kind: safeErrorKind(error),
    });
    return correlatedJson({ error: "ingestion_unavailable" }, 500, traceId);
  }

  if (outcome.ok === true) {
    structuredLog("info", "ingestion_provider_event_accepted", traceId, {
      duplicate: outcome.duplicate === true,
    });
    return correlatedJson(
      { ok: true, duplicate: outcome.duplicate === true },
      200,
      traceId,
    );
  }
  const errorCode = typeof outcome.error === "string" ? outcome.error : "invalid_request";
  structuredLog("warn", "ingestion_provider_event_rejected", traceId, {
    error_code: errorCode,
  });
  return correlatedJson(
    { error: errorCode },
    STATUS_BY_ERROR[errorCode] ?? 422,
    traceId,
  );
});
