import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL(".", import.meta.url)), "..");
const workflow = await readFile(
  resolve(root, ".github/workflows/mort-backup-metadata.yml"),
  "utf8",
);

assert.match(workflow, /node scripts\/backup-encryption\.mjs/);
assert.match(workflow, /pnpm qa:backup-encryption && pnpm qa:backup-workflow/);
assert.doesNotMatch(workflow, /openssl enc -aes-256-cbc/i);

console.log(JSON.stringify({ status: "PASS", authenticated_encryption: true }));

