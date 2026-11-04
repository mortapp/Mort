# External Setup Still Needed

## Current Supabase projects

- Production: `jxbnrkasktbhtiujkhay` — current MORT production backend.
- QA: `ckcxakhxqlkhppsxxjhv` — isolated validation target.
- Retired/deleted: `rakjydmgwwgtdislanbt` — deleted. Never reconnect, deploy to, or use its credentials.

Historical rebuild reports that mention the deleted project describe the old environment only. They do not establish current production readiness.

## Remaining external work

- Keep service-role/server secrets in Supabase/server tooling only. Never put them in mobile source, `.env.local`, commits, or release archives.
- Verify Supabase Auth redirect URLs and OAuth provider configuration against the current production project.
- Complete the first-admin bootstrap only through trusted, reviewed operations.
- Re-run Supabase advisors and close the open production security findings before launch.
- Provision QA-only credentials and test accounts for hosted Stripe and provider regression. Do not reuse production credentials.
- Configure and verify production backups, retention, alerting, and an isolated restore test before release.
- Complete external legal review for teen labor, parental consent/privacy, payments, data retention/deletion, and state-law requirements.
- Confirm a monitored child-safety contact, staffed reporting/escalation workflow, and incident-response coverage.
- Complete signed Android AAB verification and real-device testing; complete iOS archive/TestFlight testing on an authorized macOS runner.
- Deploy and validate push, RevenueCat, and other non-Stripe Edge Functions in QA before any production deployment.
- Configure RevenueCat products/entitlements and sandbox purchase tests only after QA secrets and app-store configuration are ready.
- Configure AdMob IDs, UMP/consent, app-ads.txt, and App Store ads/privacy disclosures only when monetization is separately approved.

Production release controls remain closed until the technical, legal, safety, backup, and store-certification gates are evidenced.
