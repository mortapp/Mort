# Optional Guardian Mode: mutual-consent contract

## Product rule

Guardian oversight is optional in MORT. A teen may complete onboarding and marketplace activation without creating or accepting a guardian link, subject to all otherwise applicable legal, safety, age/school verification, identity, and staff-review requirements. A guardian link is never an activation prerequisite and must not be inferred from a teen's age, profile fields, emergency contact, or a staff review.

Guardian Mode is an opt-in relationship, separate from marketplace activation. The teen initiates an invitation to a specific guardian account/email. The guardian must authenticate and explicitly accept the one-time invitation. The link becomes active only after that acceptance. Neither party is linked by unilateral action.

## Current production contract (read-only review, 2026-11-27)

The deployed schema is `public.guardian_links` plus `public.guardian_preferences`; private invite state is held in `private.guardian_invite_codes` and `private.guardian_invite_accept_limits`. The legacy `guardian_connections` / `guardian_connection_audit_events` schema described by the existing QA script is not the deployed production schema.

Current client RPCs include:

- `create_guardian_invite_v2`: teen-initiated invite. It requires a 13–17 teen profile, creates a 256-bit random code, stores only its SHA-256 hash, expires it after seven days, and limits creation to three per teen per 24 hours.
- `accept_guardian_invite`: authenticated guardian acceptance. It requires an active `guardian` role, age 18+, confirmed email, a valid 64-hex-character code, an unexpired/unconsumed invite, and invited-email match when specified. Acceptance is limited to ten attempts per guardian per minute and consumes the code.
- `cancel_guardian_invite` and `resend_guardian_invite`: teen-owned pending invite lifecycle.
- `unlink_guardian`: either participant can revoke their active link.
- `set_guardian_setup_skipped`: records the teen's explicit decision not to enable Guardian Mode and invalidates pending invites.
- `set_guardian_alert_preferences`: teen-only update path for per-link alert/approval preferences.
- `mort_set_guardian_pause_v1`: guardian/staff pause control; this is a separate authority from alert preferences and needs explicit product approval.

`get_guardian_policy_for_user` is not present in the current production catalog. Do not describe it as a deployed RPC or call it from clients unless it is deliberately implemented, reviewed, and deployed.

## Optional activation behavior

The production onboarding evaluator accepts `guardian_setup_status` values `skipped`, `invite_pending`, or `linked` as a completed Guardian Mode choice. A teen can select skip and continue through the ordinary onboarding, legal, verification, and staff-review gates. The production job-eligibility path requires guardian approval only when the individual job explicitly sets `requires_guardian_approval = true`; it does not establish a universal guardian-link prerequisite.

Preserve these independent gates. A missing Guardian Mode link must never itself reject an otherwise eligible teen from activation or a normal job application.

## Backend/security review findings — 2026-11-27

These are read-only production findings, not approved production changes.

### Positive controls verified

- `guardian_links` has RLS enabled and forced. Direct authenticated INSERT/UPDATE/DELETE privileges are absent; client mutations use server-owned RPCs.
- `private.guardian_invite_codes` and `private.guardian_invite_accept_limits` have RLS enabled/forced, deny-all client policies, and no anon/authenticated table privileges.
- The invite code is 256-bit random material, hashed at rest, one-time, expires after seven days, and is protected by acceptance rate limiting.
- `accept_guardian_invite` binds acceptance to an authenticated adult `guardian` account and to the invited email when one was specified.
- A unique partial index enforces at most one active link and one pending invite per teen.
- `guardian_preferences` direct client writes are not granted; the preference RPC accepts writes only from the linked teen.
- The production job-eligibility check treats guardian approval as job-specific, not a universal activation condition.

### Blockers requiring code changes or explicit product decisions

1. **Profile data overexposure to linked guardians — high privacy risk.** The RLS policy `guardian_reads_linked_teen_profiles` permits a fully consented guardian to SELECT the teen's `profiles` row. Authenticated users have column-level SELECT grants that include sensitive fields such as `date_of_birth`, `approximate_area`, `city`, `region`, `verification_status`, and `guardian_paused*`. RLS is row-scoped, not column-scoped. This is broader than the documented no-blanket-profile-access contract. Replace this path with a safe, allowlisted guardian summary/view or narrowly scoped RPC and test every disallowed column from a linked guardian session.

2. **Age-out revocation is not present in the deployed backend.** The production catalog has no guardian age-transition worker/function or matching `cron.job`. `private.is_fully_consented_guardian` checks link status and both consent timestamps but not the teen's current age. The profile and Safety Ping policies can therefore continue granting access after the teen ages out. Add a server-owned age-transition process and defense-in-depth age predicates to every guardian read path; prove revocation and access denial at the age boundary.

3. **Unlink leaves previously delivered Safety Ping notifications readable.** The Safety Ping trigger writes a notification containing `teen_id` and `safety_ping_id`. The current notifications SELECT policy is recipient-only, and `unlink_guardian` revokes the link without invalidating or redacting notifications already delivered to that guardian. Add server-side invalidation/redaction or a feature-scoped read policy, then test the same notification before and after unlink.

4. **Unlink does not clear a guardian-imposed pause.** `mort_set_guardian_pause_v1` allows a linked guardian to set `profiles.guardian_paused`; `unlink_guardian` revokes the relationship but does not clear that pause state. A teen could remain paused after the guardian's authority has been withdrawn. Define the desired policy with Product/Trust & Safety, then ensure unlink cannot leave an orphaned guardian-controlled restriction.

5. **Legacy consent RPC remains callable.** `mort_set_guardian_consent(uuid, boolean)` is still executable by authenticated users. Its guardian branch accepts the legacy `adult` role and does not enforce the current invite-code, guardian-role, age-18, or confirmed-email checks used by `accept_guardian_invite`. Repository search found no current client call sites, but the endpoint remains a second consent path. Confirm retirement, then revoke authenticated execution or replace it with the current invitation-bound authorization contract.

6. **Preference defaults are not strict opt-in.** The deployed `guardian_preferences` defaults enable Safety Ping alerts, job check-in alerts, accepted-job summaries, and safety-warning alerts; the notification trigger also treats a missing preference row as enabled for Safety Pings. If Guardian Mode capabilities must be expressly enabled by the teen, change defaults to false and require explicit teen selection before any delivery. Product must decide this before rollout.

7. **Guardian pause authority is broader than notification preferences.** The current pause RPC permits an active, mutually linked guardian to pause/resume the teen's activity and writes an admin audit record. This is not represented as a teen-controlled per-link preference. Product and Trust & Safety must explicitly approve this authority, its notice/appeal behavior, and whether it remains enabled for every link; do not imply Guardian Mode is limited to alerts until this is resolved.

8. **Consent audit evidence is incomplete.** The deployed revocation trigger stamps `revoked_by` and `revoked_at`, but the production catalog has no `guardian_connection_audit_events` table or equivalent append-only event ledger for invite creation, acceptance, preference changes, unlink, and age-out. Define a privacy-minimized event contract and retention rule before claiming those events are fully audited.

9. **Legacy QA/schema drift.** `scripts/qa-guardian-optional.mjs` references `guardian_connections`, `guardian_connection_audit_events`, `teen_id`, `guardian_id`, and `get_guardian_policy_for_user`. Those objects/fields/RPC are absent from the deployed schema. The script is not a valid production-parity acceptance suite in its current form and must not be pointed at production. Rewrite it for `guardian_links`, current RPCs, and current RLS, or explicitly pin it to a disposable legacy schema and do not use it as proof of production behavior.

### Required current-schema regression coverage

- Teen completes onboarding/activation with `guardian_setup_status = skipped` and no guardian link, while all non-guardian gates remain enforced.
- Teen can apply to a normal job without a link; a job explicitly requiring guardian approval returns the specific guardian-required result.
- Only the invited, authenticated, email-matched, age-eligible guardian can accept; wrong role, under-18, unconfirmed email, wrong email, malformed, expired, consumed, replayed, and unrelated-account attempts fail closed.
- Invite rate limits, one-active-link uniqueness, and one-pending-invite uniqueness hold under concurrent requests.
- Linked guardian can read only an explicitly allowlisted teen summary; DOB, exact/approximate location, verification evidence/status, private profile fields, applications, and messages are denied unless separately approved.
- Guardian cannot modify teen-controlled preferences; teen can update preferences for the exact active link only.
- Safety Ping read and notification access are denied after unlink, including previously delivered notifications.
- Unlink removes guardian access and any guardian-imposed pause; it does not deactivate the teen or reset unrelated onboarding state.
- Age-out revokes the link, invalidates all guardian read paths, and records the approved audit event.
- The legacy `mort_set_guardian_consent` endpoint is not an alternate way to create or accept a link.

## Approval gates

This design does not approve or alter legal terms, jurisdiction rules, identity-provider policy, safety procedures, retention, or staff authority. Product, counsel, and Trust & Safety must approve any new data collection, notice language, guardian eligibility changes, feature visibility, pause authority, and operational escalation before rollout. Backend/security review must verify RLS, RPC authorization, invitation entropy/rate limits, replay resistance, audit minimization, unlink/session behavior, age transition, and all client surfaces.

No production migration, deployment, policy toggle, or merge is authorized by this draft. Keep the PR in draft until the current-schema QA suite passes, the blockers above are resolved with evidence, full CI completes, and product, legal, Trust & Safety, and backend/security approvals are recorded.
