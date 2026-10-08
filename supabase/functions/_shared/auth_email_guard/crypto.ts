import { randomEightDigitCode } from "../secure_codes.ts";
export const makeCode = randomEightDigitCode;
export const encoder = new TextEncoder();
export function makeSecret(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll(
    "/",
    "_",
  ).replace(/=+$/, "");
}
const hex = (bytes: ArrayBuffer) =>
  Array.from(new Uint8Array(bytes), (v) => v.toString(16).padStart(2, "0"))
    .join("");
export async function secretDigest(secret: string): Promise<string> {
  return hex(await crypto.subtle.digest("SHA-256", encoder.encode(secret)));
}
export const verifierDigest = secretDigest;
export async function codeDigest(
  code: string,
  context: string,
  key: CryptoKey,
): Promise<string> {
  if (!/^\d{8}$/.test(code) || context.length === 0 || context.length > 1024) {
    throw new Error("Invalid credential shape");
  }
  return hex(
    await crypto.subtle.sign(
      "HMAC",
      key,
      encoder.encode(JSON.stringify(["mort-email-code-v1", context, code])),
    ),
  );
}
// Equal-length digests take the same fixed number of comparison iterations.
// Native/database execution and network scheduling are separate timing layers.
export function equalDigest(a: string, b: string): boolean {
  if (!/^[0-9a-f]{64}$/.test(a) || !/^[0-9a-f]{64}$/.test(b)) return false;
  let difference = 0;
  for (let i = 0; i < 64; i++) difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return difference === 0;
}
