import { randomUUID } from "node:crypto";
import {
  assertQa,
  createFundingFixture,
  expectDatabaseError,
  insertFairPayPolicy,
  resetRole,
  setAuthenticatedUser,
  setServiceRole,
  withLocalDatabase,
} from "./stripe-policy-qa-helpers.mjs";

await withLocalDatabase("stripe-funding-quote", async (database) => {
  const relation = await database.query(`select to_regclass('private.stripe_job_funding_quotes') quote_table`);
  assertQa(relation.rows[0].quote_table, "funding quote table is missing");

  const ids = await createFundingFixture(database, 2500);
  await insertFairPayPolicy(database, "organization", true);
  await database.query(`
    update private.stripe_runtime_controls
    set mode = 'sandbox', stripe_payments_enabled = true, stripe_job_funding_enabled = true
    where singleton
  `);
  await setServiceRole(database);

  const requestOne = randomUUID();
  const created = await database.query(
    `select public.stripe_server_create_job_funding_quote_v1($1, $2, $3) quote`,
    [ids.adult, ids.contract, requestOne],
  );
  const quoteOne = created.rows[0].quote;
  assertQa(quoteOne.ok === true, "quote creation failed");
  assertQa(quoteOne.base_pay_cents === 2500, "quote did not use backend obligation base pay");
  assertQa(quoteOne.service_fee_cents === 200, "quote did not calculate the authoritative fee");
  assertQa(quoteOne.authoritative_total_cents === 2700, "quote total is not base plus fee");
  assertQa(quoteOne.currency_code === "USD", "quote currency mismatch");
  assertQa(quoteOne.policy_version === "sandbox-2026-09-16-v1", "quote did not bind the seeded policy version");

  const stored = await database.query(
    `select *, extract(epoch from (expires_at - created_at))::integer ttl_seconds
     from private.stripe_job_funding_quotes where id = $1`,
    [quoteOne.quote_id],
  );
  assertQa(stored.rows[0].ttl_seconds === 900, "created_at/expires_at do not persist the exact 900-second TTL");
  assertQa(stored.rows[0].payer_id === ids.adult, "quote payer was not server-bound");
  assertQa(stored.rows[0].worker_id === ids.teen, "quote worker was not server-derived");
  assertQa(stored.rows[0].connected_account_readiness === "READY_FOR_TRANSFER", "readiness snapshot mismatch");

  await expectDatabaseError(
    () => database.query(
      `update private.stripe_job_funding_quotes set authoritative_total_cents = 1 where id = $1`,
      [quoteOne.quote_id],
    ),
    /immutable|funding quote/i,
    database,
  );

  const replay = await database.query(
    `select public.stripe_server_create_job_funding_quote_v1($1, $2, $3) quote`,
    [ids.adult, ids.contract, requestOne],
  );
  assertQa(replay.rows[0].quote.quote_id === quoteOne.quote_id, "same request did not replay the same quote");
  await expectDatabaseError(
    () => database.query(
      `select public.stripe_server_create_job_funding_quote_v1($1, $2, $3)`,
      [ids.adult, randomUUID(), requestOne],
    ),
    /funding_quote_request_conflict/i,
    database,
  );

  const requestTwo = randomUUID();
  const refreshed = await database.query(
    `select public.stripe_server_create_job_funding_quote_v1($1, $2, $3) quote`,
    [ids.adult, ids.contract, requestTwo],
  );
  const quoteTwo = refreshed.rows[0].quote;
  const superseded = await database.query(
    `select state, superseded_by_quote_id from private.stripe_job_funding_quotes where id = $1`,
    [quoteOne.quote_id],
  );
  assertQa(superseded.rows[0].state === "SUPERSEDED", "refresh did not supersede the old quote");
  assertQa(superseded.rows[0].superseded_by_quote_id === quoteTwo.quote_id, "supersession linkage is missing");

  const attemptRequest = randomUUID();
  const consumed = await database.query(
    `select public.stripe_server_consume_job_funding_quote_v1($1, $2, $3) result`,
    [ids.adult, quoteTwo.quote_id, attemptRequest],
  );
  assertQa(consumed.rows[0].result.ok === true, "valid quote was not consumed");
  const consumeReplay = await database.query(
    `select public.stripe_server_consume_job_funding_quote_v1($1, $2, $3) result`,
    [ids.adult, quoteTwo.quote_id, attemptRequest],
  );
  assertQa(consumeReplay.rows[0].result.ok === true && consumeReplay.rows[0].result.idempotent === true, "same attempt request was not idempotent");
  await expectDatabaseError(
    () => database.query(
      `select public.stripe_server_consume_job_funding_quote_v1($1, $2, $3)`,
      [ids.adult, quoteTwo.quote_id, randomUUID()],
    ),
    /funding_quote_already_consumed/i,
    database,
  );

  const paymentIntentId = randomUUID();
  const paymentAttemptId = randomUUID();
  await database.query(
    `insert into private.stripe_job_payment_intents (
       id, contract_id, contract_version_id, obligation_id, adult_id, teen_id,
       environment, operation_version, earnings_amount_cents, service_fee_cents,
       total_amount_cents, currency_code, transfer_group, idempotency_key, status
     ) values ($1, $2, $3, $4, $5, $6, 'test', 99, 2500, 200, 2700, 'USD',
       $7, $8, 'processing')`,
    [
      paymentIntentId,
      ids.contract,
      ids.contractVersion,
      ids.obligation,
      ids.adult,
      ids.teen,
      `MORT_JOB_${ids.contract.replaceAll("-", "")}`,
      `test:bp02:${randomUUID()}`,
    ],
  );
  await database.query(
    `insert into private.stripe_job_payment_attempts (
       id, payment_intent_id, request_id, initiated_by, outcome
     ) values ($1, $2, $3, $4, 'prepared')`,
    [paymentAttemptId, paymentIntentId, randomUUID(), ids.adult],
  );
  const consumedSnapshot = await database.query(
    `select * from private.stripe_job_funding_quotes where id = $1`,
    [quoteTwo.quote_id],
  );
  const expiredQuoteId = randomUUID();
  await database.query(
    `insert into private.stripe_job_funding_quotes (
       id, environment, payer_id, worker_id, job_id, contract_id,
       contract_version_id, obligation_id, base_pay_cents, service_fee_cents,
       authoritative_total_cents, currency_code, financial_policy_version_id,
       fair_pay_policy_version_id, fair_pay_decision, connected_account_id,
       connected_account_readiness, payment_eligibility, provider_availability,
       request_id, request_payload_sha256, state, created_at, expires_at, expired_at
     ) values (
       $1, 'test', $2, $3, $4, $5, $6, $7, 2500, 200, 2700, 'USD',
       $8, $9, 'GREEN', $10, 'READY_FOR_TRANSFER', true, 'NOT_CHECKED',
       $11, repeat('a', 64), 'EXPIRED', statement_timestamp() - interval '1000 seconds',
       statement_timestamp() - interval '100 seconds', statement_timestamp() - interval '100 seconds'
     )`,
    [
      expiredQuoteId,
      ids.adult,
      ids.teen,
      ids.job,
      ids.contract,
      ids.contractVersion,
      ids.obligation,
      consumedSnapshot.rows[0].financial_policy_version_id,
      consumedSnapshot.rows[0].fair_pay_policy_version_id,
      ids.connectedAccount,
      randomUUID(),
    ],
  );
  await expectDatabaseError(
    () => database.query(
      `select public.stripe_server_consume_job_funding_quote_v1($1, $2, $3)`,
      [ids.adult, expiredQuoteId, randomUUID()],
    ),
    /funding_quote_not_active/i,
    database,
  );
  const attemptAfterUnusedExpiry = await database.query(
    `select outcome from private.stripe_job_payment_attempts where id = $1`,
    [paymentAttemptId],
  );
  assertQa(attemptAfterUnusedExpiry.rows[0].outcome === "prepared", "unused quote expiry altered an existing PaymentAttempt");

  const boundary = new Date("2026-09-16T12:00:00.000Z");
  const before = new Date(boundary.getTime() - 1).toISOString();
  const exact = boundary.toISOString();
  const after = new Date(boundary.getTime() + 1).toISOString();
  for (const [at, expected, label] of [[before, true, "before"], [exact, false, "exactly at"], [after, false, "after"]]) {
    const result = await database.query(
      `select private.funding_quote_is_usable_v1('ACTIVE', $1::timestamptz, $2::timestamptz) usable`,
      [exact, at],
    );
    assertQa(result.rows[0].usable === expected, `quote expiry boundary failed ${label} expires_at`);
  }

  await database.query("savepoint caller_quote_access");
  await setAuthenticatedUser(database, ids.adult);
  const own = await database.query(
    `select public.get_my_job_funding_quote_v1($1) quote`,
    [quoteTwo.quote_id],
  );
  assertQa(own.rows[0].quote.quote_id === quoteTwo.quote_id, "payer could not read own quote DTO");
  assertQa(!JSON.stringify(own.rows[0].quote).includes("acct_"), "quote DTO leaked provider account ID");
  await database.query("rollback to savepoint caller_quote_access");
  await resetRole(database);

  await database.query("savepoint direct_quote_table_access");
  await setAuthenticatedUser(database, ids.adult);
  await expectDatabaseError(
    () => database.query(`select id from private.stripe_job_funding_quotes where id = $1`, [quoteTwo.quote_id]),
    /permission denied|row-level security/i,
    database,
  );
  await database.query("rollback to savepoint direct_quote_table_access");
  await resetRole(database);

  await database.query("savepoint cross_user_quote_access");
  await setAuthenticatedUser(database, ids.otherAdult);
  await expectDatabaseError(
    () => database.query(`select public.get_my_job_funding_quote_v1($1)`, [quoteTwo.quote_id]),
    /funding_quote_not_found|permission/i,
    database,
  );
  await database.query("rollback to savepoint cross_user_quote_access");
  await resetRole(database);

  const invalidCurrencyScope = `currency-${randomUUID()}`;
  await database.query(
    `insert into private.stripe_financial_policy_versions (
       environment, policy_kind, scope_key, currency_code, version,
       effective_at, active, recommended_min_cents, recommended_max_cents,
       hard_minimum_cents, yellow_may_continue
     ) values ('test', 'fair_pay', $1, 'EUR', 'qa-eur-v1', statement_timestamp() - interval '1 minute', true,
       2000, 2800, 1400, true)`,
    [invalidCurrencyScope],
  );
  await expectDatabaseError(
    () => database.query(
      `select * from private.evaluate_fair_pay_v1(2500, 'test', 'USD', $1, statement_timestamp())`,
      [invalidCurrencyScope],
    ),
    /fair_pay_policy_missing/i,
    database,
  );

  const consumeSignature = await database.query(`
    select pg_get_function_identity_arguments(procedure.oid) arguments,
           pg_get_functiondef(procedure.oid) source
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'stripe_server_consume_job_funding_quote_v1'
  `);
  assertQa(!consumeSignature.rows[0].arguments.includes("timestamptz"), "quote consumption accepts a client clock");
  assertQa(consumeSignature.rows[0].source.includes("clock_timestamp()"), "quote consumption does not use the server clock");

  const activeIndex = await database.query(`
    select indexdef from pg_indexes
    where schemaname = 'private' and indexname = 'stripe_job_funding_quote_one_active_idx'
  `);
  assertQa(activeIndex.rows[0].indexdef.includes("UNIQUE"), "active quote concurrency constraint is not unique");
  const createSource = await database.query(`
    select pg_get_functiondef(procedure.oid) source
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'stripe_server_create_job_funding_quote_v1'
  `);
  assertQa(createSource.rows[0].source.includes("pg_advisory_xact_lock"), "quote refresh lacks transaction-scoped concurrency serialization");
  assertQa(createSource.rows[0].source.includes("state = 'ACTIVE'"), "quote expiration/supersession is not limited to unused active quotes");
});
