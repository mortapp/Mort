# Supabase-Only Mobile Notifications Plan

> Execution is authorized by the user. Retain Firebase source/packages as dormant code; disable all runtime and release-profile use.

**Goal:** Keep MORT's notification inbox on Supabase and disable Firebase/FCM initialization, device registration, and release-build configuration.

**Architecture:** Preserve the existing Supabase `notifications` and preference APIs. Force remote push off in every mobile release profile, return the disabled provider unconditionally, and make the UI state that in-app notifications are Supabase-backed while remote alerts are off. Keep Firebase packages/source for now, as requested, but ensure the app cannot activate them.

**Tech Stack:** Flutter/Dart, PowerShell release scripts, Node profile validator, PostgreSQL/Supabase local services.

**Spec:** User instruction in this conversation: “don't remove it just disable it just put it to rest”; use Supabase only.

## Global Constraints

- Keep production project `jxbnrkasktbhtiujkhay`; never contact the deleted project.
- Do not run production DDL, production data writes, or production restores.
- Keep marketplace publishing, payments, and real document collection disabled.
- Do not claim production data/Auth/Storage restore succeeded from a schema-only clone.
- Do not print or commit credentials or production data.

## Review Focus

- A manually supplied `MORT_REMOTE_PUSH_ENABLED=true` must not initialize Firebase.
- Release profile JSON, Dart profile validation, and PowerShell AAB builders must all reject/disable remote push consistently.
- Notification settings must not call absent push-device RPCs or imply remote delivery works.
- The local restore drill must preserve exact schema behavior while using synthetic Auth/Storage records unless a full authorized backup is available.
- Native Android/iOS generated plugin configuration must not trigger Firebase initialization.

---

### Task 1: Disable remote push without removing Firebase source

**Files:** `flutter_mort/lib/core/config/app_config.dart`, `flutter_mort/lib/services/push/remote_push_provider.dart`, `flutter_mort/lib/services/push/push_notification_coordinator.dart`, `flutter_mort/lib/features/notifications/notification_center_screen.dart`, `flutter_mort/lib/data/repositories/notifications_repository.dart`, release profile JSON/validators/build scripts, and notification tests.

- [ ] Add a regression that proves remote push remains disabled even if a push build define is present and that release profiles select Supabase-only inbox notifications.
- [ ] Run the new regression and confirm it fails against the current Firebase-enabled pilot profile.
- [ ] Force the app provider to the no-op implementation, prevent push device RPC calls, remove the push permission/toggle UI, and set every release profile's remote push field to false while retaining Firebase dependencies/source.
- [ ] Run focused Flutter and release-script tests; verify zero runtime initialization paths are reachable.

### Task 2: Verify local database/Auth/Storage restore boundaries

**Files:** existing local backup and restore scripts/reports; add focused test evidence only if there is an available backup artifact and local Supabase service stack.

- [ ] Inventory local backup artifacts and available local Auth/Storage services without printing secrets or exporting production user data.
- [ ] Restore the exact production schema snapshot and synthetic Auth/Storage fixtures locally if supported; verify the same database contract tests.
- [ ] Report separately what cannot be proven without a real backup containing database data and Storage object bytes.

### Task 3: Google OAuth handoff

**Files:** readiness report only.

- [ ] Record exact Google Cloud and Supabase configuration steps using the existing verified callback URI; do not change provider secrets or claim real login success without dashboard access.

