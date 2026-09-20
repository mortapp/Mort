# MORT Verify access matrix

Last audited: 2026-09-20

| Surface | Anonymous | Authenticated teen | Verification reviewer | Service role |
|---|---|---|---|---|
| `private.mort_verify_*` tables | No direct access | No direct access | No direct access | Backend/service operations only |
| `get_mort_verify_status()` | No | Own status only | Own status if called as a user | Not required |
| `start_mort_verify_teen_session(text)` | No | Own teen session; control-gated | Same user-scoped contract | Not required |
| `submit_mort_verify_session(uuid)` | No | Own live session only | Same user-scoped contract | Not required |
| `claim_mort_verify_review(text)` | No | Denied by live safety-role check | Allowed only with current reviewer/senior role | Not required |
| `admin_mort_verify_decide(...)` | No | Denied by live safety-role check | Active assignment required; senior role required for manual age exception | Not required |
| `service_mort_verify_*()` | No | No | No direct execute | Yes |
| Canonical Storage INSERT | No | Own user/session path only; live allowed session required | No special client upload privilege | Yes |
| Canonical Storage SELECT | No policy | No policy | No direct bucket policy | Service-generated signed URL after live role + assignment check |
| Canonical Storage DELETE | No | Only own unregistered upload | No | Yes |
| Canonical retention RPCs | No | No | No | Yes |
| Legacy `teen-school-id` Storage | No | Policies removed | Policies removed | Retention cleanup only |
| Legacy `teen_verification_*` client/reviewer RPCs | No | Execute revoked | Execute revoked | Client/reviewer execute revoked; retention RPCs remain service-only |

## Security-definer rules

Public security-definer entrypoints set `search_path = ''`, bind requests to `auth.uid()` where user-facing, and perform explicit live role checks where reviewer-facing. Service RPCs require `auth.jwt()->>'role' = 'service_role'` and are not executable by `anon` or `authenticated`.

## Raw evidence rule

There is intentionally no general authenticated SELECT policy for raw canonical school-ID evidence. Reviewer access is mediated by the `mort-verify` Edge Function, a current role check, a live assignment, and a short-lived signed URL.
