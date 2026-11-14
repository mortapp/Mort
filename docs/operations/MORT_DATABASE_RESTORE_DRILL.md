# MORT Database Restore Drill

Status: `NOT PERFORMED / RESTORE SOURCE AND TARGET APPROVAL REQUIRED`.

1. Obtain written owner, product/privacy, and counsel approval for the specific data categories, purpose, retention, and access controls. Production-to-QA copying is prohibited until those approvals exist. Prefer a synthetic fixture restore for mechanics; it does not prove production-data recovery.
2. Confirm whether the existing isolated QA project is an approved restore target. It has its own QA-specific migration history and must not be reset, dropped, or overwritten. Confirm it is empty immediately before any approved operation. If a full restore would overwrite that schema or data, stop and request a separately isolated target; do not improvise a reset.
3. Obtain a real, integrity-checked backup produced by an approved backup process. Record source ref, snapshot/checksum, migration head, versions, operator, time, and target ref. Current repository export tooling is partial and no complete backup/restore evidence exists.
4. Keep marketplace, provider, document collection, payment, and outbound notification controls disabled on the target. Prevent email/SMS delivery to real users.
5. Restore only with the supported plan/tooling into the authorized isolated target. The current repository has no restore executor; no restore command is approved by this document.
6. Restore database schema/data and Auth records through their supported mechanisms; separately restore actual Storage object bytes and verify object metadata. A database dump of `storage.objects` alone does not restore the bytes.
7. Apply only reviewed migration deltas after comparing the backup history with the target. Preserve the target's QA-only extensions and ledger; never blindly replay the full production chain into an existing QA project.
8. Recreate only target-specific Auth/provider settings and server secrets. Do not copy production secret values, OAuth credentials, Stripe credentials, or service-role credentials into QA.
9. Verify migration parity, table/Auth counts, bucket/object counts, object byte accessibility, key foreign-key relationships, RLS isolation, and representative application behavior using authorized synthetic accounts. Capture counts and checksums without opening teen evidence or private messages.
10. Record RPO/RTO, deviations, access logs, owner sign-off, and the target's retention/deletion date. Do not destroy the existing QA project or its QA-specific work as part of cleanup.

Abort for a wrong ref, missing approval, a non-empty/unapproved target, checksum mismatch, public bucket, provider-live state, real user communication, secret output, destructive schema/ledger replacement, or unexplained row/object divergence. No complete backup or restore drill has been performed. The current metadata workflow omits user rows, Auth records, and Storage object bytes; the separate data exporter omits Auth records and object bytes and has not been run.

