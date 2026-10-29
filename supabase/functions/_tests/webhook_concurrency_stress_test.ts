const container = "supabase_db_mort-mobile";
const migration = await Deno.readTextFile(
  new URL(
    "../../migrations/20261028201359_mort_financial_integrity_and_webhook_fencing.sql",
    import.meta.url,
  ),
);

function assertEquals<T>(actual: T, expected: T, label: string): void {
  if (actual !== expected) {
    throw new Error(
      `${label}: expected ${JSON.stringify(expected)}, received ${
        JSON.stringify(actual)
      }`,
    );
  }
}

async function docker(
  args: string[],
  stdin?: string,
): Promise<{ code: number; stdout: string; stderr: string }> {
  const child = new Deno.Command("docker", {
    args,
    stdin: stdin === undefined ? "null" : "piped",
    stdout: "piped",
    stderr: "piped",
  }).spawn();
  if (stdin !== undefined) {
    const writer = child.stdin.getWriter();
    await writer.write(new TextEncoder().encode(stdin));
    await writer.close();
  }
  const result = await child.output();
  const output = {
    code: result.code,
    stdout: new TextDecoder().decode(result.stdout).trim(),
    stderr: new TextDecoder().decode(result.stderr).trim(),
  };
  if (!result.success) {
    throw new Error(
      `docker ${args.slice(0, 5).join(" ")} failed (${output.code}): ${
        output.stderr.slice(0, 1000)
      }`,
    );
  }
  return output;
}

async function psql(database: string, sql: string): Promise<string> {
  const result = await docker([
    "exec",
    "-i",
    container,
    "psql",
    "-U",
    "supabase_admin",
    "-d",
    database,
    "-v",
    "ON_ERROR_STOP=1",
    "-q",
    "-t",
    "-A",
  ], sql);
  return result.stdout;
}

Deno.test("webhook claims are fenced under true concurrent PostgreSQL sessions", async () => {
  const suffix = crypto.randomUUID().replaceAll("-", "").slice(0, 16);
  const database = `mort_webhook_stress_${suffix}`;
  const dumpPath = `/tmp/${database}.dump`;
  const eventId = `evt_${crypto.randomUUID().replaceAll("-", "")}`;
  const payloadHash = "b".repeat(64);
  const sessions = 8;
  let databaseCreated = false;

  try {
    // Clone the local Supabase database. All committed DDL/data and all true
    // parallel client sessions below are isolated to this disposable DB.
    await docker([
      "exec",
      container,
      "pg_dump",
      "-U",
      "supabase_admin",
      "-d",
      "postgres",
      "-Fc",
      "--exclude-extension=pg_cron",
      "-f",
      dumpPath,
    ]);
    await docker(["exec", container, "createdb", "-U", "postgres", database]);
    databaseCreated = true;
    await docker([
      "exec",
      container,
      "pg_restore",
      "-U",
      "supabase_admin",
      "-d",
      database,
      "--no-owner",
      "--no-privileges",
      dumpPath,
    ]);
    await docker(["exec", container, "rm", "-f", dumpPath]);

    await psql(database, migration);

    const catalog = await psql(
      database,
      `
SELECT
  exists (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'private.stripe_webhook_events'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) = 'UNIQUE (environment, provider_event_id)'
  )::text || '|'
  || exists (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'private.stripe_payment_resolutions'::regclass
      AND contype = 'f'
      AND conkey = ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid = 'private.stripe_payment_resolutions'::regclass AND attname = 'payment_intent_id')]
      AND confrelid = 'private.stripe_job_payment_intents'::regclass
  )::text || '|'
  || exists (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'private.stripe_payment_resolutions'::regclass
      AND tgname = 'stripe_resolution_operation_initial_states'
      AND tgenabled <> 'D'
      AND tgfoid = 'private.set_resolution_operation_initial_states()'::regprocedure
  )::text || '|'
  || exists (
    SELECT 1 FROM pg_attribute
    WHERE attrelid = 'private.stripe_webhook_events'::regclass
      AND attname = 'lease_token' AND atttypid = 'uuid'::regtype
  )::text || '|'
  || exists (
    SELECT 1 FROM pg_attribute
    WHERE attrelid = 'private.stripe_webhook_events'::regclass
      AND attname = 'lease_epoch' AND atttypid = 'int8'::regtype AND attnotnull
  )::text;
`,
    );
    assertEquals(
      catalog,
      "true|true|true|true|true",
      "candidate schema parity: unique claim key, payment FK, enabled trigger, lease columns",
    );

    const delayTrigger = `
CREATE FUNCTION public.mort_test_delay_webhook_claim_update()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.provider_event_id = '${eventId}' AND NEW.lease_epoch > OLD.lease_epoch THEN
    PERFORM pg_catalog.pg_sleep(5);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER mort_test_delay_webhook_claim_update
BEFORE UPDATE ON private.stripe_webhook_events
FOR EACH ROW EXECUTE FUNCTION public.mort_test_delay_webhook_claim_update();
INSERT INTO private.stripe_webhook_events (
  environment, provider_event_id, event_type, payload_sha256, signature_verified
) VALUES ('test', '${eventId}', 'payment_intent.processing', '${payloadHash}', true);
`;
    await psql(database, delayTrigger);

    const sql =
      `SET request.jwt.claim.role = 'service_role'; SELECT public.stripe_server_claim_webhook_event('test', '${eventId}', 'payment_intent.processing', now(), '${payloadHash}');`;
    const start = performance.now();
    const processes = Array.from(
      { length: sessions },
      () =>
        new Deno.Command("docker", {
          args: [
            "exec",
            container,
            "psql",
            "-U",
            "supabase_admin",
            "-d",
            database,
            "-v",
            "ON_ERROR_STOP=1",
            "-q",
            "-t",
            "-A",
            "-c",
            sql,
          ],
          stdout: "piped",
          stderr: "piped",
        }).spawn(),
    );
    const results = await Promise.all(
      processes.map((process) => process.output()),
    );
    const elapsedMs = Math.round(performance.now() - start);
    const responses = results.map((result, index) => {
      if (!result.success) {
        throw new Error(
          `PostgreSQL session ${index} failed (${result.code}): ${
            new TextDecoder().decode(result.stderr).slice(0, 1000)
          }`,
        );
      }
      return JSON.parse(new TextDecoder().decode(result.stdout).trim()) as {
        claimed?: boolean;
        lease_epoch?: number;
        lease_token?: string;
        locked?: boolean;
        in_flight?: boolean;
        code?: string;
      };
    });
    const winners = responses.filter((response) => response.claimed === true);
    const locked = responses.filter((response) =>
      response.locked === true && response.code === "stripe_webhook_lease_lost"
    );
    const winnerEpochs = new Set(
      winners.map((response) => response.lease_epoch),
    );
    const winnerTokens = new Set(
      winners.map((response) => response.lease_token),
    );

    assertEquals(winners.length, 1, "exactly one PostgreSQL lease winner");
    assertEquals(
      locked.length,
      sessions - 1,
      "all competing PostgreSQL sessions rejected immediately",
    );
    assertEquals(winnerEpochs.size, 1, "one lease epoch was issued");
    assertEquals(winners[0].lease_epoch, 1, "first lease generation");
    assertEquals(winnerTokens.size, 1, "one lease token was issued");

    const terminal = await psql(
      database,
      `
SELECT processing_status || '|' || lease_epoch::text || '|' ||
  (lease_token IS NOT NULL)::text || '|' || attempt_count::text
FROM private.stripe_webhook_events
WHERE environment = 'test' AND provider_event_id = '${eventId}';
`,
    );
    assertEquals(
      terminal,
      "processing|1|true|1",
      "committed winner lease state",
    );

    console.log(
      JSON.stringify({
        database: "disposable local clone",
        parallelSessions: sessions,
        winners: winners.length,
        immediateLockedRejects: locked.length,
        elapsedMs,
        catalogParity: catalog,
        finalLeaseState: terminal,
      }),
    );
  } finally {
    await docker(["exec", container, "rm", "-f", dumpPath]).catch(() => {});
    if (databaseCreated) {
      await docker([
        "exec",
        container,
        "psql",
        "-U",
        "postgres",
        "-d",
        "postgres",
        "-v",
        "ON_ERROR_STOP=1",
        "-q",
        "-c",
        `DROP DATABASE IF EXISTS ${database} WITH (FORCE);`,
      ]);
    }
  }
});
