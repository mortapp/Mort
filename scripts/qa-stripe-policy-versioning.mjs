import { randomUUID } from "node:crypto";
import {
  assertQa,
  expectDatabaseError,
  setServiceRole,
  setAuthenticatedUser,
  withLocalDatabase,
} from "./stripe-policy-qa-helpers.mjs";

await withLocalDatabase("stripe-policy-versioning", async (database) => {
  const seed = await database.query(`
    select * from private.stripe_financial_policy_versions
    where environment = 'test' and policy_kind = 'service_fee'
      and scope_key = 'global' and currency_code = 'USD' and active
  `);
  assertQa(seed.rowCount === 1, "expected exactly one active sandbox service-fee policy");
  const policy = seed.rows[0];
  assertQa(policy.service_fee_bps === 800, "sandbox service fee must be 800 bps");
  assertQa(policy.service_fee_min_cents === 100, "sandbox service-fee minimum must be 100 cents");
  assertQa(policy.service_fee_max_cents === 500, "sandbox service-fee maximum must be 500 cents");
  assertQa(policy.quote_ttl_seconds === 900, "sandbox funding-quote TTL must be 900 seconds");

  const live = await database.query(`
    select count(*)::integer count from private.stripe_financial_policy_versions
    where environment = 'live' and active
  `);
  assertQa(live.rows[0].count === 0, "production policy must not default active");

  const feeCases = [
    [0, 0], [500, 100], [1000, 100], [1249, 100], [1250, 100],
    [1256, 100], [1257, 101], [2500, 200], [5000, 400],
    [6249, 500], [6250, 500], [10000, 500],
  ];
  for (const [baseCents, expectedFee] of feeCases) {
    const result = await database.query(
      `select private.calculate_mort_service_fee_v1($1, $2) fee`,
      [baseCents, policy.id],
    );
    assertQa(result.rows[0].fee === expectedFee, `fee(${baseCents}) expected ${expectedFee}, got ${result.rows[0].fee}`);
  }

  const versionScope = `qa-version-${randomUUID()}`;
  await database.query(
    `insert into private.stripe_financial_policy_versions (
       environment, policy_kind, scope_key, currency_code, version,
       effective_at, expires_at, active, tip_min_cents, tip_max_cents,
       late_tip_window_seconds, tip_teen_share_bps, tip_mort_fee_bps,
       tip_excluded_from_fair_pay
     ) values (
       'test', 'tip', $1, 'USD', '1.0.0',
       '2026-01-01T00:00:00Z', '2026-02-01T00:00:00Z', true,
       100, 10000, 604800, 10000, 0, true
     )`,
    [versionScope],
  );
  const effective = await database.query(
    `select id from private.resolve_financial_policy_v1('test', 'tip', 'USD', $1, '2026-01-15T00:00:00Z')`,
    [versionScope],
  );
  assertQa(effective.rowCount === 1, "effective policy was not selected");
  const expired = await database.query(
    `select id from private.resolve_financial_policy_v1('test', 'tip', 'USD', $1, '2026-02-01T00:00:00Z')`,
    [versionScope],
  );
  assertQa(expired.rowCount === 0, "policy remained effective exactly at expires_at");

  await expectDatabaseError(
    () => database.query(
      `insert into private.stripe_financial_policy_versions (
         environment, policy_kind, scope_key, currency_code, version,
         effective_at, active, tip_min_cents, tip_max_cents,
         late_tip_window_seconds, tip_teen_share_bps, tip_mort_fee_bps,
         tip_excluded_from_fair_pay
       ) values ('test', 'tip', $1, 'USD', '2.0.0', statement_timestamp(), true,
         100, 10000, 604800, 10000, 0, true)`,
      [versionScope],
    ),
    /duplicate key|active.*policy/i,
    database,
  );

  const replacement = await database.query(
    `insert into private.stripe_financial_policy_versions (
       environment, policy_kind, scope_key, currency_code, version,
       effective_at, active, tip_min_cents, tip_max_cents,
       late_tip_window_seconds, tip_teen_share_bps, tip_mort_fee_bps,
       tip_excluded_from_fair_pay
     ) values ('test', 'tip', $1, 'USD', '2.0.0', statement_timestamp(), false,
       100, 12000, 604800, 10000, 0, true)
     returning id`,
    [versionScope],
  );
  await setServiceRole(database);
  const activation = await database.query(
    `select public.stripe_server_activate_financial_policy_v1($1) result`,
    [replacement.rows[0].id],
  );
  assertQa(activation.rows[0].result.ok === true, "controlled policy activation failed");
  const lifecycle = await database.query(
    `select version, active, retired_at from private.stripe_financial_policy_versions
     where environment = 'test' and policy_kind = 'tip' and scope_key = $1
     order by version`,
    [versionScope],
  );
  assertQa(lifecycle.rowCount === 2, "policy replacement removed historical version");
  assertQa(lifecycle.rows[0].active === false && lifecycle.rows[0].retired_at, "old policy was not safely retired");
  assertQa(lifecycle.rows[1].active === true, "replacement policy was not activated");

  await expectDatabaseError(
    () => database.query(
      `update private.stripe_financial_policy_versions
       set service_fee_bps = 900 where id = $1`,
      [policy.id],
    ),
    /immutable|policy/i,
    database,
  );

  await expectDatabaseError(
    () => database.query(
      `select private.calculate_mort_service_fee_v1(-1, $1)`,
      [policy.id],
    ),
    /invalid_compensated_base_cents/i,
    database,
  );

  await database.query("savepoint unauthorized_policy_write");
  await setAuthenticatedUser(database, randomUUID());
  await expectDatabaseError(
    () => database.query(
      `insert into private.stripe_financial_policy_versions (
         environment, policy_kind, scope_key, currency_code, version,
         effective_at, active, service_fee_bps, service_fee_min_cents,
         service_fee_max_cents, quote_ttl_seconds
       ) values ('test', 'service_fee', 'forged', 'USD', 'forged', statement_timestamp(), false,
         1, 0, 1, 900)`,
    ),
    /permission denied|row-level security/i,
    database,
  );
  await database.query("rollback to savepoint unauthorized_policy_write");
});
