# MORT Multi-Signal Trust RLS Matrix

Hosted catalog audit: 2026-07-18, project `rakjydmgwwgtdislanbt`.

## Tables

All 18 new public tables have RLS enabled. Each has one deliberately narrow SELECT policy; mutations occur through caller-bound RPCs or the service role.

| Tables | User-readable scope | Direct client mutation |
| --- | --- | --- |
| `account_trust_profiles`, `account_security_preferences`, `account_trust_appeals` | own row(s) | denied; checked RPC only |
| `trust_signal_events` | own minimized signals | denied; server/reviewer only |
| `sensitive_action_reauth_events` | own minimized audit | denied; service-only writer |
| `school_domains`, `official_source_allowlist` | approved minimized directory rows | denied |
| `partner_organizations`, `partner_domains`, `partner_programs` | approved same-environment summaries | denied; reviewer RPC only |
| `partner_invite_codes`, `partner_audit_events` | no raw code or broad audit access | denied; restricted RPC only |
| `partner_memberships`, `partner_verification_requests` | own relationship/request | denied; checked RPC only |
| `business_registry_checks`, `business_representative_claims` | own request/claim | denied; checked RPC only |
| `digital_credential_sessions`, `digital_credential_events` | own minimized status | denied; service-only writer |

Private `trust_policy_versions` has RLS with no policy and is intentionally deny-by-default outside privileged functions.

## RPC grants

All 21 new/redefined trust RPCs use `SECURITY DEFINER`, `SET search_path = ''`, schema-qualified references, and explicit grants. `anon` has EXECUTE on none.

- Authenticated caller-bound: trust profile, public badges, eligibility, device preference, visibility, affiliation, partner redemption, business requests, appeal, restricted admin queue/review operations.
- Service role only: `create_digital_credential_session`, `process_digital_credential_result`, `record_server_reauthentication_event`.
- Admin functions derive actor from `auth.uid()`, require specialized role, access reason, and case ID, and emit audit records.

## Negative verification

Hosted QA rejected self-level changes, self-approval, environment/provider/status forgery, raw table writes, unknown public sources, sandbox promotion, unsigned/expired/replayed credentials, unrelated user reads, ordinary-admin identity decisions, public contact/school/residence disclosure, and guardian-derived identity. The comprehensive remote isolation suite passed all 30 checks, including private Storage boundaries.

The legacy `qa-rls.mjs` deliberately refused the hosted target because it is local-only. The hosted equivalent coverage came from `qa-complete-multi-user-isolation.mjs`, `qa-flutter-data-isolation.mjs`, the 12 trust suites, and targeted incident/address/verification suites.
