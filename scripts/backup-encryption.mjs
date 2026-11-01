import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const VERSION = 1;
const SALT_BYTES = 16;
const NONCE_BYTES = 12;
const KEY_BYTES = 32;
const TAG_BYTES = 16;
const SCRYPT_OPTIONS = { N: 1 << 15, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
const MIN_PASSPHRASE_LENGTH = 32;

function deriveKey(passphrase, salt) {
  if (typeof passphrase !== "string" || passphrase.length < MIN_PASSPHRASE_LENGTH) {
    throw new Error("Backup passphrase must be at least 32 characters.");
  }
  return scryptSync(passphrase, salt, KEY_BYTES, SCRYPT_OPTIONS);
}

export function encryptBackupBytes(plaintext, passphrase) {
  if (!Buffer.isBuffer(plaintext)) {
    throw new TypeError("Backup plaintext must be a Buffer.");
  }

  const salt = randomBytes(SALT_BYTES);
  const nonce = randomBytes(NONCE_BYTES);
  const cipher = createCipheriv(
    "aes-256-gcm",
    deriveKey(passphrase, salt),
    nonce,
    { authTagLength: TAG_BYTES },
  );
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const envelope = {
    version: VERSION,
    algorithm: "aes-256-gcm",
    kdf: "scrypt",
    scrypt: SCRYPT_OPTIONS,
    salt: salt.toString("base64"),
    nonce: nonce.toString("base64"),
    tag: cipher.getAuthTag().toString("base64"),
    ciphertext: ciphertext.toString("base64"),
  };
  return Buffer.from(`${JSON.stringify(envelope)}\n`, "utf8");
}

export function decryptBackupBytes(encrypted, passphrase) {
  if (!Buffer.isBuffer(encrypted)) {
    throw new TypeError("Encrypted backup must be a Buffer.");
  }
  const envelope = JSON.parse(encrypted.toString("utf8"));
  if (
    envelope.version !== VERSION ||
    envelope.algorithm !== "aes-256-gcm" ||
    envelope.kdf !== "scrypt" ||
    JSON.stringify(envelope.scrypt) !== JSON.stringify(SCRYPT_OPTIONS)
  ) {
    throw new Error("Unsupported encrypted backup format.");
  }

  const salt = Buffer.from(envelope.salt, "base64");
  const nonce = Buffer.from(envelope.nonce, "base64");
  const tag = Buffer.from(envelope.tag, "base64");
  const ciphertext = Buffer.from(envelope.ciphertext, "base64");
  if (
    salt.length !== SALT_BYTES ||
    nonce.length !== NONCE_BYTES ||
    tag.length !== TAG_BYTES
  ) {
    throw new Error("Malformed encrypted backup envelope.");
  }

  const decipher = createDecipheriv(
    "aes-256-gcm",
    deriveKey(passphrase, salt),
    nonce,
    { authTagLength: TAG_BYTES },
  );
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
}

function runCli(args, env) {
  const [inputPath, outputPath] = args;
  if (!inputPath || !outputPath) {
    throw new Error("Usage: node backup-encryption.mjs <input> <output>");
  }
  const passphrase = env.BACKUP_ARCHIVE_PASSPHRASE;
  if (!passphrase) {
    throw new Error("BACKUP_ARCHIVE_PASSPHRASE is required.");
  }
  const encrypted = encryptBackupBytes(readFileSync(inputPath), passphrase);
  writeFileSync(outputPath, encrypted, { flag: "wx", mode: 0o600 });
  console.log(`[backup-encryption] Authenticated encrypted archive written: ${outputPath}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    runCli(process.argv.slice(2), process.env);
  } catch {
    console.error("[backup-encryption] Failed to create authenticated encrypted archive.");
    process.exitCode = 1;
  }
}
