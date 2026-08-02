# MORT Identity Verification Owner Action Plan

Updated: 2026-07-30

Do not put credentials in Flutter, `.env.local`, source control, chat, build
artifacts, or screenshots.

## Provider And Legal Approval

1. Give counsel and the provider a written description of MORT: US local
   physical-services marketplace, adults post work, users ages 13-17 may apply,
   identity verification is adult-only, Guardian Mode is optional, and public
   access is closed during the pilot.
2. Obtain written provider confirmation that the exact trust/safety use case is
   allowed and is not an unsupported employment/FCRA or minor-verification use.
3. Approve the privacy notice, consent copy, biometric/document disclosures,
   data processor terms, retention period, deletion workflow, and user
   alternative/support path.
4. Decide whether business verification requires KYB, representative identity,
   beneficial-owner checks, or only an individual poster flow.
5. Select the provider and approve cost. Do not activate a paid plan from this
   repository task.

## Sandbox Configuration

1. Create a separate provider sandbox account/workflow.
2. Configure an adult-only hosted capture flow and disable unnecessary fields.
3. Configure the exact redirect/handoff host and webhook endpoint.
4. Store provider API and webhook secrets only in Supabase Edge Function
   secrets or an approved server-side broker.
5. Map provider-native events to MORT's normalized statuses and safe failure
   codes. Do not pass raw provider payloads to Flutter.
6. Configure provider-side redaction/deletion and document the actual SLA.
7. Run happy-path, needs-input, under-review, failure, expiration, cancellation,
   duplicate-event, signature-failure, account-mismatch, and deletion tests.
8. Verify real-device capture and accessibility with synthetic provider test
   identities only.

## Production Activation Gates

All must be evidenced before changing runtime mode:

- Provider selected and contract/account approved
- Provider credentials and session broker configured server-side
- Exact handoff hosts approved
- Signed webhook adapter and key rotation verified
- Adult workflow approved
- Business workflow separately approved or kept disabled
- Retention/deletion policy implemented and tested
- Privacy notice version approved and published
- Legal and child-safety approval recorded
- Restricted reviewer roles trained and staffed
- Incident and support escalation drill completed
- Sandbox QA complete and production-candidate review approved
- Public marketplace activation reviewed separately

After those gates, use a new reviewed migration to update the private control
row and set Supabase secrets. Do not change the row manually in the dashboard.
Roll out first to a small closed adult pilot with monitoring and rollback.

## Stop Conditions

Keep identity verification disabled if any provider secret is missing, a host
does not match exactly, webhook verification is unproven, legal wording is not
approved, deletion cannot be demonstrated, reviewer staffing is absent, or the
provider will not confirm the marketplace use case.

