import { readFile } from "node:fs/promises";
import { relative, resolve } from "node:path";

import pg from "pg";

const projectRef = "rakjydmgwwgtdislanbt";
const migrationRoot = resolve("supabase", "migrations");
const requestedPaths = process.argv.slice(2);
const dbPassword = process.env.SUPABASE_DB_PASSWORD;

if (!requestedPaths.length) {
  throw new Error("Usage: node scripts/transaction-dry-run.mjs <migration.sql> [migration.sql ...]");
}
if (!dbPassword) {
  throw new Error("SUPABASE_DB_PASSWORD is required.");
}

const migrations = await Promise.all(requestedPaths.map(async (requestedPath) => {
  const migrationPath = resolve(requestedPath);
  const relativePath = relative(migrationRoot, migrationPath);
  if (relativePath.startsWith("..") || !relativePath.endsWith(".sql")) {
    throw new Error("Migration paths must be SQL files under supabase/migrations.");
  }
  return {
    relativePath: relativePath.replaceAll("\\", "/"),
    sql: await readFile(migrationPath, "utf8"),
  };
}));
const client = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password: dbPassword,
  ssl: { rejectUnauthorized: false },
});

await client.connect();
try {
  await client.query("begin");
  for (const migration of migrations) {
    await client.query(migration.sql);
  }
  await client.query("rollback");
  console.log(`Transaction dry-run passed: ${migrations.map((migration) => migration.relativePath).join(", ")}`);
} catch (error) {
  await client.query("rollback").catch(() => {});
  throw error;
} finally {
  await client.end();
}
