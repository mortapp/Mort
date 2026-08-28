# MORT Trust Level Policy

## Level definitions

| Level | Precise label | Required authoritative signal | Current availability |
| --- | --- | --- | --- |
| 0 | Basic account | Supabase account and confirmed email | Available |
| 1 | Account secured | Contact and account-security controls defined by policy | Partially available; phone and passkeys are disabled |
| 2 | Affiliation verified | Approved school/program affiliation or reviewed business registry signal | Sandbox/controlled workflows only |
| 3 | Government digital ID verified | Signed current credential, expected issuer/type, nonce, replay protection, age result, account binding | Disabled |
| 4 | Provider identity verified | Approved provider authenticity, ownership/liveness, age and signed production result | No provider connected |
| 5 | Enhanced adult screening | Consented compliant screening with disputes, adverse-action handling, expiry and re-screening | Disabled |

No level is a numerical safety score. Public UI uses the precise indicator labels returned by the server.

## Active hosted policy

The active policy is `zero-budget-hosted-closed`:

- `production_marketplace_enabled = false`
- ordinary production users cannot participate in marketplace workflows
- isolated test accounts may use current sandbox identity records for QA
- real identity-document collection is disabled
- provider identity, Apple Wallet, Android digital credentials, and passkeys are disabled
- phone verification is unavailable in the hosted Auth configuration
- Guardian Mode is optional

## Eligibility

`get_marketplace_trust_eligibility(action, job_id)` returns `allowed`, required/current level, missing requirements, reason codes, retry timing, support route, policy version, environment state, and Guardian Mode status. Account restriction always overrides level. Sandbox signals never count as production evidence.

Future pilot activation requires a new immutable policy version and documented legal, safety, staffing, participant, region, and provider approvals. Existing policy rows remain auditable.
