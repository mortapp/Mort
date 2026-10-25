# MORT External Release Gates

Each entry is a dependency this program cannot close without a human action or a
credential/account this session does not have and should not fabricate.

---

GATE=BrowserStack account/credentials
STATUS=RESOLVED_FOR_IOS_QA
WHY=Protected repository secrets were injected by GitHub Actions; the local shell correctly cannot read their values. Workflow run 34472297830 generated the BrowserStack app URL, uploaded the candidate, and completed the real-device matrix.
TECHNICAL_WORK_COMPLETE=YES — [GitHub Actions run 34472297830](https://github.com/mortapp/Mort/actions/runs/34472297830) passed macOS pub get, formatting, analyze,  full Flutter tests, CocoaPods, xcodebuild validation, unsigned iOS build/package, BrowserStack upload, and functional QA on iPhone 15/iOS 17, iPhone 17/iOS 26, and iPhone SE 2022/iOS 15. Evidence was uploaded by the workflow.
HUMAN_ACTION_REQUIRED=None for BrowserStack QA. App Store/TestFlight distribution still requires the separate Apple signing gate.
CREDENTIAL_REQUIRED=YES (BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY)
PROVIDER=BrowserStack
LAUNCH_IMPACT=No longer blocks iOS BrowserStack QA; real Android cloud QA remains outside the local emulator evidence
FAIL_CLOSED_BEHAVIOR=N/A (test infrastructure, not a production runtime gate)

---

GATE=Android upload/release signing keystore
STATUS=NOT_CONFIGURED (repo secrets), BUT CI PIPELINE ALREADY BUILT
WHY=No `android/key.properties` and no MORT_UPLOAD_* env vars present locally; `gh secret list --repo mortapp/Mort` returns empty, so `MORT_UPLOAD_KEYSTORE_BASE64`/`MORT_UPLOAD_KEY_ALIAS`/`MORT_UPLOAD_STORE_PASSWORD`/`MORT_UPLOAD_KEY_PASSWORD`/`SUPABASE_SERVICE_ROLE_KEY` are not set in GitHub either. `android/app/build.gradle.kts:60-64` intentionally raises `Release signing is required. Debug-signing fallback is intentionally disabled.` when a release build is requested without them — verified live this session (`flutter build apk --release` fails with exactly this message with no signing configured). A complete, ready-to-run signed-build workflow already exists at `.github/workflows/mort-signed-closed-test.yml` (`workflow_dispatch`, materializes the keystore from the base64 secret, runs `scripts/build-standard-closed-test-apk.ps1`/`.aab.ps1`) — it is simply missing its secrets.
TECHNICAL_WORK_COMPLETE=YES — both the fail-closed gate and the CI automation to produce a real signed build the moment secrets exist are already implemented; this session additionally verified the R8/shrink pipeline itself works by building and runtime-testing a release APK with a throwaway local-only key (never committed, deleted after use) on the `MORT_QA_Pixel6` emulator — launched and stayed resumed with no crash in logcat.
HUMAN_ACTION_REQUIRED=Add the five GitHub Actions secrets `mort-signed-closed-test.yml` already expects (`MORT_UPLOAD_KEYSTORE_BASE64`, `MORT_UPLOAD_KEY_ALIAS`, `MORT_UPLOAD_STORE_PASSWORD`, `MORT_UPLOAD_KEY_PASSWORD`, plus `SUPABASE_SERVICE_ROLE_KEY`/`SUPABASE_URL` var) via `gh secret set` or the repo Settings UI, using the real MORT upload keystore.
CREDENTIAL_REQUIRED=YES (owner keystore + passwords)
PROVIDER=Google Play (app signing)
LAUNCH_IMPACT=Blocks `flutter build apk --release` / `--appbundle --release` locally and the already-built `mort-signed-closed-test` CI workflow, and therefore Play Store submission
FAIL_CLOSED_BEHAVIOR=Correct — build hard-fails rather than silently falling back to debug signing.

---

GATE=Apple Developer account / signing certificates
STATUS=UNAVAILABLE for App Store distribution; macOS CI build PASS
WHY=This program runs on a Windows host, but [GitHub Actions run 34472297830](https://github.com/mortapp/Mort/actions/runs/34472297830) supplied the missing macOS/Xcode evidence: pub get, format, analyze, full Flutter tests, CocoaPods, `xcodebuild` validation, unsigned iOS release build, IPA packaging, BrowserStack upload, and three-device real-device QA all passed for `0180d27`. The build intentionally has no App Store signing. Separately, `test/ios_platform_parity_test.dart` deliberately asserts the Xcode project has no APNs/Sign-in-with-Apple entitlement until provider configuration and legal gates actually exist; this is intentional, not an oversight (see `MORT_IOS_NATIVE_SOURCE_AUDIT.md`).
TECHNICAL_WORK_COMPLETE=YES for every pre-account technical check, including the real macOS build. Distribution signing remains intentionally unverified without Apple credentials.
HUMAN_ACTION_REQUIRED=Provide Apple Developer Program membership plus signing certificates/provisioning profiles once TestFlight/App Store distribution is needed. BrowserStack real-device QA is already verified separately in run 34472297830.
CREDENTIAL_REQUIRED=YES, for App Store distribution specifically
PROVIDER=Apple
LAUNCH_IMPACT=Blocks TestFlight/App Store submission; it does not block the completed BrowserStack QA evidence.
FAIL_CLOSED_BEHAVIOR=N/A (build/distribution gate, not a runtime safety gate)

---

GATE=Payment provider (Stripe) live-mode approval
STATUS=NOT LIVE (correctly disabled)
WHY=`private.stripe_runtime_controls.mode` live-gate requires ~15 explicit approval flags (legal, privacy, minor-payout, tax-reporting, negative-balance plan, retention, receipts policy, reconciliation schedule, monitoring on-call, production release) all true, enforced by a database CHECK constraint (`stripe_runtime_phase12_live_gate`) — verified by reading the migration, not by attempting to flip it live.
TECHNICAL_WORK_COMPLETE=YES — internal architecture, idempotency, and separation-of-duties controls audited and sound (see Session 2 report).
HUMAN_ACTION_REQUIRED=Complete real Stripe Connect onboarding, legal/privacy/tax sign-off, and set each approval flag deliberately via `stripe_server_update_controls` once each prerequisite is genuinely true.
CREDENTIAL_REQUIRED=YES (live Stripe keys + business onboarding)
PROVIDER=Stripe
LAUNCH_IMPACT=Blocks real job payments/payouts
FAIL_CLOSED_BEHAVIOR=Correct — cannot be flipped live piecemeal; all gates required simultaneously at the DB constraint level.

---

GATE=Identity verification provider
STATUS=NOT LIVE (correctly disabled)
WHY=`identity-verification-session` returns 503 unless `IDENTITY_VERIFICATION_MODE=production` and every provider env var (provider name, broker URL/secret, allowed handoff hosts) is set.
TECHNICAL_WORK_COMPLETE=YES — provider abstraction, SSRF-safe handoff validation, and webhook signature verification audited and sound.
HUMAN_ACTION_REQUIRED=Select and onboard a real identity verification provider; configure its credentials and allowed handoff hostnames.
CREDENTIAL_REQUIRED=YES
PROVIDER=Not yet selected/configured
LAUNCH_IMPACT=Blocks any marketplace flow that mandates identity verification
FAIL_CLOSED_BEHAVIOR=Correct.

---

GATE=Legal final approval (attorney sign-off)
STATUS=NOT CLAIMED
WHY=Public legal site build+validate scripts pass technically (13 routes), which confirms the delivery pipeline works, not that counsel has approved the content. Every legal document in the catalog is `publication_status = 'draft_attorney_review'`, and both `LegalCenterScreen`/`LegalClickwrapScreen` render an explicit "DRAFT — NOT ATTORNEY REVIEWED" banner — no approval is claimed anywhere in the client.
TECHNICAL_WORK_COMPLETE=YES for everything engineering-controllable — see `MORT_LEGAL_RECONSENT_AUDIT.md`: server-authoritative hash-bound acceptance, role/age-specific requirements, decline handling, and the re-consent-after-revision flow (a real gap found and fixed this session) are all verified/implemented. Only the actual attorney review of the document *text* remains, which is not an engineering task.
HUMAN_ACTION_REQUIRED=Attorney review and sign-off on Terms/Privacy/Community Rules content.
CREDENTIAL_REQUIRED=NO
PROVIDER=N/A (legal counsel)
LAUNCH_IMPACT=Blocks public launch regardless of technical readiness.
FAIL_CLOSED_BEHAVIOR=N/A

---

GATE=Moderation/support staffing
STATUS=NOT STAFFED (tooling only)
WHY=Staff-role provisioning tooling (`admin_create_team_role_assignment`, training/confidentiality/conflict/device-compliance gates) is implemented and audited sound; no evaluation of whether real humans are assigned to these roles was possible or attempted.
TECHNICAL_WORK_COMPLETE=YES (tooling)
HUMAN_ACTION_REQUIRED=Recruit/assign real moderators and support staff to the roles this tooling already supports.
CREDENTIAL_REQUIRED=NO
PROVIDER=N/A (internal staffing)
LAUNCH_IMPACT=Blocks live moderation response even though the tooling is ready.
FAIL_CLOSED_BEHAVIOR=N/A

---

GATE=Live Supabase Auth dashboard settings verification (email confirmation, login rate limits)
STATUS=CANNOT_VERIFY_FROM_REPOSITORY
WHY=`supabase/config.toml` (local CLI dev config only) shows `enable_confirmations = false`, but this does not necessarily reflect the hosted project's actual Dashboard setting, which is not stored in git. Auth login rate-limiting is likewise Dashboard-managed, not expressed in migrations. This session's Supabase MCP is bound to an unrelated project ("Loop"), so neither could be checked live.
TECHNICAL_WORK_COMPLETE=N/A — not a code defect, a live-configuration unknown.
HUMAN_ACTION_REQUIRED=Someone with access to the `rakjydmgwwgtdislanbt` Supabase project dashboard should confirm Authentication → Providers → Email confirmation is enabled, and that login rate limits are configured, for production.
CREDENTIAL_REQUIRED=NO (just dashboard access, already held by the project owner)
PROVIDER=Supabase
LAUNCH_IMPACT=If confirmations are actually disabled in production, anyone could sign up with an unowned email address.
FAIL_CLOSED_BEHAVIOR=Unknown until verified.

---

GATE=Financial Safety (teen earnings/tax feature) branch reconciliation
STATUS=RESOLVED — transferred to integration/mort-final-100-readiness (commits e82d664, 7484ff1)
WHY=Previously existed only as uncommitted work on `feature/compact-onboarding-and-screen-polish` (PR #4). Forensically inventoried read-only (PR #4 itself never touched) and surgically transferred — see MORT_FINANCIAL_SAFETY_TRANSFER.md.
TECHNICAL_WORK_COMPLETE=YES — full regression green (487 passed/2 skipped/0 failed); one real bug found and fixed during transfer (guardian financial summary identity).
HUMAN_ACTION_REQUIRED=None to use this branch. Separately, PR #4 itself still exists as its own open PR with its own unrelated (atmosphere-redesign, onboarding) work — its disposition (merge, close, rebase) is the user's decision and out of scope for this program, which only needed the Financial Safety substance.
CREDENTIAL_REQUIRED=NO
PROVIDER=N/A
LAUNCH_IMPACT=None remaining for this branch.
FAIL_CLOSED_BEHAVIOR=N/A

---

GATE=Real iOS AdMob app (dedicated App ID for MORT's iOS bundle)
STATUS=NOT CREATED — genuine internal defect found and fixed around this gap this session
WHY=`.env.example` already documented "No iOS AdMob app has been created yet"; `AppConfig.admobIosAppId` has no default (empty string) unlike Android's real, hardcoded `ca-app-pub-9883419411387958~1048817736`. This was previously believed harmless because `ADS_ENABLED=false` in every QA/CI build. It is not harmless: `google_mobile_ads` is compiled into every iOS build unconditionally (`AppConfig.nativeAdsCompiledIn = true`), and the native Google Mobile Ads SDK enforces a hard `GADApplicationIdentifier` Info.plist requirement at process launch *independent of the ADS_ENABLED dart-define* — it crashes with `GADInvalidInitializationException` before any Dart code gets a chance to gate it. This was caught by a real BrowserStack real-device session (session `3070c49d...`, device "iPhone 15" iOS 17, run 34145579365/34147137707): the device log showed `Terminating app due to uncaught exception 'GADInvalidInitializationException'` ~1s after launch, on every attempt.
TECHNICAL_WORK_COMPLETE=YES — fixed by adding `GADApplicationIdentifier` to `flutter_mort/ios/Runner/Info.plist` using Google's own official public sample iOS App ID (`ca-app-pub-3940256099942544~1458002511`, the same publisher used for this codebase's existing test ad-unit IDs in `admob_service.dart`) as a non-fabricated placeholder, with a regression test added to `test/ios_platform_parity_test.dart` (`declares a GADApplicationIdentifier for the compiled-in AdMob SDK`) so the key cannot silently disappear again. Full regression suite reverified green (488 passed/2 skipped/0 failed) and Android debug build reverified unaffected.
HUMAN_ACTION_REQUIRED=Create a real iOS app entry under the existing AdMob publisher account (`pub-9883419411387958`, same one already used for Android) — a few minutes in the AdMob console, no new account or approval wait needed — then set `ADMOB_IOS_APP_ID`/`ADMOB_IOS_*_AD_UNIT_ID` env vars and swap the sample value in Info.plist for the real one before ads are ever enabled for real iOS users.
CREDENTIAL_REQUIRED=NO to keep the app from crashing (already fixed with Google's public sample ID); YES (AdMob console access) only before real iOS ads can be served.
PROVIDER=Google AdMob
LAUNCH_IMPACT=Without this fix, MORT crashed on launch on every real iPhone, regardless of ADS_ENABLED — this was a P0 correctness defect, not merely an ads-feature gap.
FAIL_CLOSED_BEHAVIOR=N/A (this was a gap in the fail-closed design, now corrected; ads themselves remain fully gated behind ADS_ENABLED and assertValidReleaseConfiguration's ad-unit-configured check)

---

## Current Flutter production-readiness update (2026-10-25)

This dated update reflects checks on `codex/mort-production-readiness` at PR #28. It supersedes earlier statements above where the current local checkout provides newer evidence.

- **Android upload key:** The existing upload keystore was found in the owner's protected local archive, outside the repository. Its alias and certificate fingerprint match MORT's release documentation. The Windows-user DPAPI credential record decrypted successfully and both credential fields are present, but they were not passed to `keytool`, so the key/password pair remains unverified. No key or credential was copied into this repository, printed, or replaced.
- **GitHub release secrets:** The repository has no configured upload-key secrets, so the signed closed-test workflow remains blocked until the owner supplies the existing key and passwords through repository secrets. The signed workflow was not run; no release artifact was signed or uploaded.
- **iOS entitlements:** The current release configuration includes the production APNs environment entitlement. Apple distribution signing and App Store submission remain unverified; Sign in with Apple is not enabled by this entitlement file.
- **Current local checks:** `dart analyze --format machine lib test` is clean; the complete Flutter suite passes (744 passed, 23 skipped); `flutter build apk --debug --no-pub` succeeds; and the signed-build service-role boundary check passes. These checks do not establish release signing or real-device QA for this exact commit.
- **Backend rollout:** The Supabase migrations and Edge Function changes in PR #28 have not been applied to the production project. Live Stripe job payments remain deliberately disabled until the account, credentials, legal approvals, and production controls are configured and verified.
- **Real-device reruns:** The BrowserStack run cited above is historical evidence. The current BrowserStack quota is exhausted, so this candidate has not received a fresh cloud-device matrix.

### Production Supabase comparison (read-only, 2026-10-25)

- The connected `Mort` Supabase project reports `ACTIVE_HEALTHY` on Postgres 17.6.1. No production writes were made.
- Production migration history contains 275 versions; this branch contains 245 migration files. Four branch versions are absent from production history (`20260831120000`, `20260905180000`, `20260905190000`, and `20261025012531`), while 34 production versions have no matching file in this branch. Production history ends at `20261012014250`; the newest local migration is `20261025012531_mort_financial_integrity_and_webhook_fencing.sql`. This is migration-history drift and must be reconciled before any production migration is applied.
- Production has 38 active Edge Functions. Five functions in this branch are not present in the production function inventory: `document-vault-access`, `google-play-rtdn`, `google-play-verify-purchase`, `stripe-get-financial-document`, and `stripe-list-financial-history`. Production also has three functions missing from this branch: `mort-verify`, `stripe-task31-qa-runner`, and `teen-verification-retention-processor`. The frontend cannot assume the five branch-only endpoints are available in production.
- Supabase security advisors report leaked-password protection disabled and five anonymous-callable `SECURITY DEFINER` RPCs; review the public RPC grants and enable compromised-password checks before broad public onboarding. The advisor also reports 344 authenticated-callable `SECURITY DEFINER` functions for review; this count alone does not establish a vulnerability. Its 125 RLS-without-policy notices refer to tables in the `private` schema and are INFO-level. One performance warning names overlapping SELECT policies on `public.account_deletion_requests`.
- These findings were inspected as read-only evidence only. Production schema history, function deployment, Auth settings, and policy changes still require an owner-reviewed rollout plan.
