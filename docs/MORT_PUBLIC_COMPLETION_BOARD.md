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
| AUTH | PASS (pre-existing, reverified) | Email/password + Google OAuth both live in `UnifiedAuthScreen`; see GOOGLE_AUTH row for detail. |
| GOOGLE_AUTH | PASS (engineering) / BLOCKED_EXTERNAL (live activation) | Reinspected rather than rebuilt -- Google Auth was already comprehensively engineered in a prior session: `GoogleAuthSection` renders on both Sign In and Create Account (`unified_auth_screen.dart:382`, gated only by reviewer-mode, not by sign-in/sign-up), Supabase Auth + PKCE (`authFlowType: AuthFlowType.pkce`), canonical deep-link callback `com.mortapp.mobile://app/auth-callback` wired in `app_router.dart`, `AndroidManifest.xml`, and iOS `Info.plist`. `auth_repository.dart` handles: launch-gate against duplicate taps, 3-minute/30-second timeouts, provider-cancel, offline/network-unavailable classification, invalid/error callback rejection, cold/warm/delayed session events via `AuthChangeEvent.initialSession/signedIn/userUpdated`, idempotent `_completionGate`-guarded profile bootstrap (`ensure_my_profile` RPC), suspended-account and deletion-pending blocking, Google link/unlink with 15-minute recent-auth window + password reauth fallback, and full sign-out (local/global) with OAuth-state cleanup. `test/google_auth_contract_test.dart`: 13/13 PASS (verified live tonight), covering PKCE-only tokens (no `signInWithIdToken`/provider-token storage), exact callback identity across Dart/Android/iOS, closed-test build scripts already pass `-GoogleAuthEnabled $true`, onboarding/role guards preserved, idempotent profile-bootstrap trigger, no embedded secrets. Genuinely remaining is external-only and already documented in `docs/MORT_GOOGLE_AUTH_EXTERNAL_SETUP.md`: the owner must create a Google Cloud OAuth consent screen + Web client and enter the Client ID/Secret into the Supabase Auth provider dashboard (`Web client ID entered in Supabase: NOT CONFIGURED`, `Google provider enabled: NOT CONFIGURED`) -- this cannot and must not be done by fabricating or handling real OAuth credentials. Installed-APK login/linking/deletion end-to-end tests stay `BLOCKED BY PROVIDER SETUP` until that owner step completes. |
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
| ADS | PASS (engineering) / BLOCKED_EXTERNAL (live ad serving) | Reinspected rather than rebuilt -- `lib/features/ads/` (data + widgets), `AppConfig.adsEnabled`/`nativeAdsCompiledIn = false` gate, and dedicated docs (`ADMOB_SETUP.md`, `ADMOB_FINAL_SETUP.md`, `ADMOB_SCREEN_ELIGIBILITY_MATRIX.md`, `ADS_AND_IAP_SAFETY.md`) already exist. Reran 3 live adversarial suites tonight: `qa-admob-disabled-mode` (SDK/runtime stays disabled, Android advertising ID stripped while unconfigured), `qa-sensitive-ad-placement` (auth/safety/messaging/proof/verification/payment/admin/paywall all correctly reject ads), `qa-teen-ad-treatment` (teen and unknown-age traffic forced non-personalized + age-restricted). 0 findings. Rewarded ads remain optional by design (paywall QA covers this). Native ad rendering/live serving is correctly gated off pending the owner's AdMob account setup + app-ads.txt hosting + consent/UMP flow -- `ADULT_OWNER_ACTION_REQUIRED`, matches the Google Auth pattern; do not enable until that owner step completes. |
| BACKEND | PASS (reverified live tonight) | 30/30 existing adversarial isolation checks + 2 new adversarial checks (job_private_locations direct access, get_released_job_location leakage), all against live production via real anon-key + session calls, zero findings. |
| RLS | PASS (reverified live tonight) | Same as BACKEND row. |
| EXPLOIT_PREVENTION | PASS (reverified live tonight) | Same as BACKEND row. |
| MODERATION | PASS (pre-existing, reverified live) | Reran `qa-moderation-legal-completion` live tonight: legal controls/inactive drafts/direct-write removal/hard activation trigger, coded job/review moderation with reason allowlists, access logging, ban-appeal isolation, assignment expiry, independent reversal. 0 findings. |
| LEGAL | PASS (drafts) / OWNER_ACTION_REQUIRED (counsel approval) | Reinspected rather than rebuilt -- `docs/legal/` already holds a comprehensive draft package (Terms of Service, Terms of Use, Privacy Policy, Community Guidelines, Child Safety Standards, Acceptable Use, Prohibited Work, Payment/Cancellation/Dispute policies, Data Retention and Deletion, Guardian Terms, Business Account Agreement, Evidence and Dispute Policy, Moderation and Appeals Policy, Location and Meeting Policy, Marketplace Risk Disclosure, Limitation of Liability, plus a dedicated `MORT_LEGAL_REVIEW_PACKET.md` counsel handoff) and `lib/features/legal/legal_screens.dart` renders/gates them with version-and-hash-bound clickwrap. Reran `qa-legal-clickwrap` live tonight (affirmative, teen-summary-first, version/hash-bound acceptance) -- PASS. These remain drafts pending qualified attorney/adult review before public-production launch, as they always have been; Claude is not a lawyer and this session does not claim legal compliance. |
| PLAY | PASS (prior session) | 0.9.16+107 approved on Closed testing - Alpha, 2026-08-18. Not re-touched tonight. |
| ACCOUNT_DELETION | PASS (pre-existing, reverified live) | Reran `qa-account-deletion` (remote create/status/cancel, cross-account read denied) and `qa-account-deletion-in-app` (easy to locate, reauthenticated, dedicated, status-aware) live tonight -- both PASS. `qa-account-deletion-processor` requires server-only/service-role environment variables not present in this session (correct -- this session does not handle service-role or database-password secrets) and was not run; the in-app + remote-request paths that engineering controls were verified instead. |
| REVIEWER_ACCESS | PASS (pre-existing, reverified live) | Reran `qa-play-reviewer-isolation` live tonight: reservation trigger enabled with no public execute grant, Auth Admin creation of the exact reviewer identifier denied, ordinary email/password auth unaffected, anonymous access cannot read profiles/messages/proof evidence, demo PINs rejected by production job-verification, destructive administration denied without a real authorized session. 0 findings. |
| DATA_SAFETY | PASS (pre-existing, reverified live) | Reran `qa-data-safety-inventory` live tonight: declared data categories and detected privacy-relevant Flutter SDKs are inventoried and consistent. |
| ANDROID | NOT_STARTED | No device QA performed tonight (no UI changes yet to verify). |
| IOS | PASS (source parity audited and reverified live) | `ios/Runner/Info.plist` permission-usage descriptions checked against `AndroidManifest.xml` runtime permissions -- exact match (camera/notifications/biometric-FaceID/location, no unused entries either side); deep-link callback identity already covered by `google_auth_contract_test.dart` (`<string>com.mortapp.mobile</string>` in Info.plist). Reran `qa-ios-android-feature-parity` live: found and fixed a genuine stale check (script asserted the removed legacy `android:scheme="mort"` still existed, contradicting the deliberate hardening already verified by `google_auth_contract_test.dart`'s `isNot(contains('android:scheme="mort"'))` -- fixed to assert the current exact `com.mortapp.mobile` scheme and the legacy scheme's absence). Also found the 34-capability `MORT_PLATFORM_CAPABILITY_MATRIX.json` predated tonight's Leaderboard feature; added a MOB-035 record (pure shared Dart/RPC, no native code on either platform, so parity is exact by construction) and the matching required-capability entry in the QA script. Suite now passes at 35 records. No Xcode/TestFlight/App Store claim made -- physical iPhone verification remains explicitly pending on both new and pre-existing records, as the matrix already stated for every row. |
| PERFORMANCE | NOT_STARTED | Not touched tonight. |
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
  engineering side is 100% complete and tested); any Play/legal step
  requiring the owner's own identity or payment action.

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

Genuinely remaining work, all requiring either a reachable physical
device or a new build/release action (cannot be faked or skipped):
1. **iOS source parity** (item 20): audit for drift against the latest
   Android/Dart changes (Leaderboard, Transportation matching, Google
   Auth reverification) -- likely already carried since this session's
   pattern has been Dart-shared logic with platform config parity, but
   needs an explicit pass, not an assumption.
2. **Full Android physical QA** (item 21): blocked tonight on wireless
   ADB reachability (`adb connect`/`adb mdns services` both came back
   empty). Retry continues; do not fake PHYSICAL_VERIFIED without a real
   device session.
3. **Final production regression** (item 22): full flutter test suite
   already reverified clean tonight (398/0/2) as part of the checkpoint
   process, but the true "final" pass belongs right before build/release,
   not now, since further changes are still expected.
4. **Final signed AAB/APK** (items 23-24) and **artifact verification**
   (item 25): hold until items 20-22 are genuinely done -- a new signed
   build today would not reflect a meaningfully different app than the
   already-approved 0.9.16+107 Closed Testing build.
5. Owner decisions still pending (not engineering blockers): navigation
   SDK billing/API-key setup (Google Cloud), AdMob account setup
   (+ app-ads.txt hosting + consent/UMP flow), Google OAuth provider
   activation (Google Cloud + Supabase dashboard), qualified legal
   counsel review of the drafted documents.
