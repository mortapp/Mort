import assert from "node:assert/strict";
import test from "node:test";

let backupEncryption;
try {
  backupEncryption = await import("./backup-encryption.mjs");
} catch {
  // Keep the initial red test an assertion failure until the implementation exists.
}

const passphrase = "an-example-test-passphrase-with-more-than-32-characters";

test("encrypted backup round-trips and rejects wrong keys and tampering", async () => {
  assert.ok(backupEncryption, "backup encryption module must be available");
  const source = Buffer.from("metadata snapshot fixture\n", "utf8");
  const encrypted = backupEncryption.encryptBackupBytes(source, passphrase);

  assert.notDeepEqual(encrypted, source);
  assert.deepEqual(
    backupEncryption.decryptBackupBytes(encrypted, passphrase),
    source,
  );
  assert.throws(
    () => backupEncryption.decryptBackupBytes(encrypted, `${passphrase}x`),
  );

  const envelope = JSON.parse(encrypted.toString("utf8"));
  const ciphertext = Buffer.from(envelope.ciphertext, "base64");
  ciphertext[0] ^= 0x01;
  envelope.ciphertext = ciphertext.toString("base64");
  assert.throws(
    () =>
      backupEncryption.decryptBackupBytes(
        Buffer.from(JSON.stringify(envelope), "utf8"),
        passphrase,
      ),
  );
});
