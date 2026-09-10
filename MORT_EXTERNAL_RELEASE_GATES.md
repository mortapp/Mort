# MORT External Release Gates

Each entry is a dependency this program cannot close without a human action or a
credential/account this session does not have and should not fabricate.

---

GATE=BrowserStack account/credentials
STATUS=NOT_EXECUTABLE_FROM_CURRENT_SHELL
WHY=The local shell has no `BROWSERSTACK_USERNAME`/`BROWSERSTACK_ACCESS_KEY`, and `verify-browserstack-env.ps1` therefore fails closed. Repository secret names for `BROWSERSTACK_USERNAME` and `BROWSERSTACK_ACCESS_KEY` are now present, but their values cannot be read or exported by this session; no `BROWSERSTACK_APP_URL` is available locally and no BrowserStack MCP connection is active.
TECHNICAL_WORK_COMPLETE=YES — [GitHub Actions run 34131627976](https://github.com/mortapp/Mort/actions/runs/34131627976) passed its macOS iOS build/test/pod-install/unsigned-IPA artifact pipeline and uploaded `mort-ios-browserstack-qa`. Its BrowserStack upload step was skipped in that run because credentials were unavailable to the job. The workflow and `scripts/browserstack/*.ps1` (verify-env, upload-ios-app, upload-android-app, poll-build, download-results) are ready but cannot be exercised end-to-end from this shell.
HUMAN_ACTION_REQUIRED=Run the BrowserStack workflow with the configured repository secrets, or provide the credentials through the protected environment and upload the iOS artifact to obtain `BROWSERSTACK_APP_URL`; never paste the key into source or chat.
CREDENTIAL_REQUIRED=YES (BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY)
PROVIDER=BrowserStack
LAUNCH_IMPACT=Blocks all real-iPhone and real-Android-cloud QA (Tracks 10-11)
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
WHY=This program runs on a Windows host, but [GitHub Actions run 34131627976](https://github.com/mortapp/Mort/actions/runs/34131627976) supplied the missing macOS/Xcode 16.2 evidence: pub get, format, analyze, 487 tests, CocoaPods, `xcodebuild -list`, unsigned `flutter build ios --release --no-codesign`, IPA packaging, and artifact upload all passed for `62b48fd`. The build intentionally has no signing. Separately, `test/ios_platform_parity_test.dart` deliberately asserts the Xcode project has no APNs/Sign-in-with-Apple entitlement until provider configuration and legal gates actually exist; this is intentional, not an oversight (see `MORT_IOS_NATIVE_SOURCE_AUDIT.md`).
TECHNICAL_WORK_COMPLETE=YES for every pre-account technical check, including the real macOS build. Distribution signing remains intentionally unverified without Apple credentials.
HUMAN_ACTION_REQUIRED=Provide Apple Developer Program membership plus signing certificates/provisioning profiles once TestFlight/App Store distribution is needed. BrowserStack App Live/App Automate testing may not require full Apple distribution signing, but that remains unverified until credentials allow a real device-cloud upload.
CREDENTIAL_REQUIRED=YES, for App Store distribution specifically
PROVIDER=Apple
LAUNCH_IMPACT=Blocks TestFlight/App Store submission. Does not necessarily block BrowserStack device testing (BrowserStack can often re-sign uploaded apps for its own devices) — needs verification once a build artifact exists.
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
