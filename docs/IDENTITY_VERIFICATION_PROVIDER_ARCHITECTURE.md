# Identity Verification Provider Architecture

## Current Status

- Hosted project: `rakjydmgwwgtdislanbt`
- Hosted mode: `disabled`
- Trust/safety architecture: implemented
- Production identity provider: not connected
- Real identity collection: disabled
- Sandbox verification: isolated QA simulation only
- Guardian Mode: optional
- Public marketplace: closed wherever production verification is required

This is a provider-safe foundation, not a production verification system.

## Authority Model

The private `identity_verification_control` row is the server authority. `anon` and `authenticated` have no access. The mode can be `disabled`, `sandbox`, or `production`.

Production is constrained to fail closed unless all readiness fields are true: provider configuration, production provider environment, signed webhook, approved workflow, retention policy, legal approval, operational readiness, and trained reviewers. Client code and ordinary admin RPCs cannot satisfy or bypass these controls.

## Client Contract

Flutter and Swift expose the same conceptual contract:

- `IdentityVerificationProvider`
- `VerificationSession`
- `VerificationResult`
- `VerificationEnvironment`
- `VerificationEvidenceType`
- `VerificationDecision`
- `VerificationFailureReason`

`DisabledVerificationProvider` always refuses session creation. `SandboxVerificationProvider` accepts only a server-returned sandbox test session and asserts `test_mode=true`. `ProductionVerificationProvider` is an interface only; the unavailable implementation fails closed until a vendor is approved.

## Environment Separation

Every identity verification has an `environment` of `sandbox` or `production`. Provider, provider reference, decision source, level, status, timestamps, and expiry are server-controlled.

Sandbox simulations:

- require an explicitly marked QA account
- use `provider=mort_sandbox`
- use `decision_source=sandbox_simulation`
- create no identity document
- cannot grant production eligibility or a production badge
- remain isolated from ordinary marketplace feeds

Production verification requires a current, nonexpired production record and an authorized decision source. Existing legacy/manual records were quarantined as sandbox and marked production-ineligible.

## Decision Sources

The schema recognizes `provider_webhook` and a future `approved_manual_exception` as possible production sources. The hosted project has no approved manual-exception process, no configured production provider, and no production verification rows.

The deployed vendor-neutral webhook is the only prepared provider path. Its database RPC is executable by `service_role` only. A local image, table edit, client RPC, sandbox result, ordinary admin action, or uploaded-only record cannot produce production approval.

## Data Exposure

Own-status payloads are minimized. Public trust badges are authenticated-only and derive from current production results. They expose no document path, school identifier, government identifier, selfie metadata, student number, or residential address.

