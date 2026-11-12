# Supabase Setup and Environment Boundaries

## Current projects

- Production: `jxbnrkasktbhtiujkhay` (`https://jxbnrkasktbhtiujkhay.supabase.co`).
- QA: `ckcxakhxqlkhppsxxjhv` (`https://ckcxakhxqlkhppsxxjhv.supabase.co`).
- Retired/deleted: `rakjydmgwwgtdislanbt`. Do not link, reconnect, restore, or deploy to this project.

Use only public anon/publishable keys in client apps. Never put a service-role key, database password, Supabase access token, webhook secret, or provider secret in Flutter, iOS, Android, Expo, web bundles, or source control.

## Migration sources

This repository contains more than one schema lineage:

- `supabase-production/migrations` is the production migration history.
- `supabase/migrations` includes the legacy/reference schema used by local regression and compatibility tests.

Do not run the root legacy migration directory against production. Do not use `supabase db reset` against production. Do not apply broad compatibility SQL to production.

## Safe workflow

1. Make schema changes in a dedicated branch.
2. Replay the exact production migration sequence in an isolated database/QA environment.
3. Run SQL compilation, RLS/policy checks, pgTAP, authenticated positive/negative tests, and relevant app integration tests.
4. Verify a current production backup artifact and isolated restore path before a production schema change.
5. Review the exact SQL diff and confirm the target project is `jxbnrkasktbhtiujkhay`.
6. Apply only the reviewed migration through the production migration workflow after explicit release approval.
7. Re-run advisors and verify release controls remain closed.

For QA validation, link only to `ckcxakhxqlkhppsxxjhv` and use QA-scoped credentials:

```bash
supabase login
supabase link --project-ref ckcxakhxqlkhppsxxjhv
```

Production linking and migration application are separate, explicitly approved operations. A passing local test is not permission to apply SQL to production.

## Edge Function secrets

Store function secrets in the target project's server-side secret store. Use QA-only secrets for QA functions. Never copy production service-role keys, DB passwords, access tokens, Stripe live secrets, or Apple private keys into QA or source code.

## First Admin

Create a real user through Supabase Auth, complete profile setup, and use a trusted, reviewed admin bootstrap procedure. Admin role must never be self-selected in client onboarding. Do not run the historical example SQL below without checking the current production schema and authorization controls.

## Security review

The November 3–4, 2026 production review is tracked in `docs/MORT_DEPLOYED_SUPABASE_AUDIT.md` and GitHub issue #49. Known open items include RLS coverage review, SECURITY DEFINER authorization review, leaked-password protection status, and the trusted verification-provider evidence gate. Re-run the advisor before release; historical July 2026 counts in older reports are not current evidence.

The leaked-password protection setting was found disabled in the November audit. The old project's plan status does not establish the current production project's plan capability; see `docs/ENABLE_LEAKED_PASSWORD_PROTECTION.md`.
