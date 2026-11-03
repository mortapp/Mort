# MORT Android Catch-Up Report

## Current status (updated 2026-10-26)

The owner confirms MORT is publicly distributed on Google Play, and the supplied Google Play Support email confirms production access for `com.mortapp.mobile`. That distribution status is separate from verification of the exact live artifact and from backend marketplace/provider activation.

On PR #28 at `79a0f565fcf6e735a9f053319000caab3fdd74ad`, the Flutter Android integration suite passed on an Android 16/API 36 x86_64 QA emulator. The debug QA app installed and launched, and all three native integration tests passed. This is emulator evidence, not physical-device evidence, and the debug APK is not a Play release artifact. A production-signed AAB from this branch has not been built or uploaded; the public-build path continues to enforce the production activation gate. The live backend readiness snapshot remains restricted, with marketplace, remote push, identity verification, and live billing unavailable. One legal record has since been published as described below; this does not change those backend gates.

## Current legal record (updated 2026-10-26)

- The owner supplied the three-page PDF identified as `MORT-LEGAL-2026-V1` and reported that counsel approved this exact version.
- The existing production row contained a payment clause saying MORT held funds in escrow, which conflicted with the supplied PDF. The production Markdown and database record were corrected to the PDF's wording that MORT is not an escrow agent and describes Stripe marketplace authorization holds.
- Production record: `mort_terms_of_service`, version `MORT-LEGAL-2026-V1`, status `published`, effective `2026-10-26`; content SHA-256 `cf1044b1415b644ff0bfa93fde0d132577b407bfab4951017a091515ab1cd542`. Counsel approval metadata records the owner's attestation; counsel identity and approval date were not supplied.
- The version's stored hash matches its Markdown source. No existing active acceptance or reacceptance rows were queued for this version at verification time.
- The overall legal package and public marketplace readiness checks remain false. Release mode remains `closed_test` and marketplace mode remains `closed_pilot`; other counsel, safety, privacy, Play-declaration, moderation, on-call, identity, payment, and operational gates are unchanged.

## Original catch-up snapshot (historical)

At the time of the original catch-up report, Android shared-feature source parity was implemented, the unsigned release APK compiled, and an Android 16 emulator ran the optimized app and a native-plugin integration smoke. The original snapshot did not include a physical Android-device run, signed AAB, or verification of Google Play distribution. It is not the current distribution status.

## Current Android emulator verification (2026-10-26)

- Source: PR #28, commit `79a0f565fcf6e735a9f053319000caab3fdd74ad`.
- Device: dedicated `MORT_CODEX_QA_API36_20261026` AVD, Android 16/API 36, x86_64.
- Artifact: debug QA APK for `com.mortapp.mobile`, version `0.9.16+107`; installed and launched successfully.
- Integration command: `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/android_native_smoke_test.dart -d emulator-5554 --dart-define=MORT_EXPECTED_VERSION_NAME=0.9.16 --dart-define=MORT_EXPECTED_VERSION_CODE=107`.
- Result: all 3 tests passed. Coverage includes secure-storage round-trip, device-auth capability, native permission snapshot, secure-screen acquire/release, and safety acknowledgements at 1.6x text scale.
- The existing `MORT_QA_Pixel6` emulator already held version `0.9.16+113` signed with the protected Play upload certificate. It was left intact; the debug APK was tested on the separate QA AVD.
- Limits: this does not verify physical hardware, credentialed account journeys, provider delivery, the current Play artifact, or a signed production AAB.

## Gaps found and fixed

1. The manifest resolved `.MainActivity` as `com.mortapp.mobile.MainActivity`, but Kotlin declared `com.mortapp.flutter_mort`. The activity now uses the real package and `FlutterFragmentActivity` required by `local_auth`.
2. The release manifest lacked Internet access. Hosted Supabase HTTPS access is now declared.
3. Flutter told native users to use SwiftUI for device authentication. Shared Flutter now uses OS-backed face/fingerprint/PIN/pattern/passcode authentication and never receives biometric material.
4. Native Supabase sessions previously used default shared preferences. Native session persistence now uses `flutter_secure_storage`; web retains browser storage.
5. App lock existed only in SwiftUI. Flutter now stores an encrypted opt-in setting, locks after 1-240 minutes in the background, covers app-switcher content, and supports immediate lock.
6. Sensitive Android messages, reports, proof, safety cases, sessions, and evidence exports now set `FLAG_SECURE` while visible.
7. Android had no release camera, notification, biometric, or foreground-location declarations. They are now explicit, with camera/location hardware optional and no background location.
8. Job search now supports city/state fallback and one-shot native area resolution. Raw coordinates are discarded and never sent to Supabase by this flow.
9. Android custom deep links and the Supabase PKCE callback route are configured with `mort://app/auth-callback`.
10. Release builds silently used the debug key. Release signing now reads four environment variables and otherwise emits an unsigned compile-validation APK. Signed AAB creation is blocked when they are absent.
11. Gradle and Kotlin could each reserve 8 GB on a 15.45 GB machine. Heaps/workers were reduced to avoid memory pressure.
12. `flutter_local_notifications` failed release AAR validation because desugaring was missing. Java 17 desugaring 2.1.4 and multidex are now enabled.
13. Disabled monetization plugins merged billing, advertising ID, Ad Services, and foreground-service permissions. Those permissions are removed from the current ads/IAP-disabled Android manifest.
14. A plugin made camera hardware required. The merged release manifest now treats camera capture as optional.
15. Native session restoration and app-lock settings opened two separate Android keystores. They now share one encrypted namespace, session reads are cached after initialization, and app-lock settings load in one native read.
16. First-launch initialization could begin before Flutter painted its startup state. Initialization now begins after the first Flutter frame, while authenticated content remains covered until app-lock settings are restored.
17. The Windows regression script did not stop when an intermediate command returned a nonzero exit code. It now checks and propagates every typecheck, lint, build, and Expo Doctor failure.

## Verified build evidence

- Flutter 3.41.2, Dart 3.11.0
- Android SDK 36.1.0, compile/target SDK 36, min SDK 24
- Package and launch activity: `com.mortapp.mobile`
- `flutter analyze`: no issues
- `flutter test`: 83 tests passed
- Android 16 emulator integration test: 1 native-plugin test passed
- Optimized emulator launch: MORT welcome and sign-in screens rendered; custom-scheme cold start reached the app; no Dart/native fatal or missing-plugin errors were found
- Cleared first launch: the headless AVD held the native splash while Flutter/plugin registration took about 20 seconds, then rendered MORT; one expected secure-storage cipher initialization completed
- Subsequent cold launch: Android `am start -W` reported 5,475 ms; no secure-storage migration warning and no Dart/native fatal error
- APK: `flutter_mort/build/app/outputs/flutter-apk/app-release.apk`
- APK size: 70,529,106 bytes
- APK SHA-256: `9E3FCBA29925B1DDB0556C8D7EA6D9B65F76D02337A47947A0DABBB7EB8E3393`
- Signing audit: unsigned (`DOES NOT VERIFY`); not a distributable Play release
- Emulator runtime copy: signed only with the local Android debug key for QA; not a Play release
- Production AAB: not produced. The public builder stopped before compilation because the local profile has `productionActivationApproved=false`; it did not bypass the gate. The protected local upload credential is recoverable and its certificate matches MORT's release identity, verified without printing credentials.
- `flutter build web --release` against hosted Supabase: passed with ads/IAP disabled, confirming the Android additions did not break shared web compilation
- Source secret scan: passed
- Clean source/archive sensitive-file scan: passed for 1,023 files
- Android artifact/archive sensitive-file scan: passed for 9 files
- Mobile parity QA: 34 records passed without physical-device or iOS overclaims
- Denied-location QA: passed with manual city/state fallback and no background permission
- Feature-count integrity QA: passed with no million-scale implementation claim
- Preserved Expo reference: `pnpm check`, `pnpm lint`, 48-route web export, and Expo Doctor 20/20 passed after clean package staging was removed

## Production AAB attempt (2026-10-26)

The signed public-production entry point was run from this branch. It rejected the build during local profile validation because production activation is false, before compilation and before writing an AAB. The protected upload key was separately recovered through its configured Windows credential store; its SHA-256 certificate matched the checked-in MORT release identity. No credentials were displayed or changed. The hosted project independently still reports the closed-test/closed-pilot policy, so setting the local profile alone would not produce an acceptable public artifact.

## Device work still required

- Install a release-signed QA build on an API 24 device and at least one current physical Android device.
- Test biometric and device-credential fallback, lockout, cancellation, lifecycle timeout, process death, and account switching.
- Test approximate versus precise permission, denied and permanently denied location, disabled services, geocoder failure, and manual area fallback.
- Test camera and Android Photo Picker with rotation, large files, cancellation, and permission denial.
- Test notification permission and lock-screen privacy. FCM delivery is not connected.
- Test deep-link cold start, warm start, email confirmation, and password recovery after adding the redirect URL in Supabase.
- Run TalkBack, large text, display scaling, keyboard, low-memory, offline, and background/restore checks.

## Production release blockers (verified 2026-10-26)

- The public production builder fails closed at local profile validation because `productionActivationApproved=false`. No production AAB was generated.
- Hosted Supabase remains `closed_test` / `closed_pilot`; public marketplace, remote push, live billing, identity verification, and real document collection remain disabled.
- The full legal package is unready: V1 Terms is published, but 12 required document keys remain unpublished; owner, attorney package, child-safety, privacy, support, Play-declaration, moderation, and incident on-call controls remain false.
- Identity/document collection readiness is 0 of 18 gates. Missing gates include an adult operating entity, privacy/legal review, trained reviewers, retention/deletion procedures, incident staffing, audit/monitoring, two-person approval, and production storage/RLS QA.
- One legacy unbounded admin role assignment remains, which independently prevents public marketplace activation.
- Production profile still has placeholder privacy, community-guidelines, and safety-rules versions. The approved Terms version is configured as `MORT-LEGAL-2026-V1`.
- A production build still requires live push/crash provider configuration and successful hosted release validation. Do not switch the live release policy or bypass these checks without the corresponding evidence.
- Verify the current live Play artifact/revision and physical-device critical flows before a public update.

## Emulator evidence boundary

The emulator pass proves that the package launches and that secure storage, permission status, local-auth capability detection, and the secure-screen MethodChannel are registered. It does not prove camera capture, biometric prompts, notification prompts, precise/approximate location choices, low-memory behavior, or real-device performance. The headless AVD was unusually slow during a cleared first launch, so its timing is not a physical-device performance result.
