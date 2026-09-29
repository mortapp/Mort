import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const read = (path) => readFileSync(resolve(root, path), "utf8");

const legacyFoundation = read(
  "supabase/migrations/20260920180350_mort_verify_age_school_foundation.sql",
);
const legacyReview = read(
  "supabase/migrations/20260920180910_mort_verify_review_access_hardening.sql",
);
const legacyRetention = read(
  "supabase/migrations/20260920181521_mort_verify_retention_cleanup.sql",
);
const legacyBinding = read(
  "supabase/migrations/20260920181647_mort_verify_storage_helper_binding.sql",
);
const canonical = read(
  "supabase/migrations/20260920201000_mort_verify_first_party_age_school_v1.sql",
);
const canonicalStorage = read(
  "supabase/migrations/20260920203500_mort_verify_storage_policy_hardening_v1.sql",
);
const canonicalEmail = read(
  "supabase/migrations/20260920205000_mort_verify_email_challenge_hardening_v1.sql",
);
const canonicalHardening = read(
  "supabase/migrations/20260920214100_mort_verify_canonical_hardening_v2.sql",
);
const retentionReviewHardening = read(
  "supabase/migrations/20260920214728_mort_verify_retention_and_review_hardening_v3.sql",
);
const edge = read("supabase/functions/mort-verify/index.ts");
const retentionWorker = read(
  "supabase/functions/teen-verification-retention-processor/index.ts",
);
const repository = read(
  "flutter_mort/lib/data/repositories/mort_verify_repository.dart",
);
const releaseProfiles = JSON.parse(read("config/mort-release-profiles.json"));

assert.match(legacyFoundation, /bucket_id = 'teen-school-id'/);
assert.match(legacyReview, /active_school_id_access_grant_required/);
assert.match(legacyBinding, /auth\.uid\(\) = p_user_id/);
assert.match(legacyBinding, /auth\.uid\(\) = p_reviewer_id/);
assert.match(legacyRetention, /preserved_until/);
assert.match(retentionWorker, /SUPABASE_SERVICE_ROLE_KEY/);
assert.match(retentionWorker, /constantTimeEqual/);

assert.match(canonical, /mode text not null default 'disabled'/);
assert.match(
  canonical,
  /production_document_collection_approved boolean not null default false/,
);
assert.match(canonical, /bucket_id = 'mort-verify-evidence'/);
assert.match(canonical, /school_domain_not_approved/);
assert.match(canonical, /legal_identity_claimed', false/);
assert.match(canonicalStorage, /mort_verify_storage_upload_allowed/);
assert.match(canonicalStorage, /session\.user_id = v_user_id/);
assert.match(canonicalEmail, /service_mort_verify_verify_email_code/);
assert.match(canonicalEmail, /from public, anon, authenticated/);

assert.match(canonicalHardening, /set mode = 'disabled'/);
assert.match(canonicalHardening, /drop policy if exists teen_school_id_insert_own/);
assert.match(
  canonicalHardening,
  /revoke execute on function public\.start_my_teen_verification\(\) from authenticated, service_role/,
);
assert.match(canonicalHardening, /has_admin_safety_role/);
assert.match(canonicalHardening, /verification_reviewer_required/);
assert.doesNotMatch(canonicalHardening, /auth\.role\(\)/);
assert.match(canonicalHardening, /auth\.jwt\(\)->>'role'/);

assert.match(
  retentionReviewHardening,
  /service_list_expired_mort_verify_documents/,
);
assert.match(
  retentionReviewHardening,
  /service_finalize_mort_verify_document_purge/,
);
assert.match(
  retentionReviewHardening,
  /senior_review_required_for_age_exception/,
);
assert.match(retentionReviewHardening, /school_id_front_required/);
assert.match(retentionReviewHardening, /review_result='accepted'/);

assert.match(edge, /\| "start"/);
assert.match(edge, /resend_code/);
assert.match(edge, /verify_email/);
assert.match(edge, /challengeDigest/);
assert.match(edge, /HMAC/);
assert.match(edge, /detectContentType/);
assert.match(edge, /document_extension_mismatch/);
assert.match(edge, /createSignedUrl\(document\.storage_path, 300\)/);

assert.match(repository, /'mort-verify'/);
assert.match(repository, /'verify_email'/);
assert.match(repository, /'resend_code'/);
assert.match(repository, /'finalize_document'/);
assert.match(repository, /'mort-verify-evidence'/);

for (const profileName of ["closed_test", "reviewer_demo"]) {
  const profile = releaseProfiles.profiles[profileName];
  assert.equal(profile.identityVerificationEnabled, false);
  assert.equal(profile.publicMarketplaceEnabled, false);
  assert.equal(profile.marketplacePaymentsEnabled, false);
}

console.log(
  "PASS: canonical MORT Verify is fail-closed; legacy client access is retired; reviewer access is live-role checked; canonical and legacy retention stay service-only; age exceptions require senior review.",
);
