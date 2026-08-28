# MORT Server-Authoritative Onboarding Report

Updated: 2026-07-29 (America/Indianapolis)

## Scope

Phase 4 completed the code-controlled onboarding path for teen,
adult/business, and guardian accounts. Authentication/session startup remains
regression locked; the new resume cursor is loaded through the existing
startup boundary.

This is closed-pilot product/safety acknowledgment engineering. Existing legal
documents remain drafts and are not represented as attorney-approved public
terms. Public release continues to fail closed when required published legal
documents are unavailable.

## Server State

- `onboarding_progress` stores the caller's current step, completed steps,
  notification choice, accessibility preferences, adult/business choice, and
  optional Guardian Mode choice.
- `onboarding_acknowledgements` stores the versioned
  `mort-closed-pilot-safety-v1` product/safety acknowledgment, platform, app
  version, and timestamp.
- `onboarding_progress_events` stores privacy-minimized step and changed-field
  metadata, never form values.
- All three tables have forced RLS and no `anon` or `authenticated` table
  privileges. Authenticated clients use caller-bound RPCs only.
- Steps are prerequisite ordered and re-saving an earlier step cannot regress
  a later resume cursor.
- DOB and role are immutable after selection; admin cannot be self-selected.
- Transportation and Guardian Mode are persisted but optional.
- Completion requires age/role compatibility, profile identity fields,
  username, every mandatory step, the current safety acknowledgment, adult
  business details when applicable, and any published role-specific legal
  acceptance.
- `production_public` also requires published legal documents. Draft documents
  do not satisfy that gate.

## Client State

- Startup resumes from the hosted `resume_path` after app close, logout, or a
  restored session.
- Age, role, profile, skills, availability, transportation, payment
  preference, optional Guardian Mode, notification/accessibility preferences,
  safety acknowledgment, and review each persist before navigation.
- The onboarding hub displays hosted progress instead of a hardcoded counter.
- Legacy `cash_app` and `square_link` profile values are clamped to safe,
  non-credential choices. No payment credential is collected.
- The safety screen requires five explicit closed-pilot safety notices and
  records package/platform metadata before final review.
- Only the final review invokes `complete_my_onboarding`; completion remains a
  backend decision and grants no verification or privileged role.

## Verified Results

- Migration transaction dry-runs: PASS for all four Phase 4 migrations.
- Remote migration parity: PASS, 131 local/remote aligned.
- Hosted three-role onboarding QA: PASS, including under-13 denial,
  age/role mismatch denial, out-of-order denial, cursor resume, optional
  transportation/Guardian Mode, business-name requirement, partial
  acknowledgment denial, completion, and isolation.
- Full Supabase regression: PASS, 32/32 scripts.
- Flutter regression: PASS, 240 passed and 2 expected skips.
- Flutter analyze: PASS, no issues.
- Android API 36.1 native integration: PASS, 2/2 tests on `emulator-5554`.
- Secret scan: PASS.
- Sensitive-file scan: PASS, 1,705 files and 10 protected values checked.

## Security Defect Repaired

The inherited `save_my_onboarding_profile` RPC still accepted
`p_complete_onboarding=true`. The first hosted exploit test proved it could
complete a profile without the new safety checks. An initial trigger guard also
failed because SQL compared an absent setting with `<>`, which evaluates to
unknown for `NULL`.

The final trigger uses `IS DISTINCT FROM 'true'` and permits a false-to-true
completion transition only when the validated transaction-local completion
flag is explicitly set. The hosted exploit was rerun and blocked before the
full regression passed.

## External Gates

- Draft legal notices require attorney and teen-safety review before public
  legal publication.
- Identity provider verification is not connected; finishing onboarding never
  marks identity verified.
- Public marketplace access remains closed under hosted release policy.
- Physical Android force-close/logout journeys remain a manual-device gate;
  hosted resume behavior and emulator UI/native behavior are automated.
- iPhone, TestFlight, App Store, and Google Play production review were not
  performed by this phase.
