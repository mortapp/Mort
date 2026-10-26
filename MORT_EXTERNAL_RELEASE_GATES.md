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

GATE=Google Play production access
STATUS=GRANTED (owner-provided Google Play Support email and Console screenshots, 2026-10-25)
WHY=Google Play Support confirmed production access for Mort (`com.mortapp.mobile`). The owner confirms MORT is already operating in production; this work must target production distribution and production backend behavior, not a closed-beta milestone.
TECHNICAL_WORK_COMPLETE=YES for production-access eligibility. This approval does not provision signing automation or establish which artifact/revision is currently live.
HUMAN_ACTION_REQUIRED=None for production-access eligibility. Continue with a production-signed release and verify its rollout against the live listing.
CREDENTIAL_REQUIRED=YES for automated signing only (the existing upload key is locally recoverable).
PROVIDER=Google Play
LAUNCH_IMPACT=Production access is no longer a blocker. The production release pipeline, signing configuration, app artifact, and live rollout still require verification.
FAIL_CLOSED_BEHAVIOR=N/A (account eligibility, not an app runtime control)

---

GATE=Android upload/release signing keystore
STATUS=LOCAL KEY VERIFIED; GITHUB ACTIONS SIGNING SECRETS NOT CONFIGURED
WHY=The existing upload keystore and DPAPI-protected credentials are present outside the repository and were verified against MORT's release certificate report. There is no local `flutter_mort/android/key.properties`, and the repository plus `closed-test-release` environment lack the protected upload and Supabase client secrets required by the current workflow. Gradle correctly fails closed when release signing inputs are missing. The only signing workflow currently in the repository is `mort-signed-closed-test`; it is not a production release workflow and forbids a service-role key.
TECHNICAL_WORK_COMPLETE=YES for local key recovery and keytool argument secrecy. The release-signing boundary test and the Android device-test APK CI build pass. A production-signed AAB has not been built or uploaded.
HUMAN_ACTION_REQUIRED=For signed CI, configure protected GitHub secrets `MORT_UPLOAD_KEYSTORE_BASE64`, `MORT_UPLOAD_KEY_ALIAS`, `MORT_UPLOAD_STORE_PASSWORD`, `MORT_UPLOAD_KEY_PASSWORD`, and `SUPABASE_ANON_KEY`, plus the `SUPABASE_URL` variable, using the existing upload key. Never provide `SUPABASE_SERVICE_ROLE_KEY` to a mobile build.
CREDENTIAL_REQUIRED=YES for signed CI (owner keystore + passwords)
PROVIDER=Google Play (app signing)
LAUNCH_IMPACT=Blocks automated signed release builds in GitHub Actions. The protected local key is usable for local signing. The public AAB entry point now routes through the shared production validators, but the checked-in production profile currently keeps activation approval false and therefore rejects a public build.
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

This dated update reflects checks on `codex/mort-production-readiness` at PR #28, head `b0f07ab`. It supersedes earlier statements above where the current checkout provides newer evidence.

- **Google Play production access:** Granted for Mort (`com.mortapp.mobile`) according to the owner-provided Google Play Support email and Console screenshots on 2026-10-25. MORT is being prepared and assessed as a production app, not as a closed-beta milestone. The current live artifact/release revision was not independently visible in the supplied screenshots.
- **Android upload key:** The existing upload keystore is present in the owner's protected local archive, outside the repository. Read-only `keytool -list -v` and `keytool -certreq` checks used the DPAPI-protected store and key passwords through temporary process environment variables; the alias and SHA-1/SHA-256 fingerprints match MORT's release certificate report, and the private key successfully produced a certificate request that was discarded without writing a file. The upload key and credentials are therefore locally recoverable and cryptographically usable. No key or credential was copied into this repository, printed, or replaced.
- **GitHub release secrets:** The repository has no configured upload-key secrets, so automated signed builds remain blocked until the owner provisions the existing key and passwords in the protected GitHub environment. The only signing workflow is closed-test-specific; no production-signed workflow exists yet. No release artifact was signed or uploaded in this turn.
- **Public production AAB path:** `scripts/build-production-public-aab.ps1` now invokes the shared `production` profile pipeline instead of unconditionally throwing. It retains certificate, Supabase project, hosted release-mode, public marketplace, identity, push/crash, and activation checks. The current matrix sets `productionActivationApproved=false`, so the entry point rejects the build before signing or artifact creation; no owner approval or server activation was inferred from Play Console production-access eligibility.
- **iOS entitlements:** The current release configuration includes the production APNs environment entitlement. Apple distribution signing and App Store submission remain unverified; Sign in with Apple is not enabled by this entitlement file.
- **Current local and CI checks:** `flutter analyze --no-pub` reports no issues; the complete local Flutter suite passes (745 passed, 23 skipped), including the auth-startup recovery regression; the auth-startup file passes 26/26; and the financial-history Edge Function suite passes 11/11 with Deno type checks passing. On commit `6b4008a`, CI run `40232907406` passed the authoritative Flutter, Android device-test APK, Stripe local regression, Stripe security, and Stripe contract jobs. Its overall conclusion is failure because the unrelated `public-site` and `expo-reference` jobs failed. This does not establish a production-signed artifact or real-device installation of the current source.
- **Backend rollout:** On 2026-10-25, deployed `stripe-list-financial-history` and `stripe-get-financial-document` version 1 to the production Supabase project with JWT verification enabled. Both live endpoints returned HTTP 401 to unauthenticated POST requests. Their authenticated user RPCs and rate-limit actions were verified in production before deployment. A cross-check of all 16 Edge Function names called from Flutter found each active in production with JWT verification enabled. No SQL migrations were applied; live Stripe job payments remain disabled until the provider account, credentials, legal approvals, and production controls are configured and verified.
- **Real-device reruns:** The BrowserStack run cited above is historical evidence. The current BrowserStack quota is exhausted, so this candidate has not received a fresh cloud-device matrix.

### Production Supabase comparison (read-only, 2026-10-25)

- The connected `Mort` Supabase project reports `ACTIVE_HEALTHY` on Postgres 17.6.1. The metadata/schema comparisons below are read-only; the two Edge Function deployments recorded above are the only production writes in this update.
- Production migration history contains 275 versions; this branch contains 245 migration files. Four branch versions are absent from production history (`20260831120000`, `20260905180000`, `20260905190000`, and `20261025012531`), while 34 production versions have no matching file in this branch. Production history ends at `20261012014250`; the newest local migration is `20261025012531_mort_financial_integrity_and_webhook_fencing.sql`. This is migration-history drift and must be reconciled before any production migration is applied.
- Production now has 40 active Edge Functions. Three functions in this branch are still not present in the production inventory: `document-vault-access`, `google-play-rtdn`, and `google-play-verify-purchase`. The financial-history and financial-document wrappers are active at version 1 with JWT verification. Production also has three functions missing from this branch: `mort-verify`, `stripe-task31-qa-runner`, and `teen-verification-retention-processor`.
- Supabase security advisors report leaked-password protection disabled and five anonymous-callable `SECURITY DEFINER` RPCs. Their live definitions were reviewed read-only: all use an empty search path and schema-qualified objects. `get_release_mode_status` and `get_runtime_feature_status` are consumed by the mobile app for public status; `get_auth_provider_readiness` returns provider/CAPTCHA readiness, including a public site key; `check_school_email_for_signup` returns only a school-eligibility boolean; and `request_school_directory_entry` validates submitted suggestions and enforces project-wide caps of 30/hour and 200/day. The last three have no matching call sites in this branch; eligibility probing and shared quota exhaustion remain abuse surfaces to evaluate, but no direct secret disclosure was found. No RPC grants were changed. Leaked-password protection is unavailable on the current Free plan and remains a documented plan-limited enhancement; enable it after a separately authorized upgrade to Pro, as described in `docs/ENABLE_LEAKED_PASSWORD_PROTECTION.md`. The advisor also reports 344 authenticated-callable `SECURITY DEFINER` functions for review; this count alone does not establish a vulnerability. Its 125 RLS-without-policy notices refer to tables in the `private` schema and are INFO-level. One performance warning names overlapping SELECT policies on `public.account_deletion_requests`.
- These findings were inspected as read-only evidence only. Production schema history, function deployment, Auth settings, and policy changes still require an owner-reviewed rollout plan.

### Latest branch CI result (2026-10-25)

On exact head `a1866267112c1e9599b640ba3db24a9c6117a7e8`, GitHub Actions run [40235221905](https://github.com/mortapp/Mort/actions/runs/40235221905) passed the authoritative Flutter job (format, analyze, payment integration test, full Flutter suite, provider-disabled build, generated-artifact secret scan), Android device-test APK build, local Stripe regression, Stripe contracts, and Stripe security checks. The workflow conclusion is failure because the separate `public-site` and `expo-reference` jobs failed; the hosted/provider Stripe E2E jobs were skipped by their configured conditions. No production-signed artifact or physical-device install was produced by these checks.

### Current live release policy and public activation gates (read-only, 2026-10-25)

The owner-provided Play Console evidence confirms Google Play granted production access for `com.mortapp.mobile`, and the owner states MORT is publicly distributed as a production app. Play distribution eligibility and backend marketplace activation are separate states; the live backend query does not establish whether a Play production track currently serves a particular artifact.

A read-only call to `get_release_mode_status()`, `get_runtime_feature_status()`, and the authenticated `get_public_release_readiness()` reported:

- The backend policy remains `release_mode=closed_test`, `marketplace_mode=closed_pilot`, and `public_marketplace_enabled=false`; real document collection, identity verification, live billing, ads, and remote push are disabled. This describes the backend's restricted marketplace policy, not Google Play distribution status.
- Runtime emergency controls show maintenance off, payments disabled, AI provider disabled, marketplace closed, and new-job publishing not globally disabled. The runtime controls' last update was 2026-09-17.
- Public activation is not ready. Owner, counsel package, child-safety contact, privacy contact, support contact, Play declarations, moderation staffing, and incident on-call approvals all report false. Legal readiness and identity-provider readiness report false. The RPC lists 13 missing attorney-approved published document keys and one active admin-role assignment without an expiry.
- Flutter's marketplace availability card correctly says “Marketplace access limited”; the Settings release diagnostics screen also exposes the backend `release_mode` value. Keep this runtime policy label distinct from the app's confirmed public Play distribution state.

No production policy, runtime flag, legal publication, role assignment, or SQL migration was changed. Do not open public marketplace access until qualified legal approval, real named operational contacts/staffing, an identity-provider readiness decision, Play declaration approval, and cleanup/review of the unbounded admin assignment are evidenced; then use the audited administrative activation path. The migration history remains unreconciled as recorded above, so the branch-only financial-integrity migration is not ready for production application.

### Original local Flutter checkout verification (2026-10-25)

The original `C:\Users\micha\Mort\flutter_mort` checkout was checked in place without resetting, stashing, or replacing its existing work. Its `flutter analyze --no-pub` passed, `dart format --output=none --set-exit-if-changed lib test integration_test` checked 316 files with no changes, and `flutter test --no-pub` passed 579 tests with 23 skipped. The active local feature branch is substantially behind the readiness branch; shared Flutter assets/features/tests are already present in PR #28. Where the older checkout differs, the readiness branch contains additional route privacy, legal-reacceptance, auth-recovery, and webhook-signature protections. Its older webhook/migration snapshots were not copied over those stronger versions. Generated UI/guard evidence and the local checkout's remaining uncommitted work were left intact.
