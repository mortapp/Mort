import { directPeerSource } from "./trusted-source.ts";
import pg from "pg";
import { Webhook } from "standardwebhooks";
import { createFixtureStore } from "./store.ts";
import { runDeliveryBatch, sendFixedEmail } from "./delivery.ts";
import { handleEmailHook } from "../../mort-auth-email-hook/handler.ts";
import { makeSecret, secretDigest } from "./crypto.ts";
import { Admission } from "./admission.ts";
import { createFixtureProvider } from "./provider.ts";
import { handleEmailGuard } from "../../mort-auth-email-guard/handler.ts";
function check(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
if (Deno.env.get("MORT_FIXTURE_VERIFIED") !== "1") {
  throw new Error("Fixture delivery refused");
}
const body = await new Response(Deno.stdin.readable).text();
if (body.length > 4096) throw new Error("Fixture delivery refused");
const config = JSON.parse(body), target = new URL(config.dbUrl);
if (
  config.mode !== "local_fixture" || target.hostname !== "127.0.0.1" ||
  target.port !== "55422"
) throw new Error("Fixture delivery refused");
const owner = new pg.Client({
  connectionString: config.dbUrl,
  connectionTimeoutMillis: 2000,
  query_timeout: 2000,
});
const events: string[] = [];
let store: Awaited<ReturnType<typeof createFixtureStore>> | undefined;
let gateway: Deno.HttpServer | undefined;
try {
  await owner.connect();
  const identity = await owner.query("SELECT id FROM mort_fixture.identity");
  check(
    identity.rows.length === 1 && identity.rows[0].id === config.fixtureId,
    "Exact fixture identity required",
  );
  check(
    (await owner.query(
      "SELECT enabled=false AS disabled FROM mort_auth_guard.control",
    )).rows[0].disabled,
    "Fixture starts disabled",
  );
  await owner.query("UPDATE mort_auth_guard.control SET enabled=true");
  store = await createFixtureStore(config);
  const context = await store.context(
    config.accountId,
    await secretDigest(config.recipient),
  );
  check(context?.addressGeneration === 1, "Private context positive");
  const key = await crypto.subtle.generateKey(
      { name: "AES-GCM", length: 256 },
      false,
      ["encrypt", "decrypt"],
    ),
    codeKey = await crypto.subtle.generateKey(
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
  const signingSecret = crypto.getRandomValues(new Uint8Array(32)),
    webhook = new Webhook(signingSecret, { format: "raw" });
  async function hook() {
    const id = crypto.randomUUID(), date = new Date();
    events.push(await secretDigest(id));
    const raw = JSON.stringify({
      user: { id: config.accountId, email: config.recipient },
      email_data: {
        email_action_type: "signup",
        token: "discard-provider-value",
      },
    });
    return await handleEmailHook(
      new Request("http://127.0.0.1:55426/hook", {
        method: "POST",
        body: raw,
        headers: {
          "content-type": "application/json",
          "webhook-id": id,
          "webhook-timestamp": String(Math.floor(date.getTime() / 1000)),
          "webhook-signature": webhook.sign(id, date, raw),
        },
      }),
      {
        mode: "local_fixture",
        signingSecret,
        encryptionKey: key,
        codeKey,
        store: store!,
        resolveTrustedSource: async () =>
          secretDigest("owned-synthetic-ingress-context"),
      },
    );
  }
  check(
    (await hook()).status === 200,
    "Real private store signed hook positive",
  );
  const queued = await owner.query(
    "SELECT i.state='issued' AND o.encrypted_envelope LIKE 'v1.%' AS private FROM mort_auth_guard.items i JOIN mort_auth_guard.outbox o ON o.item_id=i.id JOIN mort_auth_guard.families f ON f.id=i.family_id WHERE f.account_id=$1",
    [config.accountId],
  );
  check(
    queued.rows.length === 1 && queued.rows[0].private,
    "Queue encrypted/unusable before dispatch",
  );
  const mailConfig = {
    mode: "local_fixture",
    host: "127.0.0.1",
    port: 55425,
    ca: await Deno.readTextFile(config.certificate),
    user: "fixture",
    password: "fixture-only",
  } as const;
  const stats = await runDeliveryBatch({
    mode: "local_fixture",
    key,
    store: store!,
    send: (message, lease) => sendFixedEmail(message, lease, mailConfig),
  });
  check(
    stats.claimed === 1 && stats.acknowledged === 1,
    "Actual SMTP ACK promotion positive",
  );
  check(
    (await owner.query(
      "SELECT count(*)=1 AS valid FROM mort_auth_guard.items i JOIN mort_auth_guard.outbox o ON o.item_id=i.id JOIN mort_auth_guard.families f ON f.id=i.family_id WHERE f.account_id=$1 AND i.state='usable' AND i.delivery_state='acknowledged' AND o.encrypted_envelope IS NULL",
      [config.accountId],
    )).rows[0].valid,
    "ACK purges ciphertext and makes one item usable",
  );
  const capture = await (await fetch("http://127.0.0.1:55424/api/v1/messages"))
    .json();
  let matched = false, capturedLink: URL | undefined;
  for (const message of capture.messages ?? []) {
    const detail =
      await (await fetch(`http://127.0.0.1:55424/api/v1/message/${message.ID}`))
        .json();
    if (
      (detail.To ?? []).some((to: { Address?: string }) =>
        to.Address === config.recipient
      ) && (detail.Text ?? "").includes(
        "https://mortapp.org/auth/confirmation/#itemId=",
      )
    ) {
      check(
        !detail.Text.includes("discard-provider-value") &&
          detail.Text.includes("Expires at "),
        "Captured fixed content safe",
      );
      matched = true;
      const urlMatch =
        /https:\/\/mortapp\.org\/auth\/confirmation\/#itemId=[0-9a-f-]{36}&linkSecret=[A-Za-z0-9_-]{43}/
          .exec(detail.Text);
      if (urlMatch) capturedLink = new URL(urlMatch[0]);
    }
  }
  check(matched, "Actual custom SMTP capture positive");
  await owner.query(
    "UPDATE mort_auth_guard.families SET last_promoted_at=clock_timestamp()-interval '61 seconds' WHERE account_id=$1",
    [config.accountId],
  );
  check((await hook()).status === 200, "Successor hook positive");
  const otherKey = await crypto.subtle.generateKey(
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
  const wrong = await runDeliveryBatch({
    mode: "local_fixture",
    key: otherKey,
    store: store!,
    send: () => {
      throw new Error("Transport cannot precede decryption");
    },
  });
  check(
    wrong.claimed === 1 && wrong.acknowledged === 0,
    "Wrong key cannot dispatch or promote",
  );
  check(
    (await owner.query(
      "SELECT count(*)=1 AS once FROM mort_auth_guard.quota_events WHERE account_id=$1 AND kind='dispatch'",
      [config.accountId],
    )).rows[0].once,
    "Undecryptable successor costs zero SMTP charge",
  );
  check(
    (await owner.query(
      "SELECT count(*)=1 AS valid FROM mort_auth_guard.items i JOIN mort_auth_guard.families f ON f.id=i.family_id WHERE f.account_id=$1 AND i.state='usable'",
      [config.accountId],
    )).rows[0].valid,
    "Failed successor preserves old delivered challenge",
  );
  console.log(
    "PASS isolated signed-hook/encrypted-queue/SMTP-delivery integration",
  );
  check(capturedLink, "Captured owned link required for real gateway test");
  const provider = await createFixtureProvider(config, store!);
  const admission = new Admission(), sourceKey = await crypto.subtle.generateKey({name:"HMAC",hash:"SHA-256"},false,["sign"]);
  gateway = Deno.serve({
    hostname: "127.0.0.1",
    port: 55426,
    onListen: () => {},
    onError: () => Response.json({ ok: false }, { status: 503 }),
  }, async (request, info) => {
    // Runtime socket identity is authoritative here. Browser forwarding fields
    // never enter the quota identity or server dependency contract.
    const remote = info.remoteAddr;
    if (remote.transport !== "tcp" || remote.hostname !== "127.0.0.1") {
      return Response.json({ ok: false }, { status: 503 });
    }
    return await handleEmailGuard(request, {
      mode: "local_fixture",
      sourceHash: await directPeerSource(remote.hostname, sourceKey),
      admission,
      allowedOrigins: ["https://mortapp.org"],
      codeKey,
      store: store!,
      dispatch: provider.dispatch,
    });
  });
  const fragment = new URLSearchParams(capturedLink.hash.slice(1)),
    verifier = makeSecret();
  const input = {
    itemId: fragment.get("itemId"),
    linkSecret: fragment.get("linkSecret"),
    verifierHash: await secretDigest(verifier),
  };
  const post = async (path: string, value: unknown) => {
    const response = await fetch("http://127.0.0.1:55426" + path, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: "https://mortapp.org",
        "x-forwarded-for": "arbitrary-untrusted-source",
      },
      body: JSON.stringify(value),
      signal: AbortSignal.timeout(15000),
    });
    return { status: response.status, value: await response.json() };
  };
  await owner.query("BEGIN");
  await owner.query("SELECT singleton FROM mort_auth_guard.control FOR UPDATE");
  try {
    const start = performance.now(), contended = await post("/continue", input);
    check(
      contended.status === 429 && contended.value.retryAfterSeconds === 1 &&
        performance.now() - start < 550,
      "Actual store contention is bounded Busy",
    );
    check(
      (await owner.query(
        "SELECT failures=0 AS unchanged FROM mort_auth_guard.families WHERE account_id=$1",
        [config.accountId],
      )).rows[0].unchanged,
      "Actual store contention charges no shared failure",
    );
  } finally {
    await owner.query("ROLLBACK");
  }
  const continued = await post("/continue", input);
  check(
    continued.status === 200 && continued.value.ok &&
      continued.value.purpose === "confirmation",
    "Actual Continue produces committed one-use capability",
  );
  check(
    (await post("/continue", input)).status === 400,
    "Lost/consumed Continue cannot issue a second capability",
  );
  const password = "Aa9!" + makeSecret(),
    passwordInput = {
      capability: continued.value.capability,
      verifier,
      password,
    };
  check(
    (await post("/password", { ...passwordInput, verifier: makeSecret() }))
      .status === 400,
    "Wrong raw verifier cannot dispatch",
  );
  const policy = await post("/password", {
    ...passwordInput,
    password: "weak",
  });
  check(
    policy.status === 400 &&
      policy.value.message === "Choose a password that meets the requirements.",
    "Actual possession-only policy result preserves capability",
  );
  const changed = await post("/password", passwordInput);
  check(
    changed.status === 200 && changed.value.ok,
    "Real gateway succeeds only after supported Admin transaction commit",
  );
  check(
    (await post("/password", passwordInput)).status === 400,
    "Real gateway capability cannot reset twice",
  );
  const login = await fetch(config.authUrl + "/token?grant_type=password", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer " + config.anonKey,
    },
    body: JSON.stringify({ email: config.recipient, password }),
    signal: AbortSignal.timeout(10000),
  });
  check(
    login.status === 200 && (await login.json()).user?.id === config.accountId,
    "Replacement signs in through real private address-proof token hook",
  );
  check(
    admission.snapshot().active === 0,
    "Actual gateway releases all admissions",
  );
  console.log(
    "PASS actual HTTP Continue/verifier-bound password/Admin/sign-in integration",
  );
} catch (error) {
  console.error(
    error instanceof Error && error.message === "Private context positive"
      ? error.message
      : "Fixture delivery assertion failed (redacted)",
  );
  Deno.exitCode = 1;
} finally {
  await gateway?.shutdown();
  await store?.close();
  await owner.query("UPDATE mort_auth_guard.control SET enabled=false");
  await owner.query(
    "DELETE FROM mort_auth_guard.operation_grants WHERE account_id=$1",
    [config.accountId],
  );
  await owner.query(
    "DELETE FROM mort_auth_guard.address_proofs WHERE account_id=$1",
    [config.accountId],
  );
  await owner.query(
    "DELETE FROM mort_auth_guard.capabilities WHERE account_id=$1",
    [config.accountId],
  );
  await owner.query(
    "DELETE FROM mort_auth_guard.hook_events WHERE event_digest=ANY($1::text[])",
    [events],
  );
  await owner.query(
    "DELETE FROM mort_auth_guard.quota_events WHERE account_id=$1",
    [config.accountId],
  );
  await owner.query(
    "DELETE FROM mort_auth_guard.families WHERE account_id=$1",
    [config.accountId],
  );
  await owner.query(
    "DELETE FROM mort_auth_guard.account_generations WHERE account_id=$1",
    [config.accountId],
  );
  await owner.query("UPDATE mort_auth_guard.control SET enabled=false");
  await owner.end();
}
