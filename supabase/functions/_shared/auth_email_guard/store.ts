import pg from "pg";
import { canonicalId } from "./parser.ts";
import type { DeliveryLease, DeliveryOutcome } from "./delivery.ts";
export class GuardBusy extends Error {
  constructor() {
    super("MORT is busy. Try again shortly.");
  }
}
export type StoreConfig = {
  mode: "local_fixture";
  fixtureId: string;
  dbUrl: string;
};
// Fixture-only constructor: no hosted activation path or browser database key.
export async function createFixtureStore(config: StoreConfig) {
  const target = new URL(config.dbUrl);
  canonicalId(config.fixtureId);
  if (
    config.mode !== "local_fixture" || target.protocol !== "postgresql:" ||
    target.hostname !== "127.0.0.1" || target.port !== "55422" ||
    target.pathname !== "/postgres" || target.username !== "supabase_admin" ||
    target.search
  ) throw new Error("Fixture store refused");
  const pool = new pg.Pool({
    connectionString: config.dbUrl,
    max: 8,
    connectionTimeoutMillis: 1000,
    query_timeout: 1000,
  });
  try {
    const identity = await pool.query("SELECT id FROM mort_fixture.identity");
    if (
      identity.rows.length !== 1 || identity.rows[0].id !== config.fixtureId
    ) throw new Error("Fixture store refused");
  } catch {
    await pool.end();
    throw new Error("Fixture store refused");
  }
  async function execute(name: string, args: unknown[], signal?: AbortSignal) {
    signal?.throwIfAborted();
    const client = await pool.connect();
    let discarded = false, released = false, inTransaction = false;
    const release = (destroy = false) => {
      if (!released) {
        released = true;
        client.release(destroy);
      }
    };
    const abort = () => {
      discarded = true;
      release(true);
    };
    signal?.addEventListener("abort", abort, { once: true });
    try {
      signal?.throwIfAborted();
      await client.query("BEGIN");
      inTransaction = true;
      await client.query(
        "SET LOCAL statement_timeout='200ms'; SET LOCAL lock_timeout='100ms'",
      );
      const placeholders = args.map((_, i) => `$${i + 1}`).join(",");
      // Fixed internal helper names only; never a request-selected identifier.
      const result = await client.query(
        `SELECT mort_auth_guard.${name}(${placeholders}) AS result`,
        args,
      );
      signal?.throwIfAborted();
      await client.query("COMMIT");
      inTransaction = false;
      return result.rows[0].result;
    } catch (error) {
      if (!discarded && inTransaction) {
        try {
          await client.query("ROLLBACK");
        } catch {
          discarded = true;
        }
      }
      if (
        ["55P03", "57014", "40P01"].includes(
          (error as { code?: string }).code ?? "",
        )
      ) throw new GuardBusy();
      throw new Error("Guard store unavailable");
    } finally {
      signal?.removeEventListener("abort", abort);
      release(discarded);
    }
  }
  return {
    context: (
      accountId: string,
      recipientHash: string,
      signal?: AbortSignal,
    ): Promise<Record<string, number> | null> =>
      execute("issuance_context", [accountId, recipientHash], signal),
    issue: (
      event: Record<string, unknown>,
      material: Record<string, unknown>,
      signal?: AbortSignal,
    ): Promise<{ ok: boolean }> =>
      execute(
        "issue_event",
        [JSON.stringify(event), JSON.stringify(material)],
        signal,
      ),
    claim: (): Promise<DeliveryLease | { ok: false }> =>
      execute("claim_delivery", []),
    beginDispatch: (lease: DeliveryLease): Promise<{ ok: boolean }> =>
      execute("begin_dispatch", [JSON.stringify(lease)]),
    finish: (
      lease: DeliveryLease,
      outcome: DeliveryOutcome,
    ): Promise<boolean> =>
      execute("finish_delivery", [JSON.stringify(lease), outcome]),
    consume: (
      input: Record<string, unknown>,
      material: Record<string, unknown>,
      signal?: AbortSignal,
    ) =>
      execute(
        "consume_item",
        [JSON.stringify(input), JSON.stringify(material)],
        signal,
      ),
    close: () => pool.end(),
  };
}
