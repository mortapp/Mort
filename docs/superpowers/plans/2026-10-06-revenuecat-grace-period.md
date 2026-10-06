# RevenueCat grace-period correction

Builds 115 and 116 and their verification evidence remain immutable. The hosted
rollback reproduction found paid-period expiry incorrectly removes access during
provider-confirmed billing grace. This narrow correction requires a new 117 candidate.

1. Reproduce webhook normalization and hosted subscription failure before fixes.
2. Preserve the provider grace deadline only for BILLING_ISSUE normalization.
3. Add a migration extending only an existing active finite subscription. Require
   a matching numeric provider deadline, newer event, and unchanged product grants.
   Never activate an absent/revoked product, shorten paid access, or alter lifetime.
4. Test cancellation, stale/replayed events, recovery, grace expiry, revocation,
   Plus isolation and lifetime, with all database fixtures rolled back.
5. Run the complete relevant source gates. Review and deploy only this migration
   and webhook after focused tests; verify hosted behavior and privileges.
6. Commit version 0.9.16+117, package and verify signed APK/AAB from clean exact HEAD.
   Preserve 115/116 files; record hashes, size, alignment, scans and external gates.

No UI changes, local Pro grants, Plus catalog activation, Stripe activation,
emulator, production merge or rollout. Real Play lifecycle testing stays pending.
