import { randomUUID } from "node:crypto";
import {
  assertQa,
  expectDatabaseError,
  insertFairPayPolicy,
  withLocalDatabase,
} from "./stripe-policy-qa-helpers.mjs";

await withLocalDatabase("stripe-settlement-policy", async (database) => {
  const fairScope = `qa-fair-${randomUUID()}`;
  const blockedScope = `qa-fair-blocked-${randomUUID()}`;
  await insertFairPayPolicy(database, fairScope, true);
  await insertFairPayPolicy(database, blockedScope, false);

  const fairCases = [
    [2500, fairScope, "GREEN", true],
    [1500, fairScope, "YELLOW", true],
    [1500, blockedScope, "YELLOW", false],
    [1399, fairScope, "RED", false],
  ];
  for (const [amount, scope, expectedBand, expectedAllowed] of fairCases) {
    const result = await database.query(
      `select * from private.evaluate_fair_pay_v1($1, 'test', 'USD', $2, statement_timestamp())`,
      [amount, scope],
    );
    assertQa(result.rows[0].decision === expectedBand, `Fair Pay ${amount} expected ${expectedBand}`);
    assertQa(result.rows[0].may_continue === expectedAllowed, `Fair Pay ${amount} allow/block mismatch`);
  }
  await expectDatabaseError(
    () => database.query(
      `select * from private.evaluate_fair_pay_v1(2500, 'test', 'USD', $1, statement_timestamp())`,
      [`missing-${randomUUID()}`],
    ),
    /fair_pay_policy_missing/i,
    database,
  );

  const tipScope = `qa-tip-${randomUUID()}`;
  await database.query(
    `insert into private.stripe_financial_policy_versions (
       environment, policy_kind, scope_key, currency_code, version,
       effective_at, active, tip_min_cents, tip_max_cents,
       late_tip_window_seconds, tip_teen_share_bps, tip_mort_fee_bps,
       tip_excluded_from_fair_pay
     ) values ('test', 'tip', $1, 'USD', 'qa-tip-v1', statement_timestamp() - interval '1 minute', true,
       100, 10000, 604800, 10000, 0, true)`,
    [tipScope],
  );
  for (const [amount, allowed, code] of [[99, false, "TIP_BELOW_MINIMUM"], [100, true, "TIP_ALLOWED"], [10001, false, "TIP_ABOVE_MAXIMUM"]]) {
    const result = await database.query(
      `select * from private.evaluate_tip_policy_v1($1, 'test', 'USD', $2, statement_timestamp())`,
      [amount, tipScope],
    );
    assertQa(result.rows[0].may_continue === allowed, `tip ${amount} allow/block mismatch`);
    assertQa(result.rows[0].outcome_code === code, `tip ${amount} expected ${code}`);
    assertQa(result.rows[0].teen_share_cents === (allowed ? amount : 0), "tip teen share must be 100% when allowed");
    assertQa(result.rows[0].mort_fee_cents === 0, "MORT tip fee must remain zero");
    assertQa(result.rows[0].excluded_from_fair_pay === true, "tips must be excluded from Fair Pay");
  }
  await expectDatabaseError(
    () => database.query(
      `select * from private.evaluate_tip_policy_v1(500, 'test', 'USD', $1, statement_timestamp())`,
      [`missing-${randomUUID()}`],
    ),
    /tip_policy_missing/i,
    database,
  );

  const cancellationScope = `qa-cancel-${randomUUID()}`;
  const partialScope = `qa-partial-${randomUUID()}`;
  const rules = JSON.stringify({
    rules: [
      { priority: 10, outcome_code: "ADULT_CANCELS_BEFORE_WORK", required_facts: { work_started: false }, award: { kind: "basis_points", value: 0 }, explanation_code: "NO_WORK_STARTED" },
      { priority: 20, outcome_code: "ADULT_CANCELS_IN_PROGRESS", required_facts: { work_started: true }, award: { kind: "basis_points", value: 5000 }, explanation_code: "HALF_SANDBOX_FIXTURE" },
      { priority: 30, outcome_code: "TEEN_ABANDONMENT", required_facts: { worker_abandoned: true }, award: { kind: "fixed_cents", value: 0 }, explanation_code: "ABANDONED" },
      { priority: 40, outcome_code: "SUCCESSFUL_COMPLETION", required_facts: { completion_confirmed: true }, award: { kind: "basis_points", value: 10000 }, explanation_code: "FULL_COMPLETION" },
      { priority: 50, outcome_code: "DISPUTED_COMPLETION", required_facts: { dispute_open: true }, award: { kind: "basis_points", value: 0 }, explanation_code: "DISPUTE_FAIL_CLOSED" }
    ]
  });
  for (const [kind, scope] of [["cancellation", cancellationScope], ["partial_compensation", partialScope]]) {
    await database.query(
      `insert into private.stripe_financial_policy_versions (
         environment, policy_kind, scope_key, currency_code, version,
         effective_at, active, configuration
       ) values ('test', $1, $2, 'USD', 'qa-engine-v1', statement_timestamp() - interval '1 minute', true, $3::jsonb)`,
      [kind, scope, rules],
    );
  }

  const engineCases = [
    ["ADULT_CANCELS_BEFORE_WORK", { work_started: false }, 0],
    ["ADULT_CANCELS_IN_PROGRESS", { work_started: true }, 5000],
    ["TEEN_ABANDONMENT", { worker_abandoned: true }, 0],
    ["SUCCESSFUL_COMPLETION", { completion_confirmed: true }, 10000],
    ["DISPUTED_COMPLETION", { dispute_open: true }, 0],
  ];
  for (const [outcome, facts, expected] of engineCases) {
    const evaluator = outcome.startsWith("ADULT_CANCELS")
      ? "private.evaluate_cancellation_v1"
      : "private.evaluate_partial_compensation_v1";
    const scope = outcome.startsWith("ADULT_CANCELS") ? cancellationScope : partialScope;
    const result = await database.query(
      `select * from ${evaluator}('test', 'USD', $1, $2, 10000, $3::jsonb, statement_timestamp())`,
      [scope, outcome, JSON.stringify(facts)],
    );
    assertQa(result.rows[0].compensated_base_cents === expected, `${outcome} compensation mismatch`);
    assertQa(result.rows[0].compensated_base_cents >= 0 && result.rows[0].compensated_base_cents <= 10000, "compensation escaped funded-base bounds");
  }

  const production = await database.query(`
    select count(*)::integer count from private.stripe_financial_policy_versions
    where environment = 'live' and policy_kind in ('cancellation', 'partial_compensation') and active
  `);
  assertQa(production.rows[0].count === 0, "production compensation values must remain inactive/unapproved");
});
