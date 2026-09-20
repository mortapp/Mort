# MORT Verify verification record

Last audited: 2026-09-20

## Hosted Supabase checks

Verified against project `rakjydmgwwgtdislanbt`:

- canonical `mort_verify_control.mode = disabled`
- legacy `teen_verification_control.mode = disabled`
- legacy `production_enabled = false`
- legacy school-ID Storage policies: 0
- authenticated execution of the legacy start/review RPCs: revoked
- canonical raw-document helper: service-role only
- canonical raw-document helper contains a current reviewer-role recheck
- legacy retention helpers use JWT-role checks rather than deprecated `auth.role()`
- canonical retention list/finalize RPCs are service-role only
- `manual_exception` age approval requires a current senior safety moderator
- scheduled retention Edge Function deployed as version 2 and covers both legacy and canonical evidence

## Migration parity

Hosted/source MORT Verify migration history:

- `20260920180350_mort_verify_age_school_foundation`
- `20260920180910_mort_verify_review_access_hardening`
- `20260920181521_mort_verify_retention_cleanup`
- `20260920181647_mort_verify_storage_helper_binding`
- `20260920201000_mort_verify_first_party_age_school_v1`
- `20260920203500_mort_verify_storage_policy_hardening_v1`
- `20260920205000_mort_verify_email_challenge_hardening_v1`
- `20260920214100_mort_verify_canonical_hardening_v2`
- `20260920214728_mort_verify_retention_and_review_hardening_v3`

The three canonical migrations originally applied through the hosted migration API had generated timestamps different from their source filenames. Their stored SQL was verified byte-equivalent before only the migration-history versions were repaired to the source timestamps.

## Source contract

`scripts/qa-teen-verification-security-contract.mjs` locks the fail-closed control defaults, HMAC email challenge, private Storage binding, legacy retirement, live reviewer role check, canonical retention, senior-review age exception, and disabled closed-test/reviewer-demo release flags.

## CI status

Do not treat this document as proof of exact-head CI by itself. PR #19 must have a fresh workflow run for its final head before the PR is taken out of Draft.

## Project-wide advisor note

The Supabase security advisor contains broader pre-existing warnings outside this feature, including leaked-password protection being disabled and generic warnings for many authenticated security-definer RPCs. Those project-wide findings are not being misreported here as MORT Verify-specific passes.

## Remaining external/operational validation

- production collection remains disabled
- email-provider secrets/configuration must be valid before an end-to-end school-email test can succeed
- real authenticated upload/reviewer exercise must be run before production activation
- legal/privacy/reviewer-operations approval remains external to this code audit
