# MORT Flutter ↔ Production Supabase Contract Diff

**Status:** In progress; no production changes applied.  
**Snapshot:** 2026-10-31 local date (Supabase catalog inspected read-only; migration list through `20261101002805_safety_reports_server_only_idempotent`).  
**Code baseline:** `29a8cf141b44b6ae7a4a37965b99f9c47b310282`.  
**Isolated branch:** `codex/flutter-backend-integration` (new local worktree).  
**Production target:** Supabase `jxbnrkasktbhtiujkhay`.

## Authentication and school-affiliation follow-up

- The live Auth trigger requires a DOB in signup metadata. Email signup now collects DOB and sends `date_of_birth`; server-side trigger validation remains authoritative. This does not constitute identity/age-provider verification.
- Teen onboarding requires active email confirmation and an allowlisted school email domain. The current allowlist has `herronclassical.org` and `herronriverside.org`; domain allowlisting is not proof of enrollment, age, or identity.
- Production lacks `get_my_account_trust_profile`, `get_marketplace_trust_eligibility`, and `request_school_email_affiliation`; the corresponding settings routes cannot complete those requests. No compatibility RPCs were invented. These screens need an approved server contract or explicit fail-closed UI before release.
- `get_my_identity_verification_v2()` reports no provider, no production verification, and disabled submissions. Keep document collection disabled and do not mark users verified.

## Nov 1, 2026 local draft verification update

- Application wrapper now treats absent/NULL `eligible` as false. The eligibility RPC uses a fresh wall clock after locking profile/job/release/Guardian/verification evidence and serializes with the canonical poster/teen block-pair lock. The lower-level submission function rechecks eligibility before insert.
- The private-location draft now uses private-schema storage and an address-only authenticated save contract. Release binds the application, assignment, job owner, active assignment state, mutual current safety confirmations, location version, and participant block state. Owner and teen releases are denied after job/assignment cancellation or completion.
- The previous proposal at `supabase/proposals/private_job_location_lifecycle.sql` is marked superseded. Do not apply it or mix it with the current migration.
- Flutter's active private-location repository now calls `save_job_private_location_v1(uuid,text,text,text,uuid)` with address, private arrival/access notes, and a request UUID. It no longer sends client latitude/longitude. The draft stores these private notes and archives the old values when terms change.
- Local structural Node tests: **14 passed, 0 failed**. Static and UTF-8 migration checks passed; ACL contract passed on disposable PostgreSQL 17. A data-free schema clone from the existing local Supabase database was created, but its schema is not production-equivalent: application migration replay stopped at missing `public.mort_release_control`. No further SQL was run against that clone and no production SQL was applied.
- Removed client-side precise-location capture from active job posting; the app no longer claims a distance estimate without a trusted server calculation.
- Production read-only catalog evidence remains the source for live signatures. Full hosted-schema migration replay, pgTAP data behavior, RLS negative/positive cases, and real two-session application/block-message races remain blocked until a production-equivalent schema is available locally without a paid resource.
- The latest production read-only catalog check found no job assignments, so there is no live assignment record against which to validate release behavior. Production was only queried read-only.

## 2026-11-01 marketplace safety follow-up

### Application contract actually used by Flutter

| Operation | Production contract | Authorization/state notes | Flutter status |
|---|---|---|---|
| Read current applications | `get_my_job_applications(p_application_id uuid default null) returns jsonb` | Production function returns only rows authorized for the current teen, poster, or active Guardian with mutual consent. Row output includes production `applicant_id` and `cover_note` (alongside the UI's prior `teen_id`/`note` form). | Repository uses this RPC; model maps both field shapes. It does not access absent `applications`. |
| Change application state | `update_my_job_application_status(p_application_id uuid, p_action text, p_expected_updated_at timestamptz) returns jsonb` | Existing server transition logic permits adult poster `accepted`, `shortlisted`, `rejected`, `viewed`; applicant `withdrawn` only from submitted/shortlisted. Expected timestamp is checked server-side. | Repository sends the exact production arguments and rejects unsupported client actions. |
| Submit application | `submit_job_application(p_job_id uuid, p_note text, p_availability_confirmed boolean, p_portfolio_ids uuid[]) returns jsonb` | Eligibility is checked before delegation. Underlying submission locks the job, but the observed recheck does not cover every eligibility field after lock. | Not altered in this follow-up. Treat eligibility stale-state race as unresolved until secure additive database change passes isolated concurrency tests. |
| Accept application | `mort_accept_job_application(p_application_id uuid) returns uuid` | Existing implementation checks poster role/identity, teen age verification, Guardian link/consent when required, and block state. | No replacement contract or client bypass added. |
| Guardian application decision | **No production RPC** | No production `guardian_pending`/Guardian decision state was found. Existing Guardian link read authorization is not an application decision authorization contract. | UI is read-only; no approve/reject action is presented as functional. |

### Private location and distance

- `jobs.exact_address` exists, but the observed save/publish RPC sets it to null and the column is not selectable by `anon` or `authenticated`. No private-location relation or save/release RPC exists in production.
- No production server distance RPC or job-coordinate columns were found. The historical migration `20260819000000_job_site_precise_location_and_distance.sql` targets legacy `applications`; it is design reference only and is not safe to apply as written.
- Flutter removed the missing distance-RPC call and client coordinate request. Distance stays unavailable until a server-side contract has explicit eligibility and privacy tests.

### Current Flutter regression changes

- `ApplicationsRepository` now reads and mutates via the exact production application RPCs, and no longer sends unsupported Quick Accept/status-v3 calls.
- Teen application lists are scoped to the teen; Guardian views are read-only; adult job lists are scoped to the poster. Server response authorization remains the source of protected rows.
- `MortApplication.fromMap` accepts actual production `applicant_id`/`cover_note` fields and the existing UI aliases.
- Job feed no longer calls `get_nearby_job_distances_v1` or uses precise device coordinates for distance.
- Quick Accept UI and tests were removed because no production contract exists.

### Validation boundary

These Flutter changes can be regression-tested locally, but database behavior is **not verified** in an isolated production-equivalent database. Production has 69 migrations through `20261101002805_safety_reports_server_only_idempotent`; local repo/container migration history is different. Local container egress to the production database returned `Network is unreachable`, and no supported temporary Supabase branch is available. No production SQL was executed. Application stale-state concurrency, Guardian decisions, private-location save/release, server distance, and message/block serialization remain blockers pending an isolated database matching the production catalog plus pgTAP and independent two-session tests.

### Authorization matrix and contract state

| Capability | Intended authorization | Production evidence / state |
|---|---|---|
| Read an application | Applicant; job poster; or active linked Guardian only with both teen and Guardian consent | `get_my_job_applications(p_application_id uuid default null)` enforces these branches in its body. **Flutter aligned; production RPC was inspected read-only.** |
| Submit an application | Active, age-verified eligible teen; not self-applying; job open, approved, unexpired, accepting applications; valid age range/Guardian requirements; no block either direction | `submit_job_application(p_job_id uuid,p_note text,p_availability_confirmed boolean,p_portfolio_ids uuid[]) returns jsonb` exists. Eligibility currently precedes the locked insert; required full recheck under lock is **BLOCKED**. Preserve the unique `(job_id, applicant_id)` key. |
| Change application state | Adult job poster may mark viewed/shortlisted/accepted/rejected; applicant may withdraw only from allowed current states; Guardian cannot decide without a dedicated contract | `update_my_job_application_status(p_application_id uuid,p_action text,p_expected_updated_at timestamptz)` applies row lock and optimistic timestamp. Flutter calls it using supported actions. **Guardian approval/rejection remains BLOCKED** because no Guardian decision RPC/state exists. |
| Read precise job location | Poster for their own job; assigned teen only after accepted assignment and mutual confirmation of the current `job_safety_agreements.agreement_version`, and only while neither party blocks the other | No private location relation/RPC exists. `job_assignments.status` accepts `accepted`, `in_progress`, `awaiting_confirmation`, `completed`, `cancelled`, `disputed`; `job_safety_agreements.status` accepts `awaiting_both`, `awaiting_teen`, `awaiting_adult`, `confirmed`, `reconfirmation_required`. Proposed access must be narrowly restricted to an active assignment state and `confirmed` at the current version. **BLOCKED; no locations are saved or released.** |
| Request job distance | Active teen only; bounded IDs and validated fresh coordinates; server computes and returns coarse band; no persisted teen coordinates | No production RPC or job coordinate columns exist. Flutter does not call an absent RPC or calculate client-side distances. **BLOCKED; distance remains unavailable.** |
| Create/remove a block | Authenticated blocker for self as blocker; cannot block self; idempotent create, scoped removal | Existing `user_blocks` PK is `(blocker_id,blocked_id)`. Local proposal serializes RPC and direct table mutations through one canonical pair lock. **PROPOSED; not production-applied or concurrency-verified.** |
| Send a message | Active conversation member, sender matches authenticated user, conversation active, and neither direction blocked | Existing `conversations.status` includes `active`, `closed`, `under_review`; `send_safe_message_v2` and `mort_send_message` exist. Proposed insert trigger checks sender, membership, active status, and both block directions, then locks the same participant pair(s) as block mutations. **PROPOSED; requires the isolated two-session test.** |

Required isolated database test cases are enumerated in the execution request. They must use actual production schema and roles. The local `supabase/tests/production_safety_pair_lock_concurrency.ps1` harness uses two independent authenticated PostgreSQL sessions and refuses production/deleted project refs. It must demonstrate that after the block transaction acquires the canonical pair lock and commits, a concurrent message transaction cannot commit. It has not been run; a single-session pgTAP sequence does not prove this race property.

Flutter-side regression results on 2026-11-01: `flutter test --no-pub` completed **617 passed, 2 skipped, 0 failed**. The focused affected-area command (`flutter test test/teen_core_visual_convergence_test.dart test/android_native_parity_test.dart test/application_detail_screen_test.dart test/production_readiness_contract_test.dart --no-pub`) completed **29 passed, 0 failed**. `flutter analyze --no-pub` completed with **No issues found**; `dart format` and `git diff --check` pass. These client tests do not verify database concurrency, RLS, transaction rollback, private-location authorization, or location distance bands.

## 2026-11-01 execution update from production read-only inspection

### Migration/environment reconciliation

- Branch starts at `c76ad2f337e2565439064ef954193494fb515a08`; working tree was clean at inspection start. No PR exists for this branch.
- Production Supabase reports **69** migrations, from `20261026194801` through `20261101002805_safety_reports_server_only_idempotent`.
- Local `supabase/migrations` contains **240** SQL files, with a different history including older August/September schemas and the unverified `20261101022649` proposal. The local Docker database is healthy but is not a schema-equivalent environment. Supabase CLI is not installed.
- Supabase branch listing returned only `main`; no isolated child branch is available. No branch/project was created and no upgrade/cost was incurred. Per instruction, all database execution and pgTAP runs are stopped until a no-cost exact isolated schema is available.

### Exact active production contracts and findings

| Area | Production evidence | Result |
|---|---|---|
| Application submit | `submit_job_application(p_job_id uuid,p_note text default null,p_availability_confirmed boolean default false,p_portfolio_ids uuid[] default '{}') returns jsonb`; authenticated execute. It calls eligibility before `mort_submit_job_application`. The latter is service-role-only, locks `jobs`, then checks open/approved, self-apply, age/DOB/age-verification and blocks. | Locked function does not recheck release flag, `applications_open`, expiry, active poster or Guardian consent. A local replacement proposal now locks the job and authorization rows before rerunning the existing eligibility RPC; it is not applied or verified. Existing unique `(job_id,applicant_id)` remains the final duplicate guard. |
| Guardian | `accept_guardian_invite`, `mort_set_guardian_consent`, `unlink_guardian`, and `set_guardian_alert_preferences` exist. Consent is stored on `guardian_links` as teen/Guardian timestamps; acceptance also validates Guardian role, active account, DOB 18+, confirmed email, invite expiry and rate limit. | No application approval/rejection RPC or Guardian application status exists. No Guardian decision permission was added; application screens stay read-only. |
| Application read | `get_my_job_applications(p_application_id uuid default null) returns jsonb` checks active account and returns applicant, poster, or mutually-consented active Guardian rows; output contains general job area but no exact address. | Flutter uses this server-authorized response and the live state update RPC. No application state names were added. |
| Location | No `private` or `public` location table, location RPC, or distance RPC exists. `jobs.exact_address` has no authenticated SELECT privilege, but authenticated currently has table INSERT plus column UPDATE privilege for `exact_address`. `save_job_draft_or_publish` stores `exact_address=NULL` and returns `to_jsonb(job)-'exact_address'`. | Direct exact-address writes must be revoked in a reviewed migration. No address/coordinate has been saved or exposed by this work. Private location storage/release still requires a production-schema proposal and tests. |
| Location lifecycle | `job_assignments.status` constraint allows `accepted`, `in_progress`, `awaiting_confirmation`, `completed`, `cancelled`, `disputed`. `job_safety_agreements.status` allows `awaiting_both`, `awaiting_teen`, `awaiting_adult`, `confirmed`, `reconfirmation_required`; it stores both confirmation timestamps and versions. `private.job_safety_terms` currently omits a private-location version. | Proposed teen release should require an accepted application, assignment `accepted` or `in_progress`, agreement `confirmed` with both confirmation versions equal to the current version, and no block either direction. Owner access is poster-only; no staff/Guardian location access. Existing legal confirmations need append-only history before any location-change invalidation is implemented. |
| Messaging/blocking | `send_safe_message_v2(p_thread_id uuid,p_body text,p_client_request_id uuid)` is authenticated; it serializes idempotency by request key then calls `mort_send_message`. `mort_send_message(p_conversation_id uuid,p_body text)` is service-role-only, checks active account, active conversation membership and both block directions. `user_blocks` has RLS self insert/delete; no message or block trigger exists. | A message can race a concurrent block because the checks and writes do not share a pair lock. The existing local proposal now adds a canonical pair key, block mutation trigger, sorted pair locks for message inserts and an active-conversation row lock/check. This proposal and its pgTAP edits have not run on a matching database. |

The older August location migration is not reusable: it targets the absent legacy `public.applications` table, assumes absent location/access-audit relations, returns a one-decimal distance instead of coarse bands, and does not enforce the current eligibility/Guardian rules. It remains design reference only.

### Private-location contract proposal (not migration-ready)

Use an unexposed `private` schema table keyed by job and location revision; store exact address/coordinates there, with no direct anon/authenticated grants and forced RLS. Keep `jobs.exact_address` null and outside public/application RPC responses. The active Flutter and reference website writers use `save_job_draft_or_publish(p_job_id uuid,p_client_request_id uuid,p_payload jsonb,p_publish boolean)`, which returns a draft or `under_review` and never includes exact address. The website cutover is complete in commit `763fc1efdf8c323670c8e88b94448b268e26836d`; direct job-table writes are blocked by a regression check. The ACL migration remains unapplied until isolated schema/RLS testing passes.

Proposed server contracts for review: `save_job_private_location(p_job_id uuid,p_exact_address text,p_latitude double precision,p_longitude double precision,p_arrival_instructions text,p_access_notes text) returns jsonb`; `get_released_job_location(p_application_id uuid) returns jsonb`; and `get_nearby_job_distances_v1(p_job_ids uuid[],p_latitude double precision,p_longitude double precision) returns jsonb`. These names/signatures are proposals, not deployed contracts. The location table should retain prior revisions rather than overwrite them. A location change must bump the location revision, preserve old agreement terms/confirmation evidence in append-only history, and force both parties to reconfirm terms incorporating the current location revision. No staff or Guardian release is proposed.

The distance endpoint should require an active teen, validate coordinates and bounded IDs, filter to jobs the teen may see/apply to, compute only on the server, return coarse bands (thresholds still need product selection), and never persist/log teen coordinates or return job coordinates/address. Flutter remains fail-closed and displays distance unavailable.

Before any SQL test environment is available, the required positive/negative suite is: RLS and direct exact-address read/write denials; direct job insert/address write denial; job/poster/age/expiry/release/Guardian/block application gates; stale eligibility and concurrent submission proving exactly one row under the unique key; Guardian link with either consent missing; location save owner/non-owner and draft/open guard; poster-only and accepted-assignment/current-mutual-agreement location release; changed revision, block, cancelled/completed assignment, withdrawn/rejected application denials; distance validation/coarse response/no persisted teen coordinates; and all message/block directions plus inactive conversations. These remain **not run**.

### Local proposed artifacts added this turn

- `supabase/proposals/marketplace_application_submission_race.sql`: same production signature, adds under-lock eligibility recheck and share-locks the relevant authorization rows; proposal only.
- `supabase/proposals/production_safety_missing_contracts.sql`: strengthened local block/message proposal with a shared pair-lock helper, write trigger on `user_blocks`, active conversation check/row lock, sender/member checks, deterministic multi-member lock order, and durable request idempotency.
- `supabase/tests/production_safety_missing_contracts.sql`: pgTAP plan expanded to 25 assertions, including opposite-direction block enforcement, immutable block pair identity, closed-conversation rejection, and internal lock-helper permissions.
- `supabase/tests/production_safety_pair_lock_concurrency.ps1`: true two-process/two-connection QA harness. It requires explicit QA credentials/fixture IDs and refuses production or deleted project refs. It was not run because no isolated database is available.

No location DDL or location tests have been written as executable SQL: production currently has no location/audit contract, and the prior legacy schema is incompatible. Location remains **BLOCKED** pending an exact-schema isolated environment and implementation review. The application race proposal and pair-lock proposal are also **UNVERIFIED**, not complete.

## Scope and inventory method

Static `.rpc('name')` and `.from('name')` references were extracted from `flutter_mort/lib`. Names were compared against production `pg_proc` and public relation catalogs via read-only Supabase SQL. The counts below exclude QA fixtures, dynamic RPC names, storage buckets, and transitive website calls; a repository method is not called a required production contract solely because its name exists. Active-route reachability was checked for the critical onboarding, Guardian, report, block, identity, and admin paths.

- 192 unique statically named RPC dependencies; 77 public function names exist in production; 145 referenced names are absent.
- 33 unique statically named table dependencies; 18 referenced public relations are absent.
- Three absent RPCs have local additive proposals (`block_user_v2`, `unblock_user`, `resend_guardian_invite`); they remain absent from production.

## Critical route findings

| Flow / route evidence | Expected contract | Production status | Action |
|---|---|---|---|
| Post-auth `/onboarding` → `CompactOnboardingScreen`; legacy onboarding URLs redirect to `/onboarding` in `app_router.dart` | `ensure_my_profile`, `get_my_onboarding_progress_v2`, V2 account/work/safety save RPCs, `complete_my_onboarding_v2` | Present; inspected signatures include the V2 payload, request ID, payload version, and revision arguments used by Flutter | No compatibility RPC added. Legacy `save_my_onboarding_age/role/progress` and `save_my_profile_setup_v2` calls belong to screens unreachable through the canonical router. |
| Guardian Mode screen → `GuardianRepository` | Create/accept/cancel/unlink, preference write, list current links, resend pending invitation | Create/accept/cancel/unlink and `set_guardian_alert_preferences` exist. Old client queried absent `guardian_connections`; preferences attempted direct UPDATE despite live SELECT-only grants. Resend is absent. | Client now reads `guardian_links`, normalizes `pending` for existing UI, and calls the existing preference RPC. Local migration proposes owner-only resend behavior. |
| Safety Center, Blocked Accounts, Activity History | Report submission/read, block/unblock, safety ping/check-in | `submit_safety_report_v2`, safety ping/check-in RPCs exist. Old client queried absent `reports` and `blocks`. Block/unblock RPCs are absent. `get_safety_center_config` is absent. | Client report/block list reads now use RLS-protected `safety_reports` and `user_blocks`; report category is mapped to the current UI field. Local migration proposes idempotent block/unblock RPCs and message-insert enforcement. Safety config remains blocked. |
| Identity / verification screens | Read verification state, start/submit provider session, appeal; provider Edge Function | `get_my_identity_verification_v2` exists. Start/submit RPCs and appeal contracts are absent. Production Edge Function list contains only Stripe functions; `identity-verification-session` is not deployed. | App direct document upload already fails closed. No identity document collection or success state enabled. Provider credentials/approval and a reviewed server integration remain required. |
| Job discovery / applications / location | Applications, private location save/read/release, server distance; acceptance workflow | `applications` absent (production uses `job_applications`); private location and distance RPCs absent. `jobs.exact_address` is not selectable by anon or authenticated. | Marketplace and new publishing remain disabled; no client-side coordinates or schema shim added. These are pre-activation blockers. |
| Staff/admin routes | Moderation, incidents, report review, identity review | Multiple admin RPCs/tables absent; production has role-checked primitives for job/role/verification review but not the Flutter admin contract set. | Admin workflow readiness not established. Do not expose new staff actions until signatures/role checks and audit contracts are tested. |

## Production tables absent from direct Flutter references

- `account_ban_appeals` — referenced by data/repositories/admin_repository.dart
- `applications` — referenced by data/repositories/applications_repository.dart
- `business_verifications` — referenced by data/repositories/uploads_repository.dart
- `document_review_cases` — referenced by data/repositories/mission_pilot_repository.dart
- `future_independence_plans` — referenced by data/repositories/mission_pilot_repository.dart
- `independence_goals` — referenced by data/repositories/mission_pilot_repository.dart
- `job_management_requests` — referenced by data/repositories/jobs_repository.dart
- `job_payment_obligations` — referenced by data/repositories/legal_contract_repository.dart
- `mort_spark_grants` — referenced by data/repositories/monetization_repository.dart
- `partner_attestations` — referenced by data/repositories/mission_pilot_repository.dart
- `payment_dispute_appeals` — referenced by data/repositories/legal_contract_repository.dart
- `payment_dispute_statements` — referenced by data/repositories/legal_contract_repository.dart
- `payment_dispute_timeline` — referenced by data/repositories/legal_contract_repository.dart
- `payment_disputes` — referenced by data/repositories/legal_contract_repository.dart
- `private_resource_bookmarks` — referenced by data/repositories/mission_pilot_repository.dart
- `resource_directory_entries` — referenced by data/repositories/mission_pilot_repository.dart
- `user_ad_preferences` — referenced by data/repositories/monetization_repository.dart
- `user_subscription_status` — referenced by data/repositories/monetization_repository.dart

The corresponding live schema uses different names for three previously failing client reads: `guardian_links`, `user_blocks`, and `safety_reports`. These were corrected in the Flutter repositories. Other absent table dependencies are grouped by their actual source modules in the remaining inventory; do not create duplicate “compatibility” tables without proving the route needs them and designing against production constraints.

## RLS and authorization evidence

- Production `profiles` has forced RLS and self/staff row policies. Authenticated column privileges permit updates only to profile presentation fields inspected (`display_name`, `avatar_path`, `bio`, `city`, `region`, `timezone`); DOB, role, account status, username, and onboarding completion are not client-updatable.
- `guardian_links` has forced RLS; SELECT is limited to the teen, an active adult Guardian, or staff. Direct INSERT/UPDATE is not granted. `guardian_preferences` is SELECT-only to active participants; writes use `set_guardian_alert_preferences`.
- `safety_reports` has forced RLS and SELECT is limited to the reporter or staff. Authenticated INSERT/UPDATE is not granted; Flutter submits through `submit_safety_report_v2`.
- `user_blocks` has forced RLS. Insert/delete are scoped to the caller as blocker; select is limited to either participant. Production `send_safe_message_v2` and `private.can_access_conversation` do not reference `user_blocks`; blocking is not enforced on message insertion in the inspected definitions. The proposed trigger addresses future inserts but still needs isolated negative and concurrent tests.
- `verification_cases` has forced RLS; owners can insert only `not_started` rows and read their own records; only staff can read another user’s case. Client updates are not granted.
- `jobs.exact_address` is not selectable by anon/authenticated. Current job SELECT policy is limited to poster/staff or approved open jobs whose poster account is active; posting policy requires adult role, active account, and draft/open status. `save_job_draft_or_publish` checks `public_marketplace_enabled`.
- Release controls read-only: `public_marketplace_enabled=false`, `real_document_collection=false`; runtime status: `public_marketplace_closed=true`, `new_job_publishing_disabled=true`, `payments_disabled=true`. No control was changed.
- Supabase security advisor: 18 RLS-enabled/no-policy informational findings; one anon SECURITY DEFINER warning for `get_runtime_feature_status()` (public feature flags); 46 authenticated SECURITY DEFINER warnings requiring routine-level review; leaked-password protection is disabled. These warnings do not prove exploitation, but the full definer set has not been independently reviewed.

## Required isolated migration proposal

Local file: `supabase/proposals/production_safety_missing_contracts.sql`

- Adds `block_user_v2(uuid,uuid)`, idempotent via the existing `user_blocks(blocker_id,blocked_id)` primary key; authenticated execute only.
- Adds `unblock_user(uuid)`, scoped to the caller’s blocker row; authenticated execute only.
- Adds `resend_guardian_invite(uuid)`, verifies the pending link belongs to `auth.uid()`, returns a uniform failure for absent/foreign links, and delegates token rotation/rate limiting/expiry to the existing guarded invite creator.
- Adds a private SECURITY DEFINER insert trigger on `messages` that verifies sender membership and rejects a message if either participant has blocked the other. Search path is empty and API execute is revoked.
- No new tables or columns; no updates/deletes in the migration. The existing invite creator revokes an old pending link when rotating a code, preserving that row as an audit record.

Local SQL integration plan: `supabase/tests/production_safety_missing_contracts.sql` (pgTAP assertions for grants, signatures, request replay, self-block rejection, blocked-message rejection, unblock behavior, Guardian invite rotation and cross-user denial).

**Validation limits:** The migration syntax and core behavior passed a local, disposable PostgreSQL 17 catalog-derived fixture smoke test. This is not a production-schema clone. Supabase branch creation was refused because the connected project is not on the Pro plan; no Pro upgrade was made. Therefore the pgTAP/isolated integration suite has not run and these contracts are not complete or production-ready.

## Complete missing RPC inventory, grouped by caller module

### `data/repositories/trust_safety_repository.dart` (19 unresolved)

`accept_safety_circle_invite`, `create_safety_circle_invite`, `get_authorized_location_shares`, `get_my_active_sessions`, `get_my_incident_cases`, `get_my_safety_circle`, `get_released_job_location`, `register_incident_evidence`, `report_account_security_concern`, `save_job_private_location`, `start_identity_verification`, `start_temporary_location_share`, `stop_temporary_location_share`, `submit_account_ban_appeal`, `submit_identity_verification`, `submit_identity_verification_appeal`, `submit_incident_appeal`, `unlink_safety_circle_member`, `update_safety_circle_permissions`

### `data/repositories/support_repository.dart` (19 unresolved)

`appeal_my_support_ticket`, `confirm_draft_support_evidence_removed`, `create_support_conversation`, `get_my_support_ticket_thread`, `list_my_support_tickets`, `post_support_ticket_message`, `register_support_evidence`, `remove_draft_support_evidence`, `reopen_my_support_ticket`, `request_support_human_review`, `submit_support_evidence`, `support_get_service_status`, `support_staff_add_internal_note`, `support_staff_change_status`, `support_staff_claim_ticket`, `support_staff_get_ticket_thread`, `support_staff_list_queue`, `support_staff_post_reply`, `support_staff_release_ticket`

### `data/repositories/mission_pilot_repository.dart` (15 unresolved)

`acknowledge_pilot_policy`, `configure_support_circle`, `get_closed_pilot_eligibility`, `get_document_collection_readiness`, `get_mission_pilot_dashboard`, `get_my_partner_attestations`, `get_my_partner_invites`, `get_my_partner_staff_context`, `get_partner_connected_participants`, `get_private_work_summary`, `partner_create_pilot_invite`, `partner_revoke_pilot_invite`, `revoke_partner_attestation`, `submit_partner_attestation`, `update_discreet_mode`

### `data/repositories/financial_repository.dart` (13 unresolved)

`create_my_expense`, `delete_my_expense`, `delete_my_financial_target`, `evaluate_my_financial_alerts`, `get_my_financial_preferences`, `get_my_financial_summary`, `get_my_financial_year_report`, `list_financial_rules`, `list_my_expenses`, `set_my_expense_receipt`, `set_my_financial_preferences`, `update_my_expense`, `upsert_my_financial_target`

### `data/repositories/admin_repository.dart` (12 unresolved)

`admin_acknowledge_operational_alert`, `admin_claim_account_ban_appeal`, `admin_get_moderation_record`, `admin_list_profiles`, `admin_moderate_job`, `admin_moderate_review`, `admin_monetization_overview`, `admin_review_account_ban_appeal`, `admin_set_account_status_v2`, `admin_update_incident_case`, `admin_update_report_status`, `get_admin_operational_alerts`

### `data/repositories/profile_repository.dart` (11 unresolved)

`complete_my_onboarding`, `get_username_change_status`, `record_my_onboarding_acknowledgement`, `request_username_change`, `save_my_onboarding_age`, `save_my_onboarding_profile`, `save_my_onboarding_progress`, `save_my_onboarding_role`, `save_my_profile_setup_v2`, `save_my_transportation_preferences`, `update_my_profile`

### `data/repositories/monetization_repository.dart` (8 unresolved)

`consume_job_boost_credit`, `get_ad_eligibility`, `get_job_boost_credit_status`, `get_my_entitlements`, `grant_mort_spark_reward`, `record_ad_impression`, `record_feature_usage`, `record_paywall_event`

### `data/repositories/stripe_marketplace_repository.dart` (7 unresolved)

`get_job_payment_summary`, `get_my_payment_attempt_state_v1`, `get_my_payment_operations_queue`, `preview_job_funding`, `record_my_saved_payment_consent`, `review_payment_dispute`, `revoke_my_saved_payment_consent`

### `data/repositories/mort_guide_repository.dart` (6 unresolved)

`delete_all_my_mort_guide_history`, `delete_my_mort_guide_conversation`, `get_mort_guide_config`, `get_my_mort_guide_messages`, `list_my_mort_guide_conversations`, `submit_mort_guide_feedback`

### `data/repositories/notifications_repository.dart` (5 unresolved)

`get_my_notification_preferences`, `get_my_push_status`, `register_my_push_device_v2`, `unregister_my_push_devices_v2`, `update_my_notification_preferences`

### `data/repositories/observability_repository.dart` (4 unresolved)

`get_my_analytics_preferences`, `record_my_client_operational_event`, `record_my_product_analytics`, `update_my_analytics_preferences`

### `data/repositories/legal_contract_repository.dart` (4 unresolved)

`report_nonpayment`, `request_payment_evidence_export`, `submit_payment_dispute_appeal`, `submit_payment_dispute_statement_v2`

### `data/repositories/support_assistant_repository.dart` (4 unresolved)

`support_delete_my_conversation`, `support_get_config`, `support_get_my_conversation`, `support_list_my_conversations`

### `data/repositories/safety_repository.dart` (3 unresolved)

`block_user_v2`, `get_safety_center_config`, `unblock_user`

### `data/repositories/account_deletion_repository.dart` (3 unresolved)

`cancel_account_deletion_request`, `get_my_account_deletion_request`, `request_account_deletion`

### `data/repositories/leaderboard_repository.dart` (3 unresolved)

`get_leaderboard_v1`, `get_my_leaderboard_rank_v1`, `set_leaderboard_opt_out_v1`

### `data/repositories/account_trust_repository.dart` (2 unresolved)

`get_marketplace_trust_eligibility`, `get_my_account_trust_profile`

### `data/repositories/applications_repository.dart` (2 unresolved)

`quick_accept_job_v1`, `update_application_status_v3`

### `data/repositories/jobs_repository.dart` (1 unresolved)

`get_nearby_job_distances_v1`

### `data/repositories/avatar_repository.dart` (1 unresolved)

`record_avatar_orphan_cleanup`

### `data/repositories/auth_repository.dart` (1 unresolved)

`record_my_auth_identity_event`

### `core/observability/operational_telemetry.dart` (1 unresolved)

`record_my_client_operational_event`

### `data/repositories/repository_base.dart` (1 unresolved)

`record_my_evidence_upload_failure`

### `data/repositories/guardian_repository.dart` (1 unresolved)

`resend_guardian_invite`

## Backend review update — 2026-11-01 (supersedes earlier proposal status above)

All SQL below is a **local proposal**, not production behavior. Active production remains `jxbnrkasktbhtiujkhay`; production SQL/migrations, user data, release controls and deployed functions were not changed.

### Application submission race

Production signature: `submit_job_application(p_job_id uuid, p_note text DEFAULT NULL, p_availability_confirmed boolean DEFAULT false, p_portfolio_ids uuid[] DEFAULT '{}') RETURNS jsonb`. It calls the service-role-only `mort_submit_job_application(uuid,text)`. Live source confirms the wrapper runs `get_job_application_eligibility` before the lower RPC locks the job. The lower RPC then rechecks only active teen role, open/approved job state, blocks, age-verification existence, DOB/job age range, and note length; it does not recheck marketplace release, application window, job expiry, active poster, or required Guardian consent. The proposal adds the job lock before its eligibility recheck and relies on the live unique `(job_id, applicant_id)` key. Review found the live acceptance path locks application then job, so the submission proposal reads an existing row without a row lock after taking the job lock; this avoids an app/job lock inversion while making no mutation on replay. It returns same-user successful existing states as a replay and leaves terminal existing rows unchanged. The production eligibility function is `STABLE` and uses transaction-start `now()`/`current_date`, so a job or verification could expire while submission waits on a row lock. The local proposal now captures `clock_timestamp()` after its authorization locks, derives the current date in the database session time zone, and repeats the job expiry, age-verification expiry, applicant age, and required Guardian adult/consent predicates immediately before insert. It row-locks the specific age-verification and qualifying Guardian records used by those final checks. A source-contract Node test passes and the pgTAP catalog test now asserts these guards remain present. These are proposal-level checks only: no isolated database is available, so neither SQL compilation nor behavioral or two-session race tests have passed.

### Pair-lock concurrency

`supabase/proposals/production_safety_missing_contracts.sql` has one order-independent advisory lock key for a user pair. The block RPC obtains it before insert; a `user_blocks` trigger obtains it for direct insert/update/delete; message insertion verifies the active conversation and membership, then takes all sender/recipient pair locks in sorted-key order before checking both block directions. Durable block request IDs replay the original result and reject reuse with a different target. The pgTAP suite now includes same-request replay and no block recreation after unblock. This has not passed an independent two-session test. The proposal's behavior against other production writers, transaction snapshots, and deadlocks remains unverified.

### Exact-address privilege and private location

Read-only ACL evidence: authenticated can INSERT into `public.jobs` and UPDATE its `exact_address` column; authenticated cannot SELECT `exact_address`. Production's existing `save_job_draft_or_publish(uuid,uuid,jsonb,boolean)` SECURITY DEFINER RPC checks the active adult and publishing controls and does not accept an exact-address payload. The reference website has since cut over to this RPC and the write-contract regression passes. Production still has the old grants until migration deployment; the proposal must remain unapplied until isolated schema and RLS tests pass.

`supabase/proposals/private_job_location_lifecycle.sql` proposes:

1. `private.job_private_locations` for exact address, server-geocoded coordinates and monotonic location version, with no API role table grants and forced RLS. A separate no-grant location history preserves prior address/geocode versions before any change.
2. A legacy address copy that inserts without overwriting an existing private row, verifies owner/address/fingerprint equality, and only then nulls the matching old `jobs.exact_address` value. Any mismatch raises and rolls back. A private no-grant history table archives each prior safety-agreement snapshot/state before an update.
3. `save_job_private_location_v1(uuid,text,uuid)` for active adult job owners, with request idempotency including job and address fingerprint checks; changing an address clears stale geocode and increments the version.
4. `record_job_location_geocode_v1(uuid,integer,double precision,double precision,text)`, service-role only; it accepts only the current version and returns no coordinate values.
5. `get_released_job_location_v1(uuid)` for an active assigned adult or teen only. It locks and checks both active participant profiles/roles, accepted/in-progress/awaiting-confirmation assignment state, job not cancelled/completed, current mutual agreement and current location version, relevant two-way blocks, and active dual-consented Guardian link when `requires_guardian_approval` is true. It returns exact address only in that authorized call and records access/denial.
6. `get_my_eligible_job_distance_bands_v1(uuid[])`, active teen only, accepts bounded job IDs but no coordinates; it internally calculates using job geocode plus city/region centroid and returns only coarse bands (`under_3`, `3_to_10`, `10_plus` miles). The centroid source/quality still needs product/privacy review; no teen coordinate is stored.

The SQL draft fixed the broken agreement-update loop and cross-job idempotency replay found in review. It still needs compilation against the exact production migration set. Before application: wire the existing agreement confirmation flow to current location-version terms, preserve prior legal acceptance evidence/version history, enqueue reconfirmation notifications, verify cancellation and moderation transitions, confirm the geocoding provider/source, and test direct/RPC exact-address denials. Existing Guardian application screens remain read-only; no Guardian decisions were added.

Follow-up review compared the release contract with live `job_assignments`, `job_applications`, and `job_safety_agreements` constraints. Although assignment/application job IDs have separate foreign keys, production has no composite constraint requiring those IDs to match. The location-release proposal now rejects an assignment or linked application whose `job_id` differs from the locked job/location. A source-contract regression test failed before this guard and passes after it; the pgTAP catalog file asserts both checks. This is not a behavior test: no exact isolated database is available to exercise crafted mismatched rows.

### Verification and role elevation

Production `verification_cases` has distinct `verification_type` values for `age`, `identity`, `school_email`, `school_id` and `guardian_consent`; status enum includes not-started/pending/verified/rejected/expired/needs-review. The existing `mort_review_role_request(uuid,boolean,text)` requires teen evidence and adult identity evidence but does not check the adult target's server-held DOB. `verification_role_age_gate.sql` adds an >=18 DOB check and locks verification evidence while reviewing; `verification_role_age_gate.sql` (pgTAP) covers minor rejection/no role mutation and verified-adult approval. Neither has run. Provider identity Edge Functions and their required session/webhook RPCs are absent from production; don't enable real document collection or mark users verified. `private.user_roles` is RLS-protected with no authenticated grants/policies. First reviewer access must be a named project-owner/DBA provisioned account with MFA and a recorded approval; no production staff access was granted.

Adult DOB enforcement throughout account creation, adult job posting and assignment acceptance requires a single approved product policy. Current live acceptance verifies adult identity but this audit has not yet established an adult DOB gate on every route. Guardian consent is currently per job via `requires_guardian_approval`, not universal. Live Guardian unlink revokes future consent but does not pause/cancel an already-active assignment. Product/legal must decide how to notify and protect an ongoing assignment after revocation; proposed exact-location reads deny access immediately when that job requires Guardian consent.

### Stripe, public status and remaining findings

Production contains five private Stripe tables (`stripe_runtime_controls`, `stripe_customers`, `stripe_connected_accounts`, `stripe_payment_intents`, `stripe_webhook_events`) and three deployed Edge Functions for assignment payment-intent creation, webhook processing, and runtime status. No production transfer/payout/refund/dispute lifecycle table or Edge Function exists. All payment, onboarding, funding, transfer, refund, live mode, connected-account and payout-approval controls inspected are false. Local Connect handlers are not deployed and some use legacy v1 account patterns; do not activate them. No teen payee model should be coded until Stripe confirms the supported account type/country path and product/legal approve who owns funds, tax reporting and beneficial interest. Stripe's terms require an adult representative for minors and details differ by account type/country: [Services Agreement](https://stripe.com/legal/ssa), [account age requirements](https://support.stripe.com/questions/age-requirement-to-create-a-stripe-account). No live Stripe change occurred.

`get_runtime_feature_status()` is public and SECURITY DEFINER but returns only fail-closed booleans/message/timestamp; no PII or secrets were found in the reviewed contract. No-policy private tables and the three public no-policy relations have no authenticated table grants, which is default-deny; no broad policy was added. Static SECDEF inspection found no externally callable sensitive routine lacking a visible auth/role check other than that intentionally public status function (static heuristic only). Supabase security advisor reports leaked-password protection disabled; project-owner action is required to enable and verify it. Performance advisor reports 19 unindexed FKs and 59 unused indexes (informational); no indexes were changed without workload evidence.

### Validation boundary and blockers

- Production migration history: 69 (versions `20261026194801` through `20261101002805`), latest `20261101002805_safety_reports_server_only_idempotent`. Local checkout: 238 migrations, zero matching version IDs. Migration reconciliation is unresolved; never replay the local chain.
- Supabase connection lists only production `main`; no isolated clone/branch is available without a paid plan. No upgrade was approved or attempted. All SQL test execution is stopped; no production-as-test substitution.
- Local pgTAP files: 26 assertions for block/message, 6 for application submission signature/ACL/idempotency guard, 5 for adult role age gate, 5 for exact-address ACL, and 13 for private-location grants/contracts. All plans match assertion counts; database execution is not available. Add QA-fixture positive/negative tests for job-close/Guardian-revoke/age-expiry races, simultaneous accept/retry, owner/non-owner location save, assigned/unassigned read, one-sided/stale safety consent, Guardian revoked, block in both directions, canceled/completed/disputed assignments, changed address version, and no exact fields in job/application reads before approving the location contract.
- Required before the draft PR can leave draft: exact migration compilation/apply in a matching isolated DB; pgTAP behavior and exact-address positive/negative cases; two independent sessions for block/message and application races; confirmation/revocation lifecycle. Final Flutter checks passed: `flutter analyze --no-pub` (no issues), `dart format --output=none --set-exit-if-changed lib test` (310 files, 0 changes), and `flutter test --no-pub` (617 passed, 2 skipped, 0 failed).
- Website job-write cutover is complete, but the ACL SQL remains an unapplied proposal and production still has the reviewed direct-write grants. Full isolated migration/RLS validation remains a prerequisite. Marketplace publishing, payments and document collection remain disabled; PR #45 remains draft.

## Current Flutter dependency scan — 2026-11-01

Read-only production catalog comparison against literal `.rpc('name')` and database `.from('relation')` calls in `flutter_mort/lib` found 191 distinct direct RPC names: 49 exist in public production (77 public functions total) and 142 do not. The corrected scanner excludes `.storage.from(bucket)` calls and finds 31 distinct literal database relation names; 16 are absent. Production has 43 public base tables, all RLS-enabled. These counts exclude dynamic RPC/relation names and do not certify argument names, return fields, nested joins, table columns, or runtime route reachability. Existing route notes in this document remain necessary to classify absent names; no missing contract was added solely to lower the count.

### Refreshed source/catalog and security-advisor evidence — 2026-11-01

The reproducible scanner is `scripts/audit-flutter-supabase-literals.mjs`. It records each literal RPC/relation name and its Dart source paths. The current read-only comparison against `jxbnrkasktbhtiujkhay` finds 142 absent RPC names and these 16 absent relations: `account_ban_appeals`, `business_verifications`, `document_review_cases`, `future_independence_plans`, `independence_goals`, `job_payment_obligations`, `mort_spark_grants`, `partner_attestations`, `payment_dispute_appeals`, `payment_dispute_statements`, `payment_dispute_timeline`, `payment_disputes`, `private_resource_bookmarks`, `resource_directory_entries`, `user_ad_preferences`, and `user_subscription_status`. Source paths group these names into account/admin, upload verification, mission-pilot, legal/payment-disabled, and monetization repositories. This is a caller inventory, not proof that each repository method is reachable from a production-enabled route; the 142 names are not a request to create 142 RPCs.

The live security advisor snapshot at 2026-11-01 14:36 UTC reported 18 RLS-enabled/no-policy findings: 15 tables in the `private` schema and three public tables (`job_safety_cancellations`, `legal_acceptance_audit_events`, and `legal_role_requirements`). Read-only ACL checks confirmed all 18 have no `SELECT` privilege for `anon` or `authenticated`; `service_role` has `SELECT` on the three public tables. No policy or grant was changed. The advisor also reported 46 authenticated SECURITY DEFINER callability notices and one anon-callable SECURITY DEFINER routine, `get_runtime_feature_status()`. Its inspected definition uses an empty search path and returns only minimal release/payment/document booleans, maintenance text, and update timestamp; direct anon and authenticated execution are granted. This supports public status reporting but does not replace review of the other 46 routines. No production privilege change was made.

The scan also found an active canceled-application UI path that called absent `job_management_requests`. Production `manage_job_v2` records cancellation reasons in staff audit data, with no participant-readable history relation. The Flutter path now shows the generic cancellation/support message and makes no client query for an unsupported reason table. `flutter_mort/test/application_detail_screen_test.dart` covers the visible result; the focused screen suite passed 8 tests after first observing the regression test fail against the old call.

The same route-level follow-up found the active four-step onboarding screen calling `complete_my_onboarding_v2` with legal version IDs without first recording the required acceptance. Live production `complete_my_onboarding_v2` checks `private.mort_user_has_current_legal_acceptances` and does not consume those payload IDs; `submit_legal_acceptance` is the available exact-version/hash-bound acceptance contract. The onboarding screen now directs users to the existing Legal Center clickwrap and refuses completion while any required published version remains unaccepted. A targeted widget regression verifies the fail-closed state, and the source-contract test verifies guard ordering. This is a Flutter change using existing production contracts, not a database migration; legal acceptance still requires real user review/affirmative action in the existing clickwrap. The focused tests passed 15/15; after the mounted-guard follow-up, full `flutter test --no-pub` passed **619, 2 skipped, 0 failed**, `flutter analyze --no-pub` reported **No issues**, and the modified-file format check passed.

Latest Flutter verification after that UI change: `flutter test --no-pub` **618 passed, 2 skipped, 0 failed**; `flutter analyze --no-pub` **no issues**; format check **310 files, 0 changes**. These results validate Flutter behavior only, not any SQL proposal.

This module inventory is not a statement that each missing function should be created. See the route classifications above; remaining modules are admin-only, support operations, optional finance/monetization/pilot/leaderboard features, or disabled marketplace/payment/location flows. Resolve only after a route-level need and the production schema contract are established.

### Safety-contract follow-up from remote commit `d6cb61e` — 2026-11-01

Production ACLs use explicit column-level grants for `public.jobs`: authenticated has INSERT grants across job columns and UPDATE on `exact_address` among other fields, while table-level INSERT/UPDATE privileges are false. A table-only `REVOKE` would not remove these column grants. A table-level `GRANT SELECT` would broaden current access and make `exact_address` selectable through the existing visible-job RLS policy. The feature-branch correction removes that broad SELECT and dynamically revokes remaining authenticated INSERT/UPDATE column grants, preserving existing column-limited SELECT access. `node scripts/qa-safety-contracts-acl.mjs` exercises that ACL block in disposable PostgreSQL 17; it does not validate the full production migration.

The website source cutover to `save_job_draft_or_publish(uuid,uuid,jsonb,boolean)` is complete, and `qa:reference-website-job-write-contract` passes. Production still has the old grants until a reviewed migration is applied. The new migrations have not been replayed against a production-equivalent database; location-agreement updates, full RLS/address confidentiality, and two-session application/block-message races still require isolated integration tests.

The read-only `supabase/tests/safety_contract_schema_preflight.sql` now expects the hosted `guardian_links.teen_user_id` column. Its runner requires an explicit staging project ref matching `db.<ref>.supabase.co` and refuses the production and deleted project refs. Static assertions cover these guardrails; the SQL preflight remains unexecuted against an isolated database.

### Nov 5 release sprint final local run — 2026-11-01

The current isolated branch `codex/mort-nov5-backend-safety` includes follow-up fixes for fail-closed eligibility parsing, the address-only private-location RPC client contract, removal of client GPS coordinates from job posting, required DOB metadata during signup, and the AAB helper's declared Supabase URL. After those changes, `flutter test --no-pub --reporter expanded` completed with **620 passed, 2 skipped, 0 failed**; `flutter analyze --no-pub` completed with **No issues found** (50.5 seconds on the final tree); and `dart format --output=none --set-exit-if-changed lib test` reported **310 files, 0 changed**. Final focused checks passed: combined safety unit suite 15/15 (including private-location 11/11); safety static; 241 migration encodings; website job-write guard; AAB helper 1/1; diff check clean.

An additional independent SQL review found the draft location-release terminal-state check ran before the selected job and assignment records were loaded, making that owner-side denial ineffective. The check was moved after both locked reads, and release now also rejects a private location whose recorded poster differs from the job owner. Regression coverage asserts the read/lock ordering and ownership bind. The posting UI copy was corrected to disclose that exact-address entry is unavailable; it no longer promises an unimplemented Safety Agreement form. The updated source-contract test passes **11/11**. The final full Flutter suite and analyzer completed after this copy change with 620 passing, 2 skipped, 0 failures and no analyzer issues.

These results do not validate proposed migrations against production. The disposable ACL fixture is generic; the available local Supabase schema is behind/divergent and migration replay stops at missing `public.mort_release_control`. No production SQL was executed, and independent two-session, pgTAP/RLS, or exact-address integration tests have not passed. Production stays untouched and publishing/payment/document controls remain fail-closed. The AAB script stops before Gradle on the `production_public` release-mode gate; no gate was bypassed and no AAB was produced. See `MORT-PRODUCTION-READINESS.md` for unresolved operations and provider blockers.

