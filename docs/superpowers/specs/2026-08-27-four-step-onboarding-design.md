# Four-Step Production Onboarding Design

## Goal and invariant

MORT production onboarding has exactly four primary user-facing steps:

1. `account` — **Your account**
2. `work_preferences` — **Work preferences**
3. `safety_support` — **Safety & support**
4. `review` — **Review & finish**

`complete` is a terminal server state, not a fifth screen. Informational Terms, Privacy, and Safety destinations opened from Review & finish are links or sheets and never become additional onboarding steps.

Progress is a resume hint only. Eligibility to complete is always recomputed from canonical persisted server data. Flutter renders server truth; local draft state is unsaved input only.

## Current repository truth

- `flutter_mort/lib/features/onboarding/compact_onboarding.dart` is the production mobile path. It currently has five visible pages and translates them to the legacy age, role, profile, skills, availability, transportation, payment, guardian, preferences, safety, and review checkpoints.
- `supabase/migrations/20260730003000_server_authoritative_resumable_onboarding.sql` defines the legacy resumable model and protected completion path. Later migrations harden the completion trigger against direct client writes.
- `save_my_profile_setup_v2()` already owns atomic caller-bound validation and writes for display name, username, DOB, role, location, availability, and preferred categories. The new contract must reuse that server truth rather than duplicate its rules.
- MORT already versions published legal documents in `legal_documents`, `legal_document_versions`, `legal_role_requirements`, and `legal_acceptances`; onboarding must use that architecture.
- The legacy Expo route `app/onboarding.tsx` directly upserts `onboarding_completed`. Although Flutter is the release client, that route is a known bypass attempt and must be made incapable of completing production onboarding.
- `goals` exists on `profiles`, but compact onboarding currently submits an empty value and no current onboarding-dependent downstream use was found. It is excluded from the shortened onboarding.

## Four-step UX and persisted contracts

### 1. Your account (`account`)

Collect DOB, role, display name, username, and privacy-safe general location. Adult account type and conditional business name are also collected for an adult role because the schema and existing profile setup RPC already support them.

Before the first immutable DOB/role save, show a clear confirmation containing the selected DOB and role, validate both, offer an obvious edit action, and state concisely that they cannot be changed afterward. The server keeps DOB and role immutable and independently derives under-13, teen (13–17), and adult/guardian (18+) eligibility. Admin is never self-selectable.

The account requirement is complete only when canonical profile data passes the shared server validators: valid display name and username, eligible DOB/role pairing, valid role-appropriate location mode and location fields, and valid adult account metadata where applicable. Display-name validation accepts real Unicode letters and combining marks plus ordinary human-name punctuation, while rejecting control characters, empty/whitespace-only values, punctuation-only values, emoji-only values, repeated garbage, and known placeholder/test strings.

### 2. Work preferences (`work_preferences`)

This step is role-specific and may be intentionally short. It does not collect fields merely to fill the page.

- **Teen:** persist at least one preferred job category, a non-empty availability description, and at least one supported transportation method. Optional existing travel controls—maximum distance, maximum travel time, walking-only, and guardian transportation possible—remain optional and are persisted only when selected.
- **Adult/business:** no additional onboarding prerequisite beyond the supported account type and conditional business name already saved in Step 1. Job-specific schedule, service, payment, and posting details belong to each job-posting flow. The screen explains this and continues without inventing profile fields.
- **Guardian:** no teen job-preference or work-preference requirement. The screen explains that Guardian Mode setup occurs in Safety & support and continues without inventing fields.

Transportation is merged into the teen Work preferences screen and is not a separate primary step. Work goals are not collected. A category, availability, or transportation control shown here must persist to canonical profile data; no explanatory filler skills or availability page remains.

### 3. Safety & support (`safety_support`)

Show concise safety essentials, free reporting/blocking/Safety Ping expectations, and optional Guardian Mode setup for teens. A teen can link/invite a guardian or explicitly skip for now; skipping does not restrict basic onboarding or make safety premium. A particular job may still require guardian approval.

Persist notification intent separately from device permission. The backend may store `ask_later`, `preferred`, or `not_preferred` intent, but this is never represented as Android/iOS authorization and is never required for onboarding completion. Review & finish resolves the native state through `NativePermissionsService` and displays one of: **Enabled**, **Not enabled yet**, **Denied**, or **Needs Settings**.

OS accessibility behavior is respected automatically. Explicit larger-text, contrast, or reduced-motion overrides remain optional controls or normal Settings and are never completion prerequisites.

The safety-support requirement is complete only when canonical role-appropriate safety state exists: for a teen, Guardian Mode is `linked`, `invite_pending`, or explicitly `skipped`; for all roles, required safety-support intent/state is persisted. Published policy acknowledgements remain part of the Review & finish completion transaction, not generic Step 3 booleans.

### 4. Review & finish (`review`)

Show one editable summary and one dominant Finish action. Required current Terms, Privacy, Community/Safety, and other role-applicable documents are shown from the existing published legal-version architecture. Opening a document is informational navigation and returns to the same fourth screen.

The user acknowledges exact current published document version identifiers. The server persists authenticated user, document/version, timestamp, UI/client version, and the existing acceptance audit fields through the established legal acceptance RPC/implementation. It never invents a version, treats a draft as published, or substitutes generic `accepted_terms = true` booleans. If a required public policy is unavailable, completion remains blocked and release-readiness documentation reports the external condition truthfully.

The screen explicitly distinguishes:

- **Job payment:** MORT currently does not process or escrow real-world payment for agreed jobs, if canonical backend/release truth still confirms that state.
- **Digital MORT purchase:** optional subscriptions and digital upgrades may be billed through Google Play when legitimately configured.

It must not say broadly that “payments are disabled” when digital purchases are available, and onboarding contains no paywall.

## Server-derived completion and resume

`get_my_onboarding_progress_v2()` computes and returns:

- `completed`
- `active_step`
- `completed_steps`
- `missing_requirements`
- `role`
- a server revision or canonical `updated_at` value for stale-write detection

The computation evaluates actual persisted data in order:

1. If required account data is missing or invalid, return `account`.
2. Else if required role-specific work data is missing or invalid, return `work_preferences`.
3. Else if required safety/support state is missing, return `safety_support`.
4. Else if current required published legal/policy versions are not actively acknowledged or completion has not occurred, return `review`.
5. Else return `complete`.

Existing valid completed users remain complete. Legacy progress is consulted only as a conservative fallback when canonical data cannot safely disambiguate state; it is not the primary migration algorithm. Existing users are never forced to re-enter already-valid data merely because the state model changed.

`complete_my_onboarding_v2()` independently reruns the same canonical validators inside its transaction and locks the caller's relevant state. It does not trust `active_step`, `completed_steps`, client booleans, or any progress marker. Only after account, role-specific work, safety/support, and current legal requirements all pass may it set the existing protected completion-session setting and update `profiles.onboarding_completed`.

## Compatibility-safe v2 representation

Use a forward-only migration. Do not rewrite migration history, reset hosted Supabase, mutate the legacy step constraint incompatibly, or destructively replace legacy progress.

The preferred design is projection: `get_my_onboarding_progress_v2()` derives the four-step result from canonical tables while the legacy `onboarding_progress` representation remains available for deployed clients. If a small v2 request ledger or state table is required for idempotency/concurrency, it is additive, RLS-enabled/forced, inaccessible directly to `anon`/`authenticated`, and writable only by caller-bound RPCs.

Release lifecycle:

- **Release N:** legacy and v2 RPCs coexist; the new Flutter production candidate uses v2 exclusively.
- **After the minimum supported legacy-client window:** verify supported builds and telemetry/repository references no longer call legacy RPCs.
- **Separate approval and migration:** revoke/remove legacy write functions with a later forward-only migration. This implementation does not remove them without evidence.

## Canonical validation reuse

Do not create separate validators for profile editing, old profile setup, account onboarding, and work onboarding. Extract the authoritative validation/write logic currently embodied by `save_my_profile_setup_v2()` into a private server implementation, or have the new public RPC wrappers delegate safely to one canonical implementation.

The shared implementation owns normalization and validation for display name, username, DOB, role, location, adult account metadata, availability, categories, and existing transportation validation. Public `security definer` wrappers remain caller-bound, use an empty `search_path`, accept only allowlisted fields, and have `PUBLIC`/`anon` execute revoked before the explicit `authenticated` grant.

## Exact idempotency and concurrency contract

Each request identity binds:

- authenticated user ID;
- RPC/operation name;
- logical onboarding step;
- `client_request_id`;
- payload schema version;
- canonical payload hash.

Required behavior:

- Same user + operation + step + request ID + version + payload returns the original successful result or a safe idempotent success.
- Same bound identity with a different payload rejects with a mismatched-replay code.
- Different users using the same request ID are independent and cannot read one another's result.
- Timeout then retry creates no duplicate side effects.
- Concurrent double Finish performs one logical completion and returns one canonical completed result.
- A stale mutable save that conflicts with a newer server revision is rejected with reload-required state; it never silently overwrites immutable or server-authoritative data.

The request ledger key is scoped by user and operation, not a client ID alone. Payload hashes are generated server-side from canonicalized payloads.

## Database security boundary

The existing `profiles` completion trigger remains the database boundary. Normal authenticated clients must be unable to set `onboarding_completed = true` through direct `UPDATE`, `UPSERT`, PostgREST, stale Expo code, or malformed session configuration. Only the server-authoritative completion RPC may set the protected transaction-local completion guard after validating the authenticated caller.

Hostile-client regression coverage must prove:

- authenticated direct `UPDATE onboarding_completed=true` is denied;
- authenticated direct `UPSERT onboarding_completed=true` is denied;
- malformed or client-set completion session state is denied;
- valid `complete_my_onboarding_v2()` is allowed only after canonical prerequisites pass.

UI discipline is not a security boundary.

## Legacy Expo disposition

Audit the root Expo/EAS build and release scripts. Because `app/onboarding.tsx` currently attempts direct completion, it may not remain an intentionally usable production path.

Current release documentation identifies Flutter as canonical and Expo as a preserved reference. Therefore this stage makes Expo explicitly reference-only: production configuration/build checks must prevent the Expo app from targeting the production onboarding backend, and a regression proves the supported production artifact is Flutter. The database trigger protects production regardless of client disposition.

## Flutter architecture and reconciliation

Refactor `CompactOnboardingScreen` into a four-step coordinator with focused step widgets and a local `OnboardingDraft`. `ProfileRepository` owns v2 RPC payload construction and code-to-field user-facing error mapping.

On startup and after every successful save, Flutter refreshes `get_my_onboarding_progress_v2()` and renders the returned server state. It never infers completed steps from populated local fields. Dirty drafts protect unsaved user input but do not override newer server data.

For two-device or concurrent sessions:

- Device B's successful server advance is authoritative when Device A resumes.
- Progress never moves backward because an older device refreshes.
- A stale conflicting save rejects and reloads rather than silently overwriting protected state.
- Completion is idempotent across devices.

The coordinator owns `Step N of 4`, safe-area-aware scrolling, 100%/150% text scaling, process restart, system Back confirmation for dirty input, and a single route decision after completion.

## Production-copy requirements

Shipping onboarding and non-admin status UI must not display internal or closed-test language, including:

- `Closed Pilot`
- `Closed test`
- `Server-controlled access`
- `Approved participants only`
- `public-release approved`
- `privileged role`
- `attorney-approved`
- raw `not_started`
- raw snake_case statuses

The regression scan is deliberately scoped to production user-facing onboarding/status Flutter widgets and copy sources. It does not indiscriminately scan internal documentation or admin tooling.

## Requirement ownership

| Requirement | Authoritative owner |
| --- | --- |
| Four primary steps and terminal state | v2 server projection; Flutter renders the returned contract |
| Account/profile validation | shared private server validation implementation reused by profile setup/editing and onboarding wrappers |
| DOB/role immutability and confirmation | database validation/immutability; Flutter pre-save confirmation UX |
| Role-specific work requirements | v2 server prerequisite evaluator; Flutter role-specific Step 2 widget |
| Guardian/safety-support state | existing Guardian/profile tables and caller-bound RPCs; Flutter Step 3 widget |
| Notification intent | v2 server preference state |
| Native notification permission | `NativePermissionsService` and OS only |
| Accessibility behavior | OS defaults plus optional Flutter settings; never a server prerequisite |
| Published legal versions and acceptances | existing legal document/version/acceptance tables and RPC implementation |
| Resume/completion decision | `get_my_onboarding_progress_v2()` and shared canonical prerequisite evaluator |
| Completion write authority | `complete_my_onboarding_v2()` plus the protected profile completion trigger |
| Idempotency/concurrency | private additive request ledger and transaction-level locking |
| Existing-user migration | canonical persisted-data projection; legacy progress only as conservative fallback |
| Legacy-client compatibility | unchanged legacy RPC/state surface during Release N |
| Expo bypass disposition | reference-only production build/config guard plus database completion trigger |
| User-facing copy and four-step UI | Flutter onboarding coordinator and scoped widget/copy regressions |

## Test and verification strategy

Durable backend and Flutter contract tests must assert the production primary step sequence is exactly:

`account`, `work_preferences`, `safety_support`, `review`, followed by terminal `complete`.

No fifth required screen or legacy checkpoint translation may appear without intentionally changing that contract.

Flutter tests cover role-specific fields, persisted resume, server reconciliation, Unicode and garbage display names, username parity, DOB confirmation and age/role rejection, optional Guardian skip, notification OS truth, Back, restart, double Finish, job-payment versus digital-purchase copy, SafeArea, 100%/150% text, and shipping-copy exclusions.

Database/hostile-client tests cover canonical-data-derived resume, valid existing-user preservation, legacy coexistence, caller identity, direct completion denial, canonical validation reuse, role/DOB immutability, request replay and payload mismatch, cross-user request-ID isolation, concurrent saves/Finish, legal version enforcement, completion prerequisites, RLS, and migration parity.

Run focused red/green tests, full Flutter tests, `flutter analyze`, formatting, backend regression, RLS/hostile-client tests, migration parity, and secret scanning. Physical Galaxy A14 QA is a separate post-implementation checkpoint and reports only scenarios actually executed.

## Explicit non-goals

- No production publication, Play Console product/price changes, real-money purchase confirmation, merchant agreement, or hosted Supabase reset.
- No payment processing, escrow, wallet, teen payout, or job-payment Play Billing implementation.
- No onboarding paywall, verification entitlement, or premium safety feature.
- No fake notification permission, policy publication, product, price, entitlement, provider state, or successful physical QA claim.
- No unrelated rewrite of Google Auth, Supabase, RevenueCat, or marketplace architecture.
