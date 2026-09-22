# MORT progression and Android release certification

Date: September 22, 2026

## Verdict

`PASS_CODE_COMPLETE_EXTERNAL_GATES_REMAIN`

The progression code, restored MORT UI/UX, and Android closed-test artifacts are complete. Production Supabase was not modified by this pass. Play Console upload and production activation approvals remain external steps.

## Source and integration

- Repository: `mortapp/Mort`
- PR #21: merged into `feature/ios-android-release-parity`
- Progression merge commit: `07d674b17e46a7bad37a3dc42bc31ee5a3b25442`
- Final Android artifact source: `bb0afee35b8d3cf74cc0445dd0120f73bd2aaf9b`
- Release source checkout: `C:\Users\micha\Mort-release-final`
- Original mixed checkout: `C:\Users\micha\Mort`, preserved without reset or cleanup.
- Version: `0.9.16+112`. Version code 111 was previously used for Google Play.
- The newer black/silver UI, atmospheric background, thin motion mark, monoline wordmark, compact screens, and updated launcher icons were restored before the final build. The release APK was visually checked on the Pixel 6 emulator against the owner's recording.

## Exact-source CI and local checks

- [MORT CI run 35781354607](https://github.com/mortapp/Mort/actions/runs/35781354607): success at artifact source `bb0afee35b8d3cf74cc0445dd0120f73bd2aaf9b`.
- [MORT CI run 35781359226](https://github.com/mortapp/Mort/actions/runs/35781359226): success at the same source. Mandatory Flutter, Android device APK, iOS, Stripe, Expo, public-site, and teen-verification jobs passed. Protected provider/hosted Stripe jobs were intentionally skipped.
- Flutter analysis: no issues.
- Full Flutter suite: 702 passed, 2 intentional skips, 0 failures.
- Docker-backed local Supabase regression: 76 scripts passed, including Stripe authority, replay, payment, privacy, and isolation contracts.
- Stripe Edge Function tests: 26 passed, 0 failed.
- Local source and extraction secret scans: 14,517 files scanned, 0 findings. The full Git history scan passed in CI; a redundant local scan was stopped after the CI result was confirmed.
- iOS authoritative CI selected Xcode 26.3, resolved CocoaPods, built the provider-disabled Release app, validated the app bundle, and packaged an unsigned CI IPA. Apple distribution signing was not performed.

## Progression and safety

- XP and Motion Tokens remain server-authoritative, replay-safe, and separate from payments, tips, purchases, and subscriptions.
- Fifty levels map to Bronze, Silver, Gold, Platinum, and Diamond; Diamond is highest.
- Progression private tables enforce RLS and deny direct client mutations. Leaderboard participation defaults to hidden and public fields are minimized.
- Local migration and security regression covered concurrent token spending, invalid identifiers, cross-user denial, replay, leaderboard privacy, and account deletion financial foreign keys.
- Production progression and account-deletion migrations remain pending approval; neither was deployed to production by this pass.

## APK

- Source: `C:\Users\micha\Mort-release-final\build\play\mort-closed-test-0.9.16-112.apk`
- Downloads: `C:\Users\micha\Downloads\MORT-0.9.16-112-release.apk`
- Size: 85,108,883 bytes.
- SHA-256: `499EEF21527F42C2350EE1D4D6AE522B5B958E7926CD67B0879D62353E61D109`
- Package: `com.mortapp.mobile`; version name `0.9.16`; version code `112`; min SDK 24; target SDK 36.
- Upload signer SHA-256: `04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF`.
- Repository APK verification: pass. Pixel 6 emulator install, startup, and navigation to the welcome screen: pass; MORT remained foreground and logcat showed no app fatal or Flutter exception. The emulator's System UI briefly displayed an unresponsive dialog, then recovered.
- ELF 16 KB alignment: 30 native libraries checked, 0 failures.
- Artifact secret scan: 0 findings.

## Google Play AAB

- Source: `C:\Users\micha\Mort-release-final\build\play\mort-closed-test-0.9.16-112.aab`
- Downloads: `C:\Users\micha\Downloads\MORT-0.9.16-112-play.aab`
- Size: 85,662,171 bytes.
- SHA-256: `A6C036425263F457961397AA36ED66B71B02CAAC4FBC3C875EB42F29B7499F0F`
- Package and version: `com.mortapp.mobile`, `0.9.16+112`.
- Signed with the same MORT upload certificate. `jarsigner`, `keytool`, and repository AAB manifest/exported-component checks passed. Strict closed-test verification also passed with Play reviewer mode disabled.
- Artifact secret scan: 0 findings. The source and Downloads artifact hashes match byte for byte.

## Remaining external gates

- Upload `MORT-0.9.16-112-play.aab` to Google Play Console for review and distribution. The APK is for direct installation and QA.
- Approve and apply pending progression/account-deletion migrations to the intended hosted environment, then run hosted JWT/RLS attack tests before production activation.
- Complete production legal, marketplace, identity, payment, and provider activation approvals. Current release flags remain closed.
- Complete Apple distribution signing, physical iPhone validation, and TestFlight/App Store submission separately.
