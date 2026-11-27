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
- `get_guardian_policy_for_user`: returns jurisdiction policy; default product behavior remains optional unless a separately approved jurisdiction-specific legal requirement is established and implemented through a distinct legal review.

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

The existing `scripts/qa-guardian-optional.mjs` is the primary regression suite. It covers optional policy defaults, skip behavior, teen eligibility and application without a link, mutual invitation acceptance, isolation from unrelated guardians, teen-controlled preferences, limited Safety Ping visibility, unlink without account restriction, and age-transition revocation.

Run it only in its documented QA environment. Add/retain regression coverage for the independent activation path: a teen with no guardian link passes activation when the normal legal, safety, onboarding, verification, and staff-review gates pass; an otherwise eligible teen is not rejected solely for missing Guardian Mode.

## Approval gates

This design does not approve or alter legal terms, jurisdiction rules, identity-provider policy, safety procedures, retention, or staff authority. Product, counsel, and Trust & Safety must approve any new data collection, notice language, guardian eligibility changes, feature visibility, and operational escalation before rollout. Backend/security review must verify RLS, RPC authorization, invitation entropy/rate limits, replay resistance, audit minimization, unlink/session behavior, age transition, and all client surfaces. No production migration, deployment, or policy toggle is authorized by this draft.
