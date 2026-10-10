# CP14 hook-path decision memo

Local evidence uses the pinned GoTrue native PostgreSQL Send Email hook and a private fixture adapter. Real provider-originated recovery reaches that path; the standing suite tests password replacement, new-password login, wrong/reused/expired links, and the provider receipt/family. Synthetic SMTP acceptance is not external delivery.

Hosted activation remains blocked. The hosted HTTP hook would require a separately approved synthetic staging project, registered Send Email endpoint, protected signature secret, canonical raw-body signature verification and bounded timestamps, replay prevention, provider request-to-hook binding, and a private worker/outbox key manager. A hand-signed request does not establish real provider ingress. Tests must invoke the actual provider, prove correct recovery and signup, reject outside-path/wrong-secret/replay/drift controls, and show cleanup/log redaction before activation.

Native PG hook offers transaction-local receipt binding in this fixture but is not evidence the hosted HTTP transport behaves identically. HTTP supports the hosted deployment model but adds signature distribution, network/retry behavior and provider transaction timing. Owner chooses hosted activation only after staging evidence; this memo makes no production configuration decision.

Quota/worker requirements are exercised by issuance, shared-source-limits and actual HTTP load suites. Existing approved limits are unchanged: source-family3/hour, source5/hour, account5/hour, recipient5/hour, global40/hour; two dispatch workers. Deferred uncommitted signup must retain bounded ciphertext and consume zero dispatch quota; real queued controls and post-load legitimate consume pair denials.
