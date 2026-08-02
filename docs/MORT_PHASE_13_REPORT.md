# MORT Phase 13 And Legal-Compliance Completion Report

Date: 2026-08-01

Status: CODE-CONTROLLED MODERATION AND LEGAL GATES VERIFIED; EXTERNAL LEGAL,
STAFFING, CONTACT, PROVIDER, PLAY CONSOLE, AND PUBLICATION WORK INCOMPLETE

Budget prompt 13 contains both the moderation/admin operations phase and the
legal-consent/teen-safety compliance phase. Previously verified versioned legal
acceptance, re-consent, retention, safety, Support, evidence, dispute, identity,
and payment-boundary systems were preserved rather than rebuilt.

## Implemented

- Removed direct client admin writes for jobs, reviews, and admin audit logs.
- Added narrow coded job/review moderation RPCs with state checks, reason-code
  allowlists, bounded notes, least-privilege role checks, and server audit logs.
- Added moderation-detail access logging to `private_data_access_events`.
- Required expirations for new staff-role assignments; the legacy grant path
  may revoke but refuses new unbounded grants.
- Added forced-RLS account-ban appeals, claimant isolation, expiring reviewer
  assignment, original-actor conflict protection, and independent reversal.
- Blocked ordinary account-status RPCs from reversing bans and bounded legacy
  suspension duration.
- Wired Flutter typed moderation actions, reason/note capture, ban appeal
  submission, and the restricted reviewer queue.
- Added inactive, hash-pinned, versioned Community Guidelines, Safety Rules,
  and Guardian Terms attorney drafts.
- Added a private, service-only legal release-control record and hard server
  activation predicates. Public marketplace activation now fails unless all
  legal, owner, contact, staffing, jurisdiction, identity, and policy gates pass.
- Added a safe read-only readiness projection that returns no private approval
  references.

## Hosted Verification

The migration `20260801233508_moderation_legal_activation_completion.sql` was
applied to linked project `rakjydmgwwgtdislanbt`. The final hosted QA created
four isolated synthetic users, verified legal controls and inactive drafts,
proved unauthorized and direct-write denial, exercised coded job/review
moderation, proved sensitive-access logging, tested role expiry and ban-appeal
isolation, blocked the original banning actor, completed an independent
reversal, proved public activation closed, and removed all four users.

Earlier QA attempts exposed fixture assumptions and one transport failure. Each
attempt's four synthetic users was explicitly removed. The adult fixture was
updated with sandbox identity state required by the existing job gate; the teen
fixture was updated with sandbox identity state required by the existing review
gate. A Postgres client error listener was added so a later socket close cannot
bypass cleanup. No failed attempt is counted as pass evidence.

## Commands And Results

| Command | Result |
|---|---|
| `npx supabase migration new moderation_legal_activation_completion` | PASS; required CLI-created migration |
| `npx supabase db push --linked --dry-run` | PASS; exactly one pending migration before apply |
| `npx supabase db push --linked` | PASS; migration applied; expected idempotent constraint/trigger notices only |
| `npx supabase db lint --linked --level warning` | PASS; `No schema errors found` |
| `node --check scripts/qa-moderation-legal-completion.mjs` | PASS |
| first targeted hosted QA | FAIL at existing adult identity job gate; 4/4 synthetic users cleaned; fixture repaired |
| second targeted hosted QA | INTERRUPTED by hosted Postgres transport close; 4/4 synthetic users cleaned; cleanup hardening added |
| third targeted hosted QA | FAIL at existing teen identity review gate; 4/4 synthetic users cleaned; fixture repaired |
| bounded wrapper attempt | TIMEOUT at 240 seconds during hosted transport instability; 4/4 recent synthetic users cleaned |
| `node scripts/qa-moderation-legal-completion.mjs` final clean run | PASS in 8.3 seconds; all assertions and 4/4 cleanup passed |
| first focused Flutter test run | FAIL: 4 pass, 1 stale contract assertion; test updated for v2 RPC and ban-reversal guard |
| final focused Flutter tests | PASS: 5/5 |
| focused `flutter analyze --no-pub` | INTERRUPTED after 184 seconds with no diagnostics; not counted |
| focused `dart analyze` | PASS; final run completed in 58.2 seconds with no issues |
| targeted `dart format` | PASS; final check formatted 7 files, 0 changed |
| `npx supabase db push --linked --dry-run` after apply | PASS; remote database up to date |
| `npx supabase migration list --linked` | PASS; 158 rows aligned, 0 mismatches, latest local/remote `20260801233508` |
| `scripts/secret-scan.ps1` | PASS; no source secret value found |
| scoped `git diff --check` | PASS |
| independent Auth cleanup count | PASS; 0 Phase 13 QA users created on/after 2026-08-01 remain |
| `get_public_release_readiness` final hosted query | PASS; activation false, legal ready false, owner approval false, attorney-package approval false |
| legal draft SHA-256 comparison | PASS; 0 mismatches against the applied migration catalog |
| trailing-whitespace audit | PASS; no unexpected findings; six intentional Markdown hard breaks in hash-pinned drafts preserved |

## Defects Repaired

- Review approval previously relied on a direct update with no matching RLS
  update policy and could appear successful without changing a row.
- Generic admin direct job mutations and client-authored audit rows exposed an
  unnecessarily broad authorization surface.
- The original moderator could restore a banned account through the ordinary
  status path instead of an independent appeal.
- New safety/staff roles could be granted without expiration.
- Sensitive moderation-detail reads were not recorded as private-data access.
- Hosted QA cleanup could be skipped by a late Postgres socket error.

## External Gates

- No attorney has approved the drafts or Indiana/minor/youth-labor model.
- No adult owner, privacy contact, child-safety contact, or support contact has
  supplied recorded approval.
- Moderation staffing, training, coverage, and incident on-call remain absent.
- Play Console declarations and public HTTPS policy/contact deployment are not
  complete.
- Production identity verification is not connected; the public marketplace
  remains closed.
- No physical-device, Play-delivered, or production-public test is claimed in
  this phase.

An independent Auth inventory found two older `qa-feature-*` synthetic accounts
created on 2026-07-30 by pre-existing Phase 12 work. They were not created by
this phase and were not modified or deleted during this bounded prompt.
