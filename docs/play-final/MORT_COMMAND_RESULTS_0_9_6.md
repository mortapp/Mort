# MORT 0.9.6 Command Results

Commands were run from `C:\Users\micha\Mort` unless noted. Secret values were loaded from environment scope where required and were not printed.

## Application and Android

| Command | Result |
|---|---|
| `cd flutter_mort; flutter pub get` | PASS |
| `cd flutter_mort; dart format --output=none --set-exit-if-changed lib test` | PASS, 159 files |
| `cd flutter_mort; flutter analyze` | PASS, no issues |
| `cd flutter_mort; flutter test --reporter expanded` | PASS, 156/156 |
| Flutter hosted web release build with closed production defines | PASS, `flutter_mort/build/web` |
| `.\scripts\android-lint-release.ps1` | PASS; dependency deprecated-API note only |
| `.\scripts\build-closed-test-apk.ps1` | PASS |
| `.\scripts\qa-android-apk.ps1 -ApkPath .\build\play\mort-play-closed-test-qa.apk -RequireSigned` | PASS, `com.mortapp.mobile`, `0.9.6+96`, signed |
| `.\scripts\build-play-aab.ps1` | PASS |
| `.\scripts\verify-play-aab.ps1 -BundlePath .\build\play\mort-closed-test.aab` | PASS, MORT upload certificate |
| `node .\scripts\qa-aab-secret-scan.mjs .\build\play\mort-closed-test.aab` | PASS, 2,596 entries, five available secret values |

## Supabase

| Command | Result |
|---|---|
| `pnpm exec supabase db push --linked --dry-run` | PASS; only reviewer reservation migration pending |
| `pnpm exec supabase db push --linked --yes` | PASS; reviewer reservation applied |
| `pnpm exec supabase migration list --linked` | PASS; local/remote migration `20260726024327` aligned |
| `node .\scripts\qa-play-reviewer-isolation.mjs` | PASS, six reviewer isolation boundaries |
| `.\scripts\run-final-supabase-regression.ps1` | PASS, 31 scripts; multi-user isolation 30/30 |
| `node .\scripts\audit-supabase-advisors.mjs` | PASS with warning/info recommendations and no error-level finding |

## Expo, inventory, and security

| Command | Result |
|---|---|
| `pnpm install` | PASS |
| `pnpm check` | PASS |
| `pnpm lint` | PASS |
| `pnpm build` | PASS, 48 static routes |
| `npx expo-doctor` | PASS, 20/20 |
| `.\scripts\windows-check.ps1` | PASS |
| `node .\scripts\build-route-action-inventory.mjs` | PASS, 178 Flutter routes, 46 Expo reference routes, zero unresolved builders |
| `.\scripts\secret-scan.ps1` | PASS |
| `node .\scripts\secret-scan-git-history.mjs` | PASS, 10 commits, no findings |
| `.\scripts\sensitive-file-scan.ps1 -RootPath .` | PASS after traversal fix; 1,533 files |
| `corepack pnpm audit --prod` | PASS after dependency override fix; no known vulnerabilities |
| `git diff --check` | PASS |
| `.\scripts\package-mort-0.9.6.ps1` | PASS; ten release artifacts inventoried and scanned |

## Failures found and fixed

1. Reviewer tests initially failed to compile because Riverpod 3 moved `ChangeNotifierProvider` to the legacy import and because `MortColors.success` did not exist. The import and color reference were corrected.
2. The reviewer source-boundary test falsely treated required disclaimer text containing `Stripe` as an SDK call. The assertion now detects imports and executable calls.
3. Flutter analyze found an unnecessary interpolation brace. It was corrected.
4. `pnpm audit --prod` under global pnpm 10 failed while parsing a gzip registry response. `corepack pnpm audit --prod` provided a compatible audit path and exposed a real vulnerable `brace-expansion` dependency.
5. The package-level pnpm override field was ignored by pnpm 11. Overrides were moved to `pnpm-workspace.yaml`, `brace-expansion` was pinned to 5.0.8, the lockfile was reinstalled, and audit passed.
6. The first broad sensitive-file scan timed out after source scan completion because excluded generated directories were still enumerated. Traversal now prunes excluded directories and the full scan passes.
7. The route inventory generator wrote updated data into 0.9.5 filenames. The release slug was corrected and 0.9.6 inventory files are generated separately.
8. Emulator ADB bulk text input dropped reviewer-identifier characters. Signed-APK QA used deterministic character-by-character input; app input handling did not fail.
9. Emulator harness exact role matching did not account for multiline accessibility labels, and one restart assertion called `Trim()` on a null value. The assertions were rerun with robust matching/null handling; app behavior passed.

The Android emulator also produced one System UI ANR dialog. Waiting recovered the emulator, and no MORT fatal exception or MORT ANR was found. This remains a reason to require physical-device testing.
