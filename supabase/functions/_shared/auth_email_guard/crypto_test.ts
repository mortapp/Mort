import {
  codeDigest,
  equalDigest,
  makeCode,
  makeSecret,
  secretDigest,
  verifierDigest,
} from "./crypto.ts";
const check = (condition: boolean) => {
  if (!condition) {
    throw new Error(
      "Cryptographic contract assertion failed (values redacted)",
    );
  }
};
Deno.test("eight-digit sampling rejects biased upper range and preserves leading zero", () => {
  let calls = 0;
  const code = makeCode((values) => {
    values[0] = calls++ === 0 ? 4_200_000_000 : 0;
  });
  check(code.length === 8 && Number(code) === 0 && calls === 2);
  check(
    makeCode((values) => {
      values[0] = 4_199_999_999;
    }).length === 8,
  );
});
Deno.test("independent secrets have canonical 256-bit transport", async () => {
  const a = makeSecret(), b = makeSecret();
  check(/^[A-Za-z0-9_-]{43}$/.test(a) && a !== b);
  check(/^[0-9a-f]{64}$/.test(await secretDigest(a)));
  check(await verifierDigest(a) === await secretDigest(a));
});
Deno.test("short-code HMAC binds context and key; digest comparisons reject shape", async () => {
  const key = await crypto.subtle.importKey(
    "raw",
    crypto.getRandomValues(new Uint8Array(32)),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const code = makeCode(),
    a = await codeDigest(code, "item-a", key),
    b = await codeDigest(code, "item-b", key);
  check(
    a !== b && equalDigest(a, a) && !equalDigest(a, b) && !equalDigest(a, "") &&
      !equalDigest(a, a.toUpperCase()),
  );
});
