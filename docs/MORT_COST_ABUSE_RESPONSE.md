# MORT Cost and Abuse Response

1. Disable the affected server runtime switch. Do not ship a client-only flag as containment.
2. Preserve safe correlation IDs, rate-limit events, provider event IDs, and audit records without logging prompts, evidence, tokens, credentials, or PINs.
3. Revoke compromised provider credentials and sessions where exposure is suspected.
4. Block abusive accounts/IP sources using reviewed server controls; do not punish a safety report automatically.
5. Reconcile provider usage and billing against server reservations and webhook records.
6. Notify the named security/operations owner and open an incident record.
7. Apply a forward migration or Edge fix, run direct hostile tests, and verify provider dashboard limits.
8. Restore service gradually with conservative limits and active alert monitoring.
9. Complete a post-incident review covering root cause, cost, affected users, legal notice obligations, and durable prevention.

External AI and Stripe money movement are already off in the current closed-test environment, which is the required fail-closed state when provider controls are unverified.
