# MORT 0.9.4 Command Results

Run date: 2026-07-22 through 2026-07-23

This is real execution evidence. Secret values are omitted. Passing engineering
checks do not make MORT production ready.

## Repository

| Exact command | Real result |
|---|---|
| `git fetch origin --prune` and recovery inspection commands | PASS; remote history recovered without replacing the working tree. |
| `git commit -m "chore: recover verified MORT 0.9.3 baseline"` | PASS; commit `3301356`, parent `7bcfca7`. |
| `git commit -m "feat: harden MORT 0.9.4 operations and moderation"` | PASS; commit `b3be6c3`. |
| `git diff --cached --check` | PASS for 0.9.4 implementation commit; only line-ending conversion warnings outside the check result. |

## Hosted Supabase

| Exact command | Real result |
|---|---|
| `npx supabase db dump --linked --schema-only --file backups\0.9.4-predeploy\remote-schema-before-0.9.4.sql` | PASS; 1,595,699 bytes, SHA-256 `DA09035BA9E48BD0FACA6475408B3522DE73ABC171A81B8293DB7D507FD19CB4`. |
| `npx supabase db push --linked` | PASS; three 0.9.4 migrations applied through `20260723030622`. |
| `npx supabase migration list --linked` | PASS; local/remote aligned through `20260723030622`. |
| `npx supabase db lint --linked --level error` | PASS; no error findings. |
| `npx supabase functions deploy send-push --project-ref rakjydmgwwgtdislanbt` | PASS; hardened function deployed. |
| Stripe function deploy commands for nine `stripe-*` functions | PASS; deployed/bundled, provider runtime disabled because Stripe secrets are absent. |
| `node scripts/qa-send-push-observability.mjs` | PASS; HTTP 401 safe code and correlation ID verified without printing secrets. |
| `node scripts/qa-mort-0.9.4-operational-controls.mjs` | PASS; all controls, alerts, moderation, role isolation, and teardown checks passed. |
| `.\scripts\run-final-supabase-regression.ps1` | PASS; 26/26 scripts, including 30/30 multi-user isolation checks. |
| loop over `scripts\qa-stripe-*.mjs` | PASS; 25/25 boundary files. No Stripe provider money action ran. |
| focused support/PIN/evidence eight-file loop | PASS; 8/8 files. |
| `node scripts/qa-account-deletion-conversation-cascade.mjs` | PASS; Auth/profile/conversation residue all absent. |
| `node scripts/audit-historical-qa-accounts-0.9.4.mjs` | PASS; aggregate-only audit, no identifiers or content opened. |
| guarded `REMOVE_STALE_FEATURE_QA_ONLY` cleanup | PASS; eight strict stale accounts removed; repeat found zero. |
| `node scripts/audit-supabase-advisors.mjs` | PASS with zero error-level findings; warning/info inventory retained. |

## Flutter

| Exact command | Real result |
|---|---|
| `flutter pub get` | PASS. |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 152 files, zero changed. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | PASS; no issues. |
| `flutter test` | PASS; 128/128 tests. |
| `flutter build web --release --no-wasm-dry-run ...closed-pilot defines...` | PASS after cleaning stale generated plugin state; built `build\web`. |
| `flutter build apk --debug ...closed-pilot defines...` | PASS; built debug APK. |
| `.\scripts\build-final-play-release.ps1` | PASS; signed QA APK and closed-test AAB built and verified. |
| `.\scripts\android-lint-release.ps1` | PASS; exit 0, no lint error. Java 8 deprecation warnings remain informational. |

## Expo reference

| Exact command | Real result |
|---|---|
| `pnpm install` | PASS; lockfile current. |
| `pnpm check` | PASS. |
| `pnpm lint` | PASS. |
| `pnpm build` | PASS; 48 static routes. |
| `npx expo export --platform web` | PASS; 48 static routes. |
| `npx expo-doctor` | PASS; 20/20 checks. |
| `node scripts/build-route-action-inventory.mjs` | PASS; 175 Flutter routes, 46 Expo source routes, four unresolved builders, 142 without direct static tests. |
| `npx expo start --port 8087` / CI offline retry | PARTIAL; Metro listener was observed on port 8087 and stopped, but `/status` did not return before timeout. Build/export bundlers passed independently. |

## Android emulator and artifacts

| Exact command | Real result |
|---|---|
| `flutter emulators --launch Medium_Phone_API_36.1` | PASS; API 36.1 emulator booted. |
| `adb install -r mort-play-production-pilot-final-qa.apk` | PASS. |
| cold launch/process/log/UI inspection commands | PASS; account entry visible, process alive, zero MORT fatal/ANR lines. |
| force-stop plus offline launch and network-restoration commands | PASS; both launches alive, zero fatal/ANR lines, network restored. |
| `.\scripts\qa-android-apk.ps1 ... -RequireSigned` | PASS; `com.mortapp.mobile`, `0.9.4+94`, min 24, target 36, 10 permissions, signed. |
| `.\scripts\verify-play-aab.ps1` | PASS; protected upload certificate and manifest matched. |

## Security and integrity

| Exact command | Real result |
|---|---|
| `node scripts/secret-scan-git-history.mjs` | PASS; six commits, four configured secret values, one candidate blob, zero findings, no values printed. |
| `.\scripts\secret-scan.ps1` | PASS. |
| `.\scripts\sensitive-file-scan.ps1` | PASS; 1,470 files, 30 approved media files, nine secret values checked. |
| `pnpm audit --prod --audit-level=moderate` | PASS; no known vulnerabilities. |
| eight independent Android/deep-link/network/AI/entitlement checks | PASS; 8/8. |

## Failures found and fixed

1. Historical QA cleanup used nonexistent `stripe_saved_payment_consents.user_id`.
   It now uses `adult_id` and deletes FK graphs in dependency order.
2. Supabase Auth deletion returned HTTP 500 because a cascade update could run
   conversation synchronization after its legacy thread was deleted. Migration
   `20260723030622` guards the trigger; a real synthetic conversation deletion passes.
3. Push token failures stored arbitrary provider messages. They now store only an
   allowlisted provider code or `expo_push_error`.
4. Flutter web retained a generated reference to removed
   `flutter_local_notifications_web`. `flutter clean` plus `pub get` regenerated
   the current plugin set; web release then passed.
5. Flutter 3.41's Windows WASM dry-run failed on an untranslatable URI. The
   maintained dart2js release uses `--no-wasm-dry-run`; no WASM result is claimed.
6. The history scanner initially used unsupported Git ERE syntax, then duplicated
   commit prefixes. Both scanner defects were fixed before the passing scan.
7. Android permission QA still required removal stubs for an SDK no longer
   installed. It now accepts SDK absence only when the final AAB manifest is also clean.
8. Expo wrapper termination left a child process. The exact listener PID was
   identified and stopped; port 8087 was confirmed closed.

## Unrun external gates

No physical Android test, macOS/Xcode build, iPhone test, TestFlight upload, App
Store review, Stripe provider test transaction, live payment, legal approval,
privacy approval, teen-safety approval, staffed incident exercise, or restore
drill was performed.
