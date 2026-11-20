# QA Fixture and Configuration Change Log — 2026-11-19/20

Project: QA `ckcxakhxqlkhppsxxjhv` only. **Production was not modified.**

## Backup

- Logical snapshot schema `qa_snapshot_20261119`. It holds 139 table copies, plus `_functions`, `_triggers`, `_policies` and `_grants`. It is not a full DR backup: QA is on the Free plan, which has no PITR.

## Secrets (values stored only in QA; none were copied from production)

- **Vault:** `mort_password_attestation_secret`.
- **Function secrets:**
  - `MORT_PASSWORD_ATTESTATION_SECRET`
  - `ACCOUNT_DELETION_WORKER_SECRET`
  - `IDENTITY_VERIFICATION_MODE`
  - `IDENTITY_VERIFICATION_PROVIDER=mort_qa_test_provider`
  - `IDENTITY_VERIFICATION_WEBHOOK_SECRET`
  - `REVENUECAT_WEBHOOK_AUTH_HEADER`
  - `MORT_GOOGLE_PLAY_RTDN_SECRET`
- **Not set:** `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.

## Edge Functions deployed

- `password-guard`, `account-deletion-processor`, `identity-verification-webhook`, `revenuecat-webhook` and `google-play-rtdn`.
- Deployed from the PR #109 working tree, using `verify_jwt=false` as declared in `supabase/config.toml`.

## Migrations applied (QA ledger)

See `MIGRATION_130000_QA_REPORT_2026-11-19.md` §2: 130000, the three ports, then 120000.

## Configuration fixtures (copied read-only from production, or QA-specific)

- **`private.school_email_domains`:** added `mortapp.org`. This is QA-specific, so the QA teen accounts can pass school verification; production has its own two domains.
- **Legal content:** `legal_documents` (4), `legal_document_versions` (5) and `role_requirements` (20), copied read-only from production.
- **Release control:** a `mort_release_control` row mirroring production values (`production_public`, marketplace enabled). QA had no row, so the marketplace RPCs returned `marketplace_unavailable`. **Production release controls were not changed.**

## Accounts (QA only; passwords are unique and stored outside the repository)

| Account | Role | User id | Notes |
|---|---|---|---|
| qa.teen1@mortapp.org | teen | 6719683c-b8b7-4897-8440-d415e7c60630 | active, verified; guardian-linked |
| qa.teen2@mortapp.org | teen | 131e82a2-7275-4fa1-98be-9bc2fa273502 | active, verified; guardian skipped (unlinked) |
| qa.adult1@mortapp.org | adult | 2c98f2b7-9603-4a9f-a626-4fa8de0e0c1b | active; holds the sandbox RevenueCat entitlement from RC-01 |
| qa.adult2@mortapp.org | adult | 56a20f7f-9832-4da0-a3cb-525212bb79ce | active |
| qa.guardian1@mortapp.org | guardian | d36c5959-9e0d-4002-89bc-56235d54d63d | active; linked to TEEN1 |
| qa.staff1@mortapp.org | moderator | 90bfa099-ced5-4e27-ab65-5ac92e664bff | `private.user_roles` moderator, granted by ADMIN1 |
| qa.admin1@mortapp.org | admin | 8e5099de-4d31-40dd-82ea-02a1bdc61ea2 | **Extra account.** `private.user_roles` admin (`granted_by` null, the root of trust); only admins can activate accounts. |
| qa.delete1@mortapp.org | adult (disposable) | (deleted) | Deleted by the worker in DEL-RUN |
| qa.delete2@mortapp.org | adult (disposable) | — | In `retention_review` |
| qa.pwtest1@mortapp.org | (disposable) | — | Migration 130000 tests |

**Staff provisioning:**

- The staff roles were granted server-side in `private.user_roles`. That table is not exposed through the API and clients cannot write it (AZ-ROLES-INSERT).
- `profiles.role` was not edited to grant staff rights; clients cannot update `profiles.role`, `account_status` or `verification_status` (AZ-SELFPROMO-*).
- `has_staff_role` reads only `private.user_roles`.

**Account creation:**

- TEEN1 and TEEN2 used guarded signup.
- The remaining accounts got 429 from the 2-per-hour mailer limit and were created via admin invite instead.
- All accounts were then confirmed via an admin `generate_link` magiclink, and every password was set through `password-guard update_password`. No password was set by direct SQL.

## Fixture records

| Fixture | Details |
|---|---|
| Guardian link | 93fc216d-f23d-4732-a351-efbebf65a057 (TEEN1 ↔ GUARDIAN1); active, with both teen and guardian consent timestamps |
| Job J1 | 94d50472-2aa0-455e-b743-6e58dee2abb7 (ADULT1); open |
| Job J2 | 6f86f750-e1a9-461e-bfdf-ca2f499b5f0c (ADULT2); open |
| Job J3 | 29e0251d-77d9-436c-8db9-558a70aa356e (ADULT1); TEEN1 accepted, assignment 551731a9-b375-40a4-a092-378578abce1a, contract 00a38cfc-70fb-416d-8802-4d6de622288f |
| Job J4 | 48acbf1a-c5df-4650-97a5-805ebb272a9d (ADULT2); cancelled |
| Completed job | **Not created**: blocked by finding F-02 and the Stripe dependency |
| Applications | TEEN1→J1, TEEN1→J3, TEEN2→J1, TEEN2→J2 |
| Safety report | 7bd2e6b0-3b85-4188-9f28-db8ec6aa4368 (TEEN2 about ADULT2/J2) |
| Message thread | c5e35891-7e0b-46b9-a2a8-e68098b326a6 (TEEN1/ADULT1) |
| Storage | `verification-evidence` objects owned by five different accounts |

## Settings to restore

- None: no QA Auth configuration was changed. The attempt to raise the email rate limit was refused by the platform, which requires custom SMTP.
