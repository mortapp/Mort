# Mobile Release Evidence (Local)

**Date:** 2026-11-24  
**Branch:** `feature/compact-onboarding-and-screen-polish`  
**HEAD:** `3d18236937206ae4b34b2103c913ee8a9e3fa44e`  
**Scope:** Local repository/document/build-config evidence only. No Android device/emulator QA, signed AAB build/validation, Play Console checks, macOS/Xcode archive, iPhone/device QA, TestFlight upload, App Store Connect submission, or store review was performed in this session.

## Evidence sources reviewed

- [flutter_mort/pubspec.yaml](/C:/Users/micha/Mort/flutter_mort/pubspec.yaml) (`version: 0.9.17+122`)
- [flutter_mort/android/app/build.gradle.kts](/C:/Users/micha/Mort/flutter_mort/android/app/build.gradle.kts)
- [flutter_mort/android/key.properties.example](/C:/Users/micha/Mort/flutter_mort/android/key.properties.example)
- Android docs: [MORT_ANDROID_BUILD_CONFIG_STATUS.md](/C:/Users/micha/Mort/docs/mobile/MORT_ANDROID_BUILD_CONFIG_STATUS.md), [MORT_PLAY_SIGNING_SETUP.md](/C:/Users/micha/Mort/docs/mobile/MORT_PLAY_SIGNING_SETUP.md), [MORT_ANDROID_PERMISSION_RELEASE_AUDIT.md](/C:/Users/micha/Mort/docs/mobile/MORT_ANDROID_PERMISSION_RELEASE_AUDIT.md), [MORT_ANDROID_ARTIFACT_README.md](/C:/Users/micha/Mort/docs/mobile/MORT_ANDROID_ARTIFACT_README.md), [MORT_VERSIONING_POLICY.md](/C:/Users/micha/Mort/docs/mobile/MORT_VERSIONING_POLICY.md), [MORT_ANDROID_*_EMULATOR_EVIDENCE*](/C:/Users/micha/Mort/docs)
- iOS docs: [MORT_IOS_RELEASE_BLOCKERS.md](/C:/Users/micha/Mort/docs/ios/MORT_IOS_RELEASE_BLOCKERS.md), [MORT_IOS_BUILD_REPORT.md](/C:/Users/micha/Mort/docs/mobile/MORT_IOS_BUILD_REPORT.md), [MORT_IOS_ANDROID_PARITY_MATRIX.md](/C:/Users/micha/Mort/docs/mobile/MORT_IOS_ANDROID_PARITY_MATRIX.md), [MORT_MAC_BUILD_AND_TEST_TASK.md](/C:/Users/micha/Mort/docs/ios/MORT_MAC_BUILD_AND_TEST_TASK.md), [MORT_TESTFLIGHT_READINESS_CHECKLIST.md](/C:/Users/micha/Mort/docs/ios/MORT_TESTFLIGHT_READINESS_CHECKLIST.md), [MORT_APP_STORE_SUBMISSION_PACKET.md](/C:/Users/micha/Mort/docs/ios/MORT_APP_STORE_SUBMISSION_PACKET.md)
- Release/privacy docs: [APP_STORE_PRIVACY_PREP.md](/C:/Users/micha/Mort/docs/APP_STORE_PRIVACY_PREP.md), [GOOGLE_PLAY_DATA_SAFETY_WORKSHEET.md](/C:/Users/micha/Mort/docs/GOOGLE_PLAY_DATA_SAFETY_WORKSHEET.md), [MORT_RELEASE_READINESS.md](/C:/Users/micha/Mort/docs/MORT_RELEASE_READINESS.md), [MORT_SUPREME_RELEASE_CHECKLIST.md](/C:/Users/micha/Mort/docs/MORT_SUPREME_RELEASE_CHECKLIST.md)

## Android release

### Implementation / build configuration (local evidence)

| Area | Evidence | Status |
| --- | --- | --- |
| App/version source | `flutter_mort/pubspec.yaml` = `0.9.17+122`; Android uses Flutter versionCode/versionName in [build.gradle.kts](/C:/Users/micha/Mort/flutter_mort/android/app/build.gradle.kts) | **Present** (must be checked against Play Console history before upload). |
| Package/SDK targets | `applicationId = "com.mortapp.mobile"`, `compileSdk = 36`, `minSdk = 24`, `targetSdk = 36` | **Present**. |
| Release signing enforcement | Gradle requires complete signing values for release tasks, rejects partial config, rejects missing keystore file, and does not allow debug-signing fallback | **Implemented in build config**; actual signing material not present/verified in this session. |
| Signing inputs | Env vars `MORT_UPLOAD_*` or `android/key.properties`; example provided at [key.properties.example](/C:/Users/micha/Mort/flutter_mort/android/key.properties.example) | **Documented/configurable**; secrets must remain outside repo. |
| Release hardening | `isMinifyEnabled = true`, `isShrinkResources = true`, ProGuard rules configured | **Present**. |
| Permissions/manifest audit | [MORT_ANDROID_PERMISSION_RELEASE_AUDIT.md](/C:/Users/micha/Mort/docs/mobile/MORT_ANDROID_PERMISSION_RELEASE_AUDIT.md) documents retained permissions and no background location | **Documented source audit**; final AAB/merged manifest must be re-verified per release. |
| Build/signing scripts/docs | [MORT_PLAY_SIGNING_SETUP.md](/C:/Users/micha/Mort/docs/mobile/MORT_PLAY_SIGNING_SETUP.md), [MORT_ANDROID_ARTIFACT_README.md](/C:/Users/micha/Mort/docs/mobile/MORT_ANDROID_ARTIFACT_README.md), [MORT_ANDROID_BUILD_CONFIG_STATUS.md](/C:/Users/micha/Mort/docs/mobile/MORT_ANDROID_BUILD_CONFIG_STATUS.md) | **Present**; some docs reference prior candidate versions/artifacts and dated evidence. |

### QA / validation gates

| Gate | Status | Notes |
| --- | --- | --- |
| Android QA and regression testing | **Incomplete / unverified in this session** | Repo contains prior emulator/test evidence docs, but no current full-device regression evidence was produced now. Physical-device QA for biometrics, camera/photo picker, notifications, foreground location, deep links, and session flows remains required per docs. |
| Signed production AAB produced and validated | **Not verified** | `MORT_ANDROID_BUILD_CONFIG_STATUS.md` reports release signing variables missing in that captured environment; `MORT_PLAY_SIGNING_SETUP.md` describes build/verify scripts and candidate artifact paths but current AAB existence/signature verification was not confirmed. |
| Release signing and Play requirements | **Partially documented, not complete** | Upload key/keystore handling, Play App Signing enrollment, upload-certificate comparison, and Play Console version-code checks require owner/console access and must be verified outside this checkout. |
| Store metadata/policy/readiness | **Not complete** | Data Safety, permissions declarations, screenshots/content, support/deletion/privacy URLs, and Play review readiness require current product/legal/store-owner confirmation. |

## iOS release

### Implementation / shared-source evidence

| Area | Evidence | Status |
| --- | --- | --- |
| Shared Flutter iOS source alignment | [MORT_IOS_ANDROID_PARITY_MATRIX.md](/C:/Users/micha/Mort/docs/mobile/MORT_IOS_ANDROID_PARITY_MATRIX.md), [MORT_IOS_BUILD_REPORT.md](/C:/Users/micha/Mort/docs/mobile/MORT_IOS_BUILD_REPORT.md) | **Source-aligned (local claim in docs)**; not build-validated on macOS in this session. |
| Bundle/version context | `flutter_mort/pubspec.yaml` `0.9.17+122`; iOS docs reference `com.mortapp.mobile` and older candidate versions/builds in dated packets | **Needs current-release reconciliation** before submission artifacts are created. |
| iOS release blockers | [MORT_IOS_RELEASE_BLOCKERS.md](/C:/Users/micha/Mort/docs/ios/MORT_IOS_RELEASE_BLOCKERS.md) | **Blocked:** Apple Developer membership, macOS/Xcode build/archive, signing, entitlements, privacy manifests, physical iPhone QA, TestFlight/App Review not completed. |
| Mac/Xcode task and submission/readiness docs | [MORT_MAC_BUILD_AND_TEST_TASK.md](/C:/Users/micha/Mort/docs/ios/MORT_MAC_BUILD_AND_TEST_TASK.md), [MORT_APP_STORE_SUBMISSION_PACKET.md](/C:/Users/micha/Mort/docs/ios/MORT_APP_STORE_SUBMISSION_PACKET.md), [MORT_TESTFLIGHT_READINESS_CHECKLIST.md](/C:/Users/micha/Mort/docs/ios/MORT_TESTFLIGHT_READINESS_CHECKLIST.md) | **Present as checklists/packets**; execution evidence not available. |

### Requested A-01 through A-07 fixes

| Item | Status |
| --- | --- |
| A-01–A-07 implementation and verification | **Not traceable in local docs by identifier.** `rg` over `docs/` did not find `A-01`…`A-07` labels. The exact fix definitions, approved scope, implementation commits/files, and verification evidence must be located in the authoritative task ledger/review thread or defined explicitly before this gate can be reported complete. |

### iOS validation gates

| Gate | Status | Notes |
| --- | --- | --- |
| Xcode release-build validation | **Not done** | Windows environment cannot produce required archive/build evidence. |
| Signing, entitlements, privacy manifests | **Not verified** | Requires Mac/Xcode/team configuration and archive validation. |
| Physical iPhone/device QA | **Not done** | Camera/photo, location, notifications, biometrics, deep links, secure storage, lifecycle, accessibility, and role flows need real-device evidence. |
| Distribution and store requirements | **Not complete** | TestFlight, App Privacy, age rating, support/deletion/privacy URLs, screenshots, review notes, and App Review require owner/legal/store actions. |

## Cross-platform release evidence gaps

1. **Current artifact evidence:** no signed AAB, no iOS archive/TestFlight build, and no current Play/App Store submission records verified in this session.
2. **Device evidence:** no physical Android or iPhone test runs performed now.
3. **Policy/legal/store metadata:** privacy disclosures and submission packets exist as prep, but final owner/legal/store confirmation is incomplete.
4. **Versioning reconciliation:** current pubspec version/build (`0.9.17+122`) differs from versions cited in some dated docs/artifact references; release candidates must be reconciled before upload.
5. **iOS A-01–A-07:** definitions and proof not found locally by label.

## Recommended next evidence-producing steps (owner/Mac/device access required)

- **Android:** configure release signing in a secure environment, run `flutter build appbundle --release` with approved defines, run signing/verification scripts, validate merged manifest/permissions, test on physical devices, and capture Play Console pre-upload checks.
- **iOS:** execute [MORT_MAC_BUILD_AND_TEST_TASK.md](/C:/Users/micha/Mort/docs/ios/MORT_MAC_BUILD_AND_TEST_TASK.md) on macOS with approved signing/team, produce archive/TestFlight evidence, complete device matrix, and attach results to the A-01–A-07 ledger items once identified.
- **Both:** update release/version docs to the actual candidate, attach test logs/screenshots, and separate “documented/prepared” from “executed/approved”.

*This report does not claim mobile release readiness and does not assign a readiness percentage.*