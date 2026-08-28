const allowedStatuses = new Set(["pending", "needs_input"]);

export function normalizeProviderHandoff({
  value,
  expectedProvider,
  allowedHosts,
  now = Date.now(),
  maximumTtlMs = 30 * 60 * 1000,
}) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return failure("provider_response_invalid");
  }
  const providerReference = cleanString(value.provider_reference, 8, 200);
  const status = cleanString(value.status, 2, 40)?.toLowerCase();
  const handoffUrl = cleanString(value.handoff_url, 12, 4096);
  const expiresAt = Date.parse(value.handoff_expires_at ?? "");
  if (value.provider !== expectedProvider || !providerReference) {
    return failure("provider_response_binding_mismatch");
  }
  if (!status || !allowedStatuses.has(status)) {
    return failure("provider_response_status_invalid");
  }
  let uri;
  try {
    uri = new URL(handoffUrl);
  } catch {
    return failure("provider_handoff_invalid");
  }
  const hostSet = new Set(
    (allowedHosts ?? []).map((host) => host.trim().toLowerCase()).filter(Boolean),
  );
  if (uri.protocol !== "https:" || uri.username || uri.password || !hostSet.has(uri.hostname.toLowerCase())) {
    return failure("provider_handoff_host_denied");
  }
  if (!Number.isFinite(expiresAt) || expiresAt <= now || expiresAt > now + maximumTtlMs) {
    return failure("provider_handoff_expiry_invalid");
  }
  return {
    ok: true,
    providerReference,
    status,
    handoffUrl: uri.toString(),
    handoffExpiresAt: new Date(expiresAt).toISOString(),
  };
}

export function safeProviderFailure(status) {
  if (status === 408 || status === 429 || status >= 500) return "provider_unavailable";
  return "unknown_failure";
}

function cleanString(value, minimum, maximum) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length >= minimum && normalized.length <= maximum
    ? normalized
    : null;
}

function failure(code) {
  return { ok: false, code };
}

