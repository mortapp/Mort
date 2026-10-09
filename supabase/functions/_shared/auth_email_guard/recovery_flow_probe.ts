import { Admission } from "./admission.ts";
import { makeSecret, secretDigest } from "./crypto.ts";
import { createFixtureProvider } from "./provider.ts";
import { handleEmailGuard } from "../../mort-auth-email-guard/handler.ts";
import type { createFixtureStore } from "./store.ts";
import type pg from "pg";

export async function recoveryFlow(
  config: {
    mode: "local_fixture";
    authUrl: string;
    serviceKey: string;
    anonKey: string;
    accountId: string;
    recoveryScenario: string;
    privateAuditPath: string;
  },
  store: Awaited<ReturnType<typeof createFixtureStore>>,
  codeKey: CryptoKey,
  db: pg.Client,
) {
  const check = (value: unknown, label: string) => {
    if (!value) throw new Error("Recovery control failed: " + label);
  };
  check(["replace", "expired"].includes(config.recoveryScenario), "scenario");
  const audit = new Set<string>();
  const trackedSecret = () => {
    const value = makeSecret();
    audit.add(value);
    return value;
  };
  const original =
    (await db.query("SELECT encrypted_password FROM auth.users WHERE id=$1", [
      config.accountId,
    ])).rows[0].encrypted_password;
  const family = (await db.query(
    "SELECT id FROM mort_auth_guard.families WHERE account_id=$1 AND purpose='recovery'",
    [config.accountId],
  )).rows[0];
  const capture = await (await fetch("http://127.0.0.1:55424/api/v1/messages"))
    .json();
  let link: URL | undefined;
  for (const message of capture.messages ?? []) {
    const detail =
      await (await fetch("http://127.0.0.1:55424/api/v1/message/" + message.ID))
        .json();
    const match =
      /https:\/\/mortapp\.org\/auth\/recovery\/#itemId=[0-9a-f-]{36}&linkSecret=[A-Za-z0-9_-]{43}/
        .exec(detail.Text ?? "");
    if (match) {
      const candidate = new URL(match[0]);
      const itemId = new URLSearchParams(candidate.hash.slice(1)).get("itemId");
      if (
        (await db.query(
          "SELECT id FROM mort_auth_guard.items WHERE id=$1 AND family_id=$2",
          [itemId, family.id],
        )).rowCount === 1
      ) {
        link = candidate;
        const code = /Your eight-digit code: (\d{8})/.exec(detail.Text ?? "");
        check(code, "actual SMTP recovery code");
        audit.add(code![1]);
      }
    }
  }
  check(link, "actual SMTP recovery link");
  const provider = await createFixtureProvider(config, store),
    admission = new Admission();
  const sourceHash = await secretDigest(trackedSecret());
  const gateway = Deno.serve(
    { hostname: "127.0.0.1", port: 55426, onListen: () => {} },
    (request) =>
      handleEmailGuard(request, {
        mode: "local_fixture",
        sourceHash,
        admission,
        allowedOrigins: ["https://mortapp.org"],
        codeKey,
        store,
        dispatch: provider.dispatch,
      }),
  );
  try {
    const fragment = new URLSearchParams(link!.hash.slice(1)),
      verifier = trackedSecret();
    const input = {
      itemId: fragment.get("itemId"),
      linkSecret: fragment.get("linkSecret"),
      verifierHash: await secretDigest(verifier),
    };
    audit.add(String(input.linkSecret));
    audit.add(input.verifierHash);
    const post = async (path: string, value: unknown) => {
      const response = await fetch("http://127.0.0.1:55426" + path, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          origin: "https://mortapp.org",
        },
        body: JSON.stringify(value),
        signal: AbortSignal.timeout(15000),
      });
      return { status: response.status, value: await response.json() };
    };
    if (config.recoveryScenario === "expired") {
      // Backdate this disposable challenge, preserving the exact 600s lifetime.
      // No token is revived and no production expiry threshold changes.
      await db.query(
        "UPDATE mort_auth_guard.families SET issued_at=statement_timestamp()-interval '601 seconds',family_expires_at=statement_timestamp()-interval '1 second' WHERE id=$1",
        [family.id],
      );
      check(
        (await post("/continue", input)).status === 400,
        "expired link denied",
      );
      check(
        (await db.query(
          "SELECT encrypted_password FROM auth.users WHERE id=$1",
          [config.accountId],
        )).rows[0].encrypted_password === original,
        "expired link changes no password",
      );
      check(
        (await db.query(
          "SELECT count(*)::int n FROM mort_auth_guard.capabilities WHERE account_id=$1",
          [config.accountId],
        )).rows[0].n === 0,
        "expired link grants no capability",
      );
    } else {
      check(
        (await post("/continue", { ...input, linkSecret: trackedSecret() }))
          .status === 400,
        "wrong link denied",
      );
      check(
        (await db.query(
          "SELECT encrypted_password FROM auth.users WHERE id=$1",
          [config.accountId],
        )).rows[0].encrypted_password === original,
        "wrong link changes no password",
      );
      const continued = await post("/continue", input);
      check(
        continued.status === 200 && continued.value.ok &&
          continued.value.purpose === "recovery",
        "real recovery capability",
      );
      audit.add(String(continued.value.capability));
      check(
        (await post("/continue", input)).status === 400,
        "reused link denied",
      );
      const password = "Aa9!" + trackedSecret(),
        passwordInput = {
          capability: continued.value.capability,
          verifier,
          password,
        };
      audit.add(password);
      const changed = await post("/password", passwordInput);
      check(
        changed.status === 200 && changed.value.ok,
        "password replacement committed",
      );
      check(
        (await post("/password", passwordInput)).status === 400,
        "reused capability denied",
      );
      check(
        (await db.query(
          "SELECT encrypted_password FROM auth.users WHERE id=$1",
          [config.accountId],
        )).rows[0].encrypted_password !== original,
        "stored password actually changed",
      );
      const login = await fetch(config.authUrl + "/token?grant_type=password", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: "Bearer " + config.anonKey,
        },
        body: JSON.stringify({
          email: (await db.query("SELECT email FROM auth.users WHERE id=$1", [
            config.accountId,
          ])).rows[0].email,
          password,
        }),
        signal: AbortSignal.timeout(10000),
      });
      const loginValue = await login.json();
      for (const field of ["access_token", "refresh_token"]) {
        if (typeof loginValue[field] === "string") audit.add(loginValue[field]);
      }
      check(
        login.status === 200 &&
          loginValue.user?.id === config.accountId,
        "replacement password signs in",
      );
    }
    check(admission.snapshot().active === 0, "admission released");
    console.log("PASS real recovery " + config.recoveryScenario + " controls");
  } finally {
    // Exact --allow-write target lies in the ACL-protected ignored fixture.
    // Parent reads it privately for sink auditing and removes it in finally.
    await Deno.writeTextFile(
      config.privateAuditPath,
      JSON.stringify([...audit]),
      { mode: 0o600 },
    );
    await gateway.shutdown();
    await db.query(
      "DELETE FROM mort_auth_guard.operation_grants WHERE account_id=$1",
      [config.accountId],
    );
    await db.query(
      "DELETE FROM mort_auth_guard.address_proofs WHERE account_id=$1",
      [config.accountId],
    );
  }
}
