# Production replica acceptance and authorization audit — 2026-11-16

Status: local replica evidence only. Nothing in this document was executed against
production. Production was inspected read-only (catalog, ACLs, function bodies,
migration ledger) to build the replica.

## What the replica is

`scripts/qa/replica/build-and-test.sh` builds an isolated local Supabase stack
(`supabase/production-replica`, project id `mort-production-replica`) from:

1. the 2026-11-12 production baseline recovery set,
2. the 27 exact production ledger statements applied 2026-11-13..15
   (`supabase/production-baseline-recovery/ledger-2026-11-13-to-2026-11-15/`),
3. production grants (`production-acl-2026-11-16.sql`),
4. non-payment configuration rows (`production-config-rows-2026-11-16.sql`; Stripe rows removed),
5. the MORT triggers on `auth.users` (`auth-triggers-2026-11-16.sql`) — these were
   **missing from the baseline recovery set** (DR finding, see below).

It then computes a catalog fingerprint (buckets, columns, functions, grants, policies,
RLS flags, routine grants, triggers) and diffs it against the recorded production
fingerprint (`scripts/qa/replica/production-fingerprint-2026-11-16.txt`). The run fails on any
difference. Only after parity does it apply migrations listed in
`supabase/production-baseline-migrations/PENDING_PRODUCTION_APPROVAL.txt` (skipped with `PRE_FIX=1`).

All test identities are created through public GoTrue signup with email
confirmation via the local Mailpit inbox, synthetic names, synthetic DOBs, and
generated images. The single out-of-band step is the staff root of trust:
owner SQL inserting one admin and one moderator into `private.user_roles` on the
replica, because no RPC exists to grant staff roles (by design). Every other
transition — onboarding, legal acceptance, evidence upload, staff review,
activation, guardian invite/accept/revoke — goes through the same RPCs and
Storage API the apps use. `lib.mjs` refuses to run against any non-localhost URL.

## Results

| Run | Journeys (P4) | Authorization / Storage (P2, P5) |
|---|---|---|
| Production as-is (`PRE_FIX=1`) | 47/53 | 101/104 |
| With `20261116120000_…` applied | 53/53 | 108/108 |

Pre-fix failures (each is a reproduced defect):

- teen "skip guardian" during onboarding does not advance (D2) — two teens
- teen cannot complete onboarding as a consequence (D2)
- adult with incomplete onboarding was activated by staff (D3)
- guardian cannot be activated: `activation_request_required` (D4)
- `accept_guardian_invite` → `adult_guardian_account_required` (D4)
- teen PATCHes `profiles.guardian_setup_status = 'linked'` with no guardian (D5)
- moderator reviews and verifies their own verification case (D6)
- guardian revocation cannot be exercised because no guardian can exist (D4)

## Findings

| ID | Severity | Component | Exploitability | Fix | Regression |
|---|---|---|---|---|---|
| D1 | High (launch blocker) | Flutter `AuthRepository.signUp`, `unified_auth_screen.dart`; Expo `app/auth/sign-up.tsx`; iOS | Not a security issue; every email signup from current Flutter main fails because the production trigger requires `date_of_birth` metadata (`MORT_DOB_REQUIRED`) | Client change (separate PR) | Replica signup without DOB is rejected; journeys sign up with DOB |
| D2 | Medium (functional) | `set_guardian_setup_skipped`, `save_my_onboarding_safety_v2` | Pending teens are stuck; refusal silently discarded | Allow skip while pending/onboarding incomplete; return `guardian_skip_unavailable` on refusal | `P4-onboarding … guardian "skip"` |
| D3 | Medium | `private.mort_is_eligible_for_role_activation`, activation queue | Staff could activate accounts that never completed onboarding or accepted current legal documents | Eligibility requires `onboarding_completed_at` and current legal acceptances; `complete_my_onboarding_v2` queues activation | `P4-activation adult_c …` |
| D4 | High (functional) | role activation, `role_requests_requested_role_check` | Guardians could never become active; guardian linking unreachable | Guardian track (identity verified, age ≥ 18, email confirmed); constraint includes `guardian` | `P4-guardian …`, `P5-guardian revocation …` |
| D5 | Medium | column grant on `public.profiles.guardian_setup_status` | Any authenticated teen could self-assert `linked` via PostgREST | Revoke column UPDATE; state only changes through RPCs | `P5-escalation teen cannot self-assert …` |
| D6 | Medium | `mort_record_staff_document_review`, `mort_review_verification_case`, `mort_review_role_request` | A staff member could verify their own identity evidence and approve their own role request | Self-review blocked | `P5-staff moderator cannot review their own …` |
| L1 | Low | `private.mort_is_eligible_for_role_activation` executable by `authenticated` | Leaks a boolean about eligibility for an arbitrary user id | Not changed (noted) | — |
| DR1 | High (DR) | baseline recovery set | Restoring from the recovery set alone would silently drop `on_auth_user_created_mort` and `mort_enforce_minor_school_email_on_auth_email_change`, so new users would get no profile and minors' school-email enforcement would be off | Added `auth-triggers-2026-11-16.sql`; replica parity check covers triggers | fingerprint `trigger` count 24 |

## Storage (P2) — verified on the replica with production policies

- `job-evidence`, `dispute-evidence`: no policies → deny-all for anon and
  authenticated (upload, list, download, signed URL). No app code references these
  buckets. The outstanding uncertainty is resolved as: **intentionally unused and
  closed**; any future use needs new policies and tests.
- `verification-evidence`: owner-folder upload only; staff read; no overwrite;
  no delete once registered; MIME and size limits enforced; cross-account signed URLs denied.
- `profile-avatars`, `chat-attachments`, `proof-uploads`: owner/participant isolation,
  cross-account read/write/delete denied.

## #106 regression (P5)

Exercised against the real production `update_my_job_application_status_v3`:
adult B receives `application_not_available` for `accepted`, `rejected`,
`shortlisted`, `viewed` on adult A's job. PR #106 itself is not merged.

## Limitations

- Replica parity is a catalog fingerprint, not a byte-for-byte schema diff;
  function bodies are taken verbatim from production.
- Edge Functions, SMTP, OAuth providers, and push are not exercised here.
- This is not production validation. Applying the migration to production
  requires explicit approval, and should be followed by a fresh-user production
  acceptance run with a human staff reviewer.
