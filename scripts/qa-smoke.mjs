import { createClient } from "@supabase/supabase-js";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const requiredTables = [
  "profiles",
  "teen_profiles",
  "adult_profiles",
  "guardian_profiles",
  "guardian_connections",
  "jobs",
  "applications",
  "message_threads",
  "messages",
  "reports",
  "blocks",
  "payment_preferences",
  "push_tokens",
  "business_verifications",
  "proof_uploads",
  "safety_pings",
  "notifications",
  "notification_events",
  "support_tickets",
  "admin_action_logs"
];

const requiredBuckets = ["proof-uploads", "verification-uploads", "report-uploads"];
const currentMismatchedLiveRef = "rakjydmgwwgtdislanbt";
const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const mobileSourceRoots = ["app", "components", "lib", "providers"];
const forbiddenMobileSecretPatterns = [/service_role/i, /SUPABASE_SERVICE_ROLE_KEY/];

function fail(message) {
  console.error(`QA smoke failed: ${message}`);
  process.exit(1);
}

function log(message) {
  console.log(`[qa-smoke] ${message}`);
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

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
const target = process.env.MORT_QA_TARGET;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const allowServiceRole = process.env.MORT_QA_ALLOW_SERVICE_ROLE === "LOCAL_OR_STAGING_ONLY";

if (!supabaseUrl || !anonKey) {
  fail("Set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY.");
}

if (!["local", "staging"].includes(target ?? "")) {
  fail("Set MORT_QA_TARGET=local or MORT_QA_TARGET=staging. Do not run this against the mismatched live project.");
}

const url = new URL(supabaseUrl);
if (target === "local" && !["localhost", "127.0.0.1"].includes(url.hostname)) {
  fail("MORT_QA_TARGET=local requires a localhost or 127.0.0.1 Supabase URL.");
}

if (url.hostname.includes(currentMismatchedLiveRef)) {
  fail("This points at the current mismatched live Supabase project. Use local Supabase or a fresh staging project for QA.");
}
log("Mismatched live project guard OK.");

const sendPushFile = join(repoRoot, "supabase", "functions", "send-push", "index.ts");
if (!existsSync(sendPushFile)) {
  fail("Missing Supabase Edge Function file: supabase/functions/send-push/index.ts");
}
log("send-push Edge Function file OK.");

for (const sourceRoot of mobileSourceRoots) {
  for (const filePath of listFiles(join(repoRoot, sourceRoot))) {
    if (!/\.(ts|tsx|js|jsx)$/.test(filePath)) continue;
    const contents = readFileSync(filePath, "utf8");
    const matched = forbiddenMobileSecretPatterns.find((pattern) => pattern.test(contents));
    if (matched) {
      fail(`Forbidden service-role reference in mobile source: ${filePath}`);
    }
  }
}
log("No service-role references in Expo/mobile source.");

const anon = createClient(supabaseUrl, anonKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});

log(`Target ${target}: ${url.origin}`);
const sessionResult = await anon.auth.getSession();
if (sessionResult.error) {
  fail(`Anon client auth check failed: ${sessionResult.error.message}`);
}
log("Anon client initialized.");

if (!serviceRoleKey) {
  log("SUPABASE_SERVICE_ROLE_KEY not set. Skipping schema/bucket read checks.");
  log("For local/staging schema checks only, set SUPABASE_SERVICE_ROLE_KEY and MORT_QA_ALLOW_SERVICE_ROLE=LOCAL_OR_STAGING_ONLY.");
  process.exit(0);
}

if (!allowServiceRole) {
  fail("SUPABASE_SERVICE_ROLE_KEY is set, but MORT_QA_ALLOW_SERVICE_ROLE is not LOCAL_OR_STAGING_ONLY.");
}

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});

for (const table of requiredTables) {
  const { error } = await admin.from(table).select("*", { count: "exact", head: true });
  if (error) {
    fail(`Table check failed for ${table}: ${error.message}`);
  }
  log(`Table OK: ${table}`);
}

const { data: buckets, error: bucketError } = await admin.storage.listBuckets();
if (bucketError) {
  fail(`Bucket list failed: ${bucketError.message}`);
}

for (const bucketName of requiredBuckets) {
  const bucket = buckets.find((item) => item.name === bucketName);
  if (!bucket) {
    fail(`Missing bucket: ${bucketName}`);
  }
  if (bucket.public) {
    fail(`Bucket must be private but is public: ${bucketName}`);
  }
  log(`Private bucket OK: ${bucketName}`);
}

log("Local/staging schema smoke passed.");
