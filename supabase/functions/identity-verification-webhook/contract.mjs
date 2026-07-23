const encoder = new TextEncoder();

export const verificationEnvironments = Object.freeze(["sandbox", "production"]);
export const verificationEvidenceTypes = Object.freeze([
  "government_id",
  "school_id",
  "selfie_liveness",
  "address_evidence",
  "provider_assertion",
]);
export const verificationDecisions = Object.freeze([
  "approved",
  "rejected",
  "needs_review",
]);
export const verificationFailureReasons = Object.freeze([
  "disabled",
  "sandbox_account_required",
  "provider_not_configured",
  "signature_missing",
  "signature_invalid",
  "timestamp_invalid",
  "timestamp_outside_tolerance",
  "event_id_missing",
  "event_id_mismatch",
  "payload_invalid",
  "provider_environment_mismatch",
  "account_binding_mismatch",
  "replayed_event",
  "unknown_result",
]);

export async function signWebhookBody({ rawBody, eventId, timestamp, secret }) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${timestamp}.${eventId}.${rawBody}`),
  );
  return bytesToHex(new Uint8Array(signature));
}

export async function sha256Hex(value) {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return bytesToHex(new Uint8Array(digest));
}

export async function validateWebhookEnvelope({
  rawBody,
  headers,
  secret,
  expectedProvider,
  now = Date.now(),
  toleranceMs = 5 * 60 * 1000,
}) {
  if (!secret || !expectedProvider) {
    return failure("provider_not_configured");
  }

  const timestampHeader = headerValue(headers, "x-mort-timestamp");
  const eventId = headerValue(headers, "x-mort-event-id");
  const signatureHeader = headerValue(headers, "x-mort-signature");
  if (!eventId || eventId.length < 8 || eventId.length > 200) {
    return failure("event_id_missing");
  }
  if (!signatureHeader) return failure("signature_missing");

  const timestampSeconds = Number(timestampHeader);
  if (!Number.isSafeInteger(timestampSeconds) || timestampSeconds <= 0) {
    return failure("timestamp_invalid");
  }
  const timestampMs = timestampSeconds * 1000;
  if (Math.abs(now - timestampMs) > toleranceMs) {
    return failure("timestamp_outside_tolerance");
  }

  const expectedSignature = await signWebhookBody({
    rawBody,
    eventId,
    timestamp: timestampHeader,
    secret,
  });
  const receivedSignature = signatureHeader.startsWith("v1=")
    ? signatureHeader.slice(3)
    : signatureHeader;
  if (!constantTimeHexEqual(expectedSignature, receivedSignature)) {
    return failure("signature_invalid");
  }

  let payload;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return failure("payload_invalid");
  }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return failure("payload_invalid");
  }
  if (payload.event_id !== eventId) return failure("event_id_mismatch");
  if (payload.provider !== expectedProvider) return failure("provider_not_configured");
  if (payload.environment !== "production") {
    return failure("provider_environment_mismatch");
  }
  if (!isUuid(payload.account_id) || !validString(payload.provider_reference, 8, 200)) {
    return failure("account_binding_mismatch");
  }
  if (!verificationDecisions.includes(payload.result_status)) {
    return failure("unknown_result");
  }
  if (!["teen_13_17", "adult_18_plus"].includes(payload.age_band)) {
    return failure("payload_invalid");
  }
  if (!Number.isInteger(payload.verification_level) || payload.verification_level < 0 || payload.verification_level > 4) {
    return failure("payload_invalid");
  }
  if (payload.result_status === "approved" && !validFutureDate(payload.expires_at, now)) {
    return failure("payload_invalid");
  }

  return {
    ok: true,
    eventId,
    eventTimestamp: new Date(timestampMs).toISOString(),
    payload,
    payloadSha256: await sha256Hex(rawBody),
  };
}

function headerValue(headers, name) {
  if (headers instanceof Headers) return headers.get(name)?.trim() ?? "";
  const entry = Object.entries(headers ?? {}).find(
    ([key]) => key.toLowerCase() === name,
  );
  return typeof entry?.[1] === "string" ? entry[1].trim() : "";
}

function constantTimeHexEqual(left, right) {
  if (!/^[a-f0-9]{64}$/i.test(left) || !/^[a-f0-9]{64}$/i.test(right)) {
    return false;
  }
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

function bytesToHex(bytes) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function validString(value, minimum, maximum) {
  return typeof value === "string" && value.trim().length >= minimum && value.trim().length <= maximum;
}

function isUuid(value) {
  return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function validFutureDate(value, now) {
  const parsed = typeof value === "string" ? Date.parse(value) : Number.NaN;
  return Number.isFinite(parsed) && parsed > now && parsed <= now + 3 * 366 * 24 * 60 * 60 * 1000;
}

function failure(code) {
  return { ok: false, code };
}
