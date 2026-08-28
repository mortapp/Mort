# MORT Swift Migration Final Report

Status date: 2026-07-17

## Outcome

The native project is at `C:\Users\micha\Mort\swift_mort` with bundle identifier `com.mortapp.mobile` and an iOS 17 minimum target. Flutter remains at `C:\Users\micha\Mort\flutter_mort`; the Expo reference and hosted Supabase backend remain intact.

This is a serious source migration, not a production-readiness declaration. The Windows host has no Swift compiler or Apple toolchain, so Xcode compilation, simulator execution, signing, physical iPhone testing, TestFlight, and App Store review remain undone.

## Source delivered

- 83 app Swift files
- 9 unit-test Swift files containing 36 test methods
- 1 UI-test Swift file containing 1 launch test
- 51 feature `View`/`Screen` struct declarations, plus reusable design-system views
- A generated `MORT.xcodeproj` with all app/test source membership present
- A shared `MORT.xcscheme`
- Exact Swift package requirements for Supabase Swift 2.51.0, RevenueCat 5.80.3, and Google Mobile Ads 13.6.0
- App icon, accent/launch assets, Info.plist, entitlements, privacy manifest, and Debug/Release configuration

## Implemented application areas

- Supabase signup, email confirmation state, signin, signout, PKCE password recovery, session restore, account restriction routing, and nonflashing native restore state
- Corrected DOB typing/date-picker flow with date-only storage, leap-year validation, future-date rejection, timezone-safe age calculation, and teen/adult role boundaries
- Incremental teen, adult, business-subtype, and guardian onboarding; optional Guardian Mode does not block normal teen use
- Role-specific teen, adult/business, guardian, and admin tabs with typed navigation
- Profile editing, skills, availability, categories, goals, adult/business details, guardian emergency contact, and custom avatars with a bounded pan/zoom crop UI
- Job feed/search/filter/sort/pagination/saved state, real detail/eligibility, eight-step creation, drafts, publishing, lifecycle management, and job boost credits
- Teen applications, adult review, guardian approval where the job explicitly requires it, status timelines, withdrawal, start, private proof submission, poster proof approval/resubmission/rejection, proof-gated completion, and reviews
- Conversation list, participant-specific unread badges/read cursors, paged thread, Supabase Realtime refresh, safe-message RPC, scanner results, reporting, and blocking
- Report/block/unblock, Safety Ping, Guardian Mode connection/preferences/pause, Safety Center, emergency boundary, and AI transparency
- In-app notifications with tested role-aware destinations and `mort://notifications` URL routing, support tickets, activity history, business verification, payment preferences, username credits, settings, legal drafts, and account-deletion support requests
- RevenueCat native configuration/identity, CustomerInfo, offerings, localized price strings, purchase/cancel/restore, entitlement mapping, and Customer Center source
- Optional native paywall that keeps safety/basic use free and never locally fakes purchase success
- Google Mobile Ads backend eligibility, test/live ID selection, sensitive-screen denial, ad-free handling, banner source, and rewarded load/present service; ads remain disabled
- Server-authorized admin dashboard, profile list, queues, moderation updates, and monetization overview where contracts exist

## Supabase repositories

Concrete repository protocols/implementations exist for Auth, Profile, Job, Saved Job, Application, Message, Guardian, Safety, Notification, Review, Support, Verification, Storage, Monetization, and Admin. `PortfolioRepository` exists only to return an explicit unavailable error because the shared backend has no portfolio contract.

The native client statically maps 22 direct public tables, 29 RPCs, four private storage buckets, Realtime message changes, and the `avatar-url` Edge Function. RLS and server-side RPC checks remain authoritative. This migration pass performed no backend reset, table drop, migration removal, or destructive data action.

## Native push status

The app can request iOS notification permission, register for remote notifications, receive an APNs device token in memory, and distinguish Debug (`development`) from Release (`production`) APNs entitlements. It intentionally does not write that token to `push_tokens.expo_push_token`.

End-to-end native push is not implemented. It requires an additive APNs token contract, token lifecycle/RLS, APNs provider, production credentials, delivery cleanup, and provider-to-resolver payload handoff while preserving the existing Expo delivery path. In-app notification rows and `mort://notifications` URLs already use the shared typed resolver.

## RevenueCat and paywall status

The public iOS SDK integration is present and no RevenueCat secret is in the project. Durable access is mapped from RevenueCat CustomerInfo and existing backend webhook/cache contracts, not a local purchase flag. Real package price strings are displayed.

Mac compilation, App Store Connect product linkage, RevenueCat public key injection, StoreKit sandbox transactions, Ask to Buy/pending/refund/restore behavior, webhook observation, and physical-device testing remain required.

## AdMob status

The public app/banner/rewarded IDs are configured, Google test IDs are selected for development, and both Debug and Release currently set ads off. Banner code records an impression only after the SDK receive callback. Sensitive placements and ad-free accounts are denied before an SDK request.

Live ads must not be enabled yet. UMP/ATT runtime consent, current SKAdNetwork entries, teen/child-directed policy configuration, content-rating review, frequency behavior, test-device verification, and physical iPhone testing remain incomplete. The rewarded service has no approved user-facing placement.

## Static verification run

| Verification | Real result |
| --- | --- |
| `node .\Scripts\generate-xcode-project.mjs` | Generated project with 83 app, 9 unit-test, and 1 UI-test sources |
| `.\Scripts\static-audit.ps1` | Passed; no local env/secrets/build junk in `swift_mort` |
| Xcode project membership | 83 app sources found; 0 missing |
| PBX structure | 258 opening and 258 closing braces |
| Shared scheme | XML parsed and target identifier exists |
| Resource parsing | 4 XML resources and 4 asset JSON manifests parsed |
| App icon | 1024x1024 PNG, sRGB, TrueColor, no alpha channel reported |
| Package requirements | 3 exact pins; no up-to-next-major requirement |
| Root `scripts\secret-scan.ps1` | Passed source scan; no JWT-like key or mobile service-role exposure found |
| Apple/Swift tools | `swift`, `swiftc`, `xcodebuild`, `xcrun`, XcodeGen, and Tuist all unavailable |

No Swift tests were executed because XCTest and Xcode are unavailable on Windows.

## Defects fixed during migration

- Registered auth URL scheme and Supabase recovery URL did not match; all callbacks now use `mort://`.
- Supabase deep-link helper swallowed callback errors; recovery now awaits the PKCE `session(from:)` parser.
- Message paging returned a reversed collection instead of the declared array.
- Activity `ForEach` used removed tuple-parameter destructuring syntax.
- Guardian preference toggles captured stale local values; bindings now mutate the stored preference model.
- A guarded core-error fallback still used a forced unwrap; it was removed.
- Storage used a deprecated upload overload; it now uses the current data upload signature.
- App entry actor isolation was implicit; `MORTApp` is explicitly main-actor isolated.
- RevenueCat setup failure could block account routing; optional purchase failure is now nonblocking.
- Avatar/proof/verification paths now resolve the authenticated user before path construction.
- DOB age math was made date-only and timezone safe.
- Silent `try?` JSON probing was replaced with explicit decoding attempts.
- Hashability/equality requirements for typed navigation and action state were completed.
- Newly added profile source was missing from the previously generated project; regeneration includes it.
- The project had no committed shared scheme; command-line build/test now has a deterministic `MORT` scheme.
- Swift package ranges floated; all three top-level packages are exact-pinned.
- APNs entitlement was development-only; Debug/Release now resolve to development/production respectively.
- Notification routing was duplicated inside the view and not testable; one pure resolver now covers every payload identifier emitted by the current migrations.
- Admin support, safety-ping, review, and report notifications could open user or generic activity screens; they now open their authorized admin queues.
- Profile verification notifications use `verificationStatus`, while the prior view checked only `verificationId`; both backend variants now resolve correctly.
- Avatar selection previously forced an automatic center crop; users can now pan, pinch or slide to zoom, reset, and confirm the crop before upload.
- Large camera/library images were decoded at full resolution before downsizing; ImageIO now applies orientation-aware downsampling before display and processing.
- Camera capture encoded every photo at full JPEG quality, which could exceed avatar/proof limits before processing; capture is now resized and quality-stepped for its avatar, proof, or verification purpose and surfaces failures to the active screen.
- Flutter proof review originally referenced a view-local `job` outside its scope; the action guard now reads `application.job?.proofExpected` and Flutter analyze passes.
- The isolated proof-review QA fixture used a `.png` path while the hardened submission contract correctly requires canonical JPEG; the fixture now uploads a real tiny JPEG under a `.jpg` path without weakening the backend.

## Parity

The audited source-level Flutter-to-Swift parity is **90.0% (54 of 60 feature units)**. Partial and missing units are not counted. This percentage says only that concrete Swift source exists; it gives no credit for Mac build, simulator, iPhone, TestFlight, or policy approval because none occurred.

## Remaining product gaps

- Portfolio backend/UI
- Privacy-reviewed adult analytics backend/UI
- Native APNs persistence/provider/delivery
- Approved rewarded-ad placement and reward semantics
- Google UMP/ATT runtime consent and complete ad-policy setup
- Full admin evidence/detail/action contracts
- Self-service account deletion after retention/safety/legal rules are approved; current behavior creates a real support request
- Byte-level upload progress; current UI reports preparation and transactional upload stages

## Required next gates

### Mac/Xcode

Resolve packages and create `Package.resolved`; add client-safe local config; compile Debug and Release; run 22 unit and 1 UI test methods; inspect concurrency/deprecation/privacy warnings; validate assets, signing, capabilities, and archives.

### Physical iPhone

Test fresh install/session recovery, email and `mort://notifications` deep links, notification-row destinations for every role, camera/Photos permissions, image orientation and uploads, signed URLs, keyboard/layout/accessibility, Realtime/background behavior, APNs registration, RevenueCat sandbox, StoreKit restore/pending/cancel, and Google test ads after consent work.

### TestFlight and App Store

An authorized Apple Developer account, signing/App ID capabilities, App Store Connect record, product setup, RevenueCat linkage, archive upload, TestFlight processing/review, App Privacy answers, age rating, legal documents, moderation operations, teen-safety review, purchase disclosures, ad disclosures, and account-deletion policy are still required.

## Honest conclusion

The Swift project is a substantial, backend-aware native migration package and the Flutter web/reference app remains intact. The native backend integration is statically mapped, not device-verified. The app is not production-ready, has not passed Xcode, has not run on an iPhone, has not entered TestFlight, and has not passed App Store/legal/privacy/teen-safety review.
