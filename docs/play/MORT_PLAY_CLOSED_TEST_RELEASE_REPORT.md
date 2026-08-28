# MORT Google Play Closed-Test Release Report

Generated: 2026-07-20

## Classification

- Release stage: `closed_test`
- Operational mode: `closed_pilot`
- Public marketplace: disabled
- Real identity-document verification: disabled
- RevenueCat, Google Play Billing, AdMob, and remote push delivery: disabled for this candidate
- Status: signed closed-test publication candidate, not publicly launched and not production-ready

## Android Candidate

- Package: `com.mortapp.mobile`
- Version: `0.9.0` (`versionCode` 90)
- Minimum SDK: 24
- Target SDK: 36
- AAB: `build/play/mort-closed-test.aab`
- AAB bytes: 57,529,261
- AAB SHA-256: `F14F2CC93AC469DC622E43B8F06A9FC99D5CAFC2D5045484E753FB3862271317`
- QA APK: `build/play/mort-play-closed-test-qa.apk`
- QA APK bytes: 70,561,430
- QA APK SHA-256: `A8B082137477B02E38483C67EC2C1106BAC49FDAC5661C319F8C94637F01F3E4`
- Upload certificate SHA-1: `7F:3E:52:5C:05:F3:D8:72:C1:68:63:08:EA:F2:79:5A:8E:96:D9:97`
- Upload certificate SHA-256: `04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF`
- Signing verification: passed; signer exactly matches the protected MORT upload certificate
- Debug signing rejection: passed
- Obfuscation: enabled; symbols retained outside the repository under `C:\Users\micha\MortSymbols\android\0.9.0+90`

The bundle is cryptographically prepared for a Play Console upload. Play Console acceptance was not performed. The account owner must confirm that version code 90 is greater than every prior upload before submitting it.

## Permission Result

The final AAB contains 10 manifest permission entries: Internet, network state, camera, notifications, biometric/fingerprint, foreground coarse and fine location, vibration, and Android's package-scoped dynamic receiver permission. It contains no background location, broad media access, billing, advertising ID, AdServices, foreground-service, or wake-lock permission.

Location is requested only from a user-initiated nearby or safety flow, with manual-area fallback. The closed-test manifest contains no Google Mobile Ads provider, activity, service, or auto-initialization metadata.

## Verification Results

- `dart format lib test`: passed
- `flutter analyze --no-pub`: passed, no issues
- `flutter test --no-pub`: passed, 83 tests
- Android API 36 native integration smoke: passed after a clean emulator install
- Signed QA APK install/start smoke: passed; process stayed foregrounded with zero package fatal log matches
- Flutter web release build: passed against hosted Supabase with closed-pilot flags
- Expo reference app Windows gate: TypeScript passed, Expo lint passed, 48-route web export passed, Expo Doctor 20/20
- Linked Supabase `public` schema lint: zero errors
- Complete multi-user isolation: 30/30 checks passed; disposable users removed
- Play release QA: all checks passed, including under-13 rejection, report/block enforcement, deletion, marketplace lock, AAB secret scan, and AAB signing
- Public legal site: seven required routes returned HTTP 200 without authentication
- Source secret scan: passed

No physical Android device was used. Emulator testing is not physical-device testing.

## Bugs Found And Fixed

1. Removing the AdMob App ID while leaving `MobileAdsInitProvider` enabled caused an immediate Android release startup crash. All AdMob manifest components and optimization metadata are now removed for the no-ads closed test, and QA asserts the provider is absent.
2. The release welcome screen exposed Flutter, Supabase, Dart-define, RLS, and `service_role` implementation language. Active tester-facing copy now uses product and safety language with one global Closed Pilot marker.
3. Repeated deletion QA exhausted the intentional three-per-day rate limit on a persistent reviewer account. The test now uses disposable isolated accounts and protected database cleanup without weakening the production rate limit.
4. The first integration rerun tried to install a debug test APK over the upload-signed QA APK. The emulator-only signed package was removed and the warm integration run passed.
5. A prior deletion migration could not resolve `digest` because `pgcrypto` is installed in `extensions`. The additive search-path migration fixed the remote function without a reset or dropped data.
6. Two legacy setup documents contained the configured RevenueCat iOS SDK value. The value was replaced with an environment-variable reference, and the final archives were rescanned against reviewer, signing, Supabase, RevenueCat, and webhook values.

## Policy And Safety State

The repository includes publication-candidate privacy, terms, safety, child-safety, support, and account-deletion pages; UGC and Data Safety workbooks; reviewer access instructions; store copy; owner security controls; and a 14-day closed-test operations package. Synthetic reviewer accounts and records are isolated from ordinary users. Review credentials remain in a protected local credential store and are excluded from source and archives.

Guardian Mode remains optional. Basic applying, report, block, Safety Ping, and Guardian Mode are not paywalled. Real identity collection remains disabled. The public marketplace remains closed.

## Manual Release Blockers

- Enroll in Play App Signing and upload the AAB through the adult-owned Play Console account.
- Confirm version code history, complete App Access, Data Safety, content rating, target audience, ads, child-safety, privacy, and account-deletion declarations in Console.
- Replace the adult publisher, safety contact, support contact, and effective-date fields with approved real values, then deploy all public pages over HTTPS.
- Enter protected synthetic reviewer credentials in Play Console without placing them in source or documentation.
- Produce and review final Play feature graphic and synthetic store screenshots; no real names, addresses, messages, minors, incidents, or credentials may appear.
- Run Play pre-launch reports and complete physical-device testing across the documented matrix.
- Maintain at least the tester count and continuous 14-day participation shown by the founder's Play Console. The current Google requirement commonly shown for qualifying new personal accounts is at least 12 opted-in testers for 14 continuous days, but the Console is authoritative for this account.
- Collect tester feedback, resolve severe findings, and prepare the production-access application. Closed testing does not authorize unrestricted marketplace access.

## Production Hold

Before real users or unrestricted marketplace activation, MORT still needs adult-owned operations, trained safety moderation, provider-backed verification, insurance and labor review, privacy and teen-safety legal review, incident escalation staffing, deletion-processing operations, and explicit production approval. The app is not an emergency service and does not guarantee safety or payment.

## iOS Status

Flutter iOS source alignment and checklists exist. No Xcode build, iPhone test, TestFlight upload, App Store review, or Apple Developer Program purchase was performed in this Windows pass.
