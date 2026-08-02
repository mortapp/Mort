# MORT Database Restore Drill

Status: `CODE-COMPLETE / MANUAL VERIFICATION REQUIRED`.

1. Obtain written owner approval and create a new isolated Supabase project.
2. Record source snapshot hash, migration head, versions, operators, and target ref.
3. Force closed marketplace, provider-disabled, maintenance configuration.
4. Restore approved schema/data using plan-supported Supabase tooling.
5. Apply only reviewed migrations newer than the snapshot.
6. Recreate private buckets/policies and deploy provider-disabled Edge Functions.
7. Set target-only server secrets in the provider secret store.
8. Run migration parity, linked database lint, all 45 hosted QA suites, Storage
   isolation, account deletion, and release-profile checks.
9. Compare aggregate counts without opening teen evidence or private messages.
10. Record RPO/RTO, deviations, owner sign-off, then lock or destroy the drill target.

Abort for a wrong ref, missing approval, checksum mismatch, public bucket,
provider-live state, real user communication, secret output, or unexplained row
divergence. No restore drill was performed in this run.

