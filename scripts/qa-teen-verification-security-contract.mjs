import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const read = (path) => readFileSync(resolve(root, path), "utf8");

const foundation = read(
  "supabase/migrations/20260920180350_mort_verify_age_school_foundation.sql",
);
const review = read(
  "supabase/migrations/20260920180910_mort_verify_review_access_hardening.sql",
);
const retention = read(
  "supabase/migrations/20260920181521_mort_verify_retention_cleanup.sql",
);
const binding = read(
  "supabase/migrations/20260920181647_mort_verify_storage_helper_binding.sql",
);
const worker = read(
  "supabase/functions/teen-verification-retention-processor/index.ts",
);
const releaseProfiles = JSON.parse(read("config/mort-release-profiles.json"));

assert.match(foundation, /mode text not null default 'sandbox'/);
assert.match(foundation, /production_enabled boolean not null default false/);
assert.match(foundation, /legal_approved boolean not null default false/);
assert.match(foundation, /privacy_approved boolean not null default false/);
assert.match(foundation, /trained_reviewers_ready boolean not null default false/);
assert.match(foundation, /bucket_id = 'teen-school-id'/);
assert.match(foundation, /public,s*8388608,s*array\['image\/jpeg'\]/s);
assert.match(foundation, /p_school_id_dob_present/);
assert.match(foundation, /p_observed_age_band not in \('13_15','16_17'\)/);
assert.match(foundation, /p_observed_age_band <> v_session\.age_band/);
assert.match(foundation, /verified_school_email_required/);
assert.match(foundation, /school_id_review_not_passed/);

assert.match(review, /active_school_id_access_grant_required/);
assert.match(review, /active_teen_verification_assignment_required/);

assert.match(binding, /auth\.uid\(\) = p_user_id/);
assert.match(binding, /auth\.uid\(\) = p_reviewer_id/);
assert.match(binding, /has_trust_admin_role/);

assert.match(retention, /auth\.role\(\) <> 'service_role'/);
assert.match(retention, /preserved_until/);
assert.match(retention, /service_finalize_teen_school_id_purge/);

assert.match(worker, /SUPABASE_SERVICE_ROLE_KEY/);
assert.match(worker, /constantTimeEqual/);
assert.match(worker, /service_list_expired_teen_school_id_objects/);
assert.match(worker, /service_finalize_teen_school_id_purge/);

for (const profileName of ["closed_test", "reviewer_demo"]) {
  const profile = releaseProfiles.profiles[profileName];
  assert.equal(profile.identityVerificationEnabled, false);
  assert.equal(profile.publicMarketplaceEnabled, false);
  assert.equal(profile.marketplacePaymentsEnabled, false);
}

console.log(
  "PASS: MORT Verify stays fail-closed, caller-bound, reviewer-gated, and retention-backed.",
);
