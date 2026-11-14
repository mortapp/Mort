# Production-baseline-only migrations

SQL in this directory targets the recovered production migration baseline. It is intentionally outside `supabase/migrations`, which is the separate generic/local chain used by the Stripe and application regression suite.

`20261104182914_issue_70_guardian_application_reader_scope.sql` depends on the exact production `get_my_job_applications(uuid)` definition introduced in production migration `20261028034447_flutter_application_backend_contract`. The archived source is SHA-256 verified by `supabase-production/migration-history.json` in pinned archive commit `05325088dcbb117e5d144828bc613fef5b47777f`.

The baseline archive's SQL file for `20261102040639_restrict_job_application_direct_select` does not match its manifest hash. A read-only query of the production migration ledger recovered its exact `statements` payload: its MD5 is `806bed46eb996e0fed98e87ea9a03f3c`, and the recovered source SHA-256 `d816da845f1c71643a0d577b9629b98b3e8db9c0ed4c3667e8a4e7db7a60cf6d` matches the original manifest. The mismatched archived file and manifest remain untouched. A provenance record and recovered source are in `supabase/production-baseline-recovery/`; the test runner uses the recovered payload only for that version.

Run `scripts/run-issue-70-production-baseline.ps1` to construct a disposable local PostgreSQL baseline from those 73 source migrations, verify every source hash, run a clean migration replay, and then run the focused 33-assertion rollback-only test. The existing `scripts/run-mort-stripe-regression.ps1` CI path invokes this baseline before starting its generic local stack, avoiding port conflicts and keeping the divergent migration chains isolated. It requires Docker. The runner uses no hosted database credentials and never connects to Supabase production or hosted QA. Authenticated PostgREST sessions are not covered by this SQL regression.

Do not move these files into the generic migration chain or apply them to a hosted database without independent review and explicit deployment approval.

## Message safety scanner (issue #49)

`20261113150000_message_safety_scanner.sql`, `20261113170000_message_safety_hardening.sql` and `20261113180000_message_safety_rls.sql` target the production baseline schema (`messages.conversation_id`, `moderation_status`, `moderation_reason`, `public.mort_send_message`). The generic local chain has a different messages schema (`thread_id`, `scanner_status`, `message_safety_evidence`) and already ships its own `send_safe_message` classifier, so these files must not be placed in `supabase/migrations`. Their executable contract is `supabase/production-baseline-tests/message_safety_scanner.test.sql` and `message_safety_normalization.test.sql`, which run only against a disposable baseline-shaped database. Apply order is the filename order. Do not apply to a hosted database without independent review and explicit deployment approval.
