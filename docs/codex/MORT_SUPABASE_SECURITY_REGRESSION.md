# MORT 0.9.13 Supabase Security Regression

## Project and Migration

- Linked project ref: `rakjydmgwwgtdislanbt`.
- Applied migration: `20260802062226_video_profile_job_hardening`.
- Migration list: local and remote entries match through that migration.
- `npx supabase db lint --linked --level error`: no schema errors.
- `npx supabase db push --linked --dry-run`: remote database is up to date.

## New Security Controls

`save_my_profile_setup_v2` is caller-bound, atomic, idempotent, field-coded, and
server-validates role/age/profile rules. Its private request ledger has no
client grants. The job RPC wrapper adds server field checks and returns real
publication state while preserving existing closed-pilot publication gates.
Public/anon execution is denied.

## Hosted Evidence

- Dedicated video profile/job hardening QA passed and cleaned synthetic data.
- Six focused profile/onboarding/job hosted scripts passed and cleaned data.
- Full final Supabase regression passed 45 scripts in 334.7 seconds.
- Covered multi-user RLS, private storage, signed access, job/application/proof,
  messaging, PIN concurrency, safety, Guardian, reports, payment contracts,
  support/AI boundaries, push foundation, privacy, identity provider disabled,
  Google controls, RevenueCat atomicity, and cleanup.
- Database lint across `public` and `private` returned no warnings/errors at the
  configured fail threshold.

## Fail-Closed and External States

- Public marketplace: disabled until production verification/approval.
- Real identity-document collection: disabled.
- Provider verification: not connected; sandbox is QA-only.
- Push runtime: disabled pending verified provider credentials/approval.
- Real payment processing and escrow: absent.
- Admin authority: server-verified; no fake admin IDs.

Supabase leaked-password protection is not a code bug. Status:
**DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**. Current mitigations are strong
minimum length, password complexity, auth rate limits, email verification, RLS,
account restrictions, and secure reset. When Supabase is upgraded to Pro, enable
leaked-password protection immediately and rerun Auth security advisors.

No secret value is present in this report or mobile source.
