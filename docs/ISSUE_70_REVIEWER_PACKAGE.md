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

Current tested code head: `4935b24ce91081497fc36aaa261ead1a99b8820f`. Exact-head CI run [42556619855](https://github.com/mortapp/Mort/actions/runs/42556619855) completed successfully: seven jobs passed, including the production-baseline Guardian regression, Flutter CI, and Android device-test APK packaging; `stripe-hosted-regression` and `stripe-provider-e2e` were skipped by workflow conditions. CI applied the 73-source production baseline through `20261102113314` and passed all 51 Guardian-reader pgTAP assertions; the before/after baseline fingerprint was unchanged (`170011|73|20261102113314|94a1b987774f994019ba6269b9abeb16|true|783f373cd4ad853ee690eae22abc6289`). The Android artifact is a device-test APK, not a signed release AAB. An earlier run on the prior test change emitted all 51 assertions but failed the wrapper's stale hard-coded 49-count check; commit `4935b24` made the wrapper derive its expected count from the pgTAP file, and this exact-head run passed.

On 2026-11-07, the focused regression passed **49 pgTAP assertions** against a freshly replayed local PostgreSQL 17 baseline built from all 73 SHA-256-verified production migration sources through `20261102113314`. The test applied the Issue #70 proposal and fixtures in a rollback transaction; the pre/post local baseline fingerprint matched exactly (`170006|73|20261102113314|94a1b987774f994019ba6269b9abeb16|false|783f373cd4ad853ee690eae22abc6289`). Later CI on exact head `4935b24` passed the expanded 51-assertion suite and kept the baseline unchanged. Added cases exercise the real teen `unlink_guardian` RPC, revoked Guardian denial through both application-reader and status-update paths, a single captured nested withdrawal response (applicant ID retained, poster ID masked), and administrator denial in both the reader and nested status response. The runner also checks the status-update RPC's existing `SECURITY DEFINER`, empty `search_path`, and grants.

Local mocked API harness tests passed 17/17; they validate harness behavior only. The isolated QA project's read-only inventory had zero users/profiles/Guardian links/applications/jobs/Storage objects, so there is no authorized authenticated API fixture and no hosted Guardian API result. No authenticated production call was used as a substitute.

## Adversarial cases and remaining limitations

The 51 CI pgTAP assertions cover eligible adult Guardian with valid active link/consent and ID, unrelated teen denial, applicant self-access/ID, poster access with masked ID, unconfirmed email, inactive account, wrong role, missing DOB, each missing consent, pending/revoked link, administrator denial through both response paths, grants/RLS, schema rejection of an underage Guardian role, supported Guardian unlink, and the nested status-update response.

The schema prevents assigning `guardian` to the synthetic underage profile (`23514`, `MORT_MINOR_ROLE_REQUIRED`). Therefore the suite cannot create a valid underage-Guardian database state to invoke the reader as that impossible state; it tests the account receives no rows while pending and separately verifies that the database rejects the invalid role assignment. This is constraint coverage, not an RPC execution under an impossible state.

Unverified until legitimate isolated QA fixtures exist: authenticated PostgREST behavior for each persona, administrator behavior through the actual API, service-role call behavior, and complete end-to-end app compatibility. Do not claim them passed from pgTAP or mocked tests. The QA project requires approved legal/product test language, controlled test inboxes and authorized operator, any required provider sandbox evidence, approved staff reviewer provisioning, supported Guardian consent/revocation, and a synthetic application created through normal flows.

## Reviewer checklist

1. Compare migration anchors to the latest production function definition and confirm one match per anchor.
2. Review the three independently enforced Guardian eligibility predicates (entry gate, row selection, ID disclosure) for semantic parity.
3. Confirm expected outer behavior for ineligible Guardian is zero rows, not a row with masked ID.
4. Inspect deployment transaction/rollback procedure and verify exact production grants and owner remain unchanged.
5. Keep merge/application blocked until review and, where required, authorized isolated authenticated API tests are complete.
