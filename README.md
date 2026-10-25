# MORT

MORT is a teen-first local hustle marketplace that helps teens earn money safely through local jobs, build trust, complete goals, and connect with their community.

## Source of truth

The authoritative production client is the Flutter app in `flutter_mort`.

- Android package: `com.mortapp.mobile`
- Current verified release track: closed-test Android build
- Hosted backend: Supabase project `rakjydmgwwgtdislanbt`
- Production builds must come from `flutter_mort` only

## Repository layout

The repo is intentionally structured to keep the active product client separate from legacy/reference implementations.

- `flutter_mort/` — active Flutter app and production build source of truth
- `swift_mort/` — native iOS reference implementation
- `app/`, `lib/`, `providers/`, `components/`, `config/` — retained Expo reference client and supporting legacy files
- `supabase/` — database schema, migrations, and related SQL
- `scripts/` — build, QA, and release automation
- `docs/` — runbooks, readiness notes, and release documentation

## Operating rules

1. Treat `flutter_mort` as the only production client.
2. Treat the Expo app and `swift_mort` as reference-only code paths.
3. Do not ship store artifacts or release builds from the legacy Expo app.
4. Keep app-level config and platform tooling aligned with the Flutter-first release model.
5. Prefer the docs and scripts in the root repo for operational guidance.

## Local development

Use the Flutter app for the actual product build and validation flow.

```powershell
cd flutter_mort
flutter pub get
flutter analyze
flutter test
flutter run
```

## Release and validation

Release workflows and release gates are managed via the root scripts and docs, not the legacy Expo shell.

```powershell
cd .
.
```

The repo includes a dedicated release and readiness flow for the Flutter client, including release docs and QA automation. Use those for production validation, build packaging, and release gates.
