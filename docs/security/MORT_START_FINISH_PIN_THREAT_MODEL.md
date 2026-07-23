# Start and Finish PIN Threat Model

Threats: guessing, replay, plaintext database theft, chat/log leakage, wrong participant, stale job state, race conditions, adult refusal, offline retries, and admin abuse.

Controls: server CSPRNG, separate purposes, salted hash only, six-digit format, short expiration, failed-attempt lock, one-time consumption, caller/role/job/contract/funding checks, transactional row locks, idempotent request IDs, immutable events, no analytics/chat logging, and audited exception review.

Residual risk: an authorized adult can disclose a visible one-time PIN out of band; compromised devices can expose on-screen data; physical coercion cannot be solved by a PIN. Safety exit and human review remain required. Physical-device/offline adversarial testing is incomplete.
