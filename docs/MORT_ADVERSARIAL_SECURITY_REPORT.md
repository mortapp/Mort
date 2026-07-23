# MORT Adversarial Security Report

Audit date: 2026-07-22

## Nine Categories

1. Secrets: source and binary scans pass; public-only ignored local env validated; no Git history exists locally.
2. Database: RLS/Storage direct attacks pass; schema error fixed; advisor warnings documented.
3. Authentication/authorization: Supabase Auth only, caller-bound RPCs, role and cross-user forgery tests pass.
4. Rate limits: support, signed media, AI reservation, and server-owned counters tested.
5. Payments: price/destination/state remain server-owned; signatures, replay, idempotency, refund, transfer, and role separation tested.
6. Mobile: secure storage, no cleartext, minimized permissions, release signing, no debug certificate, deep-link route guards, and artifact scans verified. Root/jailbreak resistance and physical-device tests remain.
7. AI: provider key server-only, external mode off, cost reservation, prompt-injection diversion, high-stakes boundaries, and human fallback tested.
8. Deployment: closed-test flags, private backend, signed/obfuscated Android artifacts, npm audit, Expo Doctor, and clean-package exclusions verified. Production monitoring is absent.
9. Data/input: parameterized RPCs, UUID/text/file constraints, canonical paths, MIME/size limits, state/idempotency checks, and hostile direct API tests verified.

## Defects Found and Fixed

- `avatar-url` reused the `authorization` identifier and failed worker execution. Identifier scopes were corrected, QA diagnostics improved, function redeployed, and 26-script regression rerun.
- Adult cancellation used an untyped text `CASE` for `application_status`. A forward migration added enum casts; remote lint and regression pass.
- Expo reference resolved vulnerable `uuid@7.0.3`. A pnpm override installed the patched line; audit, typecheck, lint, Doctor, and web export pass.
- Sensitive-file scan rejected required public-only local config. It now permits only the exact three public Expo variables when `.env.local` is Git-ignored; archives still reject env files.
- Android app lint found five manifest references to Google Mobile Ads classes even though the SDK is intentionally absent. The obsolete merger-removal stubs were removed, generated Windows property paths were normalized by a repeatable lint wrapper, and MORT app-module release lint passed.
- PowerShell treated Java compiler warnings on stderr as terminating errors despite successful native exit codes. Both signed build scripts now preserve the real Flutter exit code and fail only when it is nonzero.
- Arrival-handshake QA depended on the workstation clock and failed after the closed-pilot evening cutoff. The safety policy was correct; the synthetic fixture now selects a daytime test timezone, reports post-publish policy state, and passes in the full remote regression.

## Remaining Risk

No known unresolved Critical or High code finding was observed. Remaining launch-blocking risk includes unverified provider actions, no production monitoring/alert exercise, no independent penetration test, no physical-device authenticated matrix, no iOS/TestFlight evidence, warning-level Supabase advisor surface, performance debt, and incomplete qualified legal/privacy/teen-safety review.
