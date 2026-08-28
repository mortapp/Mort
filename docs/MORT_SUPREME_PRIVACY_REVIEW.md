# MORT Supreme Privacy Review

## Current Data Boundary

The closed-test client can process account/profile data, DOB for age gating,
general area and optional point-of-use location, jobs/applications, messages,
guardian links, safety/report records, private proof/support attachments,
notification preferences, and audit/operational events. Exact locations,
private messages, proof, and support evidence are not public profile fields.

Real ID collection is disabled. Production identity verification is not
connected. Payments, payouts, escrow, ads, IAP, external support AI, production
push delivery, and crash-provider transmission are disabled in this release.

## Verified Protections

- Private Storage, signed URLs, owner/participant checks, short expiries, MIME/size limits, and access audit.
- Product analytics defaults off and stores only fixed-taxonomy events after versioned opt-in.
- Operational events exclude message, location, token, and evidence content.
- Account deletion is authenticated, idempotent, retention-aware, and available in app/public web contracts.
- Public account deletion self-hosts the pinned Supabase browser bundle with PKCE and self-only CSP scripts.
- Push payload contracts are privacy minimized and raw device tokens are not client readable.
- Metadata backup excludes user rows, object paths/content, Auth users, and secrets.

## Required External Review

Owner-approved Privacy Policy, Terms, Community Guidelines, Safety Rules,
retention schedules, processor list, child/minor notices, guardian disclosures,
App Store/Play Data Safety answers, breach obligations, and identity/payment
provider disclosures remain `CODE-COMPLETE / LEGAL APPROVAL REQUIRED`.

No public deployment should occur until real support/privacy contacts and legal
effective dates replace the deployment-blocking empty fields.

