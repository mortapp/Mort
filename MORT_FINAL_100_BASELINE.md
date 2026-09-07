# MORT Final-100 Readiness — Baseline

Generated fresh on 2026-09-06/07. All values below are from live commands run in this session, not prior reports.

BASE_SHA=b0a7107e60ce8f110a89cf4c6f6d4a1db541819a
BRANCH=integration/mort-final-100-readiness
WORKTREE=C:/Users/micha/Mort/.worktrees/integration-mort-final-100-readiness
DIRTY_BEFORE=NO (fresh worktree checked out from origin/main)
FLUTTER_VERSION=3.47.2 (stable, engine 1cf1c4773fb9)
DART_VERSION=3.13.2
NODE_VERSION=v24.12.0
PNPM_VERSION=not yet verified this session
ANDROID_SDK=present at C:\Users\micha\AppData\Local\Android\Sdk (ANDROID_SDK_ROOT unset, ANDROID_HOME set)
JAVA_VERSION=1.8.0_481 (Java 8 — likely too old for current Android Gradle Plugin; needs verification against this repo's AGP version before release builds)
BROWSERSTACK_STATUS=NOT_CONFIGURED (BROWSERSTACK_USERNAME/BROWSERSTACK_ACCESS_KEY unset locally; no repo secrets found via `gh secret list`; no BrowserStack MCP connected)
IOS_BUILD_ENVIRONMENT=UNAVAILABLE (Windows host, no Xcode/macOS; no macOS CI workflow exists yet in .github/workflows)
KNOWN_EXTERNAL_GATES=BrowserStack account/credentials, Apple Developer account + signing certs, App Store Connect, production payment provider, production identity provider, push notification certs, legal final approval, moderation staffing

## PR #7 merge (pre-authorized in task spec, conditions verified before merging)

- head SHA verified: c2e2e13d9672af926bd4fcd4e19784b90890117b (matched expected)
- mergeStateStatus: CLEAN, mergeable: MERGEABLE
- CI: flutter-authoritative PASS, public-site PASS, expo-reference PASS (3/3 green)
- Diff scope verified: 3 test files (formatting/assertion tweaks) + pnpm-lock.yaml + pnpm-workspace.yaml only — matched expected "formatting + pnpm workspace repair" scope, no unrelated files
- Merged via `gh pr merge 7 --merge` → merge commit b0a7107e60ce8f110a89cf4c6f6d4a1db541819a
- main updated: 14c9521c → b0a7107e

## Fresh verification run (this worktree, this session)

- `flutter pub get`: PASS (86 packages have newer versions available under current constraints — informational only, not a failure)
- `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS — 260 files, 0 changed
- `flutter analyze --no-pub`: PASS — no issues found (104.5s)
- `flutter test --no-pub`: PASS — 448 passed, 2 skipped, 0 failed, exit code 0

## Not yet run this session (next steps)

- Android debug/release APK + AAB build verification
- pnpm install --frozen-lockfile / public legal site build+validate scripts
- Backend/RLS/Supabase audit
- iOS macOS CI workflow (none exists yet — must be created)
- BrowserStack setup (blocked on user account/credentials)

## Out-of-scope working tree noted (not touched)

`C:\Users\micha\Mort` (main checkout, branch `feature/compact-onboarding-and-screen-polish`) has ~100 uncommitted changes (new Financial Safety feature code, atmosphere system, mascot picker, new Supabase migrations, deleted/replaced brand assets) tied to open PR #4, which is currently `CONFLICTING` against the new main. This is separate in-progress work and was left untouched per the instruction not to run this program on a dirty existing tree.
