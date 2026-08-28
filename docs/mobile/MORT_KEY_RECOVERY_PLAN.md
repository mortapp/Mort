# MORT Upload-Key Recovery Plan

> Status: closed-test publication candidate dated 2026-07-20. Not legal approval, not a public launch, and not a production-readiness claim.

## Ownership

The adult Play Console account owner is accountable for access recovery. The founder uses a separately invited Google account. Password sharing is prohibited.

## Required protected copies

Before the first Play upload, the adult owner must create two offline, encrypted backups containing the upload JKS and recoverable credentials. One copy should be on BitLocker-encrypted removable media in a locked location; the second should be in an approved password manager or encrypted vault controlled by the adult owner. The repository's DPAPI credential file is machine/user-bound and is not, by itself, a cross-machine recovery backup.

Never place the key or password in source ZIPs, ordinary cloud project folders, email, shared drives, group chat, screenshots, issue trackers, or documentation. Record the alias, certificate fingerprints, creation date, expiration, storage custodians, and last restore-test date without recording the private key or password.

## Restore drill

Quarterly, on an offline protected machine, restore the JKS and credentials, run `keytool -list -v`, and compare the SHA-256 fingerprint to `MORT_UPLOAD_CERTIFICATE_REPORT.md`. Do not generate a replacement key merely to test recovery.

## Loss or compromise

1. Stop uploads and remove release access from affected accounts.
2. Have the adult owner review Play Console activity and Google account sessions.
3. Follow Play Console's upload-key reset process; do not change the package ID or app-signing key casually.
4. Generate a new upload key through an approved release machine, update the public certificate record, and invalidate the old local credentials.
5. Document the incident without putting credentials in the incident record.
