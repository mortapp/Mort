# MORT Release Profile Matrix

Recorded: 2026-07-29  
Authoritative matrix: `config/mort-release-profiles.json`

## Profiles

| Profile | Server stage | Purpose | Reviewer routes | Public marketplace | External providers |
|---|---|---|---:|---:|---|
| `development` | `development` | Local engineering with fail-closed defaults | Off | Off | Off |
| `automated_test` | `internal_test` | Deterministic unit/widget/integration tests | Off | Off | Off |
| `reviewer_demo` | `closed_test` | Isolated Google Play reviewer/demo build | On | Off | Google Auth only |
| `closed_test` | `closed_test` | Authenticated closed-pilot build without demo routes | Off | Off | Google Auth only |
| `production_candidate` | `production_pilot` | Restricted candidate after real push/crash verification | Off | Off | Push and crash required |
| `production` | `production_public` | Public target after every external gate | Off | Required | Identity, push, crash, legal and server approval required |

The production row describes the required target. It is intentionally not
buildable today: production activation remains false, legal versions are
owner-approval-required, the remote server remains `closed_test`, and real
identity/push/crash providers are not verified.

## Defined Controls

Every profile defines:

- hosted Supabase public configuration requirement
- Google Auth and the approved PKCE callback
- public marketplace
- marketplace payments and provider mode
- identity verification
- remote push
- crash reporting
- external Support AI and deterministic fallback
- ads and IAP
- reviewer mode
- production activation approval
- internal support/admin routes
- Terms, Privacy, Community Guidelines, and Safety Rules versions
- minimum supported app version
- maintenance mode
- debug endpoint availability

Supabase URL and anon/publishable key are supplied at build time and are not
stored in this matrix. Privileged credentials are forbidden from the matrix and
from Dart defines.

## Enforcement

`scripts/validate-release-profile.mjs` validates the complete matrix, exact
profile set, required keys, forbidden secret-like keys, reviewer isolation,
public activation scope, deterministic support, payment consistency, and
release exclusions for ads, IAP, and debug endpoints.

`flutter_mort/lib/core/config/release_profile.dart` validates the compiled
configuration again at startup. `AppConfig.assertValidReleaseConfiguration()`
stops invalid non-development builds before Supabase initialization.

`scripts/validate-release-profile-server.mjs` calls the public,
server-authoritative `get_release_mode_status` RPC. Closed/reviewer builds are
rejected if the server is public. Production-candidate and production builds
are rejected unless the server is on the exact matching stage. Production also
requires server-confirmed public marketplace and real identity collection.

`scripts/android-release-profile-common.ps1` consumes the matrix, rejects
disagreements between wrapper arguments and the selected profile, verifies the
MORT project and upload certificate, blocks privileged `.env.local` values,
checks the server gate, denies secret-like Dart defines, and deletes the
temporary public define file after the build.

## Build Entry Points

- Reviewer/demo AAB: `powershell -ExecutionPolicy Bypass -File .\scripts\build-closed-test-aab.ps1`
- Reviewer/demo APK: `powershell -ExecutionPolicy Bypass -File .\scripts\build-closed-test-apk.ps1`
- Standard closed-test AAB: `powershell -ExecutionPolicy Bypass -File .\scripts\build-standard-closed-test-aab.ps1`
- Standard closed-test APK: `powershell -ExecutionPolicy Bypass -File .\scripts\build-standard-closed-test-apk.ps1`
- Production candidate: `powershell -ExecutionPolicy Bypass -File .\scripts\build-production-pilot-aab.ps1`
- Public production: remains hard blocked by `build-production-public-aab.ps1`

The historical closed-test wrapper continues to select `reviewer_demo` so the
existing 0.9.11 Play-review workflow is not silently changed. The new standard
closed-test wrappers explicitly compile without reviewer routes.

## Safe Diagnostics

Authenticated users can open Settings > Release diagnostics. The screen shows
only profile names, enabled/disabled capability states, legal version labels,
minimum version, and server gate states. It never shows Supabase URLs, public
keys, credentials, tokens, callback payloads, user data, or private endpoints.

