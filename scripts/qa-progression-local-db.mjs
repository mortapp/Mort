// Concurrent progression certification against a disposable local PostgreSQL.
// Refuses non-loopback hosts so this operator fixture cannot target production.
import pg from "pg";
import { randomUUID } from "node:crypto";

const { Client } = pg;
const connectionString = process.env.MORT_PROGRESSION_TEST_DATABASE_URL
  ?? "postgresql://postgres@127.0.0.1:55432/mort_progression_cert";
const parsed = new URL(connectionString);
if (!["127.0.0.1", "localhost", "::1"].includes(parsed.hostname)) {
  throw new Error("Local progression QA refuses a non-loopback database host.");
}

const teenId = "00000000-0000-0000-0000-0000000000f6";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function connectedClient(asTeen = false) {
  const client = new Client({ connectionString });
  await client.connect();
  if (asTeen) {
    await client.query("set role authenticated");
    await client.query("select pg_catalog.set_config('request.jwt.claim.sub',$1,false)", [teenId]);
  }
  return client;
}

async function spend(client, key, requestId) {
  const { rows } = await client.query(
    "select public.unlock_progression_cosmetic_v1($1,$2::uuid) as result",
    [key, requestId],
  );
  return rows[0].result;
}

const admin = await connectedClient();
const clients = [];
try {
  await admin.query(
    `insert into private.progression_accounts(user_id,motion_tokens_balance)
     values ($1,5)
     on conflict (user_id) do update set motion_tokens_balance = 5`,
    [teenId],
  );
  await admin.query("delete from private.progression_events where user_id = $1", [teenId]);
  await admin.query("delete from private.progression_equipped where user_id = $1", [teenId]);
  await admin.query("delete from private.progression_unlocks where user_id = $1", [teenId]);

  const first = await connectedClient(true);
  const second = await connectedClient(true);
  clients.push(first, second);
  const requests = [
    { key: "silver_edge", cost: 3, id: randomUUID() },
    { key: "night_signal", cost: 5, id: randomUUID() },
  ];
  const results = await Promise.all([
    spend(first, requests[0].key, requests[0].id),
    spend(second, requests[1].key, requests[1].id),
  ]);
  const winners = results
    .map((result, index) => ({ result, request: requests[index] }))
    .filter(({ result }) => result.ok === true);
  assert(winners.length === 1, `expected one concurrent winner, got ${winners.length}`);

  const winner = winners[0];
  const replay = await spend(first, winner.request.key, winner.request.id);
  assert(replay.ok === true && replay.replayed === true, "winning request did not replay idempotently");

  const losingKeys = winner.request.key === "silver_edge"
    ? ["night_signal", "ice_trace"]
    : ["silver_edge", "ice_trace"];
  const burstClients = await Promise.all(Array.from({ length: 12 }, () => connectedClient(true)));
  clients.push(...burstClients);
  const burst = await Promise.all(burstClients.map((client, index) =>
    spend(client, losingKeys[index % losingKeys.length], randomUUID())));
  assert(burst.every((result) => result.ok === false && result.code === "insufficient_tokens"),
    "concurrent burst accepted an unaffordable spend");

  const { rows: snapshotRows } = await first.query("select public.get_my_progression_v1() as result");
  const snapshot = snapshotRows[0].result;
  assert(snapshot.motion_tokens_balance === 5 - winner.request.cost,
    `unexpected final balance ${snapshot.motion_tokens_balance}`);
  assert(snapshot.motion_tokens_balance >= 0, "token balance became negative");

  let directWriteDenied = false;
  try {
    await first.query(
      "update private.progression_accounts set motion_tokens_balance = 999 where user_id = $1",
      [teenId],
    );
  } catch (error) {
    directWriteDenied = error.code === "42501";
  }
  assert(directWriteDenied, "authenticated teen could directly update token balance");

  let malformedUuidDenied = false;
  try {
    await first.query(
      "select public.unlock_progression_cosmetic_v1('silver_edge',$1::uuid)",
      ["not-a-uuid"],
    );
  } catch (error) {
    malformedUuidDenied = error.code === "22P02";
  }
  assert(malformedUuidDenied, "malformed request UUID was accepted");

  const { rows: ledgerRows } = await admin.query(
    `select
       (select count(*)::integer from private.progression_unlocks where user_id = $1) as unlocks,
       (select count(*)::integer from private.progression_events
          where user_id = $1 and event_type = 'cosmetic_unlock') as spend_events,
       (select motion_tokens_balance from private.progression_accounts where user_id = $1) as balance`,
    [teenId],
  );
  assert(ledgerRows[0].unlocks === 1 && ledgerRows[0].spend_events === 1,
    `ledger mismatch: ${JSON.stringify(ledgerRows[0])}`);
  assert(ledgerRows[0].balance === snapshot.motion_tokens_balance,
    "ledger and RPC balance disagree");
  console.log(JSON.stringify({
    ok: true,
    concurrentWinner: winner.request.key,
    finalBalance: snapshot.motion_tokens_balance,
    burstRequestsDenied: burst.length,
    directWriteDenied,
    malformedUuidDenied,
  }));
} finally {
  await Promise.allSettled(clients.map((client) => client.end()));
  await admin.end();
}
