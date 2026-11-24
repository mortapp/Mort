import { assertEquals } from "jsr:@std/assert@1";
import { createPasswordGuardHandler } from "../password-guard/handler.ts";
import { signupDateOfBirthError } from "../password-guard/signup_date_of_birth.ts";

Deno.test("signup DOB: rejects non-calendar dates and dates outside the plausible range", () => {
  const today = new Date("2026-11-21T20:00:00Z");
  for (
    const value of [
      "",
      "2009-2-20",
      "2010-02-29",
      "2012-02-30",
      "0000-01-01",
      "2026-11-22",
      "1900-01-01",
    ]
  ) {
    assertEquals(signupDateOfBirthError(value, today), "dob_invalid", value);
  }
});

Deno.test("signup DOB: accepts the 13th birthday on the UTC calendar boundary", () => {
  const before = new Date("2026-11-20T23:59:59.999Z");
  const on = new Date("2026-11-21T00:00:00Z");
  assertEquals(
    signupDateOfBirthError("2013-11-21", before),
    "dob_under_minimum_age",
  );
  assertEquals(signupDateOfBirthError("2013-11-21", on), null);
  assertEquals(signupDateOfBirthError("1995-08-20", on), null);
});

Deno.test("signup DOB: February 29 follows the app's month-and-day comparison", () => {
  assertEquals(
    signupDateOfBirthError("2012-02-29", new Date("2025-02-28T20:00:00Z")),
    "dob_under_minimum_age",
  );
  assertEquals(
    signupDateOfBirthError("2012-02-29", new Date("2025-03-01T00:00:00Z")),
    null,
  );
});

Deno.test("signup DOB: invalid and underage dates stop before HIBP, quota, or Auth", async () => {
  let outboundCalls = 0;
  let quotaCalls = 0;
  const handler = createPasswordGuardHandler({
    supabaseUrl: "https://auth.test",
    anonKey: "unused-publishable-key",
    attestationSecret: "local-fixture-for-dob-test-0123456789abcdef",
    fetchImpl: async () => {
      outboundCalls++;
      throw new Error("Unexpected outbound call");
    },
    consumeSignupQuota: async () => {
      quotaCalls++;
      throw new Error("Unexpected quota call");
    },
  });
  const year = new Date().getUTCFullYear();
  for (
    const [date_of_birth, code] of [
      [`${year + 1}-01-01`, "dob_invalid"],
      [`${year - 10}-01-01`, "dob_under_minimum_age"],
      ["2012-02-30", "dob_invalid"],
    ]
  ) {
    const res = await handler(
      new Request("https://local.test/password-guard", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          action: "signup",
          email: "dob-fixture@example.org",
          password: "Plum-Orbit-Kettle-73",
          date_of_birth,
        }),
      }),
    );
    assertEquals(res.status, 400);
    assertEquals(await res.json(), { ok: false, code, field: "date_of_birth" });
  }
  assertEquals(outboundCalls, 0);
  assertEquals(quotaCalls, 0);
});
