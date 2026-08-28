# MORT Supreme Test Report

Run date: 2026-08-01/02 America/Indianapolis  
Branch: `mort-supreme-production-readiness`  
Commit baseline: `f566885453786f1fbdea08291b1b646a5cabe1bc`  
Working tree: dirty by design; 450 modified/deleted/untracked paths at final-report inventory time.

## Passing Evidence

| Command | Real result |
|---|---|
| `flutter pub get` | Passed after aligning `intl` to Flutter's pinned `0.20.2` |
| `dart format lib test integration_test` | 202 files, 0 changed |
| `flutter analyze --no-pub` | Passed, no issues, 241.6 s |
| `flutter test --no-pub` | Passed: 265 tests, 2 intentionally skipped provider-dependent cases |
| `scripts/build-web-preview.ps1 -SkipTests` | Passed; hosted-Supabase Flutter web release built; WASM dry run passed |
| `pnpm install --frozen-lockfile` | Passed; lockfile current |
| `pnpm check` | Passed |
| `pnpm lint` | Passed |
| `pnpm build` | Passed; Expo reference exported 48 routes |
| `npx expo-doctor` | Passed 20/20 after patch-version alignment |
| `scripts/windows-check.ps1` | Passed check, lint, 48-route export, Doctor 20/20 |
| `node scripts/build-public-legal-site.mjs` | Built 13 routes; deployment ready false by required-contact gate |
| `node scripts/validate-public-legal-site.mjs` | Passed 13 routes; deployment ready false |
| `scripts/build-standard-closed-test-apk.ps1` | Passed; signed final APK 68,170,626 bytes |
| `scripts/build-standard-closed-test-aab.ps1` | Passed; signed final AAB 51,704,746 bytes |
| `node scripts/qa-aab-secret-scan.mjs` | Passed; 970 extracted APK/AAB entries, 5 available sensitive values |
| `node scripts/qa-aab-signing.mjs` | Passed; expected upload certificate, debug signing rejected |
| `node scripts/qa-android-permission-minimization.mjs` | Passed; billing/ad/storage/background-location/wake-lock capabilities absent |
| `node scripts/qa-release-network-security.mjs` | Passed; HTTPS-only and expected hosted project |
| `scripts/qa-android-16kb-alignment.ps1` | Passed; 18 native libraries |
| `zipalign -c -P 16 -v 4 ...apk` | Passed; verification successful |
| `scripts/run-final-supabase-regression.ps1` | Passed 45 hosted scripts in 363.4 s; bounded transient transport retries occurred |
| `npx supabase migration list --linked` | Passed; 158 local/remote migrations aligned |
| `npx supabase db lint --linked --level error` | Passed; no schema errors |
| `npx supabase db push --linked --dry-run` | Passed; remote database up to date, no push performed |
| `node scripts/audit-remote-storage.mjs` | Passed; nine private buckets, 18 policies |
| `node scripts/audit-supabase-advisors.mjs` | Passed; no error-level findings |
| `node scripts/backup-feature-schema.mjs` | Passed; metadata-only snapshot with 302 relations, 296 policies, 545 functions, 158 migrations |
| `pnpm audit --prod` | Passed; no known vulnerabilities found |
| `flutter pub outdated` | Passed as inventory; 13 locked upgrades and 4 constrained upgrades reported |
| `scripts/secret-scan.ps1` | Passed |
| `scripts/sensitive-file-scan.ps1 -ArchivePath ...source.zip` | Passed; 1,861 files, 54 reviewed media, 10 available secret values |
| Workflow YAML parse | Passed for all three `.github/workflows` files |

## Failures Found And Repaired

1. Flutter localization conflicted with `intl ^0.20.3`; Flutter 3.41.2 pins
   `0.20.2`. Constraint aligned and dependency resolution passed.
2. Secure PIN semantics tests initially matched label digits and disposed the
   semantics handle too late. Assertions now verify no exact PIN/bullet value,
   and disposal is explicit.
3. A component test lacked a localization scope. Shared controls now use the
   tested English fallback without weakening runtime localization.
4. AAB verification rejected two legitimate FCM receivers. The verifier now
   permits only their exact class names when protected by
   `com.google.android.c2dm.permission.SEND`.
5. Permission QA found `WAKE_LOCK` in the merged release. The manifest now
   removes it, the AAB verifier forbids it, and final APK/AAB were rebuilt.
6. Release-network QA inspected a retired wrapper script. It now inspects the
   authoritative shared release-profile script.
7. Expo Doctor found 11 SDK 57 patch mismatches. Required versions were aligned;
   Doctor, typecheck, lint, and export all pass.
8. Generic APK extraction collided on duplicate obfuscated resource names. The
   ELF checker now extracts native libraries only and verifies all 18.
9. One hosted cleanup call timed out after functional QA. Guarded strict-name
   cleanup removed three synthetic feature-QA accounts; a second aggregate
   audit found zero strict feature-QA users.
10. The first SBOM launcher used incorrect Windows batch dispatch, then
    recursive `pnpm list` exhausted Node memory. It now uses Flutter's Windows
    launcher only for constant arguments and parses unique lockfile packages.
11. PowerShell lacked the ZIP archive enum assembly and the source audit treated
    safe `.env.example` files as local secrets. The packager now loads both ZIP
    assemblies, allows templates, excludes generated public config, and passes.
12. Two existing synthetic emulator screenshots in release reports required
    explicit privacy review. Their exact hashes are allowlisted; arbitrary media
    remains rejected.

## Emulator Result

One signed `0.9.12+102` APK built before the final `WAKE_LOCK` removal installed
and launched on API 36, reached top-resumed `MainActivity`, retained a live
process, and emitted no fatal logs. The final hash retest and extended lifecycle
checks are blocked by repeatable AVD/ADB timeout/offline failures. They are not
reported as passed. See the Android emulator report and 50-journey matrix.

## Intentionally Unverified

Physical Android/iPhone, real Google chooser, real push delivery, crash-provider
events, identity provider, payments/payouts, staffed moderation/support, macOS
Xcode archive, TestFlight, Play upload/review, App Store review, public web
deployment, and destructive restore drill were not performed.
