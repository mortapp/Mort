# MORT Stage 1 Continuation — 2026-08-28 (power-loss recovery)

## Git state

```
START_HEAD=d320542e380abd1262b9d6c5d3514f842dcb99e7
CURRENT_HEAD=ea9f64bb8e329bd8d617aef3871bc2e7a75f573b
ORIGIN_MAIN=8bdec7b9632b4753ed6cb49c6c184cd0dc9dafa1
WORKTREE_RECOVERED=CLEAN (nothing lost -- working tree was already committed and pushed when this session started)
POWER_LOSS_RECOVERY=NO_UNCOMMITTED_WORK_LOST
PR=https://github.com/mortapp/Mort/pull/3 (OPEN, mergeable, CI green; not merged -- left for explicit merge decision)
```

Commits made this session (on top of START_HEAD, all pushed):

- `e98e901` fix(qa): repair local Supabase replay and RLS/onboarding QA test gaps
- `ea9f64b` fix(ci): resolve expo-reference build and flutter analyze failures

## Compatibility migration

```
COMPAT_MIGRATION_PRESENT=YES (supabase/migrations/20260828111951_onboarding_v2_legacy_completion_compatibility.sql)
COMPAT_MIGRATION_HOSTED=ALREADY_APPLIED (verified via mcp list_migrations AND `supabase migration list --linked`; local/remote match on every version; NOT reapplied)
COMPAT_QA=PASS (qa:onboarding-v2:legacy-compat, hosted; population = 24 total / 17 test / 7 non-test / 0 duplicates / 0 bad source_version, matching known preflight exactly)
```

The originally-reported test-harness bug (node-postgres extended-query-protocol rejecting a multi-command parameterized string) was already fixed before this session's recovery and is verified green. Everything else this session found was pre-existing and unrelated to the compatibility migration itself.

## Backend verification matrix

```
MIGRATION_PARITY=PASS (qa:migration-reconciliation-parity, hosted)
RLS=PASS (qa-rls.mjs, local -- see fixes below)
HOSTILE_CLIENT=COVERED (direct-completion UPDATE/UPSERT bypass denial, authenticated INSERT/UPDATE/DELETE denial on the compatibility table -- all exercised inside qa:onboarding-v2:legacy-compat and qa:onboarding-v2, hosted, PASS)
CONCURRENCY=PASS (two concurrent complete_my_onboarding_v2() calls in qa:onboarding-v2 both fail closed identically on the external legal-policy gate -- no race/partial-completion)
IDEMPOTENCY=PASS (client_request_id replay verified safe in qa:onboarding-v2, hosted)
FRESH_REPLAY=PASS (fresh `supabase db reset`, all 194 local migrations, after fixing two pre-existing local-replay defects -- see below)
ADVISORS=PASS (no ERROR-level findings; 300 security WARN + 5 performance WARN are pre-existing/unrelated; the compatibility table's own rls_enabled_no_policy is INFO-level and matches its documented lockout-by-design)
```

### Pre-existing gaps found and fixed while running the matrix for the first time end-to-end (none related to today's onboarding work)

1. **`20260812010000_support_ai_hardening_followup.sql` was silently truncated** since it was first committed (`4bbe16a`, 2026-08-17): the file ended mid-function with an unclosed dollar-quoted string, missing the back half of `support_begin_chat` plus two entire functions (`support_classify_message_internal`, `support_provider_circuit_status`/`support_record_provider_failure`). This never affected production -- hosted already had the correct, complete functions. Reconstructed the file from `pg_get_functiondef` against the live database so local replay matches hosted exactly.
2. **`20260730203047_fix_identity_storage_policy_execution.sql`'s `COMMENT ON POLICY`** requires literal ownership of `storage.objects`, which hosted grants but the local Supabase CLI's Postgres image does not. Wrapped the comment in an exception-tolerant `DO` block (metadata-only, zero behavior change) so `supabase db reset` completes locally.
3. **`qa-rls.mjs` asserted a guardian could read a supervised teen's message thread content** -- `messaging_lifecycle_privacy_and_reliability` (2026-07-30) deliberately removed that for teen privacy. Updated the assertion to match the documented design, and added `assertDenied()` to accept `business_verifications`' hard GRANT-layer denial (SELECT-only for `authenticated`) alongside RLS-only denials.
4. **`create-local-test-users.mjs` never set `is_test_account`** or seeded sandbox `identity_verifications`/`admin_role_assignments` rows, so `has_marketplace_identity()` and `has_admin_safety_role()` always failed closed under the current trust-policy model. Added both.
5. **Retired** `qa-onboarding-v2-legacy-compatibility-transaction.mjs` and `qa-four-step-onboarding-v2-transaction.mjs`: both dry-run their migration's raw SQL in a rolled-back transaction to rehearse it before deployment. Both migrations are now permanently applied to hosted, so replaying their `CREATE TABLE` statements always fails with "already exists" in any environment that already has the migration (including a fresh Supabase branch). Left in the repo with a banner explaining retirement; excluded from the ongoing matrix.

## CI

```
EXPO_REFERENCE=PASS
FLUTTER_AUTHORITATIVE=PASS
PUBLIC_SITE=PASS
NODE_ACTION_WARNINGS=RESOLVED (actions/checkout, actions/setup-node bumped to v7; pnpm/action-setup to v6; actions/upload-artifact to v7, across all three workflow files)
```

Real root causes (pulled from PR #3's actual job logs, not guessed):

- **expo-reference / `pnpm build`**: `expo export --platform web` throws `supabaseUrl is required` -- `createClient()` runs during static rendering with no `EXPO_PUBLIC_SUPABASE_URL` set in CI. Reference-only build, no real Supabase call at build time; added a syntactically valid, non-secret placeholder env for that one step.
- **flutter-authoritative / `flutter analyze`**: `CupertinoPageTransitionsBuilder` is not defined -- not transitively visible through `package:flutter/material.dart` on Flutter 3.47.2 (the version pinned in the immediately-prior commit to stop channel drift). Added an explicit `import 'package:flutter/cupertino.dart';` in `mort_page_transitions.dart`, where the class is actually defined.

## Flutter

```
FLUTTER_ANALYZE=PASS (0 issues, local run on Flutter 3.47.2 -- upgraded locally from 3.41.2 to match the CI pin exactly)
FLUTTER_TESTS=PASS (424 passed, 2 skipped, 0 failed -- `flutter test --no-pub`)
```

`flutter pub get` and `dart format --set-exit-if-changed` both clean.

## QA APK

```
SIGNED_QA_APK=BLOCKED_MISSING_RELEASE_SIGNING_SECRETS
GITHUB_ENVIRONMENT=closed-test-release
MISSING_SECRET_CONFIGURATION=
  - MORT_UPLOAD_KEYSTORE_BASE64
  - MORT_UPLOAD_KEY_ALIAS
  - MORT_UPLOAD_STORE_PASSWORD
  - MORT_UPLOAD_KEY_PASSWORD
  - SUPABASE_ANON_KEY (repo secret), SUPABASE_URL (repo/environment variable) -- present or absent status not checked further once the keystore step failed first
```

The `MORT Signed Closed Test` workflow (`workflow_dispatch`) exists and is correctly built (see `scripts/build-standard-closed-test-apk.ps1` / `android-release-profile-common.ps1`, which actively guard against `SERVICE_ROLE`/`ACCESS_TOKEN`/`PASSWORD`/`CLIENT_SECRET`/`PRIVATE_KEY`/`WEBHOOK_SECRET`-shaped dart-define keys and values, and verify the release Supabase project/redirect URL and upload-certificate identity before building). Dispatching it revealed that its target GitHub Environment, `closed-test-release`, was auto-created by this run (timestamp: `2026-08-29T00:24:31Z`) with zero secrets and no protection rules -- it was never actually provisioned. This is an external, credentials-only gap; no workaround was attempted (no substitute keystore generated, no secrets fabricated, no distribution-mechanism change).

```
EXTERNAL_OWNER_ACTION: Provision the EXISTING legitimate MORT Play upload signing credentials into the GitHub `closed-test-release` environment (MORT_UPLOAD_KEYSTORE_BASE64, MORT_UPLOAD_KEY_ALIAS, MORT_UPLOAD_STORE_PASSWORD, MORT_UPLOAD_KEY_PASSWORD, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY secrets; SUPABASE_URL variable). Once set, re-dispatch "MORT Signed Closed Test" against the target commit.
```

### Debug/QA APK (local, unsigned-release-equivalent, built for physical device testing only)

```
QA_APK=build/app/outputs/flutter-apk/app-debug.apk (flutter_mort/, gitignored -- not committed, 188,927,790 bytes)
QA_APK_SHA256=2dc94b1f00acd6632c197dae0e90b833676b967e12ffee17928e8a0d12167168
RUNTIME_COMMIT=ea9f64bb8e329bd8d617aef3871bc2e7a75f573b
PACKAGE=com.mortapp.mobile (confirmed via aapt dump badging)
VERSION=0.9.16+107 (versionName 0.9.16, versionCode 107 -- matches flutter_mort/pubspec.yaml)
SUPABASE_PROJECT=rakjydmgwwgtdislanbt (--dart-define=SUPABASE_URL=https://rakjydmgwwgtdislanbt.supabase.co)
OAUTH_CALLBACK=com.mortapp.mobile://app/auth-callback (confirmed via aapt dump xmltree AndroidManifest.xml)
DEBUG_OR_QA_BUILD=true (aapt confirms `application-debuggable`)
SERVICE_ROLE_IN_APK=NO (extracted classes.dex + assets scanned; no match for the real SUPABASE_SERVICE_ROLE_KEY or SUPABASE_DB_PASSWORD values, and no "service_role" string anywhere)
GOOGLE_OAUTH_SECRET_IN_APK=NO (no client_secret string anywhere; no google-services.json present in this build at all -- Google Sign-In was built with GOOGLE_AUTH_ENABLED=false for this QA build)
SIGNING_SECRET_IN_APK=NO (no MORT_UPLOAD_KEY*/keystore strings anywhere)
16KB_COMPATIBILITY=NOT_CHECKED (only relevant to the release/AAB pipeline's page-size checks, not exercised for this debug build)
```

Built with: `flutter build apk --debug --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=MORT_SUPABASE_PROJECT_REF=rakjydmgwwgtdislanbt --dart-define=MORT_AUTH_REDIRECT_URL=com.mortapp.mobile://app/auth-callback --dart-define=MORT_RELEASE_STAGE=qa_debug --dart-define=MORT_OPERATIONAL_MODE=qa --dart-define=MORT_PUBLIC_MARKETPLACE_ENABLED=false --dart-define=MORT_MARKETPLACE_PAYMENTS_ENABLED=false --dart-define=IAP_ENABLED=false --dart-define=ADS_ENABLED=false --dart-define=USE_TEST_ADS=true --dart-define=PLAY_REVIEW_MODE_ENABLED=false --dart-define=GOOGLE_AUTH_ENABLED=false`

A debug/QA APK PASS does **not** replace signed-release-artifact certification (see `SIGNED_QA_APK` above).

## Physical Android QA

```
PHYSICAL_ANDROID=PENDING_DEVICE_AVAILABILITY
```

`adb devices -l` and `adb mdns services` (platform-tools at `C:\Users\micha\AppData\Local\Android\Sdk\platform-tools`) both returned empty on every check this session -- the Galaxy A14 was never reachable over Wireless ADB. No pass was fabricated. The verified debug/QA APK above (`QA_APK_SHA256=2dc94b1f00acd6632c197dae0e90b833676b967e12ffee17928e8a0d12167168`) is ready to install the moment the device is reachable; no legal-policy versions need to be published to exercise onboarding through the Review step.

## Legal / external blockers

```
LEGAL_POLICY_BLOCKER=UNPUBLISHED (HOSTED_V2_FINISH_BLOCKER=LEGAL_POLICY_PUBLICATION -- hosted complete_my_onboarding_v2() correctly fails closed with published_legal_acceptance_required; this is expected, not a bug; no fake acceptance or policy publication was attempted)
```

## Internal findings

```
INTERNAL_CRITICALS=0
INTERNAL_HIGHS=0
```

(The five items fixed above were all pre-existing local-tooling/test-harness gaps discovered by running the matrix end-to-end for the first time in a while; none affected hosted production behavior, and all are now fixed and green.)

## Next exact command

```
NEXT_EXACT_COMMAND=
1. Provision closed-test-release environment secrets (external, owner-only), then:
   gh workflow run "MORT Signed Closed Test" --ref feature/compact-onboarding-and-screen-polish
2. When the Galaxy A14 is reachable over Wireless ADB:
   adb connect <device-ip>:<port>
   adb install -r "C:\Users\micha\Mort\flutter_mort\build\app\outputs\flutter-apk\app-debug.apk"
   (then run the physical QA checklist: 4-step onboarding, garbage display name rejection,
   teen DOB/role, job categories, availability, transportation, Guardian skip, safety,
   notification truth, Review, returning-user routing, grandfathered-account routing,
   Back, background/resume, process restart, 100%/150% text, logcat)
3. Merge PR #3 (https://github.com/mortapp/Mort/pull/3) into main once reviewed --
   left open deliberately, not merged by this session.
```
