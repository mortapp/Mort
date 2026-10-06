import { readFileSync } from "node:fs";
import { withDatabase, qaLog } from "./feature-qa-helpers.mjs";

if (process.env.MORT_QA_TARGET !== "local" || process.env.MORT_QA_LOCAL_SUPABASE !== "true" ||
    new URL(process.env.EXPO_PUBLIC_SUPABASE_URL ?? "http://invalid").hostname !== "127.0.0.1" ||
    new URL(process.env.SUPABASE_DB_URL ?? "postgres://invalid").hostname !== "127.0.0.1") {
  throw new Error("Grace QA requires the local MORT Supabase stack.");
}
await withDatabase(async (db) => {
  try {
    await db.query(readFileSync(new URL("../supabase/tests/revenuecat_grace_period.sql", import.meta.url), "utf8"));
  } finally {
    await db.query("rollback");
  }
});
qaLog("revenuecat-grace-period", "provider grace, cancellation, stale events, recovery, invalid grace, revocation, Plus isolation, expiry, lifetime and privileges; fixtures rolled back");
