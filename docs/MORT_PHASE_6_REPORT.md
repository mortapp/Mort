# MORT Phase 6 Report

Updated: 2026-07-29

## Result

Phase 6 is `100% VERIFIED` for its code-controlled closed-pilot scope.
Messaging lifecycle, PIN confirmation, private evidence, statements, and
appeals are deployed and verified remotely. Public marketplace access and real
payment processing remain fail-closed.

## Delivered

- Lifecycle-bound, realtime, paginated, retry-safe text messaging.
- Restricted guardian visibility and private moderation evidence.
- Deterministic address/link/off-platform and serious-safety scanning.
- Payload-bound start/finish PIN confirmations with atomic concurrency.
- Private evidence upload, manifest validation, checksum, retention,
  preservation, signed preview, audit, and human queue.
- Append-only dispute statements and independent human appeals.
- Flutter pagination/realtime/retry/read-only messaging UI.
- Flutter retry-safe PIN entry across both execution surfaces.
- Flutter statement history and appeal submission UI.
- Four new hosted adversarial suites in the canonical regression runner.

## Applied Migrations

1. `20260730043000_messaging_lifecycle_privacy_and_reliability.sql`
2. `20260730050000_job_pin_confirmation_idempotency.sql`
3. `20260730060000_dispute_statements_and_appeals.sql`
4. `20260730061000_capture_initial_dispute_statement.sql`
5. `20260730062000_fix_support_evidence_path_validation.sql`
6. `20260730063000_evidence_registration_idempotency_and_lint.sql`

All 140 local migrations match the hosted migration history. A final dry run
reported the remote database up to date.

## Verification

| Gate | Result |
|---|---|
| `flutter analyze` | PASS, no issues |
| `flutter test` | PASS, 246 passed / 2 expected skips / 0 failed |
| Phase 6 source contract | PASS, 8/8 |
| Hosted Supabase regression | PASS, 37/37 scripts |
| Migration parity | PASS, 140 aligned |
| Migration dry run | PASS, remote up to date |
| Database lint | PASS for Phase 6 objects; remaining warnings are disabled identity-provider stubs reserved for Phase 11 |
| Source secret scan | PASS |
| Sensitive-file scan | PASS, 1,723 files / 10 protected values |

## Bugs Found And Fixed

1. Linked guardians inherited unrestricted job-chat access through a broad
   participant helper. Guardian access is now limited to approved safety data.
2. Non-idempotent message sending could duplicate after ambiguous network
   failure. The v2 RPC binds request ID, thread, and body.
3. Message threads remained writable after terminal application states. A
   server trigger now moves them to read-only.
4. The Safety Plan screen still called revoked legacy arrival aliases. It now
   uses the same v2 start-PIN contract as the main execution screen.
5. PIN retry attempts were not payload-bound. Server-only bcrypt fingerprints
   and request ledgers now prevent substitution and duplicate attempts.
6. Dispute statements overwrote snapshots and no real appeal record existed.
   Statements are append-only and appeals require an independent human reviewer.
7. Newly opened disputes did not enter statement history until the capture
   trigger was added.
8. The private evidence Storage policy double-escaped `.jpg`, rejecting valid
   uploads. Policy, table constraint, and RPC validation now use a safe literal
   dot expression.
9. Evidence registration ignored its request ID. Registration is now
   request-bound, replay-safe, and rejects changed payloads.
10. PIN QA cleanup originally left null-contract events that blocked fixture
    deletion. Cleanup now removes events by actor/application and verifies no
    auth fixtures remain.
11. Two new Flutter source assertions initially used incorrect implementation
    names. The assertions were corrected and the final complete suite passed.

## External Boundaries

- No real payment was processed and no escrow/payout capability was enabled.
- Human dispute and evidence review staffing remains an external requirement.
- Physical Android and iPhone execution of these exact flows remains for later
  device phases.
- Public marketplace activation remains closed behind server policy.

