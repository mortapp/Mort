# MORT backend repair deployment record and verification checklist

## Deployment record

The repairs were applied to production using the connected Supabase migration interface after explicit authorization and read-only schema, function, provider, ledger, and storage-policy preflight checks.

| Environment | Project ref | Applied migration |
|---|---|---|
| Production (`mort p`) | `jxbnrkasktbhtiujkhay` | `20261114223346_mort_complete_repair_bundle` |
| Production (`mort p`) | `jxbnrkasktbhtiujkhay` | `20261114223714_ignore_legacy_self_reported_age_cases` |
| Dedicated test (`mort-p-backend-test`) | `ckcxakhxqlkhppsxxjhv` | Matching repair migrations plus test parity/grant hardening |

The first production attempt failed its exact-source guard and rolled back without persistent changes. The corrected bundle and follow-up migration succeeded. These migrations changed function definitions/grants and provider allowlist configuration; they did not create Auth users, update/delete existing profile, verification, or application rows, or change RLS/storage policies.

## Included repairs

1. Onboarding no longer inserts an unusable `self_reported` age case. The evidence RPC accepts age evidence, scopes duplicate checks by verification type, and ignores legacy self-reported age rows for duplicate and rate-limit checks.
2. `mort_staff_review` is enabled for age, school-ID, and identity. Existing private evidence storage and production object policies support owner upload and staff retrieval.
3. Staff review records the provider result before the separate verification decision. Verification approval auto-queues role activation when eligibility is met. Teen eligibility requires verified age and school-ID cases from an enabled provider/type pair, plus confirmed approved school email; adult eligibility requires verified identity from an enabled provider/type pair. Staff activation uses the pending role-request approval routine rather than directly changing a profile.
4. `update_my_job_application_status_v3` is installed against production's live `job_applications` schema and private mutation ledger. It retains authorization, row locking, expected-timestamp checks, and idempotent request replay. Flutter, iOS, and the shared QA helper now call this deployed RPC name.
5. `admin_set_account_status_v2` supports staff-authorized activation on the live `profiles` schema only when an eligible pending role request exists. This repair does not implement suspension/expiry; unsupported status requests return a failure rather than claiming success.

## Post-deployment checks

Production migration history records both versions above. The age, school-ID, and identity staff-review pairs are enabled. Relevant routines have `SECURITY DEFINER` with an empty search path; the private eligibility/queue helpers are not executable by `authenticated`, while intended public RPCs remain callable. Production has the expected job-application schema and the mutation-ledger unique key `(user_id, client_request_id)`. The private `verification-evidence` bucket and owner-upload/staff-read policies were present before deployment.

An aggregate-only production check found six legacy `self_reported` age rows: two pending, three verified, and one rejected. Their records were deliberately left untouched. The follow-up migration ensures pending legacy rows cannot block real uploads and ensures even a legacy row marked verified cannot satisfy activation because `self_reported` is not an enabled provider/type pair.

The dedicated test project was also updated and verified for the provider gate, duplicate/rate-limit exclusions, confirmed-school-email eligibility gate, and private queue grant policy. No SQL-created test users or manual profile/case edits were used.

## Remaining validation / release checklist

- Supabase CLI 2.109.0 is available through `npx`, but this checkout is not linked/authenticated, so `supabase migration list --linked` could not be run. Remote migration history was verified via Supabase MCP. Local Supabase database tests could not start because Docker is unavailable.
- Dart/Flutter and Swift toolchains are not installed. The Flutter/iOS source contract tests and format/analyze suites therefore remain unexecuted. `git diff --check` and `node --check scripts/feature-qa-helpers.mjs` passed.
- No fresh Auth users were created. The full teen/adult signup → verification → activation → job application → acceptance → messaging journey remains outstanding because an authorized Auth signup/confirmation method and staff test account were not available in this session. No SQL-created users or manual database intervention were used.
- Before release, run formatter/analyzer/tests in a Flutter/Swift environment, enable evidence upload only in the intended app configuration, and run the full Auth-driven journey with fresh accounts and staff review. Teen age and school-ID submissions are separate. Adult direct ID upload remains deliberately unavailable in the app; adult identity verification requires the approved provider/review path.
- Verify unsupported staff status requests remain visible as errors, then exercise fresh teen/adult eligibility, application replay/conflict behavior, acceptance, and messaging end to end.

## Rollback / stop guidance

If post-deployment checks reveal a defect, stop release and apply a reviewed forward-fix migration. Do not manually flip profile/account status, verification cases, role requests, or application status. Use the approved backup/recovery procedure if rollback is needed; preserve audit and provider-evidence records.
