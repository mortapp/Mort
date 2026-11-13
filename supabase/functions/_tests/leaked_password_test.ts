import {
  parseHibpRangeResponse,
  sha1Hex,
} from "../_shared/leaked_password.ts";

Deno.test("sha1Hex returns the known SHA-1 digest", async () => {
  const digest = await sha1Hex("password");
  if (digest !== "5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8") {
    throw new Error("SHA-1 digest did not match the known test vector.");
  }
});

Deno.test("HIBP range parser detects a positive matching suffix", () => {
  const result = parseHibpRangeResponse(
    "1E4C9B93F3F0682250B6CF8331B7EE68FD8:3\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:0",
    "1E4C9B93F3F0682250B6CF8331B7EE68FD8",
  );
  if (!result.valid || !result.leaked) {
    throw new Error("Expected a positive breach match.");
  }
});

Deno.test("HIBP range parser ignores padded zero-count matches", () => {
  const result = parseHibpRangeResponse(
    "1E4C9B93F3F0682250B6CF8331B7EE68FD8:0",
    "1E4C9B93F3F0682250B6CF8331B7EE68FD8",
  );
  if (!result.valid || result.leaked) {
    throw new Error("A zero-count padded row must not count as a breach.");
  }
});

Deno.test("HIBP range parser rejects malformed provider output", () => {
  const result = parseHibpRangeResponse(
    "not-a-valid-hash:many",
    "1E4C9B93F3F0682250B6CF8331B7EE68FD8",
  );
  if (result.valid || result.leaked) {
    throw new Error("Malformed provider output must be unavailable.");
  }
});


Deno.test("bounded JSON reader accepts a small object without content-length", async () => {
  const request = new Request("https://example.test/check", {
    method: "POST",
    body: JSON.stringify({ password: "example" }),
  });
  const result = await (await import("../_shared/leaked_password.ts"))
    .readBoundedJson(request, 2048);
  if (result.password !== "example") {
    throw new Error("Expected the bounded reader to parse a valid object.");
  }
});

Deno.test("bounded JSON reader rejects oversized streamed bodies", async () => {
  const request = new Request("https://example.test/check", {
    method: "POST",
    body: "x".repeat(2049),
  });
  let rejected = false;
  try {
    const helper = await import("../_shared/leaked_password.ts");
    await helper.readBoundedJson(request, 2048);
  } catch {
    rejected = true;
  }
  if (!rejected) {
    throw new Error("Expected oversized body to be rejected before full buffering.");
  }
});

Deno.test("bounded JSON reader rejects non-object JSON", async () => {
  const request = new Request("https://example.test/check", {
    method: "POST",
    body: JSON.stringify(["not", "an", "object"]),
  });
  let rejected = false;
  try {
    const helper = await import("../_shared/leaked_password.ts");
    await helper.readBoundedJson(request, 2048);
  } catch {
    rejected = true;
  }
  if (!rejected) {
    throw new Error("Expected array JSON payload to be rejected.");
  }
});
