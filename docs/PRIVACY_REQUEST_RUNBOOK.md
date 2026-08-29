# Privacy Request Runbook — 2026-08-29

Procedural guide for handling access, correction, export, and deletion
requests. No requester personal information is committed into this
repository — this document describes process, not individual cases.

## 1. Deletion

**Primary path**: the user does this themselves — Settings → Account →
Delete account (in-app) or the public web self-service flow
(`/account-deletion/`, magic-link verified). See
`ACCOUNT_DELETION_IMPLEMENTATION_AUDIT.md` for the full technical pipeline.

**If a user emails `mortapp.help@gmail.com` asking staff to delete their
account instead of using either self-service path:**
1. Verify the requester controls the account: ask them to complete the
   in-app or web deletion flow themselves (it requires signing in — this
   *is* the verification step, not an extra hurdle). Do not delete an
   account on the basis of an email claim alone; email sender addresses are
   trivially spoofable and MORT has no independent way to verify identity
   from an email alone.
2. If they genuinely cannot sign in (lost access to the account's email,
   lost the device, etc.), this becomes an identity-verification problem
   with no safe email-only resolution. Do not delete on unverified say-so.
   Escalate to a human decision-maker; do not automate this path.
3. Never ask for a password over email. Never ask for a full government ID
   over ordinary email as the verification step (no secure channel for that
   currently exists — see `IDENTITY_VERIFICATION_ENABLED=false` in the data
   flow map; standing this up is `OWNER_ACTION_REQUIRED` if email-based
   verification for locked-out users becomes a recurring need).

## 2. Access / "what data do you have on me"

1. Verify identity the same way as deletion (they must be signed in; this is
   not currently a self-service export button, see item 3).
2. A staff member with legitimate access queries the account's own rows
   across the categories in `DATA_RETENTION_REGISTRY.md` and
   `PRODUCTION_DATA_FLOW_MAP.md` (profile, jobs, applications, messages
   involving them, reviews, reports they filed, legal acceptances).
3. Redact other users' identities from shared records (e.g., a job's other
   party's name) before sending — the requester is entitled to their own
   data, not a counterparty's.
4. Do not attach raw safety/incident evidence about the requester without a
   human review pass — that evidence may itself concern a third party (e.g.,
   a report someone else filed about them) that shouldn't be disclosed
   verbatim.

## 3. Correction

Self-service today for: display name, avatar, availability, transportation,
notification preferences, general location/service area (see
`app_config.dart`/onboarding v2 RPCs — `save_my_onboarding_*`). **Not**
self-service: DOB and role — these are server-authoritative security
boundaries by design (age/role eligibility gate; see Phase 9 of the
production directive) and are not user-editable after onboarding. A
correction request for DOB/role is a support escalation requiring a human
decision, not an automated fix — do not build a self-service DOB/role editor
without re-litigating why that boundary exists.

## 4. Export

**Not currently a self-service feature.** No "export my data" button exists
in the app today. Until one ships, treat export requests like access
requests (item 2): a staff member compiles the account's own data manually
from the categories in the retention registry and sends it directly to the
verified account holder. `OWNER_ACTION_REQUIRED` if a jurisdiction's law
requires a specific export format/timeline this ad hoc process doesn't meet
— flag to legal review, don't invent a compliance claim this process doesn't
actually satisfy.

## 5. General rules for every request type

- No password reset instructions or account secrets sent by email as a
  "verification" step.
- No raw government ID collection through ordinary email (identity
  verification is disabled in the current shipping build regardless).
- No requester personal information (email, name, request content) committed
  to this Git repository, ever — this runbook stays generic and procedural.
- If a request touches a live safety hold, an active legal matter, or
  evidence tied to an open moderation case, do not resolve it unilaterally
  — escalate to `docs/CHILD_SAFETY_RESPONSE_RUNBOOK.md` procedures or a
  human legal/trust-and-safety decision-maker as appropriate.
