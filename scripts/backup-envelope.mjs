import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

function parseKey(keyText) {
  if (typeof keyText !== "string" || keyText.length === 0) {
    throw new Error("backup_encryption_key_required");
  }
  const key = Buffer.from(keyText, "base64");
  if (
    key.length !== 32 ||
    key.toString("base64").replace(/=+$/, "") !== keyText.replace(/=+$/, "")
  ) {
    throw new Error("backup_encryption_key_must_be_base64_32_bytes");
  }
  return key;
}

function aad(projectRef, kind) {
  if (!projectRef || !kind) throw new Error("backup_metadata_required");
  return Buffer.from(`MORT backup v1:${projectRef}:${kind}`, "utf8");
}

export function encryptBackupEnvelope({ projectRef, kind, plaintext, keyText }) {
  const key = parseKey(keyText);
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  cipher.setAAD(aad(projectRef, kind));
  const ciphertext = Buffer.concat([
    cipher.update(Buffer.isBuffer(plaintext) ? plaintext : Buffer.from(plaintext)),
    cipher.final(),
  ]);
  return Buffer.from(JSON.stringify({
    format: "mort-encrypted-backup-v1",
    algorithm: "aes-256-gcm",
    projectRef,
    kind,
    iv: iv.toString("base64"),
    authTag: cipher.getAuthTag().toString("base64"),
    ciphertext: ciphertext.toString("base64"),
  }) + "\n", "utf8");
}

export function decryptBackupEnvelope({ envelope, keyText, expectedProjectRef, expectedKind }) {
  const key = parseKey(keyText);
  const value = JSON.parse(Buffer.isBuffer(envelope) ? envelope.toString("utf8") : String(envelope));
  if (
    value?.format !== "mort-encrypted-backup-v1" ||
    value?.algorithm !== "aes-256-gcm" ||
    value?.projectRef !== expectedProjectRef ||
    value?.kind !== expectedKind
  ) {
    throw new Error("backup_envelope_metadata_mismatch");
  }
  const iv = Buffer.from(value.iv, "base64");
  const authTag = Buffer.from(value.authTag, "base64");
  const ciphertext = Buffer.from(value.ciphertext, "base64");
  if (iv.length !== 12 || authTag.length !== 16) {
    throw new Error("backup_envelope_encoding_invalid");
  }
  const decipher = createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAAD(aad(value.projectRef, value.kind));
  decipher.setAuthTag(authTag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
}
