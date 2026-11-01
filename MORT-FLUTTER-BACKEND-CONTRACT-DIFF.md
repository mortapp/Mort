# MORT Flutter ↔ Production Supabase Contract Diff

**Status:** In progress; no production changes applied.  
**Snapshot:** 2026-10-31 local date (Supabase catalog inspected read-only; migration list through `20261101002805_safety_reports_server_only_idempotent`).  
**Code baseline:** `29a8cf141b44b6ae7a4a37965b99f9c47b310282`.  
**Isolated branch:** `codex/flutter-backend-integration` (new local worktree).  
**Production target:** Supabase `jxbnrkasktbhtiujkhay`.

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
| Create/remove a block | Authenticated blocker for self as blocker; cannot block self; idempotent create, scoped removal | Existing `user_blocks` PK is `(blocker_id,blocked_id)`. Local RPC proposal exists, but no shared pair lock in proposal. **PARTIALLY PROPOSED; concurrent safety not verified.** |
| Send a message | Active conversation member, sender matches authenticated user, conversation active, and neither direction blocked | Existing `conversations.status` includes `active`, `closed`, `under_review`; `send_safe_message_v2` and `mort_send_message` exist. Proposed insert trigger checks sender and membership/block, but currently neither checks active conversation nor serializes with block changes. **BLOCKED pending corrected proposal and true two-session test.** |

Required isolated database test cases are enumerated in the pasted execution request. They must use actual production schema and roles. For messaging, two independent sessions must demonstrate that after the block transaction acquires the canonical pair lock and commits, a concurrent message transaction cannot commit. A single-session pgTAP sequence does not prove this race property.

Flutter-side regression results on 2026-11-01: `flutter test --no-pub` completed **617 passed, 2 skipped, 0 failed**. The focused affected-area command (`flutter test test/teen_core_visual_convergence_test.dart test/android_native_parity_test.dart test/application_detail_screen_test.dart test/production_readiness_contract_test.dart --no-pub`) completed **29 passed, 0 failed**. `dart format` and `git diff --check` pass. Whole-project `flutter analyze --no-pub` remains running without diagnostics; no success is claimed for it. These client tests do not verify database concurrency, RLS, transaction rollback, private-location authorization, or location distance bands.

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

Local file: `supabase/migrations/20261101022649_production_safety_missing_contracts.sql`

- Adds `block_user_v2(uuid,uuid)`, idempotent via the existing `user_blocks(blocker_id,blocked_id)` primary key; authenticated execute only.
- Adds `unblock_user(uuid)`, scoped to the caller’s blocker row; authenticated execute only.
- Adds `resend_guardian_invite(uuid)`, verifies the pending link belongs to `auth.uid()`, returns a uniform failure for absent/foreign links, and delegates token rotation/rate limiting/expiry to the existing guarded invite creator.
- Adds a private SECURITY DEFINER insert trigger on `messages` that verifies sender membership and rejects a message if either participant has blocked the other. Search path is empty and API execute is revoked.
- No new tables or columns; no updates/deletes in the migration. The existing invite creator revokes an old pending link when rotating a code, preserving that row as an audit record.

Local SQL integration plan: `supabase/tests/production_safety_missing_contracts.sql` (18 pgTAP assertions for grants, signatures, idempotency, self-block rejection, blocked-message rejection, unblock behavior, Guardian invite rotation and cross-user denial).

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

This module inventory is not a statement that each missing function should be created. See the route classifications above; remaining modules are admin-only, support operations, optional finance/monetization/pilot/leaderboard features, or disabled marketplace/payment/location flows. Resolve only after a route-level need and the production schema contract are established.

