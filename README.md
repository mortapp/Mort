# MORT

MORT is a teen-first local hustle marketplace that helps teens earn money safely through local jobs, build trust, complete goals, and connect with their community.

## Source of truth

The authoritative production client is the Flutter app in `flutter_mort`.

- Android package: `com.mortapp.mobile`
- Current verified release track: closed-test Android build
- Production website: `https://mortapp.org`
- Production backend: Supabase project `mort p`, ref `jxbnrkasktbhtiujkhay`
- Production builds must come from `flutter_mort` only
- Deleted Supabase project `rakjydmgwwgtdislanbt` is retired and must never be used

## Repository layout

The repo is intentionally structured to keep the active product client separate from legacy/reference implementations.

- `flutter_mort/` — active Flutter app and production build source of truth
- `swift_mort/` — native iOS reference implementation
- `app/`, `lib/`, `providers/`, `components/`, `config/` — retained Expo reference client and supporting legacy files
- `supabase/` — database schema, migrations, and related SQL
- `scripts/` — build, QA, and release automation
- `docs/` — runbooks, readiness notes, and release documentation

## Operating rules

1. Treat `flutter_mort` as the only production mobile client.
2. Treat the Expo app and `swift_mort` as reference-only code paths.
3. Do not ship store artifacts or release builds from the legacy Expo app.
4. Keep app-level config and platform tooling aligned with the Flutter-first release model.
5. Never use the deleted Supabase project ref `rakjydmgwwgtdislanbt`.
6. Production payment, marketplace, and publishing controls remain disabled until their release gates pass.

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

Release workflows and release gates are managed via the root scripts and docs, not the legacy Expo shell. Use the dedicated release and readiness flow for production validation, build packaging, and release gates.
