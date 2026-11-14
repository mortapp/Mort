const productionProjectRef = "jxbnrkasktbhtiujkhay";

export function createBackupPostgresConfig({ projectRef, password }) {
  if (projectRef !== productionProjectRef) {
    throw new Error("backup_database_target_not_authoritative_production");
  }
  if (typeof password !== "string" || password.length === 0) {
    throw new Error("backup_database_password_required");
  }

  return {
    host: `db.${projectRef}.supabase.co`,
    port: 5432,
    database: "postgres",
    user: "postgres",
    password,
    // Never send the production database password over a connection that
    // accepts an untrusted or hostname-mismatched TLS certificate.
    ssl: { rejectUnauthorized: true },
  };
}
