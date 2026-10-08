import {
  parseContinue,
  parseHook,
  parseJson,
  parsePassword,
  validateMailbox,
  validPassword,
} from "./parser.ts";
import { makeSecret } from "./crypto.ts";
const check = (condition: boolean) => {
  if (!condition) {
    throw new Error("Input contract assertion failed (values redacted)");
  }
};
const bytes = (x: unknown) => new TextEncoder().encode(JSON.stringify(x));
function denied(run: () => unknown) {
  let rejected = false;
  try {
    run();
  } catch {
    rejected = true;
  }
  check(rejected);
}
const id = crypto.randomUUID(), secret = makeSecret(), hash = "a".repeat(64);
Deno.test("Continue accepts locator plus exactly one recognized credential and binding", () => {
  check(
    parseContinue(bytes({ itemId: id, linkSecret: secret, verifierHash: hash }))
      .itemId === id,
  );
  check(
    parseContinue(bytes({ itemId: id, code: "00000000", verifierHash: hash }))
      .kind === "code",
  );
  for (
    const input of [
      { itemId: id, linkSecret: secret, code: "00000000", verifierHash: hash },
      { itemId: id, verifierHash: hash },
      { itemId: id.toUpperCase(), linkSecret: secret, verifierHash: hash },
      { itemId: id, linkSecret: secret + "=", verifierHash: hash },
      { email: "a@example.invalid", code: "00000000", verifierHash: hash },
      { itemId: id, code: 12345678, verifierHash: hash },
    ]
  ) denied(() => parseContinue(bytes(input)));
});
Deno.test("duplicate keys including escaped keys and nested objects fail before use", () => {
  for (
    const text of [
      '{"x":1,"x":2}',
      '{"x":1,"\\u0078":2}',
      '{"user":{"id":1,"id":2}}',
      '{"__proto__":1}',
      '{"a":NaN}',
      "[1,2]",
      '{"a":1} trailing',
    ]
  ) denied(() => parseJson(new TextEncoder().encode(text)));
  denied(() => parseJson(new Uint8Array([0xff])));
  denied(() => parseJson(new Uint8Array(16_385)));
  denied(() =>
    parseJson(
      new TextEncoder().encode('{"x":'.repeat(20) + "0" + "}".repeat(20)),
    )
  );
  check(parseJson(bytes({ x: '{"a":1}', y: [true, null, 0] })).x === '{"a":1}');
});
Deno.test("canonical secret rejects alternate final sextet encodings", () => {
  const alphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  const last = alphabet.indexOf(secret.at(-1)!);
  const alias = secret.slice(0, -1) + alphabet[last + 1];
  denied(() =>
    parseContinue(bytes({ itemId: id, linkSecret: alias, verifierHash: hash }))
  );
});
Deno.test("password requires capability and verifier, never email or extra authority", () => {
  check(
    parsePassword(
      bytes({
        capability: secret,
        verifier: makeSecret(),
        password: "Good!Password7",
      }),
    ).password.length >= 12,
  );
  for (
    const patch of [{ verifier: "" }, { password: "nosymbolPassword7" }, {
      password: "A".repeat(129) + "a1!",
    }, { role: "admin" }]
  ) {
    denied(() =>
      parsePassword(
        bytes({
          capability: secret,
          verifier: makeSecret(),
          password: "Good!Password7",
          ...patch,
        }),
      )
    );
  }
});
Deno.test("strict bound mailbox and signed hook structural action allowlist", () => {
  check(validateMailbox("QA+tag@Example.invalid") === "QA+tag@Example.invalid");
  for (
    const address of [
      "a@example.invalid\r\nBcc:x@bad.invalid",
      "Name <a@example.invalid>",
      "a@example.invalid,b@example.invalid",
      "a @example.invalid",
      "ü@example.invalid",
      "a@localhost",
      "a..b@example.invalid",
    ]
  ) denied(() => validateMailbox(address));
  const payload = {
    user: { id, email: "qa@example.invalid" },
    email_data: {
      email_action_type: "signup",
      token: "provider-owned-value",
      token_hash: "provider-owned-value",
      redirect_to: "https://mortapp.org/auth/confirmation/",
      site_url: "https://mortapp.org",
    },
  };
  check(parseHook(bytes(payload)).purpose === "confirmation");
  denied(() =>
    parseHook(
      bytes({
        ...payload,
        email_data: {
          ...payload.email_data,
          email_action_type: "email_change",
        },
      }),
    )
  );
});
Deno.test("UTF16 password boundaries agree with approved policy", () => {
  check(
    validPassword("Aa1!" + "x".repeat(8)) &&
      validPassword("Aa1!" + "x".repeat(124)),
  );
  check(
    !validPassword("Aa1!" + "x".repeat(7)) &&
      !validPassword("Aa1!" + "x".repeat(125)) &&
      !validPassword("Aa1" + "x".repeat(20)),
  );
});
