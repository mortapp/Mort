# Issue #70 — Guardian application-reader review package

**Recommendation: ready for independent code/security review; not approved for production application.** PR #71 remains draft. Production has not been modified.

## Vulnerability and narrow fix

The production `public.get_my_job_applications(uuid)` row-selection predicate admits a linked Guardian when the relationship is active and both consent timestamps exist. The separate `guardian_id` disclosure branch also requires a Guardian profile, active account, DOB age 18+, and confirmed Auth email. Before the proposed fix, a linked-but-ineligible Guardian could therefore receive the application row while `guardian_id` was masked. Masking the ID did not deny access to the application data.

The focused migration `supabase/production-baseline-migrations/20261104182914_issue_70_guardian_application_reader_scope.sql` exact-source-guards both the account gate and Guardian row-scope expression, then adds the same role, account, age/DOB, and confirmed-email checks to Guardian row selection. It keeps the active-link and dual-consent checks. It does not change tables, RLS policies, data, or grants; it does not add an administrator-wide bypass. Applicant self-access and the job poster's existing application access remain. Poster responses continue to mask the Guardian ID; a valid connected adult Guardian and applicant retain the intended ID field.

## Authorization and database behavior checked

- `SECURITY DEFINER`, empty `search_path`, function identity/signature, function grants, and direct `job_applications` table grants are checked in pgTAP. The migration refuses to proceed if the function's definer/search-path contract differs or either source anchor occurs other than exactly once.
- `job_applications` and `guardian_links` use RLS; direct `SELECT` is denied to `anon` and `authenticated`. The reader enforces its own row scope. The migration does not broaden RLS.
- `CREATE OR REPLACE` changes only the reviewed function body and preserves the existing object identity/owner/ACL/configuration. It adds no data writes. Review the full migration against the exact deployment source before approval.
- Rollback should restore the captured pre-migration function definition with a reviewed reverse migration. Do not edit history or run an ad hoc replacement. Confirm migration runner transaction behavior and capture the function definition/grants immediately before deployment.

## Evidence at current PR head

Current remote PR head: `6a9d40ddc8919900547b4b0033b01575e386791a`. Exact-head CI run [42133541731](https://github.com/mortapp/Mort/actions/runs/42133541731) completed successfully: seven jobs passed, including the production-baseline migration regression and Flutter CI; `stripe-hosted-regression` and `stripe-provider-e2e` were skipped by workflow conditions. The workflow reported 73/73 production migration sources verified, the 35-assertion Guardian-reader pgTAP suite passed on a clean local production-migration replay, 76 regression scripts passed, Flutter 615 passed/2 skipped, and Deno 26 passed. An Android device-test APK was produced; this is not a signed release AAB.

On 2026-11-07, the working tree's focused regression was expanded to **49 pgTAP assertions** and passed against a freshly replayed local PostgreSQL 17 baseline built from all 73 SHA-256-verified production migration sources through `20261102113314`. The test applied the Issue #70 proposal and fixtures in a rollback transaction; the pre/post baseline fingerprint matched exactly (`170006|73|20261102113314|94a1b987774f994019ba6269b9abeb16|false|783f373cd4ad853ee690eae22abc6289`). Added cases exercise the real teen `unlink_guardian` RPC, revoked Guardian denial through both application-reader and status-update paths, and a single captured nested withdrawal response: applicant ID is retained, poster ID is masked. The runner also checks the status-update RPC's existing `SECURITY DEFINER`, empty `search_path`, and grants. These are local working-tree results, not CI evidence for remote PR head `6a9d40d`; the changes have not been pushed.

Local mocked API harness tests passed 17/17; they validate harness behavior only. The isolated QA project's read-only inventory had zero users/profiles/Guardian links/applications/jobs/Storage objects, so there is no authorized authenticated API fixture and no hosted Guardian API result. No authenticated production call was used as a substitute.

## Adversarial cases and remaining limitations

The 49 local pgTAP assertions cover eligible adult Guardian with valid active link/consent and ID, unrelated teen denial, applicant self-access/ID, poster access with masked ID, unconfirmed email, inactive account, wrong role, missing DOB, each missing consent, pending/revoked link, no broad admin bypass, grants/RLS, schema rejection of an underage Guardian role, supported Guardian unlink, and the nested status-update response. The remote PR head's CI still reports the earlier 35-assertion suite until the working-tree changes are published and CI reruns.

The schema prevents assigning `guardian` to the synthetic underage profile (`23514`, `MORT_MINOR_ROLE_REQUIRED`). Therefore the suite cannot create a valid underage-Guardian database state to invoke the reader as that impossible state; it tests the account receives no rows while pending and separately verifies that the database rejects the invalid role assignment. This is constraint coverage, not an RPC execution under an impossible state.

Unverified until legitimate isolated QA fixtures exist: authenticated PostgREST behavior for each persona, administrator behavior through the actual API, service-role call behavior, and complete end-to-end app compatibility. Do not claim them passed from pgTAP or mocked tests. The QA project requires approved legal/product test language, controlled test inboxes and authorized operator, any required provider sandbox evidence, approved staff reviewer provisioning, supported Guardian consent/revocation, and a synthetic application created through normal flows.

## Reviewer checklist

1. Compare migration anchors to the latest production function definition and confirm one match per anchor.
2. Review the three independently enforced Guardian eligibility predicates (entry gate, row selection, ID disclosure) for semantic parity.
3. Confirm expected outer behavior for ineligible Guardian is zero rows, not a row with masked ID.
4. Inspect deployment transaction/rollback procedure and verify exact production grants and owner remain unchanged.
5. Keep merge/application blocked until review and, where required, authorized isolated authenticated API tests are complete.
