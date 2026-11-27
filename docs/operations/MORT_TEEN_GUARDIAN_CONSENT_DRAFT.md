# Optional Guardian Mode: mutual-consent contract

## Product rule

Guardian oversight is optional in MORT. A teen may complete onboarding and marketplace activation without creating or accepting a guardian link, subject to all otherwise applicable legal, safety, age/school verification, identity, and staff-review requirements. A guardian link is never an activation prerequisite and must not be inferred from a teen's age, profile fields, emergency contact, or a staff review.

Guardian Mode is an opt-in relationship, separate from marketplace activation. The teen initiates an invitation to a specific guardian account/email. The guardian must authenticate and explicitly accept the one-time invitation. The link becomes active only after that acceptance. Neither party is linked by unilateral action.

## Existing server-owned flow

Use the existing backend contract rather than introducing a second activation-consent ledger:

- `create_guardian_invite_v2`: teen-initiated invitation.
- `accept_guardian_invite`: guardian-authenticated acceptance of the one-time invitation.
- `cancel_guardian_invite` / `resend_guardian_invite`: invitation lifecycle.
- `unlink_guardian`: participant-initiated unlink.
- `set_guardian_setup_skipped`: records the teen's choice not to enable Guardian Mode.
- `get_guardian_policy_for_user`: intended jurisdiction-policy lookup; its presence and callable signature must be verified in each target environment before client use.

An active link grants only the expressly configured Guardian Mode capabilities. It does not grant blanket access to teen messages, private profile fields, application content, or location. Per-link sharing preferences remain teen-controlled. Every read and write must remain scoped to the exact active link and the feature-specific preference.

## Required invariants

1. A teen with no guardian link can finish onboarding and activate when all non-guardian requirements pass.
2. Skipping Guardian Mode does not reduce account eligibility, marketplace access, or safety protections.
3. Invitation creation alone creates no active relationship and grants no guardian visibility.
4. Only the invited, authenticated guardian can accept; unrelated accounts and replayed/expired codes fail closed.
5. Both participants can unlink through authorized server paths. Unlink immediately removes guardian access and does not suspend, deactivate, or reset the teen account.
6. Guardian access is limited to explicitly enabled features; message access remains denied.
7. Revoke/expiry/age-transition paths remove access and emit a narrowly scoped audit event.
8. A jurisdiction-specific mandatory guardian rule, if counsel later determines one applies, must be represented as a separately reviewed legal eligibility rule—not by turning Guardian Mode into a universal product requirement.

## Validation

The existing `scripts/qa-guardian-optional.mjs` is the intended primary regression suite. It is not currently accepted as a passing PR gate: it must first be reconciled with the deployed schema and run in an isolated, production-parity QA environment. Do not point it at the live production project.

The suite currently references `guardian_connections`, `guardian_connection_audit_events`, `teen_id`, and `guardian_id`. The read-only production catalog review on 2026-11-27 found the deployed objects are `public.guardian_links` and `public.guardian_preferences`, with `teen_user_id` and `guardian_user_id`; the two compatibility/audit table names are absent. The same catalog review found no deployed `get_guardian_policy_for_user()` or `get_guardian_policy_for_user(uuid)` function, although the suite invokes that RPC at startup. It also found no deployed `run_guardian_age_transitions()` function. These mismatches mean the suite cannot presently establish the documented claims against production and will fail before completing its assertions.

The production eligibility RPC currently requires a guardian link only when the specific job has `requires_guardian_approval = true`; it does not impose a universal guardian-link prerequisite. The onboarding evaluator includes a teen Guardian Mode choice, and the explicit skip path is separate from the ordinary age, safety, verification, legal, and staff-review gates. Preserve this behavior.

## Backend/security review findings — 2026-11-27

The following are read-only findings, not approved production changes:

- **Positive:** `guardian_links` has RLS enabled and forced. Direct client writes are not exposed by the observed policy set. Private invite-code and invite-rate-limit tables have RLS enabled/forced with deny-all client policies.
- **Positive:** `accept_guardian_invite` is a security-definer RPC with an empty search path. It requires an authenticated active `guardian` role, age 18+, confirmed email, a 64-hex-character one-time code, unexpired/unconsumed code, invited-email match when specified, and no existing active link. The invite code is SHA-256 hashed at rest; acceptance attempts are rate-limited.
- **Positive:** `get_job_application_eligibility` only requires a guardian link when the individual job explicitly requires guardian approval. Do not replace this with a global activation gate.
- **Blocker — stale notification visibility after unlink:** the Safety Ping trigger creates a notification containing `teen_id` and `safety_ping_id`. The current notifications SELECT policy only checks `user_id = auth.uid()`; the observed unlink function revokes the link but does not revoke, redact, or otherwise invalidate previously created Safety Ping notifications. Therefore, an unlinked guardian can continue reading the old notification metadata. Resolve this with a reviewed server-side invalidation/redaction or feature-scoped notification authorization policy, and add a regression that reads the same notification before and after unlink.
- **Blocker — consent audit evidence:** the deployed revocation trigger only stamps `revoked_by` and `revoked_at`. The production catalog did not contain `guardian_connection_audit_events` or another dedicated guardian-link consent event ledger. The suite's expected invite-created, invite-accepted, preference-updated, and age-transition audit assertions are not currently backed by the expected deployed table. Define and review a privacy-minimized audit contract before asserting those events.
- **Blocker — legacy consent RPC:** `mort_set_guardian_consent(uuid, boolean)` remains executable by `authenticated`. Its guardian branch checks for an active `adult` role, whereas the current invite acceptance path requires the distinct `guardian` role and verified adult age/email. This is a conflicting legacy authorization path. Confirm all callers are retired, then revoke authenticated execution or replace it with the same guardian-role, age, email, invitation-binding, and replay rules as the current flow.
- **Blocker — QA/schema drift:** update the suite to use the deployed table/column/function names or provide an explicitly versioned disposable schema that matches its contract. Do not create aliases or compatibility objects in production solely to make the stale test pass.

Required follow-up regression coverage includes: optional onboarding/activation without a link; application to a normal job without a link; rejection only for a job explicitly requiring guardian approval; invited guardian only; wrong-email, expired, replayed, and unrelated-account rejection; teen-only preference writes; no message/profile/location overreach; Safety Ping visibility before and after unlink; stale notification invalidation; unlink without teen account restriction; and age-out revocation plus audit evidence.

## Approval gates

This design does not approve or alter legal terms, jurisdiction rules, identity-provider policy, safety procedures, retention, or staff authority. Product, counsel, and Trust & Safety must approve any new data collection, notice language, guardian eligibility changes, feature visibility, and operational escalation before rollout. Backend/security review must verify RLS, RPC authorization, invitation entropy/rate limits, replay resistance, audit minimization, unlink/session behavior, age transition, and all client surfaces.

No production migration, deployment, policy toggle, or merge is authorized by this draft. Keep the PR in draft until the QA suite is reconciled and passes, the blockers above are resolved with evidence, full CI completes, and product, legal, Trust & Safety, and backend/security approvals are recorded.
