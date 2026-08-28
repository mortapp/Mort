import { randomUUID } from "node:crypto";
import pg from "pg";

const projectRef = "rakjydmgwwgtdislanbt";
const password = process.env.SUPABASE_DB_PASSWORD;

if (!password) {
  throw new Error("SUPABASE_DB_PASSWORD is required for redesign backend QA.");
}

const client = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password,
  ssl: { rejectUnauthorized: false },
});

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function pass(message) {
  console.log(`[qa-redesign-backend] PASS: ${message}`);
}

async function becomeAuthenticated(userId) {
  await client.query("set local role authenticated");
  await client.query(
    "select set_config('request.jwt.claim.sub', $1, true), set_config('request.jwt.claim.role', 'authenticated', true), set_config('request.jwt.claims', $2, true)",
    [userId, JSON.stringify({ sub: userId, role: "authenticated" })],
  );
}

await client.connect();
try {
  await client.query("begin");

  const migrations = await client.query(
    `select version from supabase_migrations.schema_migrations
     where version in (
       '20260728183833', '20260728184631', '20260728185618',
       '20260728220236', '20260728221118'
     )`,
  );
  assert(migrations.rowCount === 5, "All redesign and payment-disabled migrations must be applied.");
  pass("transportation, matching, and payment-disabled migrations are applied");

  const controls = await client.query(
    `select adult_service_fee_bps, adult_service_fee_fixed_cents,
            stripe_live_mode_enabled
     from private.stripe_runtime_controls where singleton`,
  );
  assert(controls.rowCount === 1, "Stripe runtime control row is missing.");
  assert(controls.rows[0].adult_service_fee_bps === 0, "Percentage fee must be zero.");
  assert(
    controls.rows[0].adult_service_fee_fixed_cents === 0,
    "Platform fee must be zero while payments are disabled.",
  );
  assert(
    controls.rows[0].stripe_live_mode_enabled === false,
    "QA must not enable Stripe live mode.",
  );
  const runtime = await client.query(
    `select payments_disabled, public_marketplace_closed
     from private.runtime_feature_controls where singleton`,
  );
  assert(runtime.rows[0].payments_disabled === true, "Payments runtime kill switch is open.");
  assert(runtime.rows[0].public_marketplace_closed === true, "Public marketplace kill switch is open.");
  pass("fees are zero and payment/public-marketplace kill switches remain closed");

  const accounts = await client.query(
    `select id, role::text as role
     from public.profiles
     where is_test_account and account_status = 'active'
       and role in ('teen', 'adult')
     order by role, created_at
     for update`,
  );
  const teen = accounts.rows.find((row) => row.role === "teen");
  const adult = accounts.rows.find((row) => row.role === "adult");
  assert(teen && adult, "Isolated active teen and adult QA profiles are required.");

  await becomeAuthenticated(teen.id);
  const transportation = await client.query(
    `select public.save_my_transportation_preferences(
       array['walking', 'bicycle']::text[], 5, 30, true, false, $1::uuid
     ) as result`,
    [randomUUID()],
  );
  const transportationResult = transportation.rows[0].result;
  assert(transportationResult.ok === true, "Transportation RPC did not succeed.");
  assert(
    transportationResult.profile.id === teen.id,
    "Transportation RPC updated a profile other than auth.uid().",
  );
  assert(
    transportationResult.profile.transportation_methods.join(",") ===
      "bicycle,walking",
    "Transportation methods were not normalized server-side.",
  );
  pass("transportation preferences are normalized and bound to auth.uid()");

  await client.query("reset role");
  await becomeAuthenticated(adult.id);
  const requestId = randomUUID();
  const draft = await client.query(
    `select public.save_job_draft_or_publish(
       null, $1::uuid,
       jsonb_build_object(
         'title', 'Rollback-only fee QA draft',
         'adult_job_amount_cents', 2500,
         'pay_amount_cents', 999999,
         'mort_service_fee_cents', 1,
         'acceptable_transportation_methods', jsonb_build_array('walking'),
         'transportation_considerations', 'Near a public meeting point'
       ),
       false
     ) as result`,
    [requestId],
  );
  const draftResult = draft.rows[0].result;
  assert(draftResult.ok === true, "Fee wrapper draft save did not succeed.");
  assert(
    draftResult.job.adult_job_amount_cents === 2500,
    "Server did not retain the adult-entered amount.",
  );
  assert(draftResult.job.mort_service_fee_cents === 0, "Server added a platform fee.");
  assert(
    draftResult.job.pay_amount_cents === 2500,
    "Server did not preserve the offered compensation.",
  );
  assert(
    draftResult.job.acceptable_transportation_methods.join(",") === "walking",
    "Server did not persist valid transportation matching methods.",
  );
  pass("forged payout and fee values are ignored; server returns 2500/0/2500");

  await client.query("savepoint legacy_execute_check");
  let legacyDenied = false;
  try {
    await client.query(
      `select public.save_job_draft_or_publish_without_fee_v1(
         null, $1::uuid, '{}'::jsonb, false
       )`,
      [randomUUID()],
    );
  } catch (error) {
    legacyDenied = error?.code === "42501";
    await client.query("rollback to savepoint legacy_execute_check");
  }
  assert(legacyDenied, "Authenticated users can execute the legacy fee function.");
  pass("legacy fee-bypass function is denied to authenticated users");

  const directFinancialUpdate = await client.query(
    `update public.jobs
     set adult_job_amount_cents = 999999
     where id = $1::uuid
     returning id`,
    [draftResult.job.id],
  );
  assert(
    directFinancialUpdate.rowCount === 0,
    "Adult owner bypassed the RPC with a direct financial update.",
  );
  pass("RLS blocks direct owner updates to job financial fields");

  await client.query("reset role");
  await client.query("rollback");
  pass("all QA writes were rolled back");
} catch (error) {
  try {
    await client.query("reset role");
    await client.query("rollback");
  } catch {
    // Preserve the original QA error.
  }
  console.error(`[qa-redesign-backend] FAIL: ${error.message}`);
  process.exitCode = 1;
} finally {
  await client.end();
}
