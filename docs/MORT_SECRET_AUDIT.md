# MORT Secret Audit

Audit date: 2026-07-22

## Results

- Source secret scan: PASS.
- Sensitive-file scan: PASS, 1,442 files, 30 known app media files, 9 available secret values checked.
- APK/AAB scan: PASS, 2,601 extracted entries checked against 4 available sensitive values.
- npm production dependency audit: PASS after replacing transitive vulnerable `uuid@7.0.3` with a patched override.
- Git history scan scope: the local repository has zero commits, so there is no local history to scan.
- `.env.local` is Git-ignored and is validated to contain exactly `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY`, and `EXPO_PUBLIC_APP_ENV` with non-empty values.
- Source and clean package rules reject service-role keys, Supabase access/DB credentials, Stripe/OpenAI/provider secrets, signing material, env files, logs, backups, and generated dependency/build folders.
- Android upload credentials and obfuscation symbols remain outside the repository.

The user reported earlier credential exposure and confirmed rotation. This audit did not print or independently verify old credential revocation. Any credential that was ever exposed must remain treated as compromised and rotated at its provider.
