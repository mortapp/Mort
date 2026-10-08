import pg from "pg";
import { Admission } from "./admission.ts";
import { createFixtureStore } from "./store.ts";
import { makeSecret, secretDigest } from "./crypto.ts";
import { handleEmailGuard } from "../../mort-auth-email-guard/handler.ts";
function check(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
if (Deno.env.get("MORT_FIXTURE_VERIFIED") !== "1") {
  throw new Error("Fixture load refused");
}
const raw = await new Response(Deno.stdin.readable).text();
if (raw.length > 4096) throw new Error("Fixture load refused");
const config = JSON.parse(raw), target = new URL(config.dbUrl);
if (
  config.mode !== "local_fixture" || target.hostname !== "127.0.0.1" ||
  target.port !== "55422" || !Array.isArray(config.accounts) ||
  config.accounts.length !== 2
) throw new Error("Fixture load refused");
const owner = new pg.Client({
  connectionString: config.dbUrl,
  connectionTimeoutMillis: 2000,
  query_timeout: 2000,
});
let store: Awaited<ReturnType<typeof createFixtureStore>> | undefined,
  gateway: Deno.HttpServer | undefined;
const admission = new Admission(),
  families: string[] = [],
  links: string[] = [],
  ids: string[] = [];
let requests = 0, active = 0, maxActive = 0;
try {
  await owner.connect();
  check(
    (await owner.query("SELECT id=$1 AS owned FROM mort_fixture.identity", [
      config.fixtureId,
    ])).rows[0].owned,
    "Owned fixture required",
  );
  check(
    (await owner.query(
      "SELECT enabled=false AS disabled FROM mort_auth_guard.control",
    )).rows[0].disabled,
    "Starts disabled",
  );
  for (const account of config.accounts) {
    const recipient = await secretDigest(account.recipient);
    check(
      (await owner.query(
        "SELECT email_confirmed_at IS NOT NULL AND email=$2 AS valid FROM auth.users WHERE id=$1",
        [account.id, account.recipient],
      )).rows[0]?.valid,
      "Committed synthetic confirmed account",
    );
    await owner.query(
      "INSERT INTO mort_auth_guard.account_generations(account_id,recipient_hash) VALUES($1,$2)",
      [account.id, recipient],
    );
  }
  async function seed(index: number) {
    const account = config.accounts[index],
      family = crypto.randomUUID(),
      item = crypto.randomUUID(),
      link = makeSecret();
    families.push(family);
    links[index] = link;
    ids[index] = item;
    await owner.query(
      `WITH t AS(SELECT clock_timestamp() AS n) INSERT INTO mort_auth_guard.families(id,account_id,purpose,recipient_hash,source_hash,address_generation,credential_generation,activation_generation,restore_generation,issued_at,family_expires_at)
      SELECT $1,g.account_id,'recovery',g.recipient_hash,$3,g.address_generation,g.credential_generation,c.activation_generation,c.restore_generation,n,n+interval '600 seconds' FROM mort_auth_guard.account_generations g,mort_auth_guard.control c,t WHERE g.account_id=$2`,
      [family, account.id, await secretDigest(makeSecret())],
    );
    await owner.query(
      `INSERT INTO mort_auth_guard.items(id,family_id,code_hmac,link_digest,state,delivery_state,issued_at,promoted_at) VALUES($1,$2,$3,$4,'usable','acknowledged',clock_timestamp(),clock_timestamp())`,
      [
        item,
        family,
        await secretDigest(makeSecret()),
        await secretDigest(link),
      ],
    );
  }
  await seed(0);
  await seed(1);
  await owner.query("UPDATE mort_auth_guard.control SET enabled=true");
  store = await createFixtureStore(config);
  const key = await crypto.subtle.generateKey(
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  // Separately authenticated synthetic ingress contexts, not forwarded client IPs.
  const tokens = [makeSecret(), makeSecret()],
    sourceHashes = await Promise.all(tokens.map(secretDigest)),
    authDigests = await Promise.all(
      tokens.map((token) => secretDigest("Bearer " + token)),
    );
  gateway = Deno.serve({
    hostname: "127.0.0.1",
    port: 55426,
    onListen: () => {},
  }, async (request) => {
    const header = request.headers.get("authorization") ?? "";
    if (header.length > 80) return new Response(null, { status: 503 });
    const source = authDigests.indexOf(await secretDigest(header));
    if (source < 0) return new Response(null, { status: 503 });
    return await handleEmailGuard(request, {
      mode: "local_fixture",
      sourceHash: sourceHashes[source],
      admission,
      allowedOrigins: [],
      codeKey: key,
      store: store!,
      dispatch: () => {
        throw new Error("Load may not change credentials");
      },
    });
  });
  const globalDeadline = AbortSignal.timeout(55000);
  async function send(source: number, payload: unknown, path = "/continue") {
    requests++;
    active++;
    maxActive = Math.max(maxActive, active);
    check(requests <= 500 && active <= 20, "Load bounds");
    try {
      const start = performance.now();
      const response = await fetch("http://127.0.0.1:55426" + path, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: "Bearer " + tokens[source],
          "x-forwarded-for": "untrusted",
        },
        body: JSON.stringify(payload),
        signal: globalDeadline,
      });
      return {
        status: response.status,
        data: await response.json(),
        elapsed: performance.now() - start,
      };
    } finally {
      active--;
    }
  }
  const input = async (index: number, link = links[index]) => ({
    itemId: ids[index],
    linkSecret: link,
    verifierHash: await secretDigest(makeSecret()),
  });
  const heldA = send(0, {}, "/continue?invalid=1"),
    heldB = send(0, {}, "/continue?invalid=2");
  await new Promise((r) => setTimeout(r, 20));
  const busy = await send(0, await input(0));
  check(
    busy.status === 429 && busy.data.retryAfterSeconds === 1,
    "Saturated source gets non-charged Busy",
  );
  check(
    (await owner.query(
      "SELECT failures=0 AS clean FROM mort_auth_guard.families WHERE id=$1",
      [families[0]],
    )).rows[0].clean,
    "Busy cannot debit family",
  );
  const independent = await send(1, await input(1));
  check(
    independent.status === 200 && independent.data.ok,
    "Source B succeeds while source A is saturated",
  );
  await Promise.all([heldA, heldB]);
  for (let wave = 0; wave < 10; wave++) {
    const jobs = [];
    for (let i = 0; i < 19; i++) {
      jobs.push(send(0, await input(0, makeSecret())));
    }
    const results = await Promise.all(jobs);
    check(
      results.every((r) =>
        [400, 429].includes(r.status) && r.data.ok === false
      ),
      "Flood never consumes or grants authority",
    );
    check(
      (await owner.query(
        "SELECT failures<=5 AS bounded FROM mort_auth_guard.families WHERE id=$1",
        [families[0]],
      )).rows[0].bounded,
      "Shared failures never exceed five",
    );
  }
  for (let i = 0; i < 8; i++) {
    const sample = await send(i % 2, {
      itemId: crypto.randomUUID(),
      linkSecret: makeSecret(),
      verifierHash: await secretDigest(makeSecret()),
    });
    check(
      sample.status === 400 && sample.elapsed >= 330 && sample.elapsed < 900,
      "Generic unknown denial has bounded 350ms schedule",
    );
    check(
      JSON.stringify(sample.data) ===
        '{"ok":false,"message":"That request is not valid."}',
      "No target-dependent failure response",
    );
  }
  await seed(1);
  const after = await send(1, await input(1));
  check(
    after.status === 200 && after.data.ok,
    "Fresh legitimate post-load consume succeeds",
  );
  check(
    admission.snapshot().active === 0 && active === 0 && maxActive <= 20 &&
      requests <= 500,
    "All admission and test tasks released",
  );
  console.log(
    "PASS bounded actual HTTP load: source isolation, non-charged Busy, bounded denial and legitimate post-load consume",
  );
} finally {
  await gateway?.shutdown();
  await store?.close();
  // Independent shutdown stages: a failed private cleanup cannot skip disable.
  let failed = false;
  try {
    await owner.query("UPDATE mort_auth_guard.control SET enabled=false");
  } catch {
    failed = true;
  }
  try {
    await owner.query(
      "DELETE FROM mort_auth_guard.capabilities WHERE family_id=ANY($1::uuid[])",
      [families],
    );
    await owner.query(
      "DELETE FROM mort_auth_guard.families WHERE id=ANY($1::uuid[])",
      [families],
    );
    await owner.query(
      "DELETE FROM mort_auth_guard.account_generations WHERE account_id=ANY($1::uuid[])",
      [config.accounts.map((a: { id: string }) => a.id)],
    );
  } catch {
    failed = true;
  }
  await owner.end();
  if (failed) throw new Error("Fixture load cleanup failed");
}
