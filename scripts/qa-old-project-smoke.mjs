import { createClient } from "@supabase/supabase-js";
import pg from "pg";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const oldProjectRef = "rakjydmgwwgtdislanbt";
const oldProjectUrl = `https://${oldProjectRef}.supabase.co`;
const requiredTables = [
  "admin_action_logs",
  "adult_profiles",
  "applications",
  "blocks",
  "business_verifications",
  "conversation_participants",
  "conversations",
  "guardian_connections",
  "guardian_profiles",
  "jobs",
  "message_threads",
  "messages",
  "notification_events",
  "notifications",
  "payment_preferences",
  "payment_disputes",
  "profiles",
  "proof_uploads",
  "push_tokens",
  "reports",
  "safety_pings",
  "support_ticket_messages",
  "support_tickets",
  "teen_profiles",
  "monetization_entitlements_cache",
  "revenuecat_events",
  "user_subscription_status",
  "ad_impressions",
  "ad_click_events",
  "ad_frequency_caps",
  "user_ad_preferences",
  "purchase_audit_logs",
  "premium_feature_usage",
  "boosted_jobs",
  "job_boost_credits",
  "boost_impressions",
  "monetization_experiments",
  "paywall_events",
  "username_change_events",
  "username_change_credits",
  "username_reservations",
  "username_moderation_flags",
  "profile_theme_unlocks",
  "user_profile_theme_settings",
  "user_saved_job_folders",
  "saved_job_folder_items",
  "guardian_preferences",
  "jurisdiction_guardian_policies",
  "saved_jobs",
  "job_templates",
  "job_status_events",
  "application_status_events",
  "reviews",
  "admin_role_assignments",
  "identity_verifications",
  "identity_verification_evidence",
  "identity_verification_appeals",
  "verification_evidence_access_grants",
  "verification_audit_events",
  "safety_incidents",
  "incident_participants",
  "incident_evidence",
  "incident_preservation_orders",
  "incident_law_enforcement_requests",
  "safety_circle_members",
  "job_safety_plans",
  "job_safety_agreements",
  "job_private_locations",
  "job_location_share_sessions",
  "job_arrival_handshakes",
  "job_checkins",
  "safety_cancellations",
  "message_safety_evidence",
  "account_security_events",
];
const requiredBuckets = [
  "proof-uploads",
  "verification-uploads",
  "report-uploads",
  "profile-avatars",
  "identity-evidence",
  "incident-evidence",
];
const forbiddenOldTables = [
  "active_jobs",
  "ad_reward_events",
  "ad_settings",
  "job_applications",
  "job_drafts",
  "job_proofs",
  "payment_records",
  "rewarded_ad_events",
  "safety_reports",
  "tracked_earnings_events",
  "trusted_circle_contacts",
  "verification_requests"
];
const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const mobileSourceRoots = ["app", "components", "lib", "providers", "flutter_mort/lib"];
const forbiddenMobileSecretPatterns = [/service_role/i, /SUPABASE_SERVICE_ROLE_KEY/];

function fail(message) {
  console.error(`Old-project smoke failed: ${message}`);
  process.exit(1);
}

function log(message) {
  console.log(`[qa-old-project-smoke] ${message}`);
}

function listFiles(root) {
  if (!existsSync(root)) return [];
  const entries = readdirSync(root);
  return entries.flatMap((entry) => {
    const fullPath = join(root, entry);
    const stats = statSync(fullPath);
    if (stats.isDirectory()) return listFiles(fullPath);
    return [fullPath];
  });
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value) fail(`Set ${name}.`);
  return value;
}

const supabaseUrl = requireEnv("EXPO_PUBLIC_SUPABASE_URL");
const anonKey = requireEnv("EXPO_PUBLIC_SUPABASE_ANON_KEY");
const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const dbPassword = requireEnv("SUPABASE_DB_PASSWORD");
const invokeSecret = requireEnv("SEND_PUSH_INVOKE_SECRET");

if (process.env.MORT_QA_TARGET !== "old-project-rebuild") fail("Set MORT_QA_TARGET=old-project-rebuild.");
if (process.env.MORT_REUSE_OLD_PROJECT_REF !== oldProjectRef) fail(`Set MORT_REUSE_OLD_PROJECT_REF=${oldProjectRef}.`);
if (supabaseUrl !== oldProjectUrl) fail(`EXPO_PUBLIC_SUPABASE_URL must be ${oldProjectUrl}.`);
if (process.env.MORT_QA_ALLOW_SERVICE_ROLE !== "LOCAL_OR_STAGING_ONLY") {
  fail("Set MORT_QA_ALLOW_SERVICE_ROLE=LOCAL_OR_STAGING_ONLY for this intentionally authorized rebuild QA.");
}

const envLocalPath = join(repoRoot, ".env.local");
if (!existsSync(envLocalPath)) fail("Missing .env.local.");
const envLocal = readFileSync(envLocalPath, "utf8");
if (envLocal.includes("SUPABASE_SERVICE_ROLE_KEY")) fail(".env.local contains SUPABASE_SERVICE_ROLE_KEY.");
const envLocalKeys = envLocal
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean)
  .map((line) => line.split("=", 1)[0])
  .sort();
const expectedEnvLocalKeys = ["EXPO_PUBLIC_APP_ENV", "EXPO_PUBLIC_SUPABASE_ANON_KEY", "EXPO_PUBLIC_SUPABASE_URL"];
if (JSON.stringify(envLocalKeys) !== JSON.stringify(expectedEnvLocalKeys)) {
  fail(`.env.local keys must be ${expectedEnvLocalKeys.join(",")}; got ${envLocalKeys.join(",")}.`);
}
log(".env.local contains only Expo public values.");

const url = new URL(supabaseUrl);
if (url.hostname !== `${oldProjectRef}.supabase.co`) fail(`Unexpected Supabase host: ${url.hostname}`);
log(`Target old project: ${url.origin}`);

const sendPushFile = join(repoRoot, "supabase", "functions", "send-push", "index.ts");
if (!existsSync(sendPushFile)) fail("Missing Supabase Edge Function file: supabase/functions/send-push/index.ts");
log("send-push Edge Function file OK.");

for (const sourceRoot of mobileSourceRoots) {
  for (const filePath of listFiles(join(repoRoot, sourceRoot))) {
    if (!/\.(ts|tsx|js|jsx)$/.test(filePath)) continue;
    const contents = readFileSync(filePath, "utf8");
    const matched = forbiddenMobileSecretPatterns.find((pattern) => pattern.test(contents));
    if (matched) fail(`Forbidden service-role reference in mobile source: ${filePath}`);
  }
}
log("No service-role references in Expo/mobile source.");

const anon = createClient(supabaseUrl, anonKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});
const sessionResult = await anon.auth.getSession();
if (sessionResult.error) fail(`Anon client auth check failed: ${sessionResult.error.message}`);
log("Anon client initialized.");

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});

for (const table of requiredTables) {
  const { error } = await admin.from(table).select("*", { count: "exact", head: true });
  if (error) fail(`Table check failed for ${table}: ${error.message}`);
  log(`Table OK: ${table}`);
}

const { data: buckets, error: bucketError } = await admin.storage.listBuckets();
if (bucketError) fail(`Bucket list failed: ${bucketError.message}`);

for (const bucketName of requiredBuckets) {
  const bucket = buckets.find((item) => item.name === bucketName);
  if (!bucket) fail(`Missing bucket: ${bucketName}`);
  if (bucket.public) fail(`Bucket must be private but is public: ${bucketName}`);
  log(`Private bucket OK: ${bucketName}`);
}

const avatarBucket = buckets.find((bucket) => bucket.name === "profile-avatars");
if (!avatarBucket || avatarBucket.public) fail("profile-avatars must exist and remain private.");
if (Number(avatarBucket.file_size_limit) !== 5 * 1024 * 1024) {
  fail("profile-avatars must enforce a 5 MB object limit.");
}
log("Private profile avatar bucket configuration OK.");

const pgClient = new pg.Client({
  host: `db.${oldProjectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password: dbPassword,
  ssl: { rejectUnauthorized: false }
});
await pgClient.connect();
try {
  const state = await pgClient.query(
    `
      with public_tables as (
        select count(*)::int as count from pg_tables where schemaname = 'public'
      ), rls_tables as (
        select count(*)::int as count
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
      ), public_functions as (
        select count(*)::int as count
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
      ), public_triggers as (
        select count(*)::int as count
        from pg_trigger t
        join pg_class c on c.oid = t.tgrelid
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and not t.tgisinternal
      ), storage_policies as (
        select count(*)::int as count from pg_policies where schemaname = 'storage'
      ), migrations as (
        select coalesce(jsonb_agg(jsonb_build_object('version', version, 'name', name) order by version), '[]'::jsonb) as rows
        from supabase_migrations.schema_migrations
      ), old_tables as (
        select coalesce(jsonb_agg(tablename order by tablename), '[]'::jsonb) as rows
        from pg_tables
        where schemaname = 'public' and tablename = any($1::text[])
      )
      select jsonb_build_object(
        'publicTables', (select count from public_tables),
        'rlsTables', (select count from rls_tables),
        'publicFunctions', (select count from public_functions),
        'publicTriggers', (select count from public_triggers),
        'storagePolicies', (select count from storage_policies),
        'migrations', (select rows from migrations),
        'oldTablesRemaining', (select rows from old_tables)
      ) as state;
    `,
    [forbiddenOldTables]
  );
  const remote = state.rows[0].state;
  const minimums = {
    publicTables: 62,
    rlsTables: 62,
    publicFunctions: 60,
    publicTriggers: 45,
    storagePolicies: 7
  };
  for (const [key, value] of Object.entries(minimums)) {
    if (remote[key] < value) fail(`${key} expected at least ${value}, got ${remote[key]}.`);
  }
  if (remote.oldTablesRemaining.length !== 0) fail(`Old tables remain: ${remote.oldTablesRemaining.join(",")}`);
  const migrationVersions = new Set(remote.migrations.map((migration) => migration.version));
  const requiredMigrationVersions = [
    "202607070001",
    "20260711170257",
    "20260711170513",
    "20260713120000",
    "20260713123000",
    "20260713124500",
    "20260713130000",
    "20260713130500",
    "20260713131000",
    "20260713131500",
    "20260713132000",
    "20260713132500",
    "20260713133000",
    "20260713133500",
    "20260713134000",
    "20260713134500",
    "20260713135000",
    "20260713135500",
    "20260713140000",
    "20260713140500",
    "20260717161125",
    "20260717161132",
    "20260717193747",
    "20260718024657",
    "20260718024844",
    "20260718030325",
  ];
  for (const version of requiredMigrationVersions) {
    if (!migrationVersions.has(version)) fail(`Required migration ${version} is missing.`);
  }
  log("Remote schema minimums and required migration history OK.");
} finally {
  await pgClient.end();
}

async function invokeSendPush(headers) {
  const response = await fetch(`${oldProjectUrl}/functions/v1/send-push`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${anonKey}`,
      apikey: anonKey,
      "Content-Type": "application/json",
      ...headers
    },
    body: JSON.stringify({ batchSize: 1 })
  });
  const body = await response.json().catch(() => ({}));
  return { status: response.status, body };
}

const unauthorized = await invokeSendPush({});
if (unauthorized.status !== 401) fail(`send-push missing-secret check expected 401, got ${unauthorized.status}.`);
log("send-push unauthorized check returned 401.");

const authorized = await invokeSendPush({ "x-mort-push-secret": invokeSecret });
if (authorized.status !== 200 || authorized.body?.ok !== true) {
  fail(`send-push authorized check failed with ${authorized.status}: ${JSON.stringify(authorized.body)}`);
}
log(`send-push authorized queue check returned 200 with processed=${authorized.body.processed}.`);

log("Old-project remote smoke passed.");
