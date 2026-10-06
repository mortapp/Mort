import { randomUUID } from "node:crypto";
import { assertQa, qaLog, withDatabase, withQaUsers } from "./feature-qa-helpers.mjs";

const scope = "revenuecat-entitlement-expiry";
if (process.env.MORT_QA_TARGET !== "local" ||
    process.env.MORT_QA_LOCAL_SUPABASE !== "true" ||
    new URL(process.env.EXPO_PUBLIC_SUPABASE_URL ?? "http://invalid").hostname !== "127.0.0.1" ||
    new URL(process.env.SUPABASE_DB_URL ?? "postgres://invalid").hostname !== "127.0.0.1") {
  throw new Error("Entitlement expiry QA requires the local MORT Supabase stack.");
}

await withQaUsers(scope, [{ key: "expiry_adult", role: "adult" }], async ({ expiry_adult: adult }) => withDatabase(async (db) => {
  await db.query("begin");
  try {
    const userId = adult.id;
    await db.query("select set_config('request.jwt.claim.sub', $1, true)", [userId]);
    await db.query("delete from public.revenuecat_product_states where user_id = $1", [userId]);
    await db.query("delete from public.monetization_entitlements_cache where user_id = $1", [userId]);
    await db.query("delete from public.user_subscription_status where user_id = $1", [userId]);
    let sequence = 0;
    const future = new Date(Date.now() + 86400000);
    async function purchase(product, entitlements, until = future) {
      await db.query(
        `select public.process_revenuecat_provider_event(
          $1, $2, 'initial_purchase', $3, $4::text[], $5::timestamptz,
          $6::timestamptz, $7, $8::jsonb)`,
        [`qa_expiry_${randomUUID()}`, userId, product, entitlements, until,
          new Date(Date.now() + sequence++ * 1000), "c".repeat(64), JSON.stringify({ test: true })],
      );
    }
    async function asAuthenticated(run) {
      await db.query("savepoint authenticated_rpc");
      await db.query("set local role authenticated");
      try { return await run(); } catch (error) {
        await db.query("rollback to savepoint authenticated_rpc");
        throw error;
      } finally {
        await db.query("reset role");
        await db.query("release savepoint authenticated_rpc");
      }
    }
    function safeQaUsername() {
      // Decimal UUID runs can resemble phone numbers and correctly fail safety.
      // This alphabet cannot form any reserved contact/profanity patterns.
      return `qax${randomUUID().replaceAll('-', '').slice(0, 14)
        .replace(/[0-9]/g, (digit) => 'abcdefghij'[Number(digit)])}`;
    }
    async function current(expected) {
      const result = await asAuthenticated(() => db.query("select * from public.get_my_entitlements()"));
      const row = result.rows[0];
      assertQa(JSON.stringify([...row.entitlements].sort()) === JSON.stringify([...expected].sort()),
        `Expected live entitlements ${expected.join(',') || 'none'}, received ${row.entitlements.join(',') || 'none'}.`);
      assertQa(row.premium_active === expected.some((id) => ["mort_pro", "mort_plus", "mort_lifetime"].includes(id)),
        "Premium summary did not follow currently active product states.");
      return row;
    }
    async function usernameAllowance(expected) {
      const result = await asAuthenticated(() => db.query("select * from public.get_username_change_status()"));
      assertQa(result.rows[0].plus_allowance_available === expected,
        "Username allowance did not follow the active Plus-or-higher tier.");
    }
    await db.query(
      `insert into public.username_change_credits (user_id, free_changes_used, token_credits, admin_credits)
       values ($1, 3, 0, 0) on conflict (user_id) do update
       set free_changes_used = 3, token_credits = 0, admin_credits = 0,
           plus_period_start = null, plus_changes_used = 0`, [userId],
    );
    await db.query(
      `insert into public.user_ad_preferences (user_id, ads_consent_ready)
       values ($1, true) on conflict (user_id) do update set ads_consent_ready = true`, [userId],
    );

    await purchase("mort_pro:monthly", ["mort_pro"]);
    await current(["mort_pro"]);
    // Simulate time passing after a valid purchase; deliberately leave its cache stale.
    await db.query(
      "update public.revenuecat_product_states set active_until = now() - interval '1 second' where user_id = $1",
      [userId],
    );
    const expired = await current([]);
    assertQa(!expired.ad_free_active, "Expired Pro still has ad-free access.");
    await usernameAllowance(false);
    await db.query("savepoint expired_username_request");
    await db.query("set local role authenticated");
    let expiredAllowanceDenied = false;
    try {
      await db.query("select * from public.request_username_change($1)",
        [safeQaUsername()]);
    } catch (error) {
      expiredAllowanceDenied = error.code === "P0001" &&
        error.message.startsWith("No username changes are available.");
    } finally {
      await db.query("rollback to savepoint expired_username_request");
      await db.query("reset role");
      await db.query("release savepoint expired_username_request");
    }
    assertQa(expiredAllowanceDenied, "Expired subscription spent a monthly username allowance.");
    const ad = await asAuthenticated(() => db.query("select * from public.get_ad_eligibility('adult_dashboard', 'banner')"));
    assertQa(ad.rows[0].allowed, "Expired Pro retained stale ad suppression.");
    qaLog(scope, "expired Pro is removed without an expiration webhook");

    await purchase("mort_plus_monthly", ["mort_plus"]);
    await current(["mort_plus", "mort_ad_free"]);
    await usernameAllowance(true);
    await purchase("mort_pro:monthly", ["mort_pro"]);
    await db.query(
      "update public.revenuecat_product_states set active_until = now() where user_id = $1 and product_id = 'mort_pro:monthly'",
      [userId],
    );
    await current(["mort_plus", "mort_ad_free"]);
    qaLog(scope, "a longer-lived Plus product cannot extend expired Pro");

    await purchase("mort_ad_free_lifetime", ["mort_ad_free"], null);
    await db.query(
      "update public.revenuecat_product_states set active_until = now() where user_id = $1 and product_id = 'mort_plus_monthly'",
      [userId],
    );
    const adOnly = await current(["mort_ad_free"]);
    assertQa(adOnly.ad_free_active, "Independent lifetime ad-free benefit was lost.");
    await usernameAllowance(false);
    await db.query(
      "update public.revenuecat_product_states set active = false where user_id = $1 and product_id = 'mort_ad_free_lifetime'",
      [userId],
    );
    qaLog(scope, "lifetime ad-free does not prolong an expired subscription tier");

    await purchase("lifetime", ["mort_pro"], null);
    await db.query(
      "update public.revenuecat_product_states set active_until = now() - interval '1 second' where user_id = $1 and product_id <> 'lifetime'",
      [userId],
    );
    await current(["mort_pro"]);
    await usernameAllowance(true);
    const newUsername = safeQaUsername();
    const changed = await asAuthenticated(() => db.query("select * from public.request_username_change($1)", [newUsername]));
    assertQa(changed.rows[0].source === "plus_allowance", "Active Pro did not inherit the Plus username allowance.");
    qaLog(scope, "lifetime remains active and Pro inherits Plus username allowance");

    await db.query("update public.revenuecat_product_states set active = false where user_id = $1", [userId]);
    await current([]);
    await db.query("delete from public.revenuecat_product_states where user_id = $1", [userId]);
    await db.query(
      "update public.monetization_entitlements_cache set entitlements = array['mort_plus'], active_until = now() + interval '1 day' where user_id = $1",
      [userId],
    );
    await current(["mort_plus"]);
    await db.query(
      "update public.monetization_entitlements_cache set active_until = now() where user_id = $1", [userId],
    );
    await current([]);
    qaLog(scope, "legacy cache fallback respects expiry and never overrides known revoked product states");

    await db.query(
      "update public.monetization_entitlements_cache set active_until = null where user_id = $1", [userId],
    );
    await current(["mort_plus"]);
    await db.query("select set_config('request.jwt.claim.sub', $1, true)", [randomUUID()]);
    await current([]);
    await db.query("select set_config('request.jwt.claim.sub', '', true)");
    await current([]);
    const grants = await db.query(
      "select has_function_privilege('anon', 'public.get_my_active_revenuecat_entitlements()', 'EXECUTE') as anon_can_execute",
    );
    assertQa(!grants.rows[0].anon_can_execute, "Anonymous role can execute the entitlement reader.");
    qaLog(scope, "reads are caller-scoped and anonymous execution is denied");
  } finally {
    await db.query("rollback");
  }
}));
qaLog(scope, "synthetic expiry evidence rolled back; no account or entitlement changed");
