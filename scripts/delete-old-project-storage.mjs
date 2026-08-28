import { createClient } from "@supabase/supabase-js";

const allowedTarget = "old-project-rebuild";
const oldProjectUrl = "https://rakjydmgwwgtdislanbt.supabase.co";
const bucketsToDelete = ["profile-avatars"];

function fail(message) {
  console.error(`delete-old-project-storage failed: ${message}`);
  process.exit(1);
}

function log(message) {
  console.log(`[delete-old-project-storage] ${message}`);
}

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (process.env.MORT_QA_TARGET !== allowedTarget) {
  fail(`Set MORT_QA_TARGET=${allowedTarget}.`);
}

if (process.env.MORT_REUSE_OLD_PROJECT_REF !== "rakjydmgwwgtdislanbt") {
  fail("MORT_REUSE_OLD_PROJECT_REF must be rakjydmgwwgtdislanbt.");
}

if (supabaseUrl !== oldProjectUrl) {
  fail(`EXPO_PUBLIC_SUPABASE_URL must be ${oldProjectUrl}.`);
}

if (!serviceRoleKey) {
  fail("Set SUPABASE_SERVICE_ROLE_KEY from the current rotated old-project key.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});

const { data: buckets, error: listError } = await supabase.storage.listBuckets();
if (listError) fail(`Could not list buckets: ${listError.message}`);

for (const bucketName of bucketsToDelete) {
  const bucket = buckets.find((item) => item.name === bucketName || item.id === bucketName);
  if (!bucket) {
    log(`Bucket already absent: ${bucketName}`);
    continue;
  }

  const { error: emptyError } = await supabase.storage.emptyBucket(bucketName);
  if (emptyError) {
    fail(`Could not empty bucket ${bucketName}: ${emptyError.message}`);
  }

  const { error: deleteError } = await supabase.storage.deleteBucket(bucketName);
  if (deleteError) {
    fail(`Could not delete bucket ${bucketName}: ${deleteError.message}`);
  }

  log(`Deleted old bucket: ${bucketName}`);
}
