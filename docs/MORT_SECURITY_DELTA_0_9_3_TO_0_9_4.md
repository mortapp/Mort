# MORT Security Delta 0.9.3 to 0.9.4

Date: 2026-07-23

Scope: code, migrations, hosted Supabase project `rakjydmgwwgtdislanbt`,
Flutter Android build, Expo reference build, generated Android artifacts, and
the six recovered Git commits. This is an engineering security review, not a
legal, privacy, child-safety, or production-readiness approval.

## Result

- Critical findings in the 0.9.4 delta: 0
- High findings in the 0.9.4 delta: 0
- Remote schema lint error findings: 0
- Source secret-scan findings: 0
- Git-history secret findings: 0
- Known production dependency vulnerabilities at moderate or higher: 0
- Flutter analyzer findings: 0
- Android release-lint errors: 0
- Public marketplace: closed
- Real identity collection: disabled
- Stripe provider operations: disabled
- External AI provider: disabled

No claim is made that future vulnerabilities or defects are impossible.

## Added controls

1. Server-owned maintenance, AI-disable, payment-disable, new-publishing-disable,
   and public-marketplace-closed controls. The database prevents opening the
   public marketplace in this release.
2. Private, redacted operational alert storage with deduplication, correlation
   IDs, specialized operator roles, acknowledgement, and audit events.
3. Admin report and verification actions now require specialized active roles,
   a reason, server-side authorization, and immutable audit records.
4. Notification destinations accept only role-correct internal routes and
   validated UUIDs. URLs, unknown roles, and forged privileged paths fail closed.
5. External URLs require public HTTPS; Stripe onboarding requires the exact
   `connect.stripe.com` host.
6. Edge Functions use correlation IDs, structured redacted logs, bounded inputs,
   safe error categories, and constant-time invocation-secret comparison.
7. Crash reporting sends only safe categories and allowlisted context. Exception
   messages and stack traces are not sent to the adapter.
8. The account-deletion conversation cascade race is fixed and remotely tested.
9. The unused local-notification package was removed. Firebase/APNs delivery is
   not implemented by that removal and remains a separate external/device gap.

## Hosted verification

- Supabase regression: 26/26 scripts passed.
- Multi-user isolation: 30/30 checks passed.
- 0.9.4 operations/moderation: all checks passed.
- Stripe server-boundary QA: 25/25 files passed; provider calls stayed disabled.
- Support/PIN/evidence QA: 8/8 files passed.
- Account-deletion conversation cascade: passed with no Auth/profile/thread residue.
- Send-push unauthorized observability smoke: HTTP 401, safe code, matching
  correlation ID, and no secret output.
- Supabase advisors: zero error-level findings. The warning/info inventory is
  retained rather than represented as zero findings.

## Advisor review

The security advisor returned 275 warning/info findings: 47 deny-by-default RLS
tables without policies, two anonymous `SECURITY DEFINER` status functions, 225
authenticated checked functions, and one leaked-password setting. The two
anonymous functions are reviewed fixed-output status endpoints:

- `get_release_mode_status()` returns release safety switches and no user data.
- `get_runtime_feature_status()` returns operational switches and no user data.

Both have an empty search path, no caller-controlled inputs, explicit grants,
and no mutation path. The authenticated function warnings are not blanket
waivers; role/ownership hostility tests cover the primary marketplace, support,
payment, moderation, and private-media paths. A future database review should
continue reducing public-schema definer functions where an equivalent
least-privilege design is practical.

The performance advisor returned 173 warning/info findings, including 97
unindexed foreign keys, 75 currently unused indexes, and one multiple-permissive
policy. There were no error-level findings. These require workload-based review;
unused-index advice must not be applied mechanically to a pre-launch system.

## Historical QA accounts

The guarded cleanup removed eight strict `qa-feature-*@mort.test` accounts.
The cleanup was rerun and found zero. Aggregate post-cleanup state:

- retained QA accounts: 11, all on the synthetic `@mort.test` domain
- phone values: 0
- production identity rows: 0
- identity evidence rows: 0
- active safety-admin assignments: 1
- active partner-staff assignments: 1
- active Auth sessions: 18
- proof rows: 13
- owned Storage objects: 1

The retained accounts are older reviewer fixtures. Their display names, proof
content, and object content were not opened, so this audit does not claim that
every retained value has been manually classified. Do not admit real users
until the owner confirms which fixtures are still required, revokes stale
sessions, removes obsolete elevated assignments, and deletes or formally
retains associated evidence under a written QA-retention decision.

## Leaked-password protection

**DEFERRED — PLAN-LIMITED SECURITY ENHANCEMENT**

Supabase dashboard reported that HaveIBeenPwned leaked-password protection
requires Pro or above. This is not an unresolved MORT code security bug, and no
plan upgrade or spending was performed.

Current mitigations:

- strong password minimum length
- required password complexity
- auth rate limiting
- email verification
- RLS
- account restriction logic
- secure password reset flow

Future upgrade task: **When Supabase is upgraded to Pro, enable leaked-password
protection immediately and rerun Auth security advisors.**

## Remaining security work

- Owner-classify retained QA fixtures, assignments, sessions, proof rows, and
  the one owned Storage object before real users.
- Configure and test an approved crash provider before enabling remote crash
  delivery; the current adapter is intentionally unconfigured.
- Configure real alert destinations and conduct staffed incident exercises.
- Perform physical Android and iPhone security testing, including camera,
  notifications, device lock, process death, and hostile deep links.
- Complete qualified privacy, child-safety, labor, legal, and payment reviews.
- Keep public marketplace, real identity collection, external AI, live ads,
  live IAP, and provider money movement disabled until their gates pass.
