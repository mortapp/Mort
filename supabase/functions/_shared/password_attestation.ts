// Single-use password attestation tokens.
//
// password-guard mints a token only after a password passes policy + HIBP,
// and passes it to Supabase Auth inside user metadata on the same request.
// Database triggers on auth.users (production-baseline migration
// 20261116130000) recompute the HMAC with the Vault secret
// `mort_password_attestation_secret`, require an unexpired, unused nonce,
// and strip the token before the row is stored. A password write without a
// valid token is rejected, so direct Auth API calls cannot bypass the guard.
//
// Format: v1.<purpose>.<nonce:32 hex>.<exp:unix seconds>.<hmac-sha256 hex>
// MAC input: "v1|<purpose>|<subject>|<nonce>|<exp>"
//   subject = lower(trim(email)) for signup, auth user id for update_password

export type AttestationPurpose = "signup" | "update_password";
export const ATTESTATION_TTL_SECONDS = 300;
export const ATTESTATION_METADATA_KEY = "mort_password_attestation";

function hex(bytes: ArrayBuffer | Uint8Array): string {
  return Array.from(new Uint8Array(bytes))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function attestationSubject(purpose: AttestationPurpose, value: string): string {
  return purpose === "signup" ? value.trim().toLowerCase() : value;
}

async function mac(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return hex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message)));
}

export function assertAttestationSecret(secret: string | undefined | null): string {
  if (!secret || secret.length < 32) {
    throw new Error("password_attestation_secret_unconfigured");
  }
  return secret;
}

export async function mintAttestation(
  secret: string,
  purpose: AttestationPurpose,
  subject: string,
  nowSeconds = Math.floor(Date.now() / 1000),
  ttlSeconds = ATTESTATION_TTL_SECONDS,
): Promise<string> {
  assertAttestationSecret(secret);
  const nonce = hex(crypto.getRandomValues(new Uint8Array(16)));
  const exp = String(nowSeconds + ttlSeconds);
  const normalized = attestationSubject(purpose, subject);
  const signature = await mac(secret, `v1|${purpose}|${normalized}|${nonce}|${exp}`);
  return `v1.${purpose}.${nonce}.${exp}.${signature}`;
}

/** Reference verifier (the database is the enforcing verifier). */
export async function verifyAttestation(
  secret: string,
  token: string,
  purpose: AttestationPurpose,
  subject: string,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<boolean> {
  const parts = token.split(".");
  if (parts.length !== 5) return false;
  const [version, tokenPurpose, nonce, exp, signature] = parts;
  if (version !== "v1" || tokenPurpose !== purpose) return false;
  if (!/^[0-9a-f]{32}$/.test(nonce) || !/^[0-9]{1,12}$/.test(exp) || !/^[0-9a-f]{64}$/.test(signature)) {
    return false;
  }
  const expiry = Number(exp);
  if (expiry < nowSeconds || expiry > nowSeconds + 900) return false;
  const expected = await mac(
    secret,
    `v1|${purpose}|${attestationSubject(purpose, subject)}|${nonce}|${exp}`,
  );
  let diff = expected.length ^ signature.length;
  for (let i = 0; i < Math.min(expected.length, signature.length); i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return diff === 0;
}

/** Remove the attestation from any Auth API user object before returning it to a client. */
export function stripAttestation(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stripAttestation);
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (k === ATTESTATION_METADATA_KEY) continue;
      out[k] = stripAttestation(v);
    }
    return out;
  }
  return value;
}
