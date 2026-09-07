# MORT External Release Gates

Each entry is a dependency this program cannot close without a human action or a
credential/account this session does not have and should not fabricate.

---

GATE=BrowserStack account/credentials
STATUS=NOT_CONFIGURED
WHY=No BROWSERSTACK_USERNAME/BROWSERSTACK_ACCESS_KEY in this environment; `gh secret list --repo mortapp/Mort` returns empty; no BrowserStack MCP connection active.
TECHNICAL_WORK_COMPLETE=YES — scaffolding built this session: `.github/workflows/mort-ios-browserstack.yml` (macOS CI: build/test/pod install/unsigned iOS artifact, conditional BrowserStack upload) and `scripts/browserstack/*.ps1` (verify-env, upload-ios-app, upload-android-app, poll-build, download-results), built against BrowserStack's documented App Automate REST API. Cannot be exercised end-to-end without credentials.
HUMAN_ACTION_REQUIRED=Create/sign into a BrowserStack account with App Live + App Automate access; get Username + Access Key from Account Settings; set as env vars or complete BrowserStack MCP OAuth; never paste the key into source or chat.
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
STATUS=UNAVAILABLE (not evaluated — no macOS environment)
WHY=This program runs on a Windows host; Xcode cannot run here. No macOS CI workflow exists in `.github/workflows` yet (being built in Track 9).
TECHNICAL_WORK_COMPLETE=NO — macOS CI workflow not yet created this session
HUMAN_ACTION_REQUIRED=Provide Apple Developer Program membership + signing certificates/provisioning profiles once App Store distribution (not BrowserStack testing) is needed. BrowserStack App Live/App Automate testing may not require full Apple distribution signing — to be confirmed once the macOS CI artifact pipeline exists.
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
WHY=Public legal site build+validate scripts pass technically (13 routes), which confirms the delivery pipeline works, not that counsel has approved the content.
TECHNICAL_WORK_COMPLETE=PARTIAL — delivery/versioning/build pipeline verified; full acceptance/re-consent flow audit still open.
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
STATUS=NOT ON MAIN
WHY=The feature exists only as uncommitted work on `feature/compact-onboarding-and-screen-polish` (open PR #4, currently CONFLICTING against main). This program was explicitly instructed not to touch that branch/PR.
TECHNICAL_WORK_COMPLETE=UNKNOWN — cannot be audited from this branch.
HUMAN_ACTION_REQUIRED=Decide how/when to reconcile PR #4 against the new main; only then can this feature be audited and scored.
CREDENTIAL_REQUIRED=NO
PROVIDER=N/A
LAUNCH_IMPACT=The Financial Safety UX feature is simply absent from any build produced off this branch until that reconciliation happens.
FAIL_CLOSED_BEHAVIOR=N/A
