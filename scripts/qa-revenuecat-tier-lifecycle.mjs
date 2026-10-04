import { randomUUID } from "node:crypto";
import { assertQa, qaLog, withDatabase } from "./feature-qa-helpers.mjs";

const scope = "revenuecat-tier-lifecycle";
if (process.env.MORT_QA_TARGET !== "local" ||
    process.env.MORT_QA_LOCAL_SUPABASE !== "true" ||
    new URL(process.env.EXPO_PUBLIC_SUPABASE_URL ?? "http://invalid").hostname !== "127.0.0.1" ||
    new URL(process.env.SUPABASE_DB_URL ?? "postgres://invalid").hostname !== "127.0.0.1") {
  throw new Error("RevenueCat lifecycle QA requires the local MORT Supabase stack.");
}

await withDatabase(async (db) => {
  await db.query("begin");
  try {
    const fixture = await db.query(
      "select id from auth.users where email = $1",
      ["adult.local@mort.test"],
    );
    assertQa(fixture.rowCount === 1, "Seed the synthetic local adult QA account first.");
    const userId = fixture.rows[0].id;
    const baseTime = Date.now();
    let sequence = 0;

    async function event(type, product, entitlementIds, activeUntil = null, id = null, hash = "a".repeat(64), metadata = {}) {
      const eventId = id ?? `qa_lifecycle_${randomUUID()}`;
      const timestamp = new Date(baseTime + sequence++ * 1000);
      const result = await db.query(
        `select public.process_revenuecat_provider_event(
          $1, $2, $3, $4, $5::text[], $6::timestamptz,
          $7::timestamptz, $8, $9::jsonb
        ) as result`,
        [eventId, userId, type, product, entitlementIds, activeUntil,
          timestamp, hash, JSON.stringify({ event: { app_id: metadata.appId, store: metadata.store }, test: true, type, product })],
      );
      return { id: eventId, result: result.rows[0].result };
    }

    async function cached(expected) {
      const result = await db.query(
        "select entitlements, active_until from public.monetization_entitlements_cache where user_id = $1",
        [userId],
      );
      assertQa(result.rowCount === 1, "Provider event did not create an entitlement cache row.");
      assertQa(
        JSON.stringify([...result.rows[0].entitlements].sort()) === JSON.stringify([...expected].sort()),
        `Unexpected cached entitlements for ${scope}.`,
      );
      return result.rows[0];
    }

    const until = new Date(baseTime + 24 * 60 * 60 * 1000);
    const plus = await event("initial_purchase", "mort_plus_monthly", ["mort_plus"], until);
    assertQa(plus.result.ok && plus.result.state_changed, "Plus provider purchase did not activate.");
    await cached(["mort_plus", "mort_ad_free"]);
    qaLog(scope, "historical Plus SKU maps to Plus and ad-free in the server cache, never mort_pro");

    await event("cancellation", "mort_plus_monthly", ["mort_plus"], until);
    await cached(["mort_plus", "mort_ad_free"]);
    await event("billing_issue", "mort_plus_monthly", ["mort_plus"], until);
    await cached(["mort_plus", "mort_ad_free"]);
    qaLog(scope, "cancellation and billing issue retain access before paid-period expiration");

    const expired = await event("expiration", "mort_plus_monthly", ["mort_plus"]);
    assertQa(expired.result.state_changed, "Plus expiration did not change state.");
    await cached([]);
    const replay = await event("expiration", "mort_plus_monthly", ["mort_plus"], null, expired.id);
    assertQa(replay.result.code === "duplicate_event", "Exact provider event replay was not deduplicated.");
    const mismatch = await event("expiration", "mort_plus_monthly", ["mort_plus"], null, expired.id, "b".repeat(64));
    assertQa(mismatch.result.code === "duplicate_payload_mismatch", "Changed replay payload was accepted.");
    qaLog(scope, "expiration removes Plus and event replay is payload-bound");

    const scheduledChange = await event("product_change", "mort_plus_monthly", ["mort_plus"], until);
    assertQa(scheduledChange.result.state_changed === false,
      "PRODUCT_CHANGE reactivated the old product before a new purchase or renewal.");
    await cached([]);
    qaLog(scope, "deferred PRODUCT_CHANGE is informational and cannot resurrect expired access");

    const syntheticPlusProduct = "qa_distinct_plus_monthly";
    const syntheticApp = "qa_play_app";
    const playMetadata = { appId: syntheticApp, store: "PLAY_STORE" };
    async function rejectedPlus(metadata) {
      await db.query("savepoint unapproved_plus");
      let rejected = false;
      try {
        await event("initial_purchase", syntheticPlusProduct, ["mort_plus"], until,
          null, "a".repeat(64), metadata);
      } catch (error) {
        rejected = error.code === "22023";
      } finally {
        await db.query("rollback to savepoint unapproved_plus");
        await db.query("release savepoint unapproved_plus");
      }
      assertQa(rejected, "Unapproved or mismatched Plus product was accepted.");
    }
    await rejectedPlus(playMetadata);
    await db.query(
      `insert into private.revenuecat_plus_products
       (product_id, revenuecat_app_id, billing_period)
       values ($1, $2, 'monthly')`,
      [syntheticPlusProduct, syntheticApp],
    );
    await rejectedPlus(playMetadata);
    await db.query(
      `update private.revenuecat_plus_products
       set enabled = true, approved_at = now()
       where product_id = $1`,
      [syntheticPlusProduct],
    );
    await rejectedPlus({ appId: "another_app", store: "PLAY_STORE" });
    await rejectedPlus({ appId: syntheticApp, store: "APP_STORE" });
    const distinctPlus = await event("initial_purchase", syntheticPlusProduct,
      ["mort_plus"], until, null, "a".repeat(64), playMetadata);
    assertQa(distinctPlus.result.state_changed, "Approved distinct Plus product did not activate.");
    await cached(["mort_plus"]);
    await event("expiration", syntheticPlusProduct, ["mort_plus"], null,
      null, "a".repeat(64), playMetadata);
    await cached([]);
    qaLog(scope, "private Plus map is empty by default and requires exact approved Play app/product binding; Plus never grants Pro");

    await event("initial_purchase", "mort_pro:monthly", ["mort_pro"], until);
    await cached(["mort_pro"]);
    await event("non_renewing_purchase", "lifetime", ["mort_pro"]);
    const lifetime = await cached(["mort_pro"]);
    assertQa(lifetime.active_until === null, "Lifetime access acquired a finite expiration.");
    await event("expiration", "mort_pro:monthly", ["mort_pro"]);
    await cached(["mort_pro"]);
    await event("revocation", "lifetime", ["mort_pro"]);
    await cached([]);
    qaLog(scope, "Pro lifetime survives monthly expiration and revocation removes final access");

    const grants = await db.query(
      `select has_function_privilege('authenticated',
        'public.process_revenuecat_provider_event(text,uuid,text,text,text[],timestamptz,timestamptz,text,jsonb)',
        'EXECUTE') as authenticated_can_execute`,
    );
    assertQa(grants.rows[0].authenticated_can_execute === false,
      "Authenticated clients can invoke the provider-only entitlement writer.");
    const productMapGrants = await db.query(
      `select has_table_privilege('authenticated',
        'private.revenuecat_plus_products', 'SELECT') as can_read,
        has_table_privilege('authenticated',
        'private.revenuecat_plus_products', 'INSERT') as can_insert`,
    );
    assertQa(!productMapGrants.rows[0].can_read && !productMapGrants.rows[0].can_insert,
      "Authenticated clients can access the private Plus catalog map.");
    qaLog(scope, "authenticated clients cannot invoke the RevenueCat provider writer");
  } finally {
    await db.query("rollback");
  }
});

qaLog(scope, "synthetic lifecycle evidence rolled back; no local account or entitlement was granted");
