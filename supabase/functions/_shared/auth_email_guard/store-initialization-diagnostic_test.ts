import pg from "pg";
import { createFixtureStore } from "./store.ts";
import {
  FixtureStoreInitializationError,
  fixtureStoreInitializationLine,
} from "./store-initialization-diagnostic.ts";

type Diagnostic = { failureClass: string; sqlstate: string; elapsedMs: number };
function check(value: unknown): asserts value {
  if (!value) {
    throw new Error("Safe store initialization diagnostic assertion failed");
  }
}
async function failure(
  error?: unknown,
  rows = [{ id: "private-identity-value" }],
  cleanupError?: Error,
) {
  const OriginalPool = pg.Pool;
  let ended = false;
  let options: pg.PoolConfig | undefined;
  class FakePool {
    constructor(config: pg.PoolConfig) {
      options = config;
    }
    query() {
      return error ? Promise.reject(error) : Promise.resolve({ rows });
    }
    end() {
      ended = true;
      return cleanupError ? Promise.reject(cleanupError) : Promise.resolve();
    }
  }
  pg.Pool = FakePool as unknown as typeof pg.Pool;
  try {
    try {
      await createFixtureStore({
        mode: "local_fixture",
        fixtureId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        dbUrl:
          "postgresql://supabase_admin:private-password@127.0.0.1:55422/postgres",
      });
    } catch (caught) {
      const observed = caught as Error & { diagnostic?: Diagnostic };
      check(observed.message === "Fixture store refused");
      check(
        ended && options?.connectionTimeoutMillis === 100 &&
          options?.query_timeout === 1000,
      );
      check(
        observed.diagnostic &&
          Number.isSafeInteger(observed.diagnostic.elapsedMs) &&
          observed.diagnostic.elapsedMs >= 0,
      );
      check(!JSON.stringify(observed).includes("private"));
      check(!(observed as Error & { cause?: unknown }).cause);
      return observed.diagnostic;
    }
    throw new Error("Store initialization unexpectedly succeeded");
  } finally {
    pg.Pool = OriginalPool;
  }
}

Deno.test("store initialization retains exact pinned driver connection deadline classes without changing limits", async () => {
  for (
    const message of [
      "Connection terminated due to connection timeout",
      "timeout exceeded when trying to connect",
      "timeout expired",
    ]
  ) {
    const diagnostic = await failure(
      new Error(message, { cause: new Error("private-cause") }),
    );
    check(
      diagnostic.failureClass === "connection_deadline" &&
        diagnostic.sqlstate === "none",
    );
  }
});

Deno.test("store initialization distinguishes query deadline from a guessed slow connection", async () => {
  const diagnostic = await failure(new Error("Query read timeout"));
  check(
    diagnostic.failureClass === "query_deadline" &&
      diagnostic.sqlstate === "none",
  );
});

Deno.test("store initialization retains only reviewed SQLSTATEs without server detail or SQL values", async () => {
  const diagnostic = await failure(
    Object.assign(new Error("private-database-message"), {
      code: "42P01",
      detail: "private-SQL-value",
      query: "private-query",
    }),
  );
  check(
    diagnostic.failureClass === "database_sqlstate" &&
      diagnostic.sqlstate === "42P01",
  );
  const unknown = await failure(
    Object.assign(new Error("private-database-message"), { code: "S3CR3" }),
  );
  check(
    unknown.failureClass === "database_sqlstate" &&
      unknown.sqlstate === "unclassified",
  );
});

Deno.test("store initialization explicitly distinguishes identity mismatch and connection errors from unknown failures", async () => {
  check((await failure()).failureClass === "identity_mismatch");
  for (
    const code of [
      "ECONNREFUSED",
      "ECONNRESET",
      "ETIMEDOUT",
      "EHOSTUNREACH",
      "ENETUNREACH",
      "EPIPE",
    ]
  ) {
    check(
      (await failure(
        Object.assign(new Error("private-network-host"), { code }),
      )).failureClass === "connection_error",
    );
  }
  check(
    (await failure(new Error("timeout expired private-secret")))
      .failureClass === "unclassified",
  );
});

Deno.test("store initialization cleanup cannot erase the original safe failure diagnosis", async () => {
  const diagnostic = await failure(
    new Error("Query read timeout"),
    [],
    new Error("private-cleanup-message"),
  );
  check(diagnostic.failureClass === "query_deadline");
});

Deno.test("store initialization formatter reconstructs only a safe typed diagnosis", () => {
  const error = new FixtureStoreInitializationError(
    new Error("Query read timeout"),
    1000.9,
  );
  check(
    fixtureStoreInitializationLine(error) ===
      "Fixture store initialization failed: class=query_deadline sqlstate=none elapsedMs=1000",
  );
  check(
    fixtureStoreInitializationLine({
      diagnostic: {
        failureClass: "private-secret",
        sqlstate: "private-secret",
        elapsedMs: 1,
      },
    }) === undefined,
  );
  const forged = Object.create(FixtureStoreInitializationError.prototype);
  forged.diagnostic = {
    failureClass: "private-secret",
    sqlstate: "private-secret",
    elapsedMs: 1,
  };
  check(fixtureStoreInitializationLine(forged) === undefined);
  check(
    fixtureStoreInitializationLine(new Error("private-secret")) === undefined,
  );
});
