import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import pg from "pg";

const databaseUrl = process.env.SUPABASE_DB_URL;

export function assertQa(condition, message) {
  if (!condition) throw new Error(message);
}

let expectedErrorSequence = 0;

export async function expectDatabaseError(operation, expectedPattern, database) {
  expectedErrorSequence += 1;
  const savepoint = `qa_expected_error_${expectedErrorSequence}`;
  if (database) await database.query(`savepoint ${savepoint}`);
  try {
    await operation();
  } catch (error) {
    const message = error?.message ?? String(error);
    if (database) await database.query(`rollback to savepoint ${savepoint}`);
    assertQa(expectedPattern.test(message), `Expected ${expectedPattern}, received: ${message}`);
    return;
  }
  if (database) await database.query(`rollback to savepoint ${savepoint}`);
  throw new Error(`Expected database error ${expectedPattern}, but the operation succeeded`);
}

export async function withLocalDatabase(scope, run) {
  const database = process.env.MORT_QA_USE_HOSTED === "true"
    ? new pg.Client({
      host: "db.rakjydmgwwgtdislanbt.supabase.co",
      port: 5432,
      database: "postgres",
      user: "postgres",
      password: required("SUPABASE_DB_PASSWORD"),
      ssl: { rejectUnauthorized: false },
    })
    : new pg.Client({ connectionString: required("SUPABASE_DB_URL") });
  database.on("error", () => {});
  await database.connect();
  await database.query("begin");
  try {
    if (process.env.MORT_QA_MIGRATION_PATH) {
      const migration = await readFile(process.env.MORT_QA_MIGRATION_PATH, "utf8");
      await database.query(migration);
    }
    await run(database);
    await database.query("rollback");
    console.log(`[${scope}] PASS`);
  } catch (error) {
    await database.query("rollback").catch(() => {});
    throw error;
  } finally {
    await database.end();
  }
}

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export async function setServiceRole(database) {
  await database.query(
    `select set_config('request.jwt.claims', $1, true)`,
    [JSON.stringify({ role: "service_role" })],
  );
}

export async function setAuthenticatedUser(database, userId) {
  await database.query("set local role authenticated");
  await database.query(
    `select set_config('request.jwt.claims', $1, true)`,
    [JSON.stringify({ role: "authenticated", sub: userId })],
  );
}

export async function resetRole(database) {
  await database.query("reset role");
  await setServiceRole(database);
}

export async function createFundingFixture(database, basePayCents = 2500) {
  const ids = {
    adult: randomUUID(),
    otherAdult: randomUUID(),
    teen: randomUUID(),
    job: randomUUID(),
    application: randomUUID(),
    contract: randomUUID(),
    contractVersion: randomUUID(),
    obligation: randomUUID(),
    connectedAccount: randomUUID(),
  };

  await database.query("set local session_replication_role = replica");
  for (const [id, email] of [
    [ids.adult, `bp02-adult-${ids.adult}@mort.test`],
    [ids.otherAdult, `bp02-other-${ids.otherAdult}@mort.test`],
    [ids.teen, `bp02-teen-${ids.teen}@mort.test`],
  ]) {
    await database.query(
      `insert into auth.users (id, email, raw_user_meta_data) values ($1, $2, '{}'::jsonb)`,
      [id, email],
    );
  }

  await database.query(
    `insert into public.profiles (
       id, role, display_name, username, dob, city, state,
       onboarding_completed, account_status, is_test_account
     ) values
       ($1, 'adult', 'BP02 Adult', 'bp02_adult', '1990-01-01', 'Indianapolis', 'IN', true, 'active', true),
       ($2, 'adult', 'BP02 Other', 'bp02_other', '1991-01-01', 'Indianapolis', 'IN', true, 'active', true),
       ($3, 'teen', 'BP02 Teen', 'bp02_teen', '2011-01-01', 'Indianapolis', 'IN', true, 'active', true)`,
    [ids.adult, ids.otherAdult, ids.teen],
  );

  await database.query(
    `insert into public.jobs (
       id, poster_id, title, description, category, location_text, city, state,
       pay_amount_cents, adult_job_amount_cents, mort_service_fee_cents,
       status, is_test, created_by_qa, environment_tag
     ) values ($1, $2, 'BP02 Quote Fixture', 'Authoritative quote fixture',
       'organization', 'Approximate area', 'Indianapolis', 'IN',
       $3, $3, 0, 'assigned', true, true, 'qa')`,
    [ids.job, ids.adult, basePayCents],
  );
  await database.query(
    `insert into public.applications (id, job_id, teen_id, status)
     values ($1, $2, $3, 'accepted')`,
    [ids.application, ids.job, ids.teen],
  );
  await database.query(
    `insert into public.job_contracts (
       id, job_id, application_id, teen_id, adult_id, status, classification_status, activated_at
     ) values ($1, $2, $3, $4, $5, 'active', 'classification_unknown', statement_timestamp())`,
    [ids.contract, ids.job, ids.application, ids.teen, ids.adult],
  );
  await database.query(
    `insert into public.job_contract_versions (
       id, contract_id, version_number, source, status,
       teen_public_identifier, adult_public_identifier, agreed_scope, excluded_work,
       location_type, exact_location_release_state, amount_type, fixed_total_cents,
       currency_code, payment_preference, payment_due_rule, cancellation_terms,
       material_change_process, dispute_process, safety_agreement_version,
       terms_snapshot, content_hash, created_by, activated_at
     ) values (
       $1, $2, 1, 'application_acceptance', 'active',
       'bp02_teen', 'bp02_adult', 'Organize labeled materials', '{}'::text[],
       'public', 'approximate_only', 'fixed', $3,
       'USD', 'cash', 'within_24_hours_of_completion', 'Fixture cancellation terms',
       'Mutual written change', 'MORT dispute process', 'bp02-safety-v1',
       '{}'::jsonb, repeat('0', 64), $4, statement_timestamp()
     )`,
    [ids.contractVersion, ids.contract, basePayCents, ids.adult],
  );
  await database.query(
    `update public.job_contracts set active_version_id = $2 where id = $1`,
    [ids.contract, ids.contractVersion],
  );
  await database.query(
    `insert into public.job_payment_obligations (
       id, contract_id, contract_version_id, obligated_poster_id, worker_id,
       amount_cents, currency_code, payment_preference, due_rule
     ) values ($1, $2, $3, $4, $5, $6, 'USD', 'cash', 'within_24_hours_of_completion')`,
    [ids.obligation, ids.contract, ids.contractVersion, ids.adult, ids.teen, basePayCents],
  );
  await database.query(
    `insert into private.stripe_connected_accounts (
       id, user_id, environment, provider_account_id, onboarding_status,
       details_submitted, charges_enabled, payouts_enabled,
       transfers_capability_status, requirements_status, guardian_requirement_status,
       country, default_currency, last_synchronized_at
     ) values ($1, $2, 'test', $3, 'complete', true, true, true,
       'active', 'satisfied', 'provider_managed_satisfied', 'US', 'USD', statement_timestamp())`,
    [ids.connectedAccount, ids.teen, `acct_BP02${ids.teen.replaceAll("-", "")}`],
  );
  await database.query("set local session_replication_role = origin");
  return ids;
}

export async function insertFairPayPolicy(database, scopeKey, yellowMayContinue = true) {
  const result = await database.query(
    `insert into private.stripe_financial_policy_versions (
       environment, policy_kind, scope_key, currency_code, version,
       effective_at, active, recommended_min_cents, recommended_max_cents,
       hard_minimum_cents, yellow_may_continue
     ) values (
       'test', 'fair_pay', $1, 'USD', $2,
       statement_timestamp() - interval '1 minute', true, 2000, 2800, 1400, $3
     ) returning id`,
    [scopeKey, `qa-${scopeKey}-${yellowMayContinue ? "allow" : "block"}-v1`, yellowMayContinue],
  );
  return result.rows[0].id;
}
