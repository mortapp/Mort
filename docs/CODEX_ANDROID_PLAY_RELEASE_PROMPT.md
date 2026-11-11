# Codex handoff: Android Play release + end-to-end production activation test

You are working on the **MORT** teen-hustle marketplace, repo `mortapp/Mort`
(private). The Flutter app lives in `flutter_mort/`. Your job is to complete
the Android Google Play release and the end-to-end production activation test
that the previous engineering sessions could not finish. Work step by step and
verify each gate before moving on. Do not fabricate credentials, keystores,
accounts, or QA results; if a gate needs a human secret or a paid account, stop
and report exactly what is missing.

## Current state (verified 2026-11-11)

- The app builds and passes full test regression locally and in CI
  (GitHub Actions macOS run 34472297830 covers iOS real-device BrowserStack QA).
- **Android QA so far is emulator-only** (`MORT_QA_Pixel6`, a release APK with
  a throwaway local key that was deleted afterward). No signed AAB exists.
- The signing pipeline is **fail-closed**: `flutter_mort/android/app/build.gradle.kts`
  raises `Release signing is required. Debug-signing fallback is intentionally disabled.`
  unless keystore env vars exist.
- A complete, ready-to-run signed-build workflow already exists at
  `.github/workflows/mort-signed-closed-test.yml` (`workflow_dispatch`). It only
  lacks its secrets.
- Android release builds hard-require Supabase project `rakjydmgwwgtdislanbt`
  (`scripts/android-release-profile-common.ps1` enforces the URL).
- Release profiles live in `config/mort-release-profiles.json` (authoritative,
  validated by `scripts/validate-release-profile.mjs`). Legal versions were
  synced on 2026-11-11 to the counsel-approved catalog:
  `MORT-LEGAL-2026-V5` (Terms), `MORT-PRIVACY-2026-10`,
  `MORT-COMMUNITY-2026-10`, `MORT-SAFETY-2026-10`.
- The production-public AAB path is intentionally blocked
  (`scripts/build-production-public-aab.ps1` throws `BLOCKED-EXTERNAL`). The
  realistic release path is the **closed test** track.

## Task 1 — Sign and build the AAB

1. Ask the owner to create (or locate) the real MORT upload keystore, then set
   these GitHub Actions secrets on `mortapp/Mort` via `gh secret set` or the
   Settings UI:
   - `MORT_UPLOAD_KEYSTORE_BASE64` (base64 of the .keystore/.jks)
   - `MORT_UPLOAD_KEY_ALIAS`
   - `MORT_UPLOAD_STORE_PASSWORD`
   - `MORT_UPLOAD_KEY_PASSWORD`
   - plus `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` repo variables if the
     workflow references them.
2. Run the workflow: dispatch `.github/workflows/mort-signed-closed-test.yml`.
   It materializes the keystore from the secret and runs
   `scripts/build-standard-closed-test-aab.ps1` / the `.aab` variant.
3. Verify the artifact with `scripts/verify-play-aab.ps1` (signing identity,
   certificate SHA-256 must match `Get-MortUploadCertificateSha256`).
4. Confirm `versionCode >= 98` (`scripts/read-mobile-version.mjs --json`;
   current pubspec is `0.9.16+111`).

## Task 2 — Install and accept on a real Android device

1. Install the signed release APK (or AAB-derived APK via `bundletool`) on at
   least one physical Android device — preferably via BrowserStack's real
   Android device cloud (credentials: `BROWSERSTACK_USERNAME` /
   `BROWSERSTACK_ACCESS_KEY`, already used for iOS QA) or a local physical
   device.
2. Confirm the app launches, stays resumed (no crash in logcat), passes
   onboarding, and that the legal clickwrap presents the V5 catalog versions
   listed above.
3. Record device model, Android version, build fingerprint, and a logcat
   excerpt in the QA report.

## Task 3 — End-to-end production activation test with legitimate accounts

Using only real, owner-provided test accounts (do not invent credentials):

1. Sign up a teen account (age 13–17) and an adult account (18+), complete
   onboarding on each.
2. Teen: upload school-ID verification evidence; verify the case appears in
   the staff review queue (web Admin HQ at `mortapp.org/app/admin`, or the app's
   admin route `/admin/home`).
3. Admin: approve and reject cases through Admin HQ; confirm the teen's
   `verification_status` changes accordingly.
4. Adult: post a job; teen applies; guardian consent flow (teen under 18);
   job start/finish PINs; proof upload and review.
5. Confirm the release-mode status endpoint (`get_release_mode_status`) and
   runtime feature flags behave as the closed-test profile expects
   (`publicMarketplaceEnabled=false` in closed test — marketplace browsing
   must not fully open).
6. Negative tests: unauthenticated and wrong-role calls to the RPCs used by
   the app must be refused (this was verified on the web backend
   `jxbnrkasktbhtiujkhay` on 2026-11-11 — repeat the same battery against
   `rakjydmgwwgtdislanbt`).

## Task 4 — Publish the closed test on Google Play

1. Package name `com.mortapp.mobile`. Create the app in Play Console if it
   does not exist, enroll in Play App Signing with the upload certificate.
2. Upload the signed AAB to the Closed testing track, add the test accounts,
   and roll out.
3. Update `MORT_EXTERNAL_RELEASE_GATES.md` with what was completed and what
   remains (production-public is still blocked by design).

## Important warnings

- **Legal server check:** the mobile app's Supabase project
  (`rakjydmgwwgtdislanbt`) must have the V5 legal catalog published
  (version labels exactly `MORT-LEGAL-2026-V5`, `MORT-PRIVACY-2026-10`,
  `MORT-COMMUNITY-2026-10`, `MORT-SAFETY-2026-10`) or the app's
  server-authoritative legal acceptance flow will fail. Verify the
  `legal_document_versions` table on that project BEFORE building the AAB.
- Never commit keystores, passwords, or service-role keys. The repo has a
  secret-scan gate (`scripts/qa-aab-secret-scan.mjs`) — keep it green.
- The production-public profile (`productionActivationApproved=true`) must
  stay false until the owner explicitly approves public launch.
