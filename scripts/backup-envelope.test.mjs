import assert from "node:assert/strict";
import test from "node:test";

import {
  decryptBackupEnvelope,
  encryptBackupEnvelope,
} from "./backup-envelope.mjs";

const keyText = Buffer.alloc(32, 7).toString("base64");
const plaintext = Buffer.from(JSON.stringify({
  projectRef: "jxbnrkasktbhtiujkhay",
  tables: { profiles: [{ id: "synthetic" }] },
}));

test("backup envelope round-trips with authenticated metadata", () => {
  const envelope = encryptBackupEnvelope({
    projectRef: "jxbnrkasktbhtiujkhay",
    kind: "feature-data",
    plaintext,
    keyText,
  });
  const decoded = decryptBackupEnvelope({
    envelope,
    keyText,
    expectedProjectRef: "jxbnrkasktbhtiujkhay",
    expectedKind: "feature-data",
  });
  assert.deepEqual(decoded, plaintext);
});

test("backup envelope rejects the wrong key", () => {
  const envelope = encryptBackupEnvelope({
    projectRef: "jxbnrkasktbhtiujkhay",
    kind: "feature-data",
    plaintext,
    keyText,
  });
  assert.throws(() => decryptBackupEnvelope({
    envelope,
    keyText: Buffer.alloc(32, 8).toString("base64"),
    expectedProjectRef: "jxbnrkasktbhtiujkhay",
    expectedKind: "feature-data",
  }));
});

test("backup envelope rejects ciphertext tampering", () => {
  const envelope = JSON.parse(encryptBackupEnvelope({
    projectRef: "jxbnrkasktbhtiujkhay",
    kind: "feature-data",
    plaintext,
    keyText,
  }).toString("utf8"));
  const ciphertext = Buffer.from(envelope.ciphertext, "base64");
  ciphertext[0] ^= 1;
  envelope.ciphertext = ciphertext.toString("base64");
  assert.throws(() => decryptBackupEnvelope({
    envelope: JSON.stringify(envelope),
    keyText,
    expectedProjectRef: "jxbnrkasktbhtiujkhay",
    expectedKind: "feature-data",
  }));
});

test("backup envelope binds ciphertext to project and backup kind", () => {
  const envelope = encryptBackupEnvelope({
    projectRef: "jxbnrkasktbhtiujkhay",
    kind: "feature-data",
    plaintext,
    keyText,
  });
  assert.throws(() => decryptBackupEnvelope({
    envelope,
    keyText,
    expectedProjectRef: "ckcxakhxqlkhppsxxjhv",
    expectedKind: "feature-data",
  }));
  assert.throws(() => decryptBackupEnvelope({
    envelope,
    keyText,
    expectedProjectRef: "jxbnrkasktbhtiujkhay",
    expectedKind: "feature-schema",
  }));
});

test("backup envelope rejects malformed encryption keys", () => {
  assert.throws(() => encryptBackupEnvelope({
    projectRef: "jxbnrkasktbhtiujkhay",
    kind: "feature-data",
    plaintext,
    keyText: "not-a-key",
  }), /backup_encryption_key_must_be_base64_32_bytes/);
});
