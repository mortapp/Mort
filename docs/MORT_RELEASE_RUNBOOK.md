# MORT Release Runbook

Status: operator runbook for verified closed testing. Production pilot and public release remain gated.

## Preconditions

1. Work from `C:\Users\micha\Mort` on an attributed tree. Do not discard unknown changes.
2. Confirm `flutter_mort/pubspec.yaml` has an unused version code of at least 97.
3. Confirm package `com.mortapp.mobile` and Supabase ref `rakjydmgwwgtdislanbt`.
4. Confirm protected `MORT_UPLOAD_*` signing values resolve and match the pinned upload certificate.
5. Load only the public Supabase URL/anon key into the build process. Never log or archive privileged values.
6. Confirm the intended profile and every feature flag. Closed testing must keep public marketplace, identity collection, payments, ads, IAP, Google auth, remote push, and crash provider flags false.

## Pre-build checks

```powershell
cd C:\Users\micha\Mort\flutter_mort
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

cd C:\Users\micha\Mort
npx supabase migration list --linked
npx supabase db push --linked --dry-run
npx supabase db lint --linked --level warning
.\scripts\run-final-supabase-regression.ps1
.\scripts\secret-scan.ps1
.\scripts\sensitive-file-scan.ps1
```

Any unexpected migration, secret finding, test failure, certificate mismatch, or project-ref mismatch stops the release.

## Closed-test build

```powershell
cd C:\Users\micha\Mort
.\scripts\build-closed-test-aab.ps1
.\scripts\build-closed-test-apk.ps1
```

Expected artifact locations:

- `build/play/mort-closed-test.aab`
- `build/play/mort-closed-test.apk`
- `build/play/mort-closed-test-aab-build-manifest.json`
- `build/play/mort-closed-test-apk-build-manifest.json`
- `build/play/reports/aab-verification.txt`

The script must report the pinned upload signer and never fall back to debug signing. Keep `%USERPROFILE%\MortSymbols\android\<version>` private and backed up outside the source archive.

## Play Console owner actions

1. Create or select an internal/closed testing release, never production.
2. Upload `mort-closed-test.aab` and confirm version `0.9.7 (97)` and package `com.mortapp.mobile`.
3. Retain the isolated reviewer instructions only for the reviewer-enabled closed artifact.
4. Reconcile Data safety, target audience, app access, UGC, permissions, financial features, and account deletion declarations against this exact AAB.
5. Run Play pre-launch report and archive screenshots/results without secrets or real teen data.
6. Test upgrade and clean-install behavior on the required API/device matrix.
7. Do not promote the release while any production gate in the readiness report remains blocked.

## Production profiles

`build-production-pilot-aab.ps1` must fail until real Flutter remote-push and crash provider implementations exist. `build-production-public-aab.ps1` must fail until identity, legal, moderation, native QA, provider, and activation evidence is approved.

Never bypass these scripts by invoking `flutter build appbundle` with hand-selected production flags.

## Rollback and containment

- Stop rollout in Play Console and retain the last known-good artifact/hash.
- Use reviewed server kill switches to close public access and payment paths; do not delete migrations.
- Revoke compromised tokens/credentials through their provider and rotate server secrets.
- For a safety incident, preserve minimal audit evidence, restrict affected accounts, and follow `MORT_INCIDENT_RUNBOOK.md`.
- Release a higher version code for fixes; never reuse 97 after Play accepts it.
