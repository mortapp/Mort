# MORT 0.9.5 Command Results

Run date: 2026-07-23 through 2026-07-24. Project:
`C:\Users\micha\Mort`. Secrets are intentionally omitted.

| Command | Result |
|---|---|
| `flutter pub get` | PASS; lock resolved, 33 incompatible newer versions reported |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 156 files, 0 changes in final full pass |
| `flutter analyze` | PASS; no issues, final focused rerun 109.2 seconds |
| `flutter test --reporter expanded` | PASS; 139/139 |
| `flutter build web --release` with closed/disabled provider defines | PASS; `build/web` |
| `scripts/android-lint-release.ps1` | PASS; third-party deprecated API note only |
| `scripts/build-closed-test-apk.ps1` | PASS after detached wrapper completed |
| `scripts/qa-android-apk.ps1 -RequireSigned` | PASS; package/version/SDK/signature |
| `scripts/build-play-aab.ps1` | PASS; 387 seconds, symbols external |
| `scripts/verify-play-aab.ps1` | PASS; MORT upload signer, debug rejected |
| `node scripts/qa-aab-secret-scan.mjs` | PASS; 2,596 entries, 5 values |
| `node scripts/qa-aab-signing.mjs` | PASS |
| `scripts/sensitive-file-scan.ps1` | PASS; 1,502 files, 10 values |
| `scripts/secret-scan.ps1` | PASS |
| `node scripts/secret-scan-git-history.mjs` | PASS; 9 commits, zero findings |
| `pnpm install` | PASS |
| `pnpm check` | PASS |
| `pnpm lint` | PASS |
| `pnpm build` | PASS; 48 static Expo routes |
| `npx expo export --platform web` | PASS; 48 static routes |
| `npx expo-doctor` | PASS; 20/20 after patch update |
| `scripts/windows-check.ps1` | PASS |
| `npx expo start --port 8085` | PASS; Metro listened, then stopped cleanly |
| `pnpm audit --prod` | PASS; no known vulnerabilities after PostCSS fix |
| `node scripts/audit-supabase-advisors.mjs` | PASS, zero error-level findings; warnings remain |
| `pnpm exec supabase migration list --linked` | PASS; local/remote aligned through `20260723061421` |
| `node scripts/audit-remote-storage.mjs` | PASS; 8 private buckets, 16 policies |
| `node scripts/qa-google-auth-controls.mjs` | PASS; isolated users created/tested/removed |
| `scripts/run-final-supabase-regression.ps1` | PASS; 26-script full run; 7-script 0.9.5 tail run |

## Errors found and fixed

1. Home screen claimed connectivity from compile-time configuration. Fixed with
   an 8-second server health check, honest offline state, and in-place retry.
2. First implementation used unavailable Riverpod `valueOrNull`. Replaced with
   `AsyncData` pattern matching; analyzer and tests then passed.
3. A timed analyzer wrapper left a stale analysis server. Only that stale PID
   chain was stopped; the clean analyzer passed.
4. Combined Android release wrapper timed out after 1,204 seconds while Gradle
   remained active. The detached APK completed, received a new timestamp/hash,
   and passed independent verification; AAB was rerun separately and passed.
5. PowerShell binary redirection corrupted three PNG captures. Evidence was
   recaptured with `adb shell screencap` plus binary-safe `adb pull`.
6. Expo Doctor found `expo-dev-client` 57.0.8 instead of `~57.0.9`. Dependency
   and lockfile were updated; Doctor then passed 20/20.
7. `pnpm audit --prod` found high-severity PostCSS source-map path traversal.
   `postcss` was overridden to 8.5.18; final audit found no known vulnerabilities.
8. Artifact scanners omitted the active RevenueCat V2 secret variable name.
   V2 was added to source, Android, and package scanner secret sets.

Warnings retained: one Expo transitive peer warning for `@expo/dom-webview`
57.0.0 versus `^57.0.1`; Expo Doctor passes 20/20. Flutter reports seven
lockfile-upgradable dependencies. Neither warning was force-upgraded in this
scoped release.
