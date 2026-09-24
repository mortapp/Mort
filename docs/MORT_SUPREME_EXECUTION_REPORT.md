# MORT progression and Android release certification

## Current Android 113 release (September 24, 2026)

Status: signed artifacts built and verified; provider activation and real-device purchase tests remain external gates. The material below this section records the historical version 112 release and is superseded for Android distribution by version 113.

- Source branch: `feature/mort-monetization-convergence-113`, PR [#23](https://github.com/mortapp/Mort/pull/23). The original mixed checkout at `C:\Users\micha\Mort` was preserved; the clean release worktree is `C:\Users\micha\Mort-monetization-113`.
- APK/AAB source commit: `cdb0c7e8613bbd01d4122464934dfd0b3b390cfd` (`gitDirty=false` in both build manifests). This source retains the newer black/silver MORT UI and the intended landing copy, “Real work near you, with safety and clear conversations built in from the start.” Backend-only migration/webhook and RevenueCat provider work followed the binary build.
- Version `0.9.16+113`, package `com.mortapp.mobile`, minimum SDK 24, target SDK 36. Android Play Billing is enabled with the Play app's public RevenueCat SDK key. The Test Store key and privileged keys are absent from the release artifacts.
- [Google Play AAB](C:/Users/micha/Mort/build/play/MORT-0.9.16-113-play.aab): 90,586,869 bytes; SHA-256 `569D3D1AA0D958EE0B3C43E63D32194DF41F1F8F87E587FDF3F15E58A213B3D6`.
- [QA APK](C:/Users/micha/Mort/build/play/MORT-0.9.16-113-release.apk): 87,047,635 bytes; SHA-256 `6858D9E7CE8EF69E2B12CCE9A260A867A62C25981116E8C6607D95C207CCD8E7`.
- APK and AAB signature, package/version/manifest, exported component, and 16 KB ELF alignment checks passed. The artifact secret scan checked 2,918 entries with zero findings against the five available sensitive values. Upload certificate SHA-256: `04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF`.
- The progression, account-deletion financial-FK repair, and MORT Pro/ad-eligibility migrations are applied to the intended hosted Supabase project. The corrected progression migration passed an isolated Docker PostgreSQL red/green regression before the hosted retry; the hosted migration list then matched locally. The MORT RevenueCat webhook is deployed with a dedicated Play authorization value while preserving the older Test Store integration.
- RevenueCat Play project `projc545d148` / app `app8eaa6ee77f`: weekly, monthly, annual, and lifetime products are attached to `mort_pro` and the current `default` offering. The MORT-branded four-plan paywall is published. Catalog/attachment/webhook configuration QA and synthetic hosted Play webhook authorization, persistence, and replay tests passed. Synthetic tests do not prove a real Google Play transaction.
- MORT local Supabase Docker containers and preserved database volumes were restored with the `mort-mobile` project label and container-name suffix. Studio `http://127.0.0.1:54323` and API `http://127.0.0.1:54321` returned HTTP 200; database and core containers are healthy. The optional Vector log collector restarts because Docker Desktop does not expose the TCP endpoint it expects. The separate Loop stack was left untouched.
- Remaining external gates: configure/activate matching Google Play Console products/base plans and tester access; upload the version 113 AAB; run real-device license-tester purchase, renewal, cancellation, restore, and RevenueCat-to-Supabase delivery; review the paywall on a device; complete production legal/payment/safety approvals. Apple distribution signing and App Store IAP remain separate.

---

## Historical version 112 certification

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
