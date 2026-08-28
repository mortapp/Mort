import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import {
  expoProductionSupport,
  supportedProductionClient,
} from "../lib/production-client.cjs";

assert.equal(supportedProductionClient, "flutter");
assert.deepEqual(expoProductionSupport(), {
  supported: false,
  reason: "reference_only",
});

const productionConfig = spawnSync(
  "pnpm exec expo config --type public",
  {
    cwd: fileURLToPath(new URL("..", import.meta.url)),
    encoding: "utf8",
    env: { ...process.env, EAS_BUILD_PROFILE: "production" },
    shell: true,
  },
);
assert.notEqual(productionConfig.status, 0, "Expo production config unexpectedly succeeded");
assert.match(
  `${productionConfig.stdout}\n${productionConfig.stderr}`,
  /reference-only and cannot be built as a supported production MORT client/,
);

console.log("[qa-production-client-contract] Flutter is the sole supported production client; Expo is reference-only.");
