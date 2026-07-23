# MORT Swift Migration Master Plan

Status date: 2026-07-14

This document records the migration track from the working Flutter product reference to a native iOS 17+ SwiftUI application. It is also the execution checklist for the Mac, iPhone, TestFlight, and policy gates that cannot be completed on Windows.

## Architecture decision

- Native iPhone app: `swift_mort`, Swift 5.9 language mode, SwiftUI, Observation, async/await, and an iOS 17 deployment target.
- Browser preview and functional reference: `flutter_mort`. It remains intact and deployable as Flutter Web/PWA.
- Earlier Expo reference: retained at the repository root.
- Backend: the existing hosted Supabase project `rakjydmgwwgtdislanbt`.
- Auth, PostgreSQL, RLS, Storage, Realtime, and Edge Functions: existing Supabase contracts.
- Native purchases: RevenueCat iOS SDK using a client-safe public iOS key supplied by Xcode configuration.
- Native ads: Google Mobile Ads, disabled in both current build configurations until consent, policy, and device verification are complete.
- Push: Apple permission and APNs registration architecture in Swift; delivery is not complete because the shared backend currently stores Expo tokens only.

No migration step in this track resets Supabase, drops data, removes migrations, or replaces the Flutter app.

## Source inventory reviewed

- `flutter_mort/lib`, `flutter_mort/test`, `flutter_mort/web`, and `flutter_mort/pubspec.yaml`
- `supabase/migrations`, `supabase/functions`, and `supabase/storage_setup.sql`
- Existing QA, security, RLS, RevenueCat, AdMob, push, privacy, and release documentation in `docs`
- Root scripts used for backend QA, secret scanning, and Windows checks

## Native project delivered

`swift_mort/MORT.xcodeproj` is a generated, shared-scheme Xcode project with:

- App bootstrap, dependency container, session store, typed router, and role shells
- Central design tokens and reusable SwiftUI controls/states
- Typed Supabase models, repository protocols, concrete repositories, and translated errors
- Auth, onboarding, age gate, profiles, jobs, applications, Guardian Mode, messaging, safety, proof, reviews, notifications, verification, support, settings, admin, RevenueCat, and AdMob source
- Asset catalog, 1024 px app icon, launch color, privacy manifest, permission copy, URL scheme, entitlements, and Debug/Release xcconfig files
- Unit tests and a launch UI test target

## Dependency policy

The generated Xcode project pins exact versions instead of floating major-version ranges:

| Package | Exact version |
| --- | --- |
| Supabase Swift | 2.51.0 |
| RevenueCat | 5.80.3 |
| Google Mobile Ads | 13.6.0 |

`Package.resolved` cannot be produced honestly without Swift Package Manager/Xcode on macOS. The Mac gate must resolve packages, inspect the resolution, and retain the generated lockfile.

## Security and privacy invariants

- Only the Supabase URL, public client key, RevenueCat public iOS key, and public AdMob IDs may enter the app build.
- No service-role key, database password, Supabase access token, RevenueCat secret, webhook secret, or AI provider key belongs in Swift, plist, xcconfig committed source, logs, or the migration zip.
- `Config/Secrets.xcconfig` is gitignored. `Config/Secrets.example.xcconfig` contains names only.
- RLS and server RPC authorization remain the security boundary. Swift role checks only shape navigation and user experience.
- All safety tools, basic applying, proof upload, blocking, reporting, Safety Ping, and basic Guardian Mode remain free.
- Payment settings are preference-only. There is no checkout, escrow, deposit, payout, or payment guarantee.
- Private image uploads are JPEG re-encodes that remove source metadata; bucket access still depends on Supabase Storage policies.
- Supabase leaked-password protection is classified separately as `DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT`; it is not a Swift code defect and no paid plan change is authorized.

## Migration gates

### Gate 1: Windows source construction - complete

- Real Xcode project structure generated.
- Shared `MORT` scheme created.
- Source membership and PBX brace balance inspected.
- Package APIs compared against the pinned SDK source.
- Local static audit passed.
- No Swift compiler, Xcode, iOS simulator, or iPhone execution was available.

### Gate 2: Mac compile and unit tests - required

- Install Xcode and resolve exact Swift packages.
- Add client-safe configuration in local `Config/Secrets.xcconfig`.
- Build Debug and Release configurations.
- Run all unit tests and UI smoke tests.
- Fix any Swift compiler, actor-isolation, SDK-import, signing, or resource-catalog issues found by Xcode.

### Gate 3: Hosted backend integration - required from the native app

- Test signup confirmation, PKCE callbacks, password recovery, session refresh, and signout.
- Exercise all four user roles with dedicated non-admin QA accounts.
- Confirm RLS denial from unrelated accounts for profiles, jobs, applications, messages, guardian data, reports, reviews, notifications, and private storage.
- Do not reset, drop, or reseed the hosted backend for this gate.

### Gate 4: Physical iPhone - required

- Verify camera, PhotosPicker, square avatar processing, proof and verification upload, signed images, keyboard behavior, deep links, accessibility, memory, offline/error states, and background/resume behavior.
- Verify notification permission and APNs registration. Delivery remains blocked until the additive native token/provider backend exists.
- Verify StoreKit/RevenueCat in sandbox with real App Store Connect products.
- Keep AdMob on test IDs and ads disabled until consent and policy work is accepted.

### Gate 5: Missing contracts - required before parity can be called complete

- Add a reviewed portfolio schema/RLS/API before enabling portfolio UI.
- Add a privacy-reviewed adult analytics contract before enabling analytics UI.
- Add proof review actions for approve, reject, and request-resubmission if product policy still requires them.
- Add a message read-state contract for real unread badges.
- Add APNs token storage, token rotation/revocation, provider delivery, and provider-to-resolver payload handoff without changing the Expo token semantics. The current in-app and `mort://notifications` destination resolver is implemented and covered by source tests.
- Add UMP/ATT consent handling and current Google SKAdNetwork entries before live ads.
- Add complete admin evidence/detail contracts for every moderation queue.
- Add a self-service deletion RPC only after retention, guardian, fraud, safety, and legal behavior is approved; the current app submits an auditable support request.

## Release gates

Before TestFlight, complete signing, capabilities, privacy manifests, App Store privacy answers, age rating, child/teen safety review, moderation operations, support response procedures, RevenueCat/App Store product linkage, APNs, and legal review. Before real users, complete a third-party security/privacy review and an end-to-end abuse-response exercise.

## Current conclusion

The Swift migration has a substantial source implementation and a real shared-backend contract layer. It is not production-ready. Mac compilation has not been performed, physical iPhone testing has not been performed, TestFlight has not been performed, and App Store/legal/teen-safety approval has not been performed.
