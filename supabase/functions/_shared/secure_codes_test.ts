import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  randomEightDigitCode,
  SCHOOL_CODE_EXPIRY_SECONDS,
} from "./secure_codes.ts";

Deno.test("school code rejects the biased uint32 tail before reducing", () => {
  const samples = [4_294_967_295, 4_200_000_000, 4_199_999_999];
  let calls = 0;
  const code = randomEightDigitCode((values) => {
    values[0] = samples[calls++];
  });
  assertEquals(calls, 3);
  assertEquals(code, "99999999");
});

Deno.test("school code preserves leading zeros and ten-minute policy", () => {
  assertEquals(
    randomEightDigitCode((values) => {
      values[0] = 0;
    }),
    "00000000",
  );
  assertEquals(SCHOOL_CODE_EXPIRY_SECONDS, 600);
});
