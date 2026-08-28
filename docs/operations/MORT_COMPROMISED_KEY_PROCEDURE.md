# MORT Compromised-Key Procedure

## Server Or Provider Credential

1. Revoke/rotate at the provider immediately; do not wait for a code release.
2. Remove the old value from User/CI/provider environments and invalidate active sessions where relevant.
3. Search repository, Git history, CI logs/artifacts, release archives, support channels, and operator logs without printing the value.
4. Review usage/audit logs and determine exposure window and affected data.
5. Set the replacement only in the approved server/provider secret store.
6. Run secret scans, Auth/RLS regression, and the affected provider smoke test.

## Supabase Anon/Publishable Key

Treat it as public but still rotate if abused. Security relies on Auth, RLS,
grants, rate limits, and server-only secrets, never obscurity of the public key.

## Android Upload Key

Stop release builds, preserve certificate evidence, audit private-key access,
and use Google Play App Signing's upload-key reset process. Never rotate the app
signing key casually. Rebuild only after Play accepts the replacement upload
certificate.

## Apple Signing Material

Revoke affected certificates/profiles in the Apple developer portal, create
replacement signing assets under the authorized Team, and validate a fresh
archive. Do not place `.p12`, provisioning profiles, or passwords in source.

