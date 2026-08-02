import pg from "pg";

const password = process.env.SUPABASE_DB_PASSWORD;
if (!password)
  throw new Error("SUPABASE_DB_PASSWORD is required and is never printed.");

const database = new pg.Client({
  host: "db.rakjydmgwwgtdislanbt.supabase.co",
  port: 5432,
  database: "postgres",
  user: "postgres",
  password,
  ssl: { rejectUnauthorized: false },
});

await database.connect();
try {
  const before = await database.query(
    `select coalesce(sum(request_count), 0)::integer as count
       from public.support_global_rate_limits
      where scope = 'provider_request'`,
  );
  await database.query("begin");
  try {
    await database.query(
      `select set_config('request.jwt.claims', '{"role":"service_role"}', true)`,
    );
    const result = await database.query(
      `select public.support_consume_global_provider_limit() as result`,
    );
    if (result.rows[0]?.result?.ok !== true) {
      throw new Error(
        "Service-authorized global provider budget did not allow a request.",
      );
    }
  } finally {
    await database.query("rollback");
  }
  const after = await database.query(
    `select coalesce(sum(request_count), 0)::integer as count
       from public.support_global_rate_limits
      where scope = 'provider_request'`,
  );
  if (before.rows[0].count !== after.rows[0].count) {
    throw new Error("Global provider budget rollback changed remote state.");
  }
  console.log(
    "[qa-support-global-budget] PASS: service-only global daily budget allowed in-transaction use and rollback preserved remote state",
  );
} finally {
  await database.end();
}
