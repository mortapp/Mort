import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const script = await readFile(
  new URL("./build-play-console-aab.ps1", import.meta.url),
  "utf8",
);

test("Play AAB script injects a declared Supabase URL variable", () => {
  const sourceVariable = script.match(
    /^\$env:SUPABASE_URL\s*=\s*\$(\w+)\s*$/im,
  )?.[1];
  assert.ok(sourceVariable, "SUPABASE_URL must be assigned from a variable");

  const declaredVariables = new Set(
    [...script.matchAll(/^\$(\w+)\s*=/gim)].map((match) =>
      match[1].toLowerCase(),
    ),
  );
  assert.ok(
    declaredVariables.has(sourceVariable.toLowerCase()),
    `SUPABASE_URL references undeclared variable $${sourceVariable}`,
  );
});
