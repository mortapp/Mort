# MORT Job State Machine

Authority is server-side Postgres functions and immutable event tables. Flutter renders returned state and cannot directly set authoritative job, application, contract, execution, or payment outcomes.

The implemented lifecycle covers draft/publish/application selection, accepted contract versions, two-sided contract acceptance, funding gate, arrival/start verification, in-progress work, proof, finish verification, completion, dispute/review, cancellation, abandonment allegation/response, payment obligations, refund/transfer states, and closure.

Important invariants:

- Scope or amount changes create a new contract version and require both parties to accept the exact hash.
- Safety exits do not create automatic reputation penalties.
- Adult cancellation with a payment obligation opens human review and cannot move money.
- A teen abandonment report is an allegation until a separate authorized decision.
- Payment provider events and staff operations use idempotency keys and audit records.

The enum assignment in adult cancellation was corrected by migration `20260722225742_fix_adult_job_cancellation_enum_cast.sql` after Supabase lint found the runtime type mismatch.
