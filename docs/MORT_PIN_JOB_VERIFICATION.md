# MORT Start and Finish PIN Verification

Status: implemented and remote contract-tested.

- START and FINISH PINs are separate six-digit server-generated challenges.
- Only a salted secure hash is stored. Plaintext is returned once to the authorized adult and is not logged or sent through chat.
- Challenges expire, limit attempts, lock after repeated failure, reject replay, and use client request IDs for idempotency.
- Start requires the assigned participants, current accepted contract, mutual safety agreement, start window, no blocking incident, and confirmed funding state.
- Finish requires a verified start and valid execution state.
- State changes write immutable `job_execution_events` and update authoritative server state atomically.
- Regeneration, unavailable/refused finish PIN, safety exit, offline retry, and audited staff review paths exist.
- No compensation or payment moves automatically from an allegation or PIN exception.

Remote evidence: `qa-job-start-funding-gate.mjs`, `qa-job-pin-replay-lock.mjs`, arrival QA, and 30-user isolation regression.
