# MORT repo architecture

## Source of truth

`flutter_mort` is the only production client for MORT.

- Android package: `com.mortapp.mobile`
- Production and release artifacts must be created from `flutter_mort`
- The root Expo app and `swift_mort` remain retained for reference, compatibility, and historical investigation only

## Repository boundaries

- `flutter_mort/` — production client and release pipeline source of truth
- `swift_mort/` — native iOS reference implementation
- `app/`, `components/`, `providers/`, `lib/`, `config/` — retained legacy Expo app and supporting reference files
- `supabase/` — database schema, migrations, and server-side logic
- `scripts/` — release automation, QA, validation, and operational tooling
- `docs/` — operational notes, release readbooks, and readiness evidence

## Operating rules

1. Treat `flutter_mort` as the only product build target.
2. Do not create store artifacts from the Expo app.
3. Do not treat the root Expo app as the production client in docs, release checklists, or packaging.
4. Use the release scripts and docs at the repo root to coordinate production validation.
5. Keep legacy apps clearly labeled as reference-only whenever they are inspected or updated.

## Why this matters

A repo with multiple client codepaths can drift quickly. The practical fix is to keep the product source of truth explicit and fail closed when a legacy app is used for production actions.

This repo now follows that rule:
- production source of truth = `flutter_mort`
- legacy app safety = explicit and intentionally guarded
