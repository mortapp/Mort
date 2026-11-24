# Migration QA Report — `20261116130000_server_enforced_password_attestation` (QA only)

- QA project: `ckcxakhxqlkhppsxxjhv` (us-east-2, Free plan)
- Production project `jxbnrkasktbhtiujkhay`: **not touched**. The migration remains pending production approval.
- Date: 2026-11-19/20 (UTC timestamps in evidence)
- Evidence: `evidence/2026-11-19/migration_130000.jsonl` (PW-01…PW-30), `QA_MATRIX_2026-11-19.md` section "Authentication"

## 1. Backup / recoverability

The QA project is on the Free plan, which has **no platform backups or PITR**. Before applying anything, a logical snapshot schema, `qa_snapshot_20261119`, was created in QA. It holds:

- copies of 139 tables;
- the catalog state of functions, triggers, policies and grants (`_functions`, `_triggers`, `_policies`, `_grants`).

**Limitation:** this is a recoverable data snapshot, not a full disaster-recovery backup. It does not include `auth` internals beyond the copied tables, storage objects, or the platform's own config. For production, the existing production-baseline procedure must be followed: a platform backup or PITR checkpoint must be confirmed immediately before applying the migration.

## 2. Object inventory (verified in QA after apply)

| Object | Type | Verified state |
|---|---|---|
| `private.password_attestation_uses` | table (nonce ledger) | RLS on; no anon/authenticated privileges |
| `private.password_guard_rate_limits` | table (signup quota) | RLS on; no anon/authenticated privileges |
| `private.mort_password_attestation_secret()` | SECURITY DEFINER, `search_path=''` | not executable by public/anon/authenticated/service_role (trigger-internal only) |
| `private.mort_consume_password_attestation(text,text,text)` | SECURITY DEFINER | same as above |
| `private.mort_auth_users_password_attestation_on_insert()` | trigger fn | same |
| `private.mort_auth_users_password_attestation_on_update()` | trigger fn | same |
| `private.mort_auth_users_strip_consumed_attestation()` | trigger fn | same |
| `private.mort_auth_identities_strip_password_attestation()` | trigger fn | same |
| `public.mort_consume_password_guard_rate_limit(text,int,int)` | SECURITY DEFINER | executable by **service_role only** |
| `mort_password_attestation_on_insert` | BEFORE INSERT on `auth.users` | enabled |
| `mort_password_attestation_on_password_change` | deferred CONSTRAINT trigger, AFTER UPDATE OF `encrypted_password` | enabled, deferrable initially deferred |
| `mort_strip_consumed_password_attestation` | BEFORE UPDATE OF `raw_user_meta_data` on `auth.users` | enabled |
| `mort_strip_password_attestation` | BEFORE INSERT/UPDATE OF `identity_data` on `auth.identities` | enabled |
| Vault secret `mort_password_attestation_secret` | vault | present (1); value never printed |
| Edge secret `MORT_PASSWORD_ATTESTATION_SECRET` | function secret | set in QA; QA-only value (not copied from production) |

**Review notes:**

- No RLS was disabled and no grants were broadened.
- No Stripe objects were touched.
- Every new function pins `search_path=''`.
- The attestation is HMAC-SHA256 over `v1|purpose|subject|nonce|exp`, where:
  - the subject is the lower-cased email for `signup` and the user id for `update_password`;
  - the 15-minute expiry window is enforced on both sides;
  - nonces are single-use through `ON CONFLICT DO NOTHING` plus a REPLAYED error.

**QA migration ledger** (Management API, version → name):

- `20261120044243` → `20261116130000_server_enforced_password_attestation`
- `20261120044256` → `20261119100000_account_deletion_processor_port` (QA port, see §5)
- `20261120044257` → `20261119100100_revenuecat_fulfillment_port` (QA port)
- `20261120044311` → `20261119100200_google_play_billing_foundation_port` (QA port)
- `20261120045436` → `20261116120000_onboarding_activation_and_staff_review_boundaries`. This one was already on `main` and is pending production approval. It was applied to QA because guardian activation could not be tested without it (see Findings D2–D6).

## 3. Test results

PASS means the HTTP result **and** the resulting database or auth state were verified.

| ID | Case | Result |
|---|---|---|
| PW-07 / PW-08 | Valid signup attestation accepted, user can log in. The attestation is stripped from `raw_user_meta_data` and `identity_data`: DB check PW-07-DB found `any_att=0` and `ident_att=0`. GoTrue's API response echoes the pre-trigger metadata, which is cosmetic. | PASS |
| PW-01 | Direct `/auth/v1/signup` with password and no attestation | PASS (rejected; no user row) |
| PW-02 / PW-14 | Admin create-user and admin update-user with a password and no attestation | PASS (rejected; service_role cannot bypass) |
| PW-03 | Forged attestation (wrong key) | PASS (rejected) |
| PW-04 | Expired attestation | PASS (rejected) |
| PW-05 | Attestation bound to a different email | PASS (rejected) |
| PW-06 | Wrong-purpose attestation | PASS (rejected) |
| PW-09 | Reused signup nonce (after user deletion) | PASS (rejected, REPLAYED) |
| PW-10 / PW-10b | `PUT /auth/v1/user` with password and no attestation; old password still works | PASS |
| PW-11 | Update attestation minted for a different account (TEEN2) | PASS (rejected) |
| PW-12 | Valid update attestation | PASS |
| PW-13 / PW-13b | Replay of a consumed update attestation; password unchanged | PASS |
| PW-15 / PW-16 | Guard `update_password` with no token, or with the anon key as bearer | PASS (401) |
| PW-17 / PW-18 | Too short; complexity | PASS (422) |
| PW-19 / PW-20 | HIBP-breached password on update and signup | PASS (422 `leaked_password_compromised`) |
| PW-21 / PW-23 | Invalid email; unknown action | PASS (400) |
| PW-22 | Future DOB (2030-01-01) on guard signup | **FINDING**: the guard checks DOB format only. The request reached GoTrue (stopped there by the QA email rate limit) and no user row was created. Age plausibility is enforced later in onboarding, not at signup. |
| PW-24 / PW-24b | Valid guard update; new password logs in | PASS |
| PW-25…PW-28 | **Recovery at API level** (iOS/Flutter flow): `generate_link(recovery)` → `/verify` → recovery session. A direct `PUT` with the recovery session is rejected; guard `update_password` with the recovery session gives 200 and the new password logs in. | PASS |
| PW-29 | Invalid/expired recovery token_hash | PASS (403 `otp_expired`; clients must surface this, see the iOS report P2) |
| PW-30 | Rate limit: 16 rapid update calls → 429 from the 6th call (per-user/per-IP in-memory limiter, per isolate) | PASS |
| — | Signup DB quota (`signup:global` 20/h, `signup:ip` 10/h, `signup:email` 5/h): 13 rows recorded in `private.password_guard_rate_limits` | PASS (observed) |
| — | Nonce ledger after tests: `signup` 4, `update_password` 12 | consistent with tests |

**Observations:**

1. Rejected writes surface from GoTrue as a generic `500 unexpected_failure` or "Database error …". This is fail-closed and correct, but clients see an opaque error. Legitimate clients only use password-guard, so this affects only bypass attempts.
2. After migration 130000, every password write must go through password-guard. That includes support tooling and dashboard "reset password", and any admin script that sets passwords. Admin magiclink and invite flows without a password still work.
3. **Recovery doc (API level):** the supported flow is:
   1. the client calls `resetPasswordForEmail` with an allow-listed `redirect_to`;
   2. the user opens the link;
   3. the client exchanges it for a recovery session;
   4. the client calls `POST /functions/v1/password-guard {action:"update_password", password}` with `Authorization: Bearer <recovery access token>`.

   A direct `supabase.auth.updateUser({password})` call **fails** after this migration. Flutter uses `PasswordGuard.updatePassword` (PR #109). For iOS, see `IOS_RECOVERY_COMPATIBILITY_REVIEW_2026-11-19.md`; the iOS live implementation is missing because of the P0 truncation.

## 4. Rollback guidance (do not blindly reverse)

Reversing this migration on a populated database removes a security control. It also does not restore any state, because the migration changes no existing rows. Preferred order:

1. **Function-level fix forward.** If password-guard misbehaves, redeploy the previous password-guard build. The triggers stay, so the system stays fail-closed: password changes fail until fixed, and no weaker path opens.
2. **Secret mismatch.** If the vault secret and the function secret differ, all password writes fail closed. To fix:
   1. rotate both to a new identical value (`vault.update_secret` plus `supabase secrets set MORT_PASSWORD_ATTESTATION_SECRET=…`);
   2. redeploy password-guard.
3. **Emergency disable (requires explicit owner approval; fail-open).** Run `alter table auth.users disable trigger mort_password_attestation_on_insert, disable trigger mort_password_attestation_on_password_change;`. Record the time window, re-enable as soon as possible, and audit `auth.audit_log_entries` for password changes during that window. Keep `private.password_attestation_uses` and `private.password_guard_rate_limits`; they are audit data.
4. Full removal (drop the triggers, then the functions, then the tables) should only follow a reviewed forward migration, never an ad-hoc reverse script.

## 5. QA-only schema ports (production-lineage parity)

QA was missing schema that production-lineage Edge Functions need. With owner approval ("Yes, port into QA"), three port migrations were added under `supabase/production-baseline-migrations/`, following the production-baseline convention:

- `20261119100000_account_deletion_processor_port.sql`: `account_deletion_requests`, the client RPCs (`request_/cancel_/get_my_account_deletion_request`) and the `service_*` worker RPCs.
- `20261119100100_revenuecat_fulfillment_port.sql`: `revenuecat_events`, `revenuecat_product_states`, `monetization_entitlements_cache` and `process_revenuecat_provider_event`.
- `20261119100200_google_play_billing_foundation_port.sql`: `purchase_records`, `billing_notification_events` and `subscription_entitlements`.

All new tables have RLS on. The `service_*` and processing RPCs are executable by `service_role` only; the client deletion RPCs by `authenticated` only.

**A read-only check of production on 2026-11-20 found none of these RPCs** (`request_account_deletion`, `process_revenuecat_provider_event`, `process_identity_verification_provider_event_v2`). If deployed to production as-is, those Edge Functions would fail.

These ports are **not** approved for production. They are proposed for review, and the production order and approval remain the owner's decision.

**Not ported:** identity verification v2 (`process_identity_verification_provider_event_v2`). This deviates from the port approval, and IDV-01/IDV-07 are BLOCKED as a result (see the integration report).

The local production replica with the ports plus 120000 passed journeys 53/53 and authz 108/108 (`evidence/2026-11-19/replica-run-ports-120000.log`).

## 6. Production readiness of 130000

The migration behaves correctly and fails closed in QA. Before production approval:

- confirm a production backup or PITR point;
- create the production vault secret and function secret with a **new** value;
- deploy password-guard **before** applying the migration;
- fix or acknowledge the iOS P0 (no guarded live recovery on iOS);
- confirm the support team's password-reset tooling uses password-guard.

Do not apply to production until the owner explicitly approves.
