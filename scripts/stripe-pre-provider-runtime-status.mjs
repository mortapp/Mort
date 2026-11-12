import pg from "pg";

const projectRef = process.env.MORT_SUPABASE_PROJECT_REF || "ckcxakhxqlkhppsxxjhv";
const dbPassword = process.env.SUPABASE_DB_PASSWORD;
if (projectRef !== "ckcxakhxqlkhppsxxjhv") {
  console.error(JSON.stringify({ status: "FAIL", code: "qa_project_required", secret_values_printed: false }));
  process.exit(2);
}
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
           payments_enabled,
           connected_onboarding_enabled,
           job_funding_enabled,
           transfers_enabled,
           refunds_enabled,
           payouts_approved,
           connected_accounts_approved,
           live_mode_enabled,
           live_owner_approved
      from private.stripe_runtime_controls
     where singleton
  `);
  const row = result.rows[0];
  if (!row) throw new Error("stripe_runtime_controls_missing");

  const requiredSandboxFlags = {
    payments_enabled: row.payments_enabled === true,
    connected_onboarding_enabled: row.connected_onboarding_enabled === true,
    job_funding_enabled: row.job_funding_enabled === true,
    transfers_enabled: row.transfers_enabled === true,
    refunds_enabled: row.refunds_enabled === true,
    payouts_approved: row.payouts_approved === true,
    connected_accounts_approved: row.connected_accounts_approved === true,
  };
  const mutationEligible =
    row.mode === "sandbox" &&
    Object.values(requiredSandboxFlags).every(Boolean) &&
    row.live_mode_enabled === false &&
    row.live_owner_approved === false;

  console.log(JSON.stringify({
    status: "PASS",
    project_ref: projectRef,
    runtime_mode: row.mode,
    currency_code: row.currency_code,
    mutation_test_eligible: mutationEligible,
    required_sandbox_flags: requiredSandboxFlags,
    live_mode_enabled: row.live_mode_enabled === true,
    live_owner_approved: row.live_owner_approved === true,
    secret_values_printed: false,
  }));
} catch {
  console.error(JSON.stringify({ status: "FAIL", code: "runtime_status_unavailable", secret_values_printed: false }));
  process.exit(3);
} finally {
  await database.end().catch(() => {});
}
