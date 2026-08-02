# MORT Messaging, PIN, Evidence, And Dispute State Machine

Updated: 2026-07-29

## Scope

This document records the deployed Phase 6 contracts in Supabase project
`rakjydmgwwgtdislanbt`. It describes platform state, authorization, and retry
behavior. It does not enable public marketplace access or payment processing.

## Messaging

- A job thread is server-created for one application, teen, and adult.
- `active` applies while the application is submitted, pending/reviewed,
  accepted, in progress, proof submitted, or pending completion release.
- Every terminal or canceled application state moves the thread to
  `read_only`, records the closure time, and records a non-sensitive reason.
- Only the thread teen and adult can read/send ordinary job chat. Guardian Mode
  does not grant broad message access. Staff use restricted moderation evidence.
- `send_safe_message_v2` requires an owner-scoped request ID, serializes retry
  handling, and rejects reuse with a different thread or body.
- Messages are text-only. Proof, identity, and dispute media use their own
  private buckets and authorization paths.
- The deterministic scanner blocks PIN-sharing requests, probable exact street
  addresses, unsafe contact/link sharing, sexual exploitation, threats, and
  other configured high-risk content. Restricted scanner evidence is not
  returned in ordinary message pages.
- `list_thread_messages_page` uses bounded keyset pagination. Realtime inserts
  use the same RLS-protected `messages` table and are deduplicated in Flutter.

## Start And Finish PINs

- The adult generates separate short-lived start and finish PINs server-side.
- Only hashes are stored. Status responses never return an existing PIN.
- The assigned teen confirms the PIN; the start confirmation also records the
  explicit person-match result.
- `confirm_job_start_pin_v2` and `confirm_job_finish_pin_v2` bind each request
  ID to the application, PIN kind, PIN fingerprint, and relevant confirmation.
- Repeated delivery of the same request returns the stored response. A changed
  payload is rejected as `pin_request_payload_mismatch`.
- Row locks and advisory locks make concurrent confirmations produce one state
  transition and one audit event. Attempt limits and expiration remain enforced.
- Legacy mobile arrival/PIN aliases are service-only. Both Flutter PIN entry
  surfaces now call the v2 contracts.
- PIN values do not enter messages, analytics, support transcripts, status
  payloads, or client-readable event tables.
- Missing/expired PIN escalation remains a human-support workflow and moves no
  money.

## Private Evidence

- Processed evidence is JPEG-only, at most 4 MiB, in the private
  `support-evidence` bucket under `<owner UUID>/<evidence UUID>.jpg`.
- Flutter re-encodes selected images before upload. Registration verifies MIME,
  byte size, SHA-256, subject authorization, category, and attachment limit.
- Registration is request-ID-bound and replay-safe. Reuse with changed metadata
  is rejected as `evidence_request_payload_mismatch`.
- Submission enters a human review queue and activates preservation/retention
  metadata when linked to a dispute.
- Submitted metadata and dispute history are immutable to participants.
- Downloads require a short-lived signed URL from the authenticated
  `support-evidence-url` Edge Function. URLs are private/no-store and access is
  audit logged. Permanent public URLs are not used.
- An authorized dispute party can preview linked evidence; outsiders cannot
  read metadata, authorize a URL, or invoke a successful preview.
- AI may not adjudicate evidence.

## Disputes And Appeals

- Party statements are append-only records. Snapshot fields remain only for
  compact current-state UI.
- Statement submission is idempotent and payload-bound, writes the private
  timeline, and notifies the other party.
- A platform dispute decision may be appealed only by a party and only when an
  appealable human decision exists.
- The appeal must be reviewed by an independently assigned, ready human
  reviewer who did not make the challenged decision.
- Appeal outcomes are `upheld`, `modified`, or `overturned`; each is recorded in
  the immutable private timeline.
- Platform dispute/appeal functions do not charge, transfer, refund, release,
  or otherwise move money. They do not create a court judgment or criminal
  finding.
- Outsiders cannot read statements, evidence, decisions, timeline events, or
  appeals.

## Verified Tests

- `qa-messaging-safety-state-machine.mjs`
- `qa-job-pin-concurrency.mjs`
- `qa-payment-dispute-appeal.mjs`
- `qa-support-evidence-lifecycle.mjs`
- `qa-evidence-isolation.mjs`
- `qa-payment-evidence-preservation.mjs`
- `qa-nonpayment-dispute-isolation.mjs`
- Full hosted Supabase regression: 37/37 scripts passed.
- Flutter: 246 tests passed, 2 expected skips, 0 failed.

