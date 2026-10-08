import pg from "pg";
import { Webhook } from "standardwebhooks";
import { handleEmailHook } from "../../mort-auth-email-hook/handler.ts";
import { createFixtureStore } from "./store.ts";
import { secretDigest } from "./crypto.ts";
import { runDeliveryBatch, sendFixedEmail } from "./delivery.ts";
function check(value: unknown): asserts value {
  if (!value) throw new Error("Fixture ingress assertion failed");
}
const config = JSON.parse(await new Response(Deno.stdin.readable).text());
check(
  Deno.env.get("MORT_FIXTURE_VERIFIED") === "1" &&
    config.mode === "local_fixture",
);
const url = new URL(config.dbUrl);
check(url.hostname === "127.0.0.1" && url.port === "55422");
const db = new pg.Client({ connectionString: config.dbUrl });
let store: Awaited<ReturnType<typeof createFixtureStore>> | undefined;
let gateway: Deno.HttpServer | undefined;
try {
  await db.connect();
  check(
    (await db.query("SELECT id FROM mort_fixture.identity")).rows[0].id ===
      config.fixtureId,
  );
  const rows = (await db.query(
    `SELECT i.*,u.email FROM mort_fixture.email_ingress i
    JOIN auth.users u ON u.id=i.account_id WHERE i.account_id=$1 AND used_at IS NULL`,
    [config.accountId],
  )).rows;
  check(rows.length === 1);
  const ticket = rows[0];
  check(await secretDigest(ticket.email) === ticket.recipient_hash);
  const raw = JSON.stringify({
    user: { id: ticket.account_id, email: ticket.email },
    email_data: { email_action_type: ticket.action },
  });
  const secret = crypto.getRandomValues(new Uint8Array(32));
  const webhook = new Webhook(secret, { format: "raw" }), date = new Date();
  const headers = {
    "content-type": "application/json",
    "webhook-id": ticket.id,
    "webhook-timestamp": String(Math.floor(date.getTime() / 1000)),
    "webhook-signature": webhook.sign(ticket.id, date, raw),
  };
  const makeRequest = (h = headers) =>
    new Request("http://127.0.0.1:55426/hook", {
      method: "POST",
      body: raw,
      headers: h,
    });
  store = await createFixtureStore(config);
  const key = await crypto.subtle.generateKey(
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
  const codeKey = await crypto.subtle.generateKey(
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const deps = {
    mode: "local_fixture" as const,
    signingSecret: secret,
    encryptionKey: key,
    codeKey,
    store,
    resolveTrustedSource: async (digest: string, account: string) => {
      if (
        digest !== await secretDigest(ticket.id) ||
        account !== ticket.account_id
      ) return null;
      const result = await db.query(
        `UPDATE mort_fixture.email_ingress SET used_at=clock_timestamp()
        WHERE id=$1 AND account_id=$2 AND recipient_hash=$3 AND used_at IS NULL
        AND created_at>clock_timestamp()-interval '30 seconds' RETURNING source_hash`,
        [ticket.id, account, ticket.recipient_hash],
      );
      return result.rows[0]?.source_hash ?? null;
    },
  };
  // Public requests never receive the private relay's resolver. Even the exact
  // captured provider event and a valid signing key cannot create provenance.
  gateway = Deno.serve(
    { hostname: "127.0.0.1", port: 55426, onListen: () => {} },
    (request) =>
      handleEmailHook(request, {
        ...deps,
        resolveTrustedSource: async () => null,
      }),
  );
  const outside = await fetch("http://127.0.0.1:55426/hook", {
    method: "POST",
    headers,
    body: raw,
  });
  check(outside.status === 400);
  await outside.body?.cancel();
  const wrong = new Webhook(crypto.getRandomValues(new Uint8Array(32)), {
    format: "raw",
  });
  check(
    (await handleEmailHook(
      makeRequest({
        ...headers,
        "webhook-signature": wrong.sign(ticket.id, date, raw),
      }),
      deps,
    )).status === 400,
  );
  check(
    (await db.query(
      "SELECT used_at IS NULL ok FROM mort_fixture.email_ingress WHERE id=$1",
      [ticket.id],
    )).rows[0].ok,
  );
  check((await handleEmailHook(makeRequest(), deps)).status === 200);
  check((await handleEmailHook(makeRequest(), deps)).status === 400);
  check(
    (await db.query(
      "SELECT count(*)::int n FROM mort_auth_guard.families WHERE account_id=$1",
      [ticket.account_id],
    )).rows[0].n === 1,
  );
  const stats = await runDeliveryBatch({
    mode: "local_fixture",
    key,
    store,
    send: (message, lease) =>
      sendFixedEmail(message, lease, {
        mode: "local_fixture",
        host: "127.0.0.1",
        port: 55425,
        ca: Deno.readTextFileSync(config.certificate),
        user: "fixture",
        password: "fixture-only",
      }),
  });
  check(stats.acknowledged === 1);
  console.log(
    "PASS provider-origin relay; outside-path, replay and wrong-secret denied; synthetic SMTP acknowledged",
  );
} finally {
  await gateway?.shutdown();
  await store?.close();
  await db.end();
}
