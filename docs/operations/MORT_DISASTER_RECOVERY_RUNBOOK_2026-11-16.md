# MORT Disaster Recovery Runbook — 2026-11-16

Status: **procedure verified end to end on disposable local production replicas only.**
No production data was read by these scripts, no production backup has been taken with them,
and nothing has been restored to a hosted project. The production backup job is committed
but **disabled** until the owner approves it (see "Enabling production backups").

Continues PR #107. That drill covered `public.*` and Storage metadata only, and ran on the
generic migration chain, which is not what production runs. This one covers everything a
working recovery needs and runs on the production-baseline replica from PR #108.

## Why MORT needs its own backup

The production project `jxbnrkasktbhtiujkhay` is on the **Free plan**.
[Supabase](https://supabase.com/docs/guides/platform/backups) gives Free projects no daily
platform backups and no PITR (Pro has 7 days of daily backups; PITR is a Pro+ add-on).
Platform backups never include Storage object bytes anyway. Until this job is enabled,
**MORT has no backup that can restore Auth users, private tables or Storage files**. The
existing weekly `mort-backup-metadata.yml` job captures schema plus `public.*` rows only.

## Scope

| Captured | Notes |
| --- | --- |
| `auth.users`, `auth.identities`, MFA factors and recovery codes, WebAuthn credentials, SSO/SAML/OAuth client config, `auth.audit_log_entries` | Password hashes are bcrypt and portable, so users keep their passwords (verified). |
| every table in `private` (26 on the replica, 25 in production today) | Staff roles (`private.user_roles`), attestation nonces, runtime control rows with their **live** values. |
| every table in `public` | |
| `storage.buckets`, `storage.objects` metadata **and object bytes** | Bytes are downloaded through the Storage API with the service-role key, inside the backup job only. |
| sequences in `public`, `private`, `auth` | |

| Not captured | Reason / recovery action |
| --- | --- |
| sessions, refresh tokens, one-time tokens, flow state, MFA challenges | Bound to the source project's JWT secret. Users sign in again. |
| `vault.secrets` | Encrypted with the source project's root key, so not portable. Re-create from the key manager (step 4). |
| Auth settings (SMTP, redirect URLs, OAuth providers, rate limits, CAPTCHA), Edge Function secrets, API keys | Project configuration, not database data. Re-apply from the configuration record (step 4). |
| `supabase_migrations`, platform-owned schemas | Re-created by step 2. |

## Security properties

- **Encryption**: AES-256-GCM via `scripts/backup-envelope.mjs`, with a 32-byte random key
  (`MORT_BACKUP_ENCRYPTION_KEY`, base64) and a random 96-bit IV. The project ref and kind
  (`full-dr-v1`) are bound as AAD, so a backup cannot be replayed as a different project or
  kind. The payload is gzipped JSON; the file is written mode 0600.
- **TLS**: the production database is read through the Supabase session pooler with
  certificate verification against the vendored, fingerprint-pinned Supabase root CA
  (`scripts/supabase-remote-tls.mjs`, PR #104). Storage and Auth are HTTPS.
- **Integrity**, checked at three levels:
  1. the outer file sha256 (`.enc.sha256`; restore refuses a missing or mismatched file);
  2. the GCM tag, which rejects a wrong key or any tampering;
  3. inside the payload, a per-table row count and a sha256 over the sorted canonical jsonb
     text of every row, plus a sha256 for every Storage object.

  Restore recomputes all of them on the target.
- **Target safety**: restore refuses the production ref and the deleted project
  `rakjydmgwwgtdislanbt` before connecting. Local mode only accepts loopback hosts. Hosted
  mode needs `DR_TARGET_REF` plus a matching `DR_CONFIRM_TARGET`.
- **Fidelity regression**: an earlier version parsed rows into JS values, which rewrote
  numeric scale inside jsonb (`25.00` became `25`). The drill's hash check caught it.
  Rows now stay as jsonb text end to end.
- **Service-role key**: used only in the backup job and the restore operator's shell. It
  never reaches any client.

## Key management and rotation

1. Generate the key: `openssl rand -base64 32`.
2. Store it in **two** places: the GitHub `backend-operations` environment secret
   `MORT_BACKUP_ENCRYPTION_KEY`, and an offline password-manager entry held by the owner
   plus one named backup custodian. A key that exists only in GitHub cannot decrypt
   anything if GitHub access is lost.
3. Rotate every 90 days, and immediately if anyone with access leaves or the key may be
   exposed:
   - add the new key under a dated password-manager entry and replace the GitHub secret;
   - **keep each retired key for at least the artifact retention period (30 days)** plus
     any off-site retention, so older backups stay decryptable;
   - record the rotation date in the operations log, so the right key can be matched to
     an artifact by its timestamp.
4. Rotating the database password or the service-role key does not affect existing
   backups. Update the corresponding secrets only.

## RPO / RTO

- **RPO**: equals the backup interval. The workflow runs weekly (Mondays 07:17 UTC), which
  is a 7-day RPO. **Recommendation: run daily before launch (24 h RPO)**; that changes the
  cron line and needs owner approval. Upgrading to Pro adds daily platform backups of the
  database (still no Storage bytes). PITR would bring the database RPO down to minutes.
- **Measured RTO for the restore step itself** (local, production-schema replica):
  - target rebuild from the recovery set: 38 s;
  - decrypt, restore and verify (86 tables, 291 rows, 10 users, 10 objects): 1.5 s.

  Production data volume is about the same today (12 users, 9 objects, 126 bytes).
- **Realistic service RTO** depends on the scenario:
  - In-place recovery into the existing project (data corruption or accidental deletion;
    needs owner approval; never rehearsed against production): about 1–2 hours.
  - Recovery into a **new** project: 1–3 days. The Flutter app pins the project ref
    (`AppConfig.expectedSupabaseProjectRef`, `secure_session_storage.dart`) and its
    URL/key, so a new project needs a new Android and iOS release and store review.

  The database restore is not the bottleneck in either case.

## Restore order (new project)

1. **Freeze**: stop writes to the damaged project if it is still reachable (pause release,
   maintenance flag). Pick the backup artifact and confirm its `.sha256`.
2. **Schema**: create the new project in the same region, then apply, in order:
   `supabase/production-baseline-recovery/production-baseline-2026-11-12.sql`,
   `storage-policies-2026-11-12.sql`, `ledger-2026-11-13-to-2026-11-15/*`,
   `production-acl-2026-11-16.sql`, `production-config-rows-2026-11-16.sql`,
   `auth-triggers-2026-11-16.sql`, and then every production-baseline migration that had
   been applied to production by then. This is the same sequence as
   `scripts/qa/replica/build-and-test.sh`; the catalog fingerprint
   (`scripts/qa/replica/fingerprint.sql`) must match.
3. **Data**: run `scripts/dr/dr-full-restore.mjs` with `DR_TARGET=hosted`,
   `DR_TARGET_REF=<new ref>`, `DR_CONFIRM_TARGET=<new ref>`, `DR_TARGET_DB_PASSWORD`, the
   new project's `SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_ANON_KEY`, `DR_BACKUP`,
   `DR_EXPECTED_SOURCE_REF=jxbnrkasktbhtiujkhay` and `MORT_BACKUP_ENCRYPTION_KEY`.
   Internally the script runs:
   - (a) decrypt and verify;
   - (b) schema compatibility check;
   - (c) `storage.buckets`;
   - (d) object bytes through the Storage API;
   - (e) one transaction with triggers suspended: auth, then private, then public tables,
     `storage.objects` metadata (keeping the new byte versions), and sequences;
   - (f) verification. Every check must PASS.
4. **Secrets and configuration**:
   - re-create Vault secrets (`mort_password_attestation_secret`) and Edge Function secrets
     from the key manager;
   - deploy the Edge Functions;
   - re-apply Auth settings: SMTP, Site URL and redirect URLs, OAuth providers (Google),
     rate limits, CAPTCHA, leaked-password setting if on Pro;
   - re-create the Storage bucket settings if they differ.

   Payment configuration is owner-managed and out of scope here.
5. **Verify on the new project**:
   - sign in with two owner-controlled accounts (not minors);
   - check that staff roles resolve;
   - download one object per bucket as its owner;
   - run the public-site health checks.
6. **Cut over**: release the app builds pointing at the new project, update mortapp.org
   configuration, and revoke the old project's keys.

In-place recovery skips steps 2 and 6. That path truncates live tables, so it needs
explicit owner approval at the time, and a fresh backup of the damaged state must be taken
first.

## Verified evidence (local)

`scripts/dr/drill-local.sh`, also CI job `disaster-recovery-drill`:

1. Built the production replica and populated it **through real user journeys**: GoTrue
   signups through `password-guard`, Storage uploads, staff role grants. Journeys 53/53,
   authz 108/108.
2. Full backup: 86 tables, 291 rows, 10 auth users, 26 private tables, 10 objects
   (1600 bytes). The ciphertext contains no plaintext email.
3. **Destroyed** the replica (all Docker volumes) and rebuilt an empty target: 0 users,
   0 objects.
4. Negative checks, all rejected: wrong key, tampered file, production as target, deleted
   project as target, unconfirmed hosted target, non-loopback "local" target.
5. Restore and verify, all PASS:
   - every table hash identical (86 of 86);
   - users 10 and identities 10;
   - private 26 tables, with `user_roles` 2 (admin and moderator);
   - 6 sequences;
   - 172 foreign keys with 0 orphans;
   - 10 of 10 objects byte-identical;
   - **all 8 restored users sign in with their original password and read their own
     profile under RLS**;
   - staff roles present.
6. After restore: fresh-user journeys 53/53 and authz 108/108 on the restored target.

## Residual risk and limitations

- **Never run against production, and no hosted restore has been performed.** Hosted
  behavior (pooler permissions for `session_replication_role`, Storage API limits) is
  expected to match the local Supabase stack, where `postgres` is likewise not a superuser,
  but it is unverified. The first approved run should restore into a throwaway hosted
  project.
- Off-site copy: GitHub artifacts expire after 30 days, and anyone with Actions read access
  can download the ciphertext. It is safe without the key, but copying to a second location
  (owner-controlled cloud bucket) is recommended.
- The payload holds every object in memory. That is fine at current volume (126 bytes); it
  needs streaming before Storage grows past a few hundred MB.
- Backups contain minors' personal data and identity evidence. Access to the key and the
  artifacts should be limited to named custodians. No published privacy-policy statement
  about backup retention was found; counsel should confirm that the 30-day retention and
  account-deletion handling are disclosed. Restoring a backup can resurrect accounts deleted
  after the backup was taken, so re-apply deletions logged since the backup before cutover.

## Enabling production backups (owner approval required)

1. Add the `backend-operations` environment secrets `SUPABASE_SERVICE_ROLE_KEY` and
   `MORT_BACKUP_ENCRYPTION_KEY`. `SUPABASE_DB_PASSWORD` is already used by the existing
   job. Add required reviewers to the environment.
2. Set the repository variable `MORT_FULL_DR_BACKUP=1`.
3. Run `MORT Encrypted Backup` once with `workflow_dispatch`, then restore that artifact
   into a throwaway hosted project using the steps above.
4. Optional: change the cron to daily.
