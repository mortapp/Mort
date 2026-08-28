# MORT Future Verification Provider Migration

## Selection gates

Before contracting a provider, evaluate supported teen age bands and jurisdictions, parental/guardian implications, government-ID authenticity, liveness/ownership, duplicate detection, address needs, data residency, subprocessors, retention/deletion, breach terms, accessibility, dispute/appeal process, webhook signing, sandbox isolation, uptime, pricing, and exit/export terms. Legal, privacy, and teen-safety approval is mandatory.

## Integration contract

The provider must integrate through server-owned sessions and signed webhooks. The mobile/web app receives no service credential and cannot submit a verified result. Map provider outcomes into minimized internal status/reason codes, retain the external reference needed for audit, and avoid raw identity evidence unless a separately approved retention policy requires it.

Production acceptance requires environment binding, timestamp/expiry, signature and replay validation, account/session binding, expected check coverage, webhook idempotency, manual-review route, restriction override, and sandbox-to-production isolation. A provider result creates the exact `Provider identity verified` indicator only when all policy conditions pass; it still does not guarantee safety.

## Rollout

Use test accounts, then an allowlisted closed pilot, then a reviewed regional policy. Preserve policy and decision history, support re-verification/expiration, and maintain a vendor-off switch. Public marketplace stays closed until this process is complete.
