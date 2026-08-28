# MORT Legal/Trust RLS, Storage, and Advisor Report

Date: 2026-07-19  
Project: `rakjydmgwwgtdislanbt`

## RLS and remote QA

The following hosted regression groups passed using isolated synthetic users that were removed after each run:

- New legal/trust suites: 21 of 21.
- Existing closed-pilot suites: 17 of 17.
- Verification safe-mode suites: 7 of 7.
- Mutual-trust suites: 19 of 19.
- Complete multi-user isolation: 30 of 30 assertions.

The tests prove direct legal-acceptance forgery denial, immutable contract history, two-party material changes, preserved evidence, private disputes, bounded poster restrictions, authorized exports, signal-only web reuse, replay rejection, accessible liveness alternatives, two-person mismatch review, assigned-reviewer access, ordinary-user/founder denial, group-chat nonauthority, optional Guardian Mode, incident isolation, and private Storage behavior.

## Storage

The read-only remote Storage audit passed:

- Buckets audited: 7.
- Public buckets: 0.
- `identity-evidence`: private, 0 objects.
- `mort-document-vault`: private, 0 objects.
- `verification-uploads`: private, 0 objects.
- Identity-bucket object total: 0.
- Storage object policies: 13.
- `proof-uploads`: private, 1 pre-existing object. Its name, path, metadata, and content were not read or changed.

The verification lockdown and multi-user suites also denied anonymous listing, cross-user listing/download, unsupported MIME uploads, ordinary-admin identity access, and real identity upload while disabled.

## Supabase advisors

Current Management API advisor result:

- Security: 167 findings; 154 WARN, 13 INFO, 0 ERROR.
- Security types: 153 authenticated security-definer executable warnings, 13 RLS-enabled/no-policy notices, and 1 Auth leaked-password warning.
- New legal/trust slice: 15 checked security-definer WARN and 1 fail-closed RLS/no-policy INFO.
- Performance: 101 INFO, 0 WARN, 0 ERROR.
- Performance types: 32 pre-existing unindexed foreign keys and 69 unused indexes.
- New legal/trust slice: 0 unindexed foreign keys and 9 unused-index INFO entries after `20260719070500`.

Security-definer functions in this slice use fixed search paths, explicit grants/revokes, authenticated identity binding, role/party/assignment checks, and remote abuse tests. The linter notices remain visible and should be re-reviewed after any function change. The RLS/no-policy notice is a private fail-closed configuration table, not a client-readable table.

The 32 remaining unindexed-FK findings are outside this new slice and remain informational technical debt for representative-load review. Unused-index findings must not be removed based only on the small synthetic QA workload.

Supabase leaked-password protection is **DEFERRED — PLAN-LIMITED SECURITY ENHANCEMENT** because the project is on the Free plan. Current mitigations are password minimum length and complexity, Auth rate limiting, email verification, RLS, account restrictions, and secure password reset. When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors. No plan upgrade or spending occurred.

## Honest boundary

This report does not make the backend production-ready. Real identity collection, real liveness, real appearance review, public marketplace access, legal enforcement, and reviewer access to real evidence remain disabled or externally gated.
