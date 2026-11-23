// Local Postgres/WASM only; this test does not accept a database URL or call Stripe.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const modulePath = process.env.MORT_PGLITE_ENTRY;
if (!modulePath) throw new Error("Set MORT_PGLITE_ENTRY to the local @electric-sql/pglite dist/index.js path");
const { PGlite } = await import(pathToFileURL(modulePath).href);
const db = new PGlite();
const migrations = new URL("../supabase/migrations/", import.meta.url);
const sql = (file) => readFileSync(new URL(file, migrations), "utf8");
const foundation = sql("20260722032907_stripe_connect_sandbox_foundation.sql");
const fn = (source, qualifiedName) => {
  const start = source.indexOf(`create or replace function ${qualifiedName}(`);
  assert.notEqual(start, -1, qualifiedName);
  return source.slice(start, source.indexOf("\n$$;", start) + 4);
};
const seed = "37a92acd-7f02-4f6e-8e86-a2714ac1dea0";
const read = async (query, params) => (await db.query(query, params)).rows[0]?.value;
const claim = (id, key, type, hash = "a".repeat(64)) =>
  read("select public.stripe_server_claim_webhook_event_v3('test', $1, $2, now(), $3, $4) as value", [id, type, hash, key]);
const finish = (id, token, observation) =>
  read("select public.stripe_server_finish_webhook_observation_v3('test', $1, $2, $3::jsonb) as value",
    [id, token, observation === null ? null : JSON.stringify(observation)]);
const deliver = async (id, key, type, observation) => {
  const c = await claim(id, key, type);
  assert.equal(c.claimed, true, id);
  return finish(id, c.lease_token, observation);
};

try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth; create schema private;
    create function auth.role() returns text language sql as $$select current_setting('request.jwt.claim.role', true)$$;
    set request.jwt.claim.role = 'service_role';
    create table auth.users (id uuid primary key);
    create table public.job_contracts (id uuid primary key);
    create table public.job_contract_versions (id uuid primary key);
    create table public.job_payment_obligations (id uuid primary key);
    insert into auth.users values ('${seed}');
    insert into public.job_contracts values ('${seed}');
    insert into public.job_contract_versions values ('${seed}');
    insert into public.job_payment_obligations values ('${seed}');
    create table private.stripe_job_funding_quotes (id uuid primary key);
    create table private.stripe_payment_resolutions (
      payment_intent_id uuid, provider_refund_id text, status text, safe_failure_code text, updated_at timestamptz
    );
  `);
  await db.exec(foundation.slice(0, foundation.indexOf("create or replace function private.require_stripe_service_role")));
  const funding = sql("20260916233244_mort_stripe_funding_attempts_and_state_v1.sql");
  await db.exec(funding.slice(0, funding.indexOf("create or replace function")));
  for (const name of [
    "private.require_stripe_service_role", "private.stripe_environment_for_mode",
    "public.stripe_server_record_connected_account_status",
    "public.stripe_server_apply_dispute_event", "public.stripe_server_apply_payout_event",
  ]) await db.exec(fn(foundation, name));
  const lease = sql("20260916235113_mort_stripe_webhook_lease_v1.sql");
  await db.exec(lease.slice(0, lease.indexOf("create or replace function")));
  await db.exec(sql("20260919000711_mort_stripe_webhook_retry_state_v1.sql"));
  await db.exec(fn(sql("20260918120347_mort_stripe_requires_action_state_v1.sql"), "private.reduce_stripe_payment_state_v1"));
  await db.exec(sql("20260918183821_mort_stripe_stale_payment_webhook_ignore_v1.sql"));
  await db.exec(sql("20260722213243_mort_0_9_3_refund_webhook_reconciliation.sql"));
  await db.exec(sql("20261123233000_stripe_marketplace_webhook_observations.sql"));

  assert.equal(await read(`select has_function_privilege('authenticated',
    'public.stripe_server_finish_webhook_observation_v3(text,text,uuid,jsonb)','execute') as value`), false);
  await db.exec(`update private.stripe_runtime_controls set mode = 'disabled'`);
  await assert.rejects(claim("evt_disabled", "payment:platform:pi_test", "payment_intent.succeeded"), /environment_mismatch/);
  await db.exec(`update private.stripe_runtime_controls set mode = 'sandbox'`);
  await db.exec(`
    insert into private.stripe_connected_accounts (id, user_id, environment, provider_account_id)
      values ('${seed}', '${seed}', 'test', 'acct_test');
    insert into private.stripe_job_payment_intents
      (id, contract_id, contract_version_id, obligation_id, adult_id, teen_id, environment, earnings_amount_cents,
       service_fee_cents, total_amount_cents, currency_code, provider_payment_intent_id, transfer_group, idempotency_key, normalized_state)
      values ('${seed}', '${seed}', '${seed}', '${seed}', '${seed}', '${seed}', 'test', 700, 134, 834, 'USD', 'pi_test',
       'MORT_JOB_1234567890abcdef1234567890abcdef', 'test_payment_idempotency', 'READY');
    insert into private.stripe_job_transfers (payment_intent_id, connected_account_id, environment, amount_cents, currency_code,
      provider_transfer_id, provider_source_charge_id, idempotency_key, eligibility_path)
      values ('${seed}', '${seed}', 'test', 700, 'USD', 'tr_test', 'ch_test', 'test_transfer_idempotency', 'mutual_completion_confirmed');
  `);

  const pKey = "payment:platform:pi_test", pType = "payment_intent.succeeded";
  const payment = { kind: "payment", id: "pi_test", state: pType, amount: 834, currency: "USD", charge: "ch_test" };
  const first = await claim("evt_first", pKey, pType);
  assert.equal(first.claimed, true);
  assert.equal((await claim("evt_first", pKey, pType)).processing_status, "received");
  assert.equal((await claim("evt_busy", pKey, pType)).processing_status, "busy");
  assert.equal((await finish("evt_first", first.lease_token, null)).processing_status, "failed");
  assert.equal((await read("select public.stripe_server_webhook_reconciliation_status_v1('test') as value")).failed, 1);
  const retry = await claim("evt_first", pKey, pType);
  assert.notEqual(retry.lease_token, first.lease_token);
  await assert.rejects(finish("evt_first", first.lease_token, payment), /claim_no_longer_active/);
  assert.equal((await finish("evt_first", retry.lease_token, payment)).processing_status, "processed");
  assert.equal(await read("select status as value from private.stripe_job_payment_intents"), "funded");
  assert.equal((await claim("evt_first", pKey, pType)).processing_status, "processed");
  await assert.rejects(claim("evt_first", pKey, pType, "b".repeat(64)), /replay_payload_mismatch/);
  assert.equal((await deliver("evt_same", pKey, "payment_intent.processing", payment)).code, "stripe_provider_state_already_applied");

  const rKey = "refund:platform:re_test";
  const refund = { kind: "refund", id: "re_test", payment: "pi_test", state: "succeeded", amount: 300, currency: "USD" };
  await deliver("evt_refund", rKey, "refund.created", refund);
  await deliver("evt_refundagain", rKey, "refund.updated", refund);
  assert.equal(await read("select count(*)::int as value from private.stripe_job_refunds"), 1);
  assert.equal(await read("select count(*)::int as value from private.stripe_financial_audit_events"), 1);
  assert.equal(await read("select status as value from private.stripe_job_payment_intents"), "partially_refunded");
  await deliver("evt_paylate", pKey, pType, { ...payment, failure: "irrelevant" });
  assert.equal(await read("select status as value from private.stripe_job_payment_intents"), "partially_refunded");

  const tKey = "transfer:platform:tr_test", tType = "transfer.reversed";
  const transfer = { kind: "transfer", id: "tr_test", state: "partially_reversed", amount: 700, currency: "USD",
    destination: "acct_test", reversed: 200 };
  const tc = await claim("evt_transfer", tKey, tType);
  await assert.rejects(finish("evt_transfer", tc.lease_token, { ...transfer, destination: "acct_wrong" }),
    /transfer_value_or_recipient_mismatch/);
  assert.equal(await read("select status as value from private.stripe_job_transfers"), "pending");
  await finish("evt_transfer", tc.lease_token, transfer);
  assert.equal(await read("select amount_reversed_cents as value from private.stripe_job_transfers"), 200);
  await deliver("evt_transferfull", tKey, tType, { ...transfer, state: "reversed", reversed: 700 });
  assert.equal(await read("select status as value from private.stripe_job_transfers"), "reversed");
  assert.equal(await read("select status as value from private.stripe_job_payment_intents"), "partially_refunded");

  const poKey = "payout:acct_test:po_test";
  const payout = { kind: "payout", id: "po_test", account: "acct_test", state: "paid", amount: 250, currency: "USD" };
  await deliver("evt_payout", poKey, "payout.paid", payout);
  await deliver("evt_payoutfailed", poKey, "payout.failed", { ...payout, state: "failed", failure: "account_closed" });
  assert.equal(await read("select status as value from private.stripe_payout_events"), "failed");
  assert.equal(await read("select count(*)::int as value from private.stripe_payout_events"), 1);

  const dispute = { kind: "dispute", id: "dp_test", payment: "pi_test", state: "needs_response", amount: 400, currency: "USD" };
  await deliver("evt_dispute", "dispute:platform:dp_test", "charge.dispute.created", dispute);
  assert.equal(await read("select status as value from private.stripe_job_payment_intents"), "disputed");
  await deliver("evt_refundpending", "refund:platform:re_second", "refund.created", {
    ...refund, id: "re_second", state: "pending", amount: 100,
  });
  await deliver("evt_refundfailure", "refund:platform:re_second", "refund.failed", {
    ...refund, id: "re_second", state: "failed", amount: 100, failure: "declined",
  });
  assert.equal(await read("select status as value from private.stripe_job_payment_intents"), "disputed");
  await deliver("evt_disputewon", "dispute:platform:dp_test", "charge.dispute.closed", { ...dispute, state: "won" });
  assert.equal(await read("select status as value from private.stripe_job_payment_intents"), "partially_refunded");
  await deliver("evt_disputelost", "dispute:platform:dp_test", "charge.dispute.closed", { ...dispute, state: "lost" });
  assert.equal(await read("select status as value from private.stripe_job_payment_intents"), "chargeback");
  console.log("PASS: Postgres lease retry/fencing, ACL, duplicate events, funding, refunds, transfer validation/reversals, payouts and disputes");
} finally {
  await db.close();
}
