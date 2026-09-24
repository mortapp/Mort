const keyServerUrl = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const transactionPattern = /^[0-9a-f]{16,128}$/i;
const signatureTail = /^(.*)&signature=([A-Za-z0-9_-]+)&key_id=(\d+)$/;
let cachedKeys: Map<string, CryptoKey> | null = null;
let cachedUntil = 0;

export type VerifiedAdMobReward = {
  userId: string;
  transactionId: string;
  adUnitId: string;
  rewardedAt: string;
};

export async function fetchAdMobKeys(): Promise<Map<string, CryptoKey>> {
  if (cachedKeys && Date.now() < cachedUntil) return cachedKeys;
  const response = await fetch(keyServerUrl, {
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error("AdMob key server unavailable");
  const body = await response.json() as {
    keys?: Array<{ keyId?: number; base64?: string }>;
  };
  const keys = new Map<string, CryptoKey>();
  for (const entry of body.keys ?? []) {
    if (!Number.isSafeInteger(entry.keyId) || !entry.base64) continue;
    try {
      const key = await crypto.subtle.importKey(
        "spki",
        decodeBase64(entry.base64),
        { name: "ECDSA", namedCurve: "P-256" },
        false,
        ["verify"],
      );
      keys.set(String(entry.keyId), key);
    } catch {
      // Unsupported or malformed rotation entries cannot authorize rewards.
    }
  }
  if (keys.size === 0) throw new Error("No AdMob verifier keys");
  cachedKeys = keys;
  cachedUntil = Date.now() + 60 * 60 * 1000;
  return keys;
}

export async function verifyAdMobCallback(
  rawQuery: string,
  allowedAdUnits: readonly string[],
  keys: Map<string, CryptoKey>,
  nowMs = Date.now(),
): Promise<VerifiedAdMobReward> {
  if (rawQuery.length > 4096) throw new Error("SSV callback too large");
  const match = signatureTail.exec(rawQuery);
  if (!match) throw new Error("Invalid SSV signature envelope");
  const [, signedContent, signature, keyId] = match;
  const key = keys.get(keyId);
  if (!key) throw new Error("Unknown SSV key");
  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    derToRawSignature(decodeBase64Url(signature)),
    new TextEncoder().encode(signedContent),
  );
  if (!valid) throw new Error("Invalid SSV signature");

  const params = new URLSearchParams(signedContent);
  for (const name of [
    "ad_unit",
    "user_id",
    "transaction_id",
    "timestamp",
    "reward_amount",
    "custom_data",
  ]) {
    if (params.getAll(name).length !== 1) {
      throw new Error("Missing or duplicate SSV field");
    }
  }
  const userId = params.get("user_id")!;
  const transactionId = params.get("transaction_id")!;
  const adUnitId = params.get("ad_unit")!;
  const timestampMs = Number(params.get("timestamp"));
  const amount = Number(params.get("reward_amount"));
  const permittedAdUnits = allowedAdUnits.map((id) => id.split("/").at(-1));
  if (
    !uuidPattern.test(userId) ||
    !transactionPattern.test(transactionId) ||
    !permittedAdUnits.includes(adUnitId) ||
    params.get("custom_data") !== "mort_spark" ||
    !Number.isSafeInteger(timestampMs) ||
    timestampMs < nowMs - 24 * 60 * 60 * 1000 ||
    timestampMs > nowMs + 5 * 60 * 1000 ||
    !Number.isSafeInteger(amount) ||
    amount <= 0
  ) {
    throw new Error("SSV reward fields rejected");
  }
  return {
    userId,
    transactionId,
    adUnitId,
    rewardedAt: new Date(timestampMs).toISOString(),
  };
}

function decodeBase64(value: string): Uint8Array<ArrayBuffer> {
  return new Uint8Array([...atob(value)].map((char) => char.charCodeAt(0)));
}

function decodeBase64Url(value: string): Uint8Array<ArrayBuffer> {
  const standard = value.replaceAll("-", "+").replaceAll("_", "/");
  return decodeBase64(standard.padEnd(Math.ceil(standard.length / 4) * 4, "="));
}

// Google's ECDSA signature is ASN.1 DER. WebCrypto expects fixed-width r||s.
function derToRawSignature(der: Uint8Array): Uint8Array<ArrayBuffer> {
  if (der.length < 8 || der[0] !== 0x30 || der[1] !== der.length - 2) {
    throw new Error("Invalid SSV signature encoding");
  }
  let offset = 2;
  const result = new Uint8Array(64);
  for (let part = 0; part < 2; part++) {
    if (der[offset++] !== 0x02) throw new Error("Invalid ECDSA integer");
    const length = der[offset++];
    if (length < 1 || length > 33 || offset + length > der.length) {
      throw new Error("Invalid ECDSA integer length");
    }
    const value = der.subarray(offset, offset + length);
    const significant = length === 33 && value[0] === 0 ? value.subarray(1) : value;
    if (significant.length > 32) throw new Error("Invalid ECDSA width");
    result.set(significant, part * 32 + 32 - significant.length);
    offset += length;
  }
  if (offset !== der.length) throw new Error("Invalid ECDSA suffix");
  return result;
}
