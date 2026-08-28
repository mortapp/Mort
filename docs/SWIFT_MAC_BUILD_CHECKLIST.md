# MORT Swift Mac Build Checklist

The Windows migration pass did not compile Swift, run Xcode, run an iOS simulator, sign an app, or test an iPhone. Complete every applicable item below on a trusted Mac before treating the native app as testable.

## 1. Mac prerequisites

- Install the current supported Xcode 16 release and its iOS platform components.
- Accept the Xcode license and install command-line tools.
- Install Node.js only if regenerating the project after adding/removing Swift files.
- Use an Apple Developer team when physical-device/TestFlight signing becomes available.

```bash
xcodebuild -version
swift --version
xcode-select -p
```

## 2. Transfer and inspect

```bash
cd /path/to/Mort/swift_mort
find . -name '.env' -o -name '.env.local' -o -name 'Secrets.xcconfig'
open MORT.xcodeproj
```

Expected source state: no `.env`, `.env.local`, committed `Secrets.xcconfig`, Pods, DerivedData, or build output. Do not place server-only credentials on the Mac project.

## 3. Add client-safe local configuration

```bash
cd /path/to/Mort/swift_mort
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
open -e Config/Secrets.xcconfig
```

Fill only:

```text
MORT_SUPABASE_URL
MORT_SUPABASE_ANON_KEY
MORT_REVENUECAT_IOS_API_KEY
```

The Supabase value must be the hosted HTTPS project URL. Use only a public client/anon key and the RevenueCat public iOS SDK key. Never add a service-role key, database password, Supabase access token, RevenueCat secret API key, webhook secret, or AI key.

## 4. Configure Supabase Auth redirects

In Supabase Auth URL configuration for project `rakjydmgwwgtdislanbt`, allow the exact native callbacks used by the app:

```text
mort://auth/callback
mort://auth/confirmation
mort://auth/recovery
```

Do not replace existing Flutter Web redirect URLs. Test email confirmation and password recovery using a dedicated QA account.

## 5. Regenerate only after source membership changes

The committed project already contains all current sources. If files are added or removed, run:

```bash
cd /path/to/Mort/swift_mort
node Scripts/generate-xcode-project.mjs
```

Regeneration must preserve `MORT.xcodeproj/xcshareddata/xcschemes/MORT.xcscheme`. Review `git diff` or a directory diff after regeneration.

## 6. Resolve exact packages

```bash
cd /path/to/Mort/swift_mort
xcodebuild -list -project MORT.xcodeproj
xcodebuild -resolvePackageDependencies -project MORT.xcodeproj -scheme MORT
```

Confirm exact resolved versions:

- Supabase Swift 2.51.0
- RevenueCat 5.80.3
- Google Mobile Ads 13.6.0

Retain the generated `Package.resolved` after review. Do not silently update a package during a release candidate.

## 7. Simulator compile and tests

Choose an installed simulator name from `xcrun simctl list devices available`. Example commands:

```bash
cd /path/to/Mort/swift_mort
xcodebuild \
  -project MORT.xcodeproj \
  -scheme MORT \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO \
  clean build

xcodebuild \
  -project MORT.xcodeproj \
  -scheme MORT \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  test

xcodebuild \
  -project MORT.xcodeproj \
  -scheme MORT \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Capture the complete logs. Fix every compiler error and all actionable concurrency, deprecation, privacy-manifest, asset-catalog, and package warning. Rerun all commands after fixes.

## 8. Xcode project review

- Bundle identifier: `com.mortapp.mobile`.
- Deployment target: iOS 17.0 or later.
- App icon renders at all required contexts with no alpha-channel rejection.
- URL scheme: `mort`.
- Debug APNs entitlement resolves to `development`; Release resolves to `production`.
- Push Notifications capability is enabled for the signed App ID.
- Background Modes includes Remote notifications only if the product actually needs it.
- In-App Purchase capability is enabled before sandbox purchase testing.
- Camera, Photos, tracking, and notification copy matches real behavior.
- Ads remain disabled and test ads remain enabled in current configurations.

Inspect effective settings:

```bash
xcodebuild -project MORT.xcodeproj -scheme MORT -configuration Debug -showBuildSettings
xcodebuild -project MORT.xcodeproj -scheme MORT -configuration Release -showBuildSettings
```

Ensure logs do not expose client keys unnecessarily. Even client-safe keys should not be pasted into tickets or public logs.

## 9. Hosted Supabase integration QA

Use separate teen, adult/business, guardian, unrelated-user, and admin QA accounts. Do not grant admin through client metadata and do not reset the project.

- Signup, confirmation, signin, restore, refresh, recovery, signout, and restricted-account routing.
- Teen/adult/guardian age boundaries and invalid DOB cases.
- Guardian invite, code acceptance, resend, cancel, unlink, preference changes, pause/resume, and skip.
- Feed, filters, QA exclusion, save/unsave, job detail, draft/publish, and every lifecycle action.
- Eligibility, apply, guardian approval when explicitly required, adult review, withdraw/start/complete, and timeline.
- Safe message send, flagged/blocked results, paging, Realtime, report, block, and unblock.
- Safety Ping authorization and guardian preference isolation.
- Avatar/proof/verification private upload, signed URL expiry, replacement, and cross-account denial.
- Reviews, notifications, support tickets, activity history, username credit, job boost, ad eligibility, and admin authorization.

For every sensitive object, test an unrelated authenticated account and confirm RLS denies read/write access.

## 10. Physical iPhone QA

- Install a Debug build on at least one current iPhone and one older supported iPhone class if available.
- Verify fresh install, background/resume, expired sessions, interrupted network, offline recovery, Dynamic Type, VoiceOver labels, Reduce Motion, contrast, and keyboard avoidance.
- Test camera permission denied/allowed, Photos limited access, large images, purpose-specific camera compression, orientation, interactive pan/zoom crop bounds, metadata removal, square avatar output, replacement, and upload interruption.
- Test email links opened from Mail into MORT for confirmation and recovery.
- Test notification permission denied/allowed and APNs registration. Do not claim delivery until native token persistence/provider work is deployed.
- Confirm no ads appear on auth, onboarding, messages, safety, Guardian approval, proof, verification, payment, admin, or paywall screens.

## 11. RevenueCat and App Store Connect

- Create/link all nine App Store products with the exact product identifiers documented for MORT.
- Configure RevenueCat entitlements, offerings, packages, public iOS key, webhook, and App Store credentials.
- Use StoreKit sandbox/TestFlight accounts to test successful purchase, user cancellation, Ask to Buy where applicable, pending purchase, restore, subscription management, expiration, refund, and cross-device restore.
- Confirm the backend webhook, not local UI state, controls durable entitlements.
- Confirm displayed prices are RevenueCat/App Store localized strings.
- Review teen purchase disclosures and guardian expectations with counsel/policy reviewers.

## 12. AdMob and consent

Ads are not release-enabled. Before changing that:

- Integrate and test Google UMP consent where required.
- Add an approved ATT request strategy only if tracking is actually used.
- Refresh the complete Google SKAdNetwork identifier list from current official documentation.
- Verify child/teen-directed settings, age restrictions, content rating, non-personalized request behavior, frequency caps, sensitive-screen exclusions, and ad-free entitlement behavior.
- Test only Google test ad units until policy signoff. Never click live ads during QA.

## 13. APNs completion

The current `push_tokens` column and `send-push` function are Expo-specific. Before native push delivery:

- Add a migration for native APNs device tokens, environment, app bundle, device identifier strategy, last-seen time, active/revoked state, and token rotation.
- Add owner-only RLS or a narrowly authorized registration RPC.
- Deploy a server-side APNs provider using server-only credentials.
- Add delivery receipts/failure cleanup and notification routing.
- Test development and production APNs separately on physical devices.
- Preserve existing Expo delivery for Flutter/Expo clients.

## 14. Privacy, legal, safety, and TestFlight

- Review `PrivacyInfo.xcprivacy` against actual SDK manifests and runtime behavior.
- Complete App Store privacy nutrition answers, age rating, terms, privacy policy, account deletion policy, moderation/reporting SLA, child/teen safety, guardian disclosures, AI transparency, advertising disclosures, and purchase disclosures.
- Complete a security review, abuse-response drill, and support escalation test.
- Archive only after all prior gates pass.

```bash
xcodebuild \
  -project MORT.xcodeproj \
  -scheme MORT \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/build/MORT.xcarchive" \
  clean archive
```

Upload through Xcode Organizer after signing, archive validation, policy review, and an authorized App Store Connect setup. TestFlight and App Store status remain incomplete until Apple actually accepts and processes a build.
