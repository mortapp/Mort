# MORT Android ↔ iOS production parity audit — 2026-09-20

Branch: `feature/ios-android-release-parity`

Authoritative client: `flutter_mort`. The secondary native Swift trees are reference/integration projects and are not allowed to replace the Flutter release contract.

## Executive state

This pass closes code-controlled iOS gaps that allowed Android CI/release work to advance without equivalent Xcode/App Store proof. It does **not** pretend external provider, legal, staffing, or signing approvals exist.

| Surface | Android | iOS after this pass | Release posture |
|---|---|---|---|
| Authoritative shared Flutter business logic | yes | yes | parity |
| Supabase/RLS/backend contracts | shared | shared | parity |
| Stripe PaymentSheet client | `flutter_stripe`, sandbox-gated | same shared implementation | parity; live Stripe still blocked |
| MORT Verify client/repository | shared | shared | parity; real minor-ID collection still disabled |
| OAuth callback | `com.mortapp.mobile://app/auth-callback` | same | parity |
| Google/Apple OAuth | browser PKCE | browser PKCE | parity |
| Sensitive-screen protection | Android FLAG_SECURE | iOS privacy shield on inactive/capture | platform-equivalent |
| Camera/photo/location/biometric permissions | native declarations | native usage descriptions | parity |
| Remote push client | Firebase FCM | Firebase FCM + APNs token bridge | code parity |
| Production push capability | Android manifest/runtime support | release/profile APNs entitlement + remote-notification mode | code parity; provider/signing still external |
| Crash reporting | shared Sentry gate | shared Sentry gate | parity |
| Ads | native AdMob | native AdMob | iOS stays non-personalized without ATT |
| Privacy manifest | N/A (Play data safety separately) | `PrivacyInfo.xcprivacy` bundled | App Store prep added |
| Normal CI device artifact | Android APK | unsigned iOS IPA | parity added |
| Normal native build gate | Gradle/Android | macOS + CocoaPods + Xcode release build | parity added |
| Signed store build automation | protected APK/AAB workflow | protected App Store Connect IPA workflow | parity added; real credentials required |
| Physical-device cloud QA | Android workflow | iOS BrowserStack deep/limited/floor workflow | both exist; exact-head evidence must be checked |
| Store signing | Android upload key required | Apple distribution cert/profile/team required | external |
| Real iOS AdMob IDs | Android real IDs already configured | iOS still uses Google sample app ID while ads are off | external before live iOS ads |

## Changes made

### App Store privacy

Added `flutter_mort/ios/Runner/PrivacyInfo.xcprivacy` and bundled it in the Runner resources. The app-owned manifest declares no tracking and records the app-owned data classes used by MORT. Third-party SDK manifests remain responsible for their own SDK collection and required-reason API declarations.

`Info.plist` now also declares `ITSAppUsesNonExemptEncryption=false` for the current HTTPS/TLS-only app cryptography posture.

### Push parity

Added release/profile-only `Runner.release.entitlements` with `aps-environment=production`, plus `UIBackgroundModes=remote-notification`.

The entitlement is intentionally not wired to Debug. Runtime push remains controlled by `MORT_REMOTE_PUSH_ENABLED` and complete Firebase client configuration; capability presence alone does not activate collection or notification registration.

### Ads / ATT fail-closed rule

The app declares no tracking and does not request ATT. Therefore iOS ad requests are forced non-personalized even if the server returns adult personalized-ad eligibility. Teens and unknown-age users were already server-enforced non-personalized on both platforms.

A future release that wants tracking/personalized iOS ads must separately add ATT, the correct user-facing usage string, matching privacy/App Store disclosures, and a reviewed policy change. This pass does not silently opt users into tracking.

### Authoritative iOS CI

`.github/workflows/mort-ci.yml` now contains an `ios-authoritative` macOS job. It:

- pins Flutter 3.47.2 and Xcode 16.2;
- runs format + analyze;
- runs iOS platform, Apple OAuth, Stripe, push, MORT Verify, payment OS integration, and monetization contracts;
- installs CocoaPods;
- validates the Xcode workspace and property lists;
- builds the current Flutter app as an unsigned iOS release with providers fail-closed;
- verifies bundle ID and bundled privacy manifest;
- packages and uploads an unsigned CI IPA.

This makes a future Flutter/Stripe/Verify change fail CI when it breaks iOS, rather than relying only on an occasional manual iOS workflow.

### Protected signed iOS release workflow

Added `.github/workflows/mort-ios-signed-closed-test.yml` as the iOS counterpart to the Android signed closed-test workflow.

It refuses to proceed without the real:

- Apple distribution P12;
- P12 password;
- App Store provisioning profile;
- Apple development team ID;
- temporary keychain password;
- approved MORT Supabase URL and anon key.

It validates the provisioning profile belongs to `com.mortapp.mobile`, belongs to the configured team, and includes production APNs. It then archives with `Apple Distribution`, verifies the signed app and entitlements, exports an App Store Connect IPA, hashes the artifact, and deletes temporary signing material.

No debug-signing fallback exists.

## Deliberate non-activations

This parity pass does **not** activate any of the following just to make a store build look complete:

- live Stripe marketplace payments or payouts;
- production MORT Verify collection of teen school IDs;
- public marketplace activation;
- live ads on iOS;
- native IAP;
- remote push without real Firebase/APNs configuration;
- crash reporting without a configured provider;
- legal documents that are still awaiting actual approval.

The code remains fail-closed where the real external prerequisite is absent.

## Known external gates after code parity

1. Apple Developer/App Store signing credentials and a provisioning profile for `com.mortapp.mobile` with Push Notifications enabled.
2. App Store Connect app record, privacy answers, age rating, review contact, screenshots/metadata, and TestFlight processing.
3. Real iOS AdMob app/ad-unit IDs before enabling iOS ads.
4. Firebase iOS app/APNs integration before enabling remote push in a production profile.
5. Live Stripe business/legal/tax/minor-payout approval before widening PaymentSheet beyond `pk_test_`.
6. Legal/privacy/reviewer operational approval before enabling real minor school-ID collection.
7. Moderation/support staffing before public marketplace activation.

## Council audit framework

The final PR certification must record four independent views:

- **Believer:** strongest evidence that one Flutter product now has enforceable Android/iOS parity rather than duplicated drifting clients.
- **Skeptic:** attack signing, APNs, ATT/ads, Stripe live-mode, MORT Verify, CocoaPods, privacy declarations, and exact-head device evidence.
- **Investor/operations:** determine whether remaining blockers are engineering defects or owner/provider/operations gates.
- **Judge:** only mark code parity complete when exact-head CI is green; never call external gates complete without direct evidence.

## Certification rule

No parity claim is final until the exact PR head passes the new `ios-authoritative` job and the existing MORT CI suite. Signed App Store distribution remains a separate credential-backed gate.
