# MORT Database Credential Rotation Runbook

Status: **OWNER-REPORTED RESET COMPLETE / PROPAGATION UNVERIFIED**. A production database password was previously disclosed in chat and is treated as compromised. The owner reports that it has been changed. This runbook contains no credential value; Codex did not retrieve or modify the password and will not initiate another reset.

## Scope and confirmed consumers

Rotate the database login credential through the authorized Supabase Dashboard, not by editing application keys. The repository uses `SUPABASE_DB_PASSWORD` for direct Postgres utilities:

- GitHub Actions `backend-operations` environment: `SUPABASE_DB_PASSWORD` is passed to the metadata-only workflow `mort-backup-metadata.yml`.
- `scripts/backup-feature-schema.mjs` and `scripts/backup-feature-data.mjs`: production-target-guarded export tools read `SUPABASE_DB_PASSWORD` from the process environment. The data exporter is not wired into the scheduled workflow.
- `scripts/play-review-secrets-common.ps1`: reads a Windows user-scoped `SUPABASE_DB_PASSWORD` into the current process for release QA helpers.
- Other remote audit and QA scripts also read this generic variable. Before running any of them after rotation, inspect their target guard and configure a process-scoped value for the intended project. Never assume a generic variable is production-safe.

The CI variable `QA_SUPABASE_DB_PASSWORD` is a separate QA credential. Do not replace it with the production password. Web/mobile clients use Supabase API keys and are not consumers of the Postgres password. Dashboard-created database connections, external operators, or other secret stores are not fully inventoried by this repository and must be checked by the owner before rotation.

A name-only GitHub secret inventory on 2026-11-07 found the repository-level `SUPABASE_DB_PASSWORD` secret last updated `2026-11-01T21:18:10Z`; its value was not retrieved, so this does not prove that it matches the owner's reported reset. The `backend-operations` environment has no secrets, variables, or protection rules. Organization-level secret inheritance was not inspected. The workflow additionally needs `MORT_BACKUP_ENCRYPTION_KEY`; that name was not present at repository or environment scope.

## Rotation steps (operator execution required)

1. Obtain owner approval and schedule a maintenance window. Assign one operator and one verifier. Pause scheduled/manual jobs that could repeatedly reconnect with the old password.
2. Inventory every external database client and pool, including GitHub environments, the Windows user secret store, CI runners, database IDEs, and any operator-managed automation. Record secret **names and owners only**, never values.
3. Confirm a current, encrypted, recoverable backup plan and its key custody before rotation. The present repository tooling is partial and has no proven restore; it is not sufficient evidence of recovery.
4. The owner reports that the production password reset has already been performed. Do not reset it again. If the owner later confirms otherwise, use the authorized Supabase Dashboard **Database → Settings** flow; never send the new value through chat, issue comments, shell history, logs, or Git.
5. Store the current value in GitHub's protected `backend-operations` environment secret and the authorized operator secret store. The repository-level secret timestamp above is not sufficient proof of propagation. Configure at least one required reviewer on `backend-operations`; currently it has no protection rules. Keep the QA secret distinct and update other inventoried consumers only through their approved secret manager.
6. Download the database CA certificate from the Supabase Dashboard **Database → Settings → SSL Configuration** and configure the Postgres client to use that CA with hostname verification (`rejectUnauthorized: true`). Do not disable certificate checks. Then verify a new direct TLS database connection with the protected credential using a harmless identity query; do not print the connection URI, password, or environment. The last attempted local connection failed at TLS verification (`SELF_SIGNED_CERT_IN_CHAIN`) before authentication, so credential propagation remains unverified. Supabase's instructions are at [Postgres SSL Enforcement](https://supabase.com/docs/guides/platform/ssl-enforcement) and [Connect to your database](https://supabase.com/docs/guides/database/connecting-to-postgres).
7. Only after the backup workflow's required inputs, encrypted artifact path, and environment reviewer gate have been corrected and verified, run one approved metadata-only backup job and verify the encrypted artifact/checksum. The current workflow fails its exporter contract and its declared environment has no protection rules. Do not run the production data exporter or copy production rows to QA as part of credential rotation.
8. Confirm old-credential attempts are not being retried by stale clients, inspect connection/auth logs for repeated failures, then resume paused jobs. Record timestamps, operators, secret names, and test outcomes without secret values.

## Downtime and connection-pool risks

- Dashboard password reset invalidates new database logins using the old credential; direct `pg.Client` jobs and scripts will fail until their protected value is updated.
- Existing database sessions may remain alive until disconnected, but reconnects using stale credentials can fail. Do not rely on open sessions as a continuity plan.
- Supabase documents a short-lived shared Supavisor credential cache after a password change. Confirm the new credential by direct connection first; retry pooler connections in a bounded manner. Repeated stale-password retries can open the pooler's circuit breaker and temporarily reject connections. Avoid rapid successive rotations.
- For future no-downtime rotations, Supabase documents creating a separate custom login role, migrating clients gradually, then retiring the old role. That requires a least-privilege design and separate reviewed SQL; it is not part of this password-reset runbook.

## Evidence and completion criteria

Propagation remains **unverified** until the owner/operator records: dashboard reset time; updated secret-store names; successful direct TLS login; successful required pooler/CI checks; no stale retry loop; and verifier sign-off. The password change is owner-reported, not independently verified by this runbook update.

References: [Reset database password](https://supabase.com/kb/troubleshooting/how-do-i-reset-my-supabase-database-password-oTs5sB), [Supavisor after password rotation](https://supabase.com/kb/troubleshooting/supavisor-error-password-authentication-failed-after-password-rotation).
