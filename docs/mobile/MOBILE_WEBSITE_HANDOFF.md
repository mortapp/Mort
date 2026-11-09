# Mobile and Website Contract Handoff

Updated: 2026-11-08. Website implementation remains owned by VS Code Desktop; this file records mobile/backend contracts only.

## Authentication and project targeting

- The authoritative Supabase project is `jxbnrkasktbhtiujkhay`. Production mobile builds must resolve `AppConfig` and the secure-session key to this project.
- Native OAuth uses PKCE with `com.mortapp.mobile://app/auth-callback`. The website must use its own exact, allowlisted HTTPS redirect on `mortapp.org`; do not reuse the native deep link.
- Mobile no longer restores sessions saved under a previous backend namespace. Existing installs may need to sign in again after the project-target correction.

## Roles, privacy, and API contracts

- Teen, adult, Guardian, and admin screens are navigation conveniences. Authorization must remain enforced by server RPCs and RLS.
- Mobile reads job discovery through `list_open_jobs_page`, manages jobs through `manage_job_v2`, reads applications through `get_my_job_applications`, and changes application status through `update_application_status_v3`.
- Adult website job posting must use `save_job_draft_or_publish` with server-derived ownership and an idempotency key. Do not restore direct `jobs` INSERT/UPDATE or `job_applications` reads in website clients.
- Guardian application access is limited by the server-side eligibility/consent contract. PR #71 proposes correcting row selection to match Guardian-ID disclosure; it remains unmerged and hosted authenticated acceptance is outstanding. The website must not treat a masked Guardian ID as permission to expose the application row.
- Marketplace publishing, real document collection, payments, Stripe, and AI remain disabled in prelaunch.

## Website coordination and evidence

- Current website PRs at handoff time: [#15](https://github.com/mortapp/mort-web/pull/15) is draft; [#16](https://github.com/mortapp/mort-web/pull/16) is open and not draft. Recheck exact heads and CI before relying on these states.
- Required website acceptance includes authorized adult posting, teen discovery/application, Guardian scope, blocking/reporting, recovery, offline/retry behavior, and cross-account denial with approved synthetic users.
- This mobile/backend work made no changes to `mortapp/mort-web`, its branches, or Vercel.
