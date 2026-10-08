const fail = (): never => {
  throw new Error("Envelope unavailable");
};
const encoder = new TextEncoder();
function validate(binding: string, key: CryptoKey): void {
  if (
    binding.length === 0 || binding.length > 2048 ||
    key.algorithm.name !== "AES-GCM" ||
    (key.algorithm as AesKeyAlgorithm).length !== 256
  ) fail();
}
export async function encryptEnvelope(
  plaintext: Uint8Array,
  binding: string,
  key: CryptoKey,
): Promise<string> {
  validate(binding, key);
  if (plaintext.length === 0 || plaintext.length > 16_384) fail();
  try {
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const cipher = new Uint8Array(
      await crypto.subtle.encrypt(
        {
          name: "AES-GCM",
          iv,
          additionalData: encoder.encode(binding),
          tagLength: 128,
        },
        key,
        Uint8Array.from(plaintext),
      ),
    );
    const packed = new Uint8Array(iv.length + cipher.length);
    packed.set(iv);
    packed.set(cipher, iv.length);
    return "v1." + btoa(String.fromCharCode(...packed));
  } catch {
    return fail();
  }
}
export async function decryptEnvelope(
  ciphertext: string,
  binding: string,
  key: CryptoKey,
): Promise<Uint8Array> {
  validate(binding, key);
  if (
    ciphertext.length > 22_000 || !/^v1\.[A-Za-z0-9+/]+={0,2}$/.test(ciphertext)
  ) fail();
  try {
    const raw = atob(ciphertext.slice(3));
    if (raw.length <= 28 || btoa(raw) !== ciphertext.slice(3)) fail();
    const packed = Uint8Array.from(raw, (c) => c.charCodeAt(0));
    return new Uint8Array(
      await crypto.subtle.decrypt(
        {
          name: "AES-GCM",
          iv: packed.slice(0, 12),
          additionalData: encoder.encode(binding),
          tagLength: 128,
        },
        key,
        packed.slice(12),
      ),
    );
  } catch {
    return fail();
  }
}
