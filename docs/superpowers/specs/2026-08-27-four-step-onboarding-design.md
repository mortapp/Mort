# Four-Step Production Onboarding Design

## Goal

Replace MORT's current five-page Flutter onboarding and its legacy twelve-checkpoint backend model with exactly four primary, resumable, server-authoritative steps:

1. **Your account**
2. **Work preferences**
3. **Safety & support**
4. **Review & finish**

The implementation must retain the existing age/role restrictions, immutable DOB and role rules, idempotency, profile privacy, legal acknowledgements, and completion guard. It must not introduce a client-side path that writes `onboarding_completed` directly.

## Current-State Findings

- The production Flutter client is the canonical mobile implementation: `flutter_mort/lib/features/onboarding/compact_onboarding.dart`. It has five visible pages, while internally calling the legacy age, role, profile, skills, availability, transportation, payment, guardian, preferences, safety, and review checkpoints.
- `supabase/migrations/20260730003000_server_authoritative_resumable_onboarding.sql` defines the legacy twelve-checkpoint state machine. Its `complete_my_onboarding()` RPC is the protected completion path.
- `save_my_profile_setup_v2()` in `20260802062226_video_profile_job_hardening.sql` already provides an atomic, caller-bound profile write with server validation for display name, username, DOB, role, location, availability, and preferred job categories.
- The legacy Expo route (`app/onboarding.tsx`) directly upserts `onboarding_completed`; it is not a safe or equivalent implementation and must not be used as the model for the Flutter flow.
- The current Flutter flow persists real work data, but its page labels and checkpoint translation expose obsolete structure and include closed-pilot wording in user-facing acknowledgement copy.

## UX and Data Design

### Step 1 — Your account

Collect and save DOB, role, display name, username, and general location. The server derives age eligibility, refuses under-13 access, enforces teen (13–17) versus adult/guardian (18+) roles, validates display name and username, and stores only general-area information.

Adult account type and business name appear here only for adults. Admin remains unavailable for self-selection. A user who returns after an interruption resumes this step with persisted values; DOB and role remain immutable after their first successful server save.

### Step 2 — Work preferences

For teens, collect real preferred job categories, availability, transportation methods, and optional work goals in one consolidated screen. Transportation is not a separate primary step. For adults, collect only work-relevant account/business and scheduling information already supported by the schema; do not show teen fields. Guardians do not receive teen job-preference fields.

The server accepts only the role-appropriate subset and never treats optional preferences as safety or verification status. The flow will not show a filler skills screen: any category control shown must be persisted through the authoritative profile/setup write.

### Step 3 — Safety & support

Show the safety essentials, optional Guardian Mode setup for teens, notification choice with truthful OS-permission language, and accessibility preferences. Guardian setup can be skipped without restricting basic account completion; a specific job may still require guardian approval. Reporting, blocking, Safety Ping, and basic guardian protection remain free.

The client must distinguish an in-app preference from an OS permission. It may report that notifications are not enabled until the native permission request actually succeeds; it must never claim that a system permission was granted based solely on a button tap.

### Step 4 — Review & finish

Present an editable summary, the required published legal/safety acknowledgements, the concise separation between an agreed job's payment and optional MORT digital purchases, and one finish action. Completion calls a single server RPC. The server validates all four logical steps and any applicable published legal requirements, records the acknowledgement, and atomically marks onboarding complete.

Repeated taps and retry-after-timeout reuse a stable request identifier. Returning completed users route to their role home, never back to onboarding.

## Server State Model

Add a forward-only migration that replaces only onboarding-progress vocabulary with these values:

`account`, `work`, `safety`, `review`, `complete`.

The migration maps existing incomplete legacy states without discarding data:

| Legacy state | New primary step |
| --- | --- |
| `age`, `role`, `profile` | `account` |
| `skills`, `availability`, `transportation`, `payment` | `work` |
| `guardian`, `preferences`, `safety` | `safety` |
| `review` | `review` |
| `complete` | `complete` |

The resulting RPC surface will remain caller-bound and use explicit versioned request payloads:

- `get_my_onboarding_progress_v2()` returns the four-step progress and resume route.
- `save_my_onboarding_account_v2(payload, client_request_id)` validates and atomically saves account fields.
- `save_my_onboarding_work_v2(payload, client_request_id)` validates and persists role-specific work preferences.
- `save_my_onboarding_safety_v2(payload, client_request_id)` saves optional guardian/preferences data and accurate notification intent.
- `complete_my_onboarding_v2(payload, client_request_id)` records acknowledgements and performs the only completion transition.

The v2 completion RPC must check server-persisted prerequisites, reject stale/mismatched replay payloads, and set the existing completion-session guard before the protected `profiles` write. Existing legacy functions are retained only long enough for deployed clients; the app moves solely to v2 and a later explicitly-approved release migration can retire them.

## Client Architecture

Refactor `CompactOnboardingScreen` into a four-step coordinator with small step widgets and a single persisted `OnboardingDraft`. The coordinator owns:

- restoring `get_my_onboarding_progress_v2()` before rendering the active step;
- `Step N of 4` progress, safe-area-aware scrolling, and system Back confirmation for dirty local input;
- per-step async save/error states and stable idempotency IDs;
- one route decision after a successful completion.

`ProfileRepository` owns RPC payload construction, code-to-field error mapping, and no direct table writes for onboarding. Native permission handling stays in `NativePermissionsService`, returning actual resolved permission state rather than optimistic UI state.

## Error Handling and Privacy

- Field errors are mapped to plain user-facing messages; database codes and raw enums never render in the UI.
- Server errors leave local input intact and offer retry.
- The client stores no raw coordinates and continues to use general city/state or the already-approved privacy-safe location mode.
- Passwords, dates of birth, access tokens, webhook secrets, and provider identifiers never appear in analytics, logs, snapshots, documentation artifacts, or error messages.

## Test and Verification Strategy

Add or update Flutter widget/repository tests for the four-step sequence, role partitions, invalid and Unicode display names, username validation parity, teen/adult DOB rejection, persisted restart/resume, Back, double finish, notification truth, optional guardian skip, job-payment copy, and 100%/150% text scaling.

Add migration/hostile-client QA for caller identity, direct-completion denial, role/DOB immutability, request replay, mismatched replay payload, legacy-progress mapping, completion prerequisites, and RLS access. Run focused tests before the full Flutter test suite, `flutter analyze`, migration parity/RLS checks, formatting, and secret scanning. Physical-device QA is a separate post-implementation checkpoint and must report only executed scenarios.

## Explicit Non-Goals

- No production release, Play Console pricing/product changes, real-money purchases, merchant agreements, or payment/escrow/wallet work.
- No new verification entitlement and no safety feature behind a paywall.
- No fake notification permission, store product, price, entitlement, or provider success state.
- No unrelated redesign of Google Auth, Supabase, or the marketplace.
