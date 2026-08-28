# MORT

MORT is a safety-sensitive local job marketplace for teens ages 13-17, adults and businesses, optional guardians, community partners, and authorized moderators.

## Authoritative client

The production-track mobile client is the Flutter application in `flutter_mort`.

- Android package: `com.mortapp.mobile`
- Current version: `0.9.7+97`
- Hosted backend: Supabase project `rakjydmgwwgtdislanbt`
- Android target SDK: 36
- Android minimum SDK: 24

The root Expo project and `swift_mort` are retained as legacy/reference clients. They are not the Play release source and must not be used to generate store artifacts.

## Current release boundary

The verified profile is a free, isolated closed-test build. It keeps all of the following disabled:

- public marketplace activation
- marketplace payment processing and platform fees
- Google Play Billing and RevenueCat purchases
- AdMob
- production identity-document collection
- Google sign-in
- production remote push and crash reporting

MORT does not process, hold, guarantee, or escrow job compensation in this release. Personal Cash App and Square handles are not collected. Public adult-to-teen marketplace access remains closed until identity, legal, moderation, provider, and native-device gates have objective evidence.

## Flutter setup

```powershell
cd C:\Users\micha\Mort\flutter_mort
flutter pub get
flutter analyze
flutter test
flutter run
```

Runtime public configuration is supplied with Dart defines. Never place a service-role key, database password, access token, signing password, Stripe secret, or webhook secret in Flutter source or a release archive.

## Supabase

The linked project is `rakjydmgwwgtdislanbt`. The mobile app uses only the hosted URL and public anon key. Privileged credentials remain in the Supabase server environment or protected operator environment.

Before any future migration:

1. Confirm the linked project ref.
2. Create timestamped schema and data backups outside release artifacts.
3. Run `npx supabase db push --linked --dry-run`.
4. Apply only reviewed additive migrations.
5. Re-run migration alignment, database lint, smoke tests, and the full RLS regression.

Do not run `supabase db reset`, drop, truncate, or destructive repair commands against this project.

## Android release profiles

```powershell
cd C:\Users\micha\Mort
.\scripts\build-closed-test-aab.ps1
.\scripts\build-closed-test-apk.ps1
```

The closed-test scripts validate version, target project, upload certificate, release flags, signing, package ID, SDK levels, merged permissions, exported components, reviewer boundary, and artifact hash. Obfuscation symbols are written outside the repository under `%USERPROFILE%\MortSymbols`.

The production pilot and public scripts intentionally fail closed until their external gates are met:

```powershell
.\scripts\build-production-pilot-aab.ps1
.\scripts\build-production-public-aab.ps1
```

## Verification

```powershell
cd C:\Users\micha\Mort\flutter_mort
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

cd C:\Users\micha\Mort
.\scripts\run-final-supabase-regression.ps1
.\scripts\secret-scan.ps1
.\scripts\sensitive-file-scan.ps1
```

See `docs/MORT_PRODUCTION_READINESS_REPORT.md` for the current evidence and blockers. See `docs/MORT_RELEASE_RUNBOOK.md` before creating or uploading any artifact.
