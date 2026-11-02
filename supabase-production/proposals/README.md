# Production backend proposals — NOT APPLIED

These files are review candidates only. They are deliberately stored outside `../migrations/` and must not be moved into the applied chain until an isolated production-equivalent PostgreSQL 17 clone is available and the full SQL, pgTAP, and two-session concurrency suites pass.

The distance-band, safety-report moderation, and Guardian application-decision proposals were copied from `codex/mort-backend-guardian-moderation-20261101`. They have not been applied to production. The Guardian visibility proposal needs the additional direct-table privilege protection in `20261102010500_restrict_job_application_direct_select.sql`: row-level policies do not hide individual columns, and the current table-level SELECT grant otherwise exposes `guardian_id` to posters of visible applications.

Do not run these SQL files in production from the Supabase SQL editor or CLI.

## Guardian identifier response mask

20261102080000_guardian_id_response_mask.sql is a narrow, unapplied proposal for the confirmed production RPC leak. It changes only the guardian_id JSON expression in public.get_my_job_applications(uuid): applicants and currently linked, consenting, active adult Guardians retain the identifier; posters and all other callers receive JSON null. It does not change which application rows the RPC returns, the function's grants, RLS, or stored data.

The migration was replayed transactionally against the isolated project's function definition after temporarily restoring the unmasked expression; SQL compilation passed; exact definition comparison confirmed only the proposed JSON field changes, while function owner, ACLs, SECURITY DEFINER, empty search_path, volatility, return type, JSON envelope, application RLS policies, authenticated table/column denial, and service_role SELECT remained unchanged, and the transaction was rolled back. The isolated database remained unchanged.

../../scripts/qa-guardian-id-rpc-privacy.mjs is an API-level regression harness for synthetic isolated accounts. It requires test-only credentials and fixture IDs through environment variables and refuses production or deleted-project URLs. The harness currently requires pre-provisioned isolated Auth accounts and an application fixture; those QA_* values are not configured. The workstation QA helper is wired to production and an older schema, so it cannot safely provision these fixtures for the isolated project. Direct fixture attempts hit the isolated DOB and three-track verification guards and rolled back. The harness fails closed before network access when these inputs are absent. Separate isolated RPC role-matrix execution is recorded in the MORT 2.0 execution checklist. Production still exposes the identifier and is not fixed.
