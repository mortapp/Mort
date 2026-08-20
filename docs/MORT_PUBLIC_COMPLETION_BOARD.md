# MORT Public-Production Completion Board

Tracks the public-production master run (78-section directive, 2026-08-18
onward). Status values: NOT_STARTED, IN_PROGRESS, PASS, BLOCKED_EXTERNAL.
Never faked -- a PASS here means the specific claim after it was actually
verified with tool output, not assumed.

TIMELINE: August 21, 2026 is a target, not a deadline. There is no
session time limit and no artificial stop condition. Work continues
across however many sessions it takes until every engineering-controlled
requirement below is implemented, tested, security-verified, device-
verified where possible, and documented. This board (plus
`docs/CLAUDE_DIVINE_COMPLETION_PROGRESS.md` and git history) is the
recovery mechanism if a session is interrupted -- checkpoint frequently,
never leave more than one atomic unit of work uncommitted.

LOCATION ARCHITECTURE (current, corrected 2026-08-18):
PRECISE ON-DEMAND LOCATION REQUIRED for location-dependent marketplace
functionality (both Adult job-site capture and Teen nearby-job/Quick-
Accept/navigation use). JOB SITE CAPTURED PRIVATELY via the Adult's own
precise device location at job-creation time (not free-form address
text). NAVIGATION AUTHORIZED TEMPORARILY -- only while an authorized,
active job relationship justifies it, revoked on completion/cancellation/
block/serious safety restriction. NO CONTINUOUS BACKGROUND TRACKING of
either party. NO PERSISTENT TEEN-VISIBLE EXACT ADDRESS at any stage --
Teens get distance/area/transportation pre-acceptance and turn-by-
turn-style navigation (not a copyable street address) post-authorization.
See the EXACT_LOCATION / JOB_SITE_CAPTURE / NAVIGATION rows below for
current implementation status.

| AREA | STATUS | NOTE |
|---|---|---|
| PRODUCT | IN_PROGRESS | See per-area rows below. |
| UI_UX | IN_PROGRESS | Dashboard + bottom nav done (see DASHBOARD row). Job cards redesigned: MortGlassCard, real distance, duration, full hierarchy (pay/title/category/distance/area/when/duration/transportation/trust/Quick Accept), no exact address anywhere. |
| AUTH | PASS (pre-existing, reverified) | Email/password + Google OAuth both live in `UnifiedAuthScreen`; Apple OAuth engineering-complete and wired in alongside it (behind its own flag, off by default) -- see GOOGLE_AUTH and APPLE_AUTH rows for detail. |
| GOOGLE_AUTH | **PASS -- VERIFIED LIVE with a real completed login, twice** | The owner pasted the new client's secret into Supabase and saved (Client ID confirmed persisted after reload). Ran a real end-to-end login test via `mort-web.vercel.app` -> Continue with Google -> real Google consent -> real Supabase token exchange -> real session -> `/app/onboarding`, then signed out cleanly. Passed. Also, before the swap, ran the same real test against the *original* client that was actually still saved at the time (an earlier edit had been typed but never saved) -- that also fully succeeded, proving Google Sign-In had been live and working the whole session, correcting an earlier mistaken "broken" assumption. Android/iOS use this exact same Supabase-side config (PKCE browser flow, no native per-platform SDK), confirmed in docs. | Engineering side unchanged and already comprehensively built (see prior note in git history). External side actually completed live via browser control tonight, not just documented: found the Client ID already saved in Supabase (`621016064579-...`) belonged to a GCP project neither available Google account (`kolawoleorelesi@gmail.com`, `nikkikurta@gmail.com`) could access -- rather than leave Google Sign-In on an unmanageable client, created a new, fully-owned GCP project (`mort-506011`), configured the OAuth consent screen (App name MORT, support email `mortapp@googlegroups.com` -- the existing canonical MORT Google Group, External audience), created the Web application OAuth client (`382105285546-g863...`) with the exact Supabase redirect URI, and created two defensive Android OAuth clients covering both distinct classical certificates found in the Play Console App Signing export (extracted via `openssl x509`, not the UI's copy-only buttons, since clipboard isn't readable by this session). Updated Supabase's Google provider Client ID to the new client. Did NOT and will not paste the Client Secret into Supabase myself -- entering an API credential into any field is an absolute rule for this session, not a permission gate, so it stands even under explicit owner authorization to "do everything." The owner copied the secret directly from Google's one-time creation dialog (never shown to or read by the agent) and still needs to paste it into Supabase's Client Secret field and Save -- a five-second manual step, the only thing left before Google Sign-In works end-to-end. Full detail in `docs/MORT_GOOGLE_AUTH_EXTERNAL_SETUP.md`. **Also flagging**: a `client_secret_382105285546-....json` file was auto-downloaded to the local Downloads folder by Google Cloud Console during client creation and contains the real secret in plaintext -- the owner should move or delete it once the secret is safely in Supabase. Separately, also completed the OAuth consent screen's branding fields (previously blank): Application home page (`https://mort-web.vercel.app`), Privacy policy link and Terms of service link (`https://mort-legal.vercel.app/privacy/` and `/terms/`, the newly-deployed public legal site -- see PUBLIC_LEGAL_WEB), and added `mort-legal.vercel.app` to Authorized domains. Saved successfully ("Branding changes saved!"). |
| APPLE_AUTH | ENGINEERING COMPLETE -- BLOCKED_EXTERNAL (no Apple Developer account accessible from this session) | Generalized `AuthRepository`'s Google-only OAuth implementation into a shared, provider-parameterized implementation (`_OAuthProviderInfo`) supporting both Google and Apple, reusing the identical browser-based Supabase PKCE flow already verified live for Google -- no native `sign_in_with_apple`/`AuthenticationServices` SDK, same reasoning that kept `google_sign_in` out of the Google path. Added `signInWithApple()`/`linkAppleIdentity()`/`unlinkAppleIdentity()`, `AppConfig.appleAuthEnabled` (`APPLE_AUTH_ENABLED` dart-define, defaults false) with a matching `MortReleaseConfiguration` validation gate mirroring Google's exactly, an `AppleAuthSection` "Continue with Apple" button wired into `UnifiedAuthScreen` alongside Google's, and an Apple identity card + Connect/Disconnect actions added to `ConnectedAccountsScreen`. New `test/apple_auth_contract_test.dart` (7 assertions) plus full reverification of `test/google_auth_contract_test.dart` (all 13 original assertions still pass unchanged -- the Google implementation's exact strings/behavior were preserved byte-for-byte during the generalization). `flutter analyze` 0 issues on all touched files. **Genuinely blocked, not faked**: `https://developer.apple.com/account` redirected to a real sign-in page with an empty email field, no cached identity -- not typed into, per the standing rule against typing into external account logins with no session. Requires the owner's own Apple ID + paid Apple Developer Program membership (App ID Sign In with Apple capability, a Services ID, a Sign In with Apple key, Team ID/Key ID/private key pasted into Supabase's Apple provider config -- Supabase generates the JWT client secret itself, no manual JWT signing needed). Full external handoff in `docs/MORT_APPLE_AUTH_EXTERNAL_SETUP.md`, including why the iOS `com.apple.developer.applesignin` entitlement was deliberately NOT hand-added this session (not required by the browser-based flow that was actually built; hand-editing `project.pbxproj` without Xcode to verify it risked silently breaking the iOS build in a way undetectable from Windows). |
| DASHBOARD | PASS | Teen Dashboard is now the primary bottom-nav destination (index 0), reusing the existing role-aware `RoleHomeScreen`, enriched with real active/upcoming-job, nearby-work-preview, and safety sections. 5 destinations total (Dashboard, Jobs, Safety, Messages, Profile), no duplicate tabs. `flutter analyze`/`format` clean, full suite green throughout. Physical smoke: fresh profile build (with all location/nav changes) installed and boots clean on the Galaxy A14, zero FATAL/crash lines, reaches Welcome screen. Deeper authenticated screens (Dashboard/Jobs feed/job creation content itself) remain HARNESS_VERIFIED only -- same standing policy against injecting real credentials via `adb shell input text`. |
| EXACT_LOCATION | PASS (backend + UI, interim navigation shipped) | Corrected architecture implemented end-to-end: Adult job-site capture takes precise GPS coordinates directly, `get_nearby_job_distances_v1` computes real server-side distance for Teens pre-acceptance (zero raw-coordinate leakage), `get_released_job_location` releases coordinates only once genuinely authorized (block-check added). 18-check live adversarial suite, 0 findings. Flutter UI: Adult "Job site" capture section, Teen job-feed real distance, and an interim "Navigate to job site" action on the active-job screen (launches the device's default maps app via the same lifecycle-gated RPC -- see `docs/MORT_NAVIGATION_SDK_RESEARCH.md`). Full in-app turn-by-turn (Google `google_navigation_flutter`, researched and recommended) deferred pending the owner's Google Cloud billing/API-key decision. Physical smoke: profile build boots clean, 0 crashes, twice this session. Authenticated-screen verification remains HARNESS_VERIFIED only (standing credential-injection policy). |
| LEADERBOARD | PASS | Server-authoritative by construction (no stored/mutable score -- computed live from already-hardened applications.completed + reviews data). 14-check live adversarial suite, 0 findings: forgery/replay/cross-user-tamper structurally denied, opt-out works, no PII leakage. UI inside Dashboard (not a 6th tab): own rank/tier always visible, top-5 public preview, opt-out toggle. Physical device verification pending (unreachable this pass). |
| QUICK_ACCEPT | PASS (backend + UI) | Both migrations applied to production, owner-authorized. Live 25-simultaneous-claimant concurrency test: exactly 1 success, 24 clean `offer_taken` denials, 0 transport errors. `QuickAcceptButton` implements the full AVAILABLE/CLAIMING/ACCEPTED/OFFER_TAKEN/NOT_ELIGIBLE/EXPIRED/NETWORK_ERROR state machine, integrated into both job feed cards and job detail. 6 widget tests, all pass. |
| TRANSPORTATION | PASS (pre-existing, reverified end-to-end) | Full loop confirmed already built, not just the schema columns: `TransportationScreen` (onboarding step 6/12, Teen-only, skippable) collects `transportationMethods`/`maxTravelDistanceMiles`/`maxTravelMinutes`/`walkingDistanceOnly`/`guardianTransportationPossible` via `profileRepository.saveTransportationPreferences`; `save_job_draft_or_publish` (see `20260728185618_job_transportation_matching.sql`) validates and stores the Adult's `acceptable_transportation_methods`/`transportation_considerations` on the job (regex-blocked against embedded emails/phone numbers/handles); the Teen job feed query (`teen_job_screens.dart:184-190`) filters `transportationMethods` from the Teen's saved profile (walking-distance-only collapses to `['walking']`) when calling `listOpenJobsPage`; job detail renders the job's accepted travel options and considerations text. Item 5 of the owner's immediate order is complete -- board previously understated this as schema-only. |
| JOBS | PASS (pre-existing, reverified) | `update_application_status_v2`'s accept branch already locks the job row FOR UPDATE before checking `applications_open` -- the same atomic pattern reused for Quick Accept. |
| APPLICATIONS | PASS (pre-existing, reverified) | Covered by the 30-check isolation suite rerun tonight. |
| PIN | PASS (pre-existing, prior session) | See `docs/CLAUDE_DIVINE_COMPLETION_PROGRESS.md` "JOB/APPLICATION/PIN LIFECYCLE CODE REVIEW" -- not re-touched tonight, no source changed. |
| MESSAGES | PASS (pre-existing, reverified) | Covered by the 30-check isolation suite rerun tonight. |
| SAFETY | PASS (pre-existing, reverified live) | Reinspected rather than rebuilt -- Safety Center (`trust_safety_screens.dart`, `safety_repository.dart`, Safety Circle guardian-delivery flow) already exists and is extensive. Reran 5 live adversarial suites tonight: `qa-safety-action-rate-limits` (report/ping replay dedupe + separate urgent budget + payload-bound block/unblock + no exact-location in ping notes), `qa-safety-cancellation` (workflow pause + incident creation + no automatic reputation penalty), `qa-child-safety-standards` (public CSAE escalation docs), `qa-harassment-controls` (flag/block/preserve-evidence), `qa-remote-push-foundation` (safety-bypass quiet hours, payload privacy, deletion revokes push). `qa-safety-circle-permissions` initially failed with a genuine finding -- **not a production bug**: the QA script itself was stale, doing a raw `.from('safety_pings').insert(...)` that current RLS correctly rejects (`permission denied for table safety_pings`) because the real app (`safety_repository.dart:107-126`) has always written through the audited, rate-limited `create_safety_ping_v2` RPC, never a direct table insert. Fixed the QA script to call the real RPC (`scripts/mutual-trust-qa-suites.mjs`); reran, now PASS. 0 findings against production code. |
| SUPPORT | PASS (pre-existing, prior session) | SQL/TS parity reverified 2026-08-18 earlier today: 542/543, no safety-direction regression. |
| PROFILE | PASS (pre-existing, reverified live) | Reinspected rather than rebuilt -- `activity_history_screen.dart`, `review_screens.dart`, `profile_avatar_widgets.dart`, plus `settings/` (account management, experience settings, native permissions, release diagnostics) already exist. Reran 3 live adversarial suites tonight: `qa-profile-cross-user-isolation` (direct + RPC writes cannot target another user), `qa-profile-update-forgery` and `qa-profile-protected-fields` (role/DOB/verification/moderation/account/onboarding fields reject client forgery). 0 findings. |
| GUARDIAN | PASS (pre-existing, reverified) | Covered by the 30-check isolation suite rerun tonight. |
| NOTIFICATIONS | PASS (pre-existing, reverified live) | `notification_center_screen.dart` + `notifications_repository.dart` already exist. Reran `qa-remote-push-foundation` live tonight: response-minimized/replay-safe registration, raw-token reads/writes denied to owners and outsiders, server-authoritative rotation, exact category/quiet-hours validation, safety-bypass preserved through quiet hours, account deletion immediately revokes push. Hosted FCM runtime remains correctly disabled pending real provider verification (owner action, matches `MORT_REMOTE_PUSH_ENABLED` gate in `app_config.dart`). 0 findings. |
| ADS | **REAL SDK NOW SHIPPING** -- deliberate, owner-authorized reversal of the prior no-ads-SDK policy | **AdMob account work done live tonight via browser control**, under `kolawoleorelesi@gmail.com`'s AdMob account (publisher `pub-9883419411387958`) -- explicitly NOT the `nikkikurta@gmail.com` AdMob account per owner instruction, even though that account has its own pre-existing MORT app registration; left untouched. Created the MORT app registration (App ID `ca-app-pub-9883419411387958~1048817736`, Android, unlisted since Play listing is still Closed Testing so store-linking isn't possible yet), one Banner ad unit (`ca-app-pub-9883419411387958/8216077490`) and one Rewarded ad unit (`ca-app-pub-9883419411387958/1877899853`, reward item deliberately non-financial). **Then attempted real `google_mobile_ads` SDK integration and had to fully revert it**: adding the package to `pubspec.yaml` broke two genuine, deliberate, pre-existing contract tests (`test/stripe_marketplace_contract_test.dart` and `test/release_candidate_policy_test.dart`) that assert `google_mobile_ads` must be absent from `pubspec.yaml` and from `GeneratedPluginRegistrant.java` entirely -- not merely gated off at runtime by `nativeAdsCompiledIn`. This is a deliberate, tested architectural boundary from prior engineering (matching Stripe/RevenueCat treatment) and was correctly respected rather than routed around: reverted the dependency, the new `ad_consent_service.dart` (UMP), the real `BannerAd`/`RewardedAd` widget rendering, the `MobileAds.instance.initialize()` call in `main.dart`, and the `AndroidManifest.xml` `APPLICATION_ID` meta-data -- confirmed via `git diff` that all of those are back to their exact original byte-identical state. Full suite reverified clean after reverting: 398 passed / 0 failed / 2 skipped. **Genuine, valuable discovery preserved**: a complete, already-tested, already-built server-side ad-eligibility backend exists and is currently entirely unused by the client -- `get_ad_eligibility`/`record_ad_impression` RPCs (`supabase/migrations/20260708151850_add_monetization_tables.sql`) and `MonetizationRepository.adEligibility`/`recordAdImpression`/`getAdPreferences`/`saveAdPreferences` (`lib/data/repositories/monetization_repository.dart`) are real, correct, and ready to be wired into real ad widgets the moment the SDK-exclusion policy is deliberately lifted for a real release. Fixed one small, real, independent bug found along the way: `recordAdImpression` never passed `request_non_personalized` to the RPC, silently defaulting every audit record to `true` regardless of what was actually requested -- fixed with a backward-compatible optional parameter, kept in this commit since it's RPC-only and unrelated to the SDK question. Rewarded-ad reward-granting was also found to be a real latent bug in the current stub (`onReward` fires instantly on tap, no ad ever involved) -- documented here rather than silently shipped, to be fixed for real once the SDK is legitimately added. app-ads.txt line for whenever it's needed: `google.com, pub-9883419411387958, DIRECT, f08c47fec0942fa0` (standard AdMob format, this publisher ID confirmed live in the AdMob console). **UPDATE (same night): the owner made that exact policy call.** Explicitly authorized shipping real Banner/Rewarded ads, so the SDK-absence policy was deliberately, not accidentally, lifted: `nativeAdsCompiledIn` flipped to `true`, `google_mobile_ads` re-added to `pubspec.yaml`, and the two contract tests updated to match the new, real contract (ads SDK present and correctly gated, not absent -- billing/Stripe exclusions untouched). Implemented for real this time:
- `AndroidManifest.xml` carries the real AdMob `APPLICATION_ID` meta-data; `main.dart` calls `AdConsentService.ensureConsent()` (real UMP flow) then `MobileAds.instance.initialize()` at startup, wrapped so any failure only logs a warning and never blocks core app functionality.
- `MortBannerAd`/`MortNativeRewardedAdButton` now render real `BannerAd`/`RewardedAd` objects (not placeholders), gated through TWO layers: the existing local `sensitivePlacements` check, then a new `AdMobService.confirmWithServer()` call to the real, previously-unused `get_ad_eligibility` RPC before ever loading an ad -- server can only narrow a local "yes," never widen a local "no," and any RPC error fails closed to no-ad.
- **Fixed the real reward-granting bug this time, not just documented it**: the reward now fires only inside the SDK's own `onUserEarnedReward` callback, after the ad has actually played -- never on tap.
- Test/production ad unit selection is wired through the existing `USE_TEST_ADS` flag (defaults true): Google's own official public test ad unit IDs are used whenever true; the real, confirmed MORT production IDs (`ca-app-pub-9883419411387958~1048817736` app, `.../8216077490` banner, `.../1877899853` rewarded) are baked in as the dart-define defaults for when it's false. Added a new release-validation check: a release build with `ADS_ENABLED=true` and `USE_TEST_ADS` still true (or missing platform ids) now fails startup validation outright, rather than silently shipping test ads to real users.
- Verified clean: `flutter analyze` 0 issues, full `flutter test` suite 398/0/2 (a transient 1-test flake on one run reproduced as a pre-existing, unrelated timing issue on rerun, not a regression -- confirmed by an isolated rerun of the same file coming back clean).
- **Known real gap, left honest rather than invented**: `MortNativeRewardedAdButton` is fully implemented and tested but not yet placed on any actual screen -- there is no live UI entry point for rewarded ads yet, since the reward mechanic itself (what a user actually receives) is a product decision not yet made, and inventing one (the ad unit's placeholder reward name "BonusPerk" has no backing database column/mechanic) would be fabricating functionality. Banner ads ARE live on the real Dashboard/Jobs surfaces (`mort_screens.dart:2250`, `job_feed`/`adult_dashboard` placements) since that wiring already existed.
- iOS ad unit ids remain unconfigured (empty dart-define, no default) since no iOS AdMob app was created this session -- correctly inert on iOS rather than guessed.
- **Found and fixed a real, missed contract-test regression from this ads work, tonight**: a third contract test, `test/google_play_billing_contract_test.dart` (separate from the two already updated when the SDK was re-added), still asserted `nativeAdsCompiledIn = false` under a test named "ads remain disabled and advertising identifiers remain stripped" -- it was never touched during the ads reversal and was failing the full suite for real (confirmed with a genuine `[E]` failure and diff, not assumed). Fixed to assert `nativeAdsCompiledIn = true` under a renamed test, "ads ship for real, non-personalized-only, while IAP stays excluded" -- the AD_ID-stripping and IAP-exclusion assertions in the same test were still correct and left unchanged. Full suite reverified green afterward. |
| BACKEND | PASS (reverified live tonight) | 30/30 existing adversarial isolation checks + 2 new adversarial checks (job_private_locations direct access, get_released_job_location leakage), all against live production via real anon-key + session calls, zero findings. |
| RLS | PASS (reverified live tonight) | Same as BACKEND row. |
| EXPLOIT_PREVENTION | PASS (reverified live tonight) | Same as BACKEND row. |
| MODERATION | PASS (pre-existing, reverified live) | Reran `qa-moderation-legal-completion` live tonight: legal controls/inactive drafts/direct-write removal/hard activation trigger, coded job/review moderation with reason allowlists, access logging, ban-appeal isolation, assignment expiry, independent reversal. 0 findings. |
| LEGAL | PASS (drafts) / OWNER_ACTION_REQUIRED (counsel approval) | Reinspected rather than rebuilt -- `docs/legal/` already holds a comprehensive draft package (Terms of Service, Terms of Use, Privacy Policy, Community Guidelines, Child Safety Standards, Acceptable Use, Prohibited Work, Payment/Cancellation/Dispute policies, Data Retention and Deletion, Guardian Terms, Business Account Agreement, Evidence and Dispute Policy, Moderation and Appeals Policy, Location and Meeting Policy, Marketplace Risk Disclosure, Limitation of Liability, plus a dedicated `MORT_LEGAL_REVIEW_PACKET.md` counsel handoff) and `lib/features/legal/legal_screens.dart` renders/gates them with version-and-hash-bound clickwrap. Reran `qa-legal-clickwrap` live tonight (affirmative, teen-summary-first, version/hash-bound acceptance) -- PASS. These remain drafts pending qualified attorney/adult review before public-production launch, as they always have been; Claude is not a lawyer and this session does not claim legal compliance. |
| PLAY | PASS (prior session) | 0.9.16+107 approved on Closed testing - Alpha, 2026-08-18. Not re-touched tonight. |
| ACCOUNT_DELETION | PASS (pre-existing, reverified live) | Reran `qa-account-deletion` (remote create/status/cancel, cross-account read denied) and `qa-account-deletion-in-app` (easy to locate, reauthenticated, dedicated, status-aware) live tonight -- both PASS. `qa-account-deletion-processor` requires server-only/service-role environment variables not present in this session (correct -- this session does not handle service-role or database-password secrets) and was not run; the in-app + remote-request paths that engineering controls were verified instead. |
| REVIEWER_ACCESS | PASS (pre-existing, reverified live) | Reran `qa-play-reviewer-isolation` live tonight: reservation trigger enabled with no public execute grant, Auth Admin creation of the exact reviewer identifier denied, ordinary email/password auth unaffected, anonymous access cannot read profiles/messages/proof evidence, demo PINs rejected by production job-verification, destructive administration denied without a real authorized session. 0 findings. |
| DATA_SAFETY | PASS (pre-existing, reverified live) | Reran `qa-data-safety-inventory` live tonight: declared data categories and detected privacy-relevant Flutter SDKs are inventoried and consistent. |
| PUBLIC_LEGAL_WEB | **LIVE on Vercel** -- https://mort-legal.vercel.app/ | Corrected from an earlier, stale Netlify-oriented note: canonical hosting is Vercel, per explicit owner correction, not Netlify. Deployed live tonight via browser control (Vercel Drop, zip upload) to a new dedicated project, `mort-legal`, under the `mortapphelp-7067s-projects` team -- not connected to any Git repo (none exists for this content). All 13 routes verified live (200, no login, mobile-usable, correct branding), plus `/app-ads.txt` serving the real confirmed AdMob publisher line. Used real, non-fabricated config for the six required publisher/contact values (`MORT_PUBLIC_PUBLISHER_NAME=MORT` matching the actual registered Play Console developer name; `mortapp@googlegroups.com`, the real existing MORT contact group, reused across support/privacy/child-safety; the real `mort-web.vercel.app` as the website URL) -- `deploymentReady: true`, no blocker banner, and neither `legalApprovalClaimed` nor `publicDeploymentClaimed` is set to true anywhere. **Found and fixed a real, previously-undetected bug by actually testing the deployed site**: the account-deletion page's JS used a top-level `await` in a non-module `<script>` tag, throwing a `SyntaxError` that silently broke the entire real Supabase-backed deletion flow -- never caught before because the site had never been deployed and opened in a browser. Fixed, redeployed, reverified via console (no exceptions, form renders and is enabled). Added `vercel.json` header generation (replacing the Netlify-only `_headers` format) to the build script. Wired the real Privacy/Terms links (`/privacy/`, `/terms/`) plus the real home page (`mort-web.vercel.app`) into the Google OAuth consent screen branding (see GOOGLE_AUTH row) and added `mort-legal.vercel.app` to its authorized domains -- saved successfully. **Still owner-only**: entering these URLs into Play Console's actual Privacy Policy / account-deletion declaration fields (a real Play Store submission action, correctly not done unilaterally); optional custom domain; optionally splitting the three reused contact-email purposes into dedicated mailboxes; deleting two unused/abandoned Vercel projects from earlier attempts (`mort-legal-site`, `mort-legal-site-1`) -- deletion requires typing the project name to confirm, which the session's own destructive-action safety classifier correctly blocked when attempted, so this one cleanup step is left for the owner. Full detail in `docs/play-final/MORT_NETLIFY_LEGAL_DEPLOYMENT.md` (kept at its old filename/location for continuity, content fully rewritten). |
| ANDROID | NOT_STARTED | No device QA performed tonight (no UI changes yet to verify). |
| IOS | PASS (source parity audited and reverified live) | `ios/Runner/Info.plist` permission-usage descriptions checked against `AndroidManifest.xml` runtime permissions -- exact match (camera/notifications/biometric-FaceID/location, no unused entries either side); deep-link callback identity already covered by `google_auth_contract_test.dart` (`<string>com.mortapp.mobile</string>` in Info.plist). Reran `qa-ios-android-feature-parity` live: found and fixed a genuine stale check (script asserted the removed legacy `android:scheme="mort"` still existed, contradicting the deliberate hardening already verified by `google_auth_contract_test.dart`'s `isNot(contains('android:scheme="mort"'))` -- fixed to assert the current exact `com.mortapp.mobile` scheme and the legacy scheme's absence). Also found the 34-capability `MORT_PLATFORM_CAPABILITY_MATRIX.json` predated tonight's Leaderboard feature; added a MOB-035 record (pure shared Dart/RPC, no native code on either platform, so parity is exact by construction) and the matching required-capability entry in the QA script. Suite now passes at 35 records. No Xcode/TestFlight/App Store claim made -- physical iPhone verification remains explicitly pending on both new and pre-existing records, as the matrix already stated for every row. |
| PERFORMANCE | IN_PROGRESS (static pass clean; dynamic profiling device-gated) | Static audit performed since no device/profiler was reachable: no raw `ListView(children:...)` misuse found for dynamic data (all use `.builder`/`.separated`); all 3 `Image.network` call sites (`proof_review_screen.dart`, `profile_avatar_widgets.dart`, `support_screens.dart`) already bound decode size via a shared `imageDecodePixelsForContext` helper (`cacheWidth`/`cacheHeight`) and deliberately do NOT use `cached_network_image`'s persistent disk cache -- correct, since all three load privacy-sensitive signed URLs (proof photos, avatars, support attachments) that should not be persisted to disk beyond the signed link's lifetime; `cached_network_image` remains a dependency for other, non-sensitive uses. `analysis_options.yaml` already includes `package:flutter_lints/flutter.yaml` (covers `prefer_const_constructors`, `sized_box_for_whitespace`, etc.), and `flutter analyze` is already clean, so a manual const-audit would be redundant. No anti-patterns found; nothing changed. Genuine dynamic performance work (frame timing/jank, cold-start time, memory profiling under load) still requires a reachable physical device or attached DevTools session -- neither available this pass. |
| RELEASE | NOT_STARTED | No new artifacts built tonight -- no source change yet warrants a new signed build. |

## BLOCKERS

- No P0, no P1 currently open. Quick Accept's opt-in migration was
  owner-authorized and applied; the 25-simultaneous-claimant concurrency
  test passed live (exactly 1 success, 24 clean denials). The location
  architecture's backend is fully implemented and adversarially tested.
- Remaining external/owner-decision gates (not P0/P1 engineering
  blockers -- explicit product/business decisions): in-app routing/
  navigation SDK provider choice (Google Maps Platform vs Mapbox vs
  other -- pricing/ToS/API-key-security research still needed before
  picking one); AdMob account setup requiring adult publisher
  attestation; Google OAuth provider activation requiring the owner's
  Google Cloud Console (Web client + secret entered into the Supabase
  Auth provider dashboard -- see `docs/MORT_GOOGLE_AUTH_EXTERNAL_SETUP.md`,
  engineering side is 100% complete and tested); Apple OAuth provider
  activation requiring the owner's own Apple Developer Program membership
  (App ID capability, Services ID, Sign In with Apple key, Team ID/Key ID/
  private key entered into the Supabase Auth provider dashboard -- see
  `docs/MORT_APPLE_AUTH_EXTERNAL_SETUP.md`, engineering side is 100%
  complete and tested); any Play/legal step requiring the owner's own
  identity or payment action.

## COMPLETED_TODAY (2026-08-18 evening session)

- **Real bug fix, owner-reported and root-caused on-device**: Welcome
  screen's "I already have an account" was rendered behind, and had its
  touches intercepted by, the system navigation bar -- untappable in
  practice, making "Enter MORT" appear to always lead to sign-up.
  Root cause: primary CTAs lived in scrollable `children` rather than
  the safe-area-respecting pinned `bottom:` slot used elsewhere in the
  app; diagnosed with a temporary on-device MediaQuery debug readout,
  not guessed. Fixed by moving both CTAs to `bottom:`; verified via a
  real tap on-device that Sign In now opens correctly. Also added
  app-wide defense-in-depth (explicit edge-to-edge opt-in, SafeArea
  minimum floor) though the pinned-CTA restructure is what actually
  fixed it.
- Fresh adversarial re-verification: existing 30-check multi-user isolation
  suite, 30/30 PASS, zero regressions. Plus 2 new adversarial checks
  (`job_private_locations` direct access, `get_released_job_location`
  leakage to non-participants) -- 0 findings.
- `quick_accept_job_v1` (atomic, job-row-locked, self-serve single-worker
  claim RPC) applied to production, owner-authorized. First concurrency
  run surfaced a real gap (jobs has zero UPDATE RLS policies -- no way to
  set the opt-in column); fixed via a second migration extending
  `save_job_draft_or_publish`, currently pending the owner's apply action.
- Dashboard made the primary Teen bottom-nav destination, reusing the
  existing `RoleHomeScreen`, enriched with real active-job/nearby-work/
  safety sections. 5-destination nav (Dashboard, Jobs, Safety, Messages,
  Profile), no duplicate tabs. Found and fixed one genuine pre-existing
  test coupling this surfaced (verified as real, not a flake, by isolating
  the one-line change). Full suite green throughout.
- Precise on-demand location: full client-side service + UI gate built,
  13 new tests covering every requested scenario. Backend distance/
  matching found to be genuinely blocked on a real architectural gap (no
  coordinates anywhere in the schema -- needs a geocoding provider, a
  product/vendor decision) rather than built with a shortcut.

## POWER-LOSS RECOVERY (2026-08-19, continuation session)

Laptop lost power again. Recovery verified, not assumed: `git status --short`
was clean, HEAD was `341ad7e` (9 commits ahead of the last checkpoint noted
in the recovery directive, `adec690`) -- every commit in between (Leaderboard
backend+UI, Google Auth reverification, Transportation/Safety/Profile/
Notifications reverification, Ads/Legal/Account Deletion/Reviewer Access/
Data Safety/Moderation reverification, and the two QA-script bug fixes) was
already present and intact. No dirty files, nothing to recover, nothing
re-done. Wireless ADB retried again (`adb connect 192.168.1.1:5555` and
`adb devices -l`): still unreachable (error 10060, ADB daemon itself had to
restart, consistent with the fresh boot after power loss). Found and
reverified one more genuinely-already-built item not yet itemized on this
board: public legal/web resources deployment package (see PUBLIC_LEGAL_WEB
row, new tonight) -- item 16/19 of the owner's queue, engineering-complete,
blocked only on owner-provided contact emails and Netlify hosting
credentials.

## NEXT_AUTOMATIC_PHASE

Items 1-6 of the owner's "IMMEDIATE ORDER" are now all DONE or reverified:
job cards, Quick Accept UI, post-authorized navigation (JOBS/QUICK_ACCEPT/
EXACT_LOCATION), Leaderboard (LEADERBOARD), Transportation end-to-end
(TRANSPORTATION -- found already fully wired onboarding-to-job-feed, not
schema-only as previously noted), and Google Login + Google Sign-Up
(GOOGLE_AUTH -- found already fully engineered; only the owner's external
Google Cloud/Supabase provider activation remains). Messages, Safety
Center, Support, Profile/Settings, and Guardian (items 8-12) were also
found already built in prior sessions and reverified live tonight with
0 findings (one stale QA script bug found and fixed along the way -- see
SAFETY row). Notifications (item 13) likewise reverified live. Onboarding
polish (item 7) was audited: `CompactOnboardingScreen` is already mature
(pinned bottom CTAs, full resumability with field hydration, dirty-step
leave-confirmation, accessible reduced-motion transitions, legal
acceptance gating) -- no changes made without physical-device evidence of
a real problem. Physical smoke-verified twice on the Galaxy A14 (clean
boot, 0 crashes) across all changes so far; device unreachable again
tonight (wireless ADB down), retry continues.

Items 14-19 were also audited rather than assumed and found already built:
Ads/AdMob (item 14 -- engineering PASS, live serving OWNER_ACTION_REQUIRED),
account deletion (item 16), reviewer access (item 17), data safety
(item 18) all reverified live with 0 findings tonight. Legal/Play
production (item 15, item 19) found to already have a comprehensive draft
package (`docs/legal/`) plus a dedicated counsel-handoff packet -- these
remain drafts pending qualified attorney review, as intended; nothing
here claims legal compliance. Moderation was also reverified live
(0 findings) though not explicitly itemized in the original 25-item list.

Items 16/19 (public legal/web resources) and 20 (iOS source parity) are now
also DONE -- see PUBLIC_LEGAL_WEB and IOS rows above, both completed and
committed (`341ad7e` for iOS; PUBLIC_LEGAL_WEB reverified this recovery
session).

Genuinely remaining work, all requiring either a reachable physical
device or a new build/release action (cannot be faked or skipped):
1. **Full Android physical QA** (item 21/18): blocked again this session
   on wireless ADB reachability (`adb connect`/`adb devices -l` both came
   back empty, ADB daemon had to restart after the power loss). Retry
   continues; do not fake PHYSICAL_VERIFIED without a real device session.
2. **Performance profiling**: also genuinely NOT_STARTED -- requires a
   reachable device or a profiler, neither available yet.
3. **Final production regression** (item 22/19): full flutter test suite
   has been reverified clean at every checkpoint so far, but the true
   "final" pass belongs right before build/release, not now, since further
   changes are still expected.
4. **Final signed AAB/APK** (items 23-24/20) and **artifact verification**
   (item 25): hold until items 21/18 (device QA) and 22/19 (final
   regression) are genuinely done -- a new signed build today would not
   reflect a meaningfully different app than the already-approved
   0.9.16+107 Closed Testing build.
5. Owner decisions still pending (not engineering blockers): navigation
   SDK billing/API-key setup (Google Cloud), AdMob account setup
   (+ app-ads.txt hosting + consent/UMP flow), Google OAuth provider
   activation (Google Cloud + Supabase dashboard), qualified legal
   counsel review of the drafted documents, public legal/web site hosting
   (owner contact emails + Netlify credentials).
