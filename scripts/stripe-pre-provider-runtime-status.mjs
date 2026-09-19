import pg from "pg";

const projectRef = process.env.MORT_SUPABASE_PROJECT_REF || "rakjydmgwwgtdislanbt";
const dbPassword = process.env.SUPABASE_DB_PASSWORD;
if (!dbPassword) {
  console.error(JSON.stringify({ status: "FAIL", code: "supabase_db_password_required", secret_values_printed: false }));
  process.exit(2);
}

const database = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password: dbPassword,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10_000,
});
database.on("error", () => {});

try {
  await database.connect();
  const result = await database.query(`
    select mode, currency_code,
           stripe_payments_enabled,
           stripe_connected_onboarding_enabled,
           stripe_job_funding_enabled,
           stripe_transfers_enabled,
           stripe_refunds_enabled,
           stripe_live_mode_enabled,
           live_owner_approved
      from private.stripe_runtime_controls
     where singleton
  `);
  const row = result.rows[0];
  if (!row) throw new Error("stripe_runtime_controls_missing");

  const requiredSandboxFlags = {
    stripe_payments_enabled: row.stripe_payments_enabled === true,
    stripe_connected_onboarding_enabled: row.stripe_connected_onboarding_enabled === true,
    stripe_job_funding_enabled: row.stripe_job_funding_enabled === true,
    stripe_transfers_enabled: row.stripe_transfers_enabled === true,
    stripe_refunds_enabled: row.stripe_refunds_enabled === true,
  };
  const mutationEligible =
    row.mode === "sandbox" &&
    Object.values(requiredSandboxFlags).every(Boolean) &&
    row.stripe_live_mode_enabled === false &&
    row.live_owner_approved === false;

  console.log(JSON.stringify({
    status: "PASS",
    project_ref: projectRef,
    runtime_mode: row.mode,
    currency_code: row.currency_code,
    mutation_test_eligible: mutationEligible,
    required_sandbox_flags: requiredSandboxFlags,
    live_mode_enabled: row.stripe_live_mode_enabled === true,
    live_owner_approved: row.live_owner_approved === true,
    secret_values_printed: false,
  }));
} catch {
  console.error(JSON.stringify({ status: "FAIL", code: "runtime_status_unavailable", secret_values_printed: false }));
  process.exit(3);
} finally {
  await database.end().catch(() => {});
}
