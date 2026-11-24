import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const functionDir = join(root, "supabase/functions/account-deletion-processor");
const handlerPath = join(functionDir, "index.ts");
const handler = readFileSync(handlerPath, "utf8");

assert.ok(existsSync(join(functionDir, "observability.ts")),
  "deployment package must contain its observability dependency");
assert.ok(handler.includes('from "./observability.ts"'),
  "worker must import the package-local observability module");
assert.ok(!handler.includes('from "../_shared/observability.ts"'),
  "worker must not depend on a parent-relative shared module at deployment time");
assert.ok(!handler.includes('throw new Error("Account deletion worker secrets are not configured.")'),
  "missing worker configuration must not fail module initialization");
const configurationGuard = handler.indexOf('code: "deletion_worker_not_configured"');
assert.ok(configurationGuard >= 0, "worker must expose the fail-closed configuration code");
assert.equal(handler.slice(configurationGuard - 180, configurationGuard + 80).includes("503"), true,
  "missing configuration must return HTTP 503");
const secretCheck = handler.indexOf("constantTimeEqual(workerSecret, suppliedSecret)");
assert.ok(secretCheck > configurationGuard,
  "configuration must be checked before comparing the worker secret");


assert.ok(existsSync(join(functionDir, "request.ts")),
  "worker package must include bounded request parsing");
assert.ok(existsSync(join(functionDir, "auth_identity.ts")),
  "worker package must include Auth identity confirmation");
assert.ok(handler.includes('from "./request.ts"'));
assert.ok(handler.includes('from "./auth_identity.ts"'));
assert.ok(handler.includes("service_assert_account_deletion_lease"),
  "worker must verify its lease before destructive stages");
assert.ok(handler.includes("DeletionStorageRemovalDidNotProgress"),
  "worker must fail closed if storage pagination stops progressing");
assert.ok(handler.includes("AbortSignal.timeout(12_000)"),
  "worker network calls must have bounded timeouts");

console.log("account-deletion package, lease, and bounded-I/O assertions passed");
