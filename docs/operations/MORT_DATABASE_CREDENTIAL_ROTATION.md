# MORT Database Credential Rotation Runbook

Status: **PREPARED / NOT EXECUTED**. A production database password was previously disclosed in chat. Treat it as compromised. This runbook contains no credential value. No rotation has been performed.

## Scope and confirmed consumers

Rotate the database login credential through the authorized Supabase Dashboard, not by editing application keys. The repository uses `SUPABASE_DB_PASSWORD` for direct Postgres utilities:

- GitHub Actions `backend-operations` environment: `SUPABASE_DB_PASSWORD` is passed to the metadata-only workflow `mort-backup-metadata.yml`.
- `scripts/backup-feature-schema.mjs` and `scripts/backup-feature-data.mjs`: production-target-guarded export tools read `SUPABASE_DB_PASSWORD` from the process environment. The data exporter is not wired into the scheduled workflow.
- `scripts/play-review-secrets-common.ps1`: reads a Windows user-scoped `SUPABASE_DB_PASSWORD` into the current process for release QA helpers.
- Other remote audit and QA scripts also read this generic variable. Before running any of them after rotation, inspect their target guard and configure a process-scoped value for the intended project. Never assume a generic variable is production-safe.

The CI variable `QA_SUPABASE_DB_PASSWORD` is a separate QA credential. Do not replace it with the production password. Web/mobile clients use Supabase API keys and are not consumers of the Postgres password. Dashboard-created database connections, external operators, or other secret stores are not fully inventoried by this repository and must be checked by the owner before rotation.

A name-only GitHub secret inventory found the repository-level `SUPABASE_DB_PASSWORD` name; the value was not retrieved. The `backend-operations` environment currently has no secrets, variables, or protection rules. Organization-level secret inheritance was not inspected. The workflow additionally needs `MORT_BACKUP_ENCRYPTION_KEY`; that name was not present at repository or environment scope.

## Rotation steps (operator execution required)

1. Obtain owner approval and schedule a maintenance window. Assign one operator and one verifier. Pause scheduled/manual jobs that could repeatedly reconnect with the old password.
2. Inventory every external database client and pool, including GitHub environments, the Windows user secret store, CI runners, database IDEs, and any operator-managed automation. Record secret **names and owners only**, never values.
3. Confirm a current, encrypted, recoverable backup plan and its key custody before rotation. The present repository tooling is partial and has no proven restore; it is not sufficient evidence of recovery.
4. In the authorized Supabase Dashboard, use **Database → Settings** to reset the production database password. Do not send the new value through chat, issue comments, shell history, logs, or Git.
5. Update the protected production `SUPABASE_DB_PASSWORD` secret in the GitHub `backend-operations` environment and the authorized operator secret store. Keep the QA secret distinct. Update any other inventoried consumer through its approved secret manager.
6. Verify a new direct TLS database connection with the new credential using a harmless identity query. Do not print the connection URI, password, or environment. Then verify each required pooler/automation consumer with bounded retries.
7. Only after the backup workflow's required inputs, encrypted artifact path, and environment reviewer gate have been corrected and verified, run one approved metadata-only backup job and verify the encrypted artifact/checksum. The current workflow fails its exporter contract and its declared environment has no protection rules. Do not run the production data exporter or copy production rows to QA as part of credential rotation.
8. Confirm old-credential attempts are not being retried by stale clients, inspect connection/auth logs for repeated failures, then resume paused jobs. Record timestamps, operators, secret names, and test outcomes without secret values.

## Downtime and connection-pool risks

- Dashboard password reset invalidates new database logins using the old credential; direct `pg.Client` jobs and scripts will fail until their protected value is updated.
- Existing database sessions may remain alive until disconnected, but reconnects using stale credentials can fail. Do not rely on open sessions as a continuity plan.
- Supabase documents a short-lived shared Supavisor credential cache after a password change. Confirm the new credential by direct connection first; retry pooler connections in a bounded manner. Repeated stale-password retries can open the pooler's circuit breaker and temporarily reject connections. Avoid rapid successive rotations.
- For future no-downtime rotations, Supabase documents creating a separate custom login role, migrating clients gradually, then retiring the old role. That requires a least-privilege design and separate reviewed SQL; it is not part of this password-reset runbook.

## Evidence and completion criteria

Rotation remains **unverified** until the owner/operator records: dashboard reset time; updated secret-store names; successful direct TLS login; successful required pooler/CI checks; no stale retry loop; and verifier sign-off. This document does not claim the password has been rotated.

References: [Reset database password](https://supabase.com/kb/troubleshooting/how-do-i-reset-my-supabase-database-password-oTs5sB), [Supavisor after password rotation](https://supabase.com/kb/troubleshooting/supavisor-error-password-authentication-failed-after-password-rotation).
