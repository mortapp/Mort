# MORT Mission Pilot RLS and Storage Report

Remote audit project: `rakjydmgwwgtdislanbt`.

## Public mission tables

- Tables audited: 25
- RLS enabled: 25
- Tables with anonymous table privileges: 0
- Deliberate no-policy table: `pilot_job_reviews` (deny-by-default)
- Prohibited public housing-status columns: 0
- `profiles.location_setup_mode`: present

Partner/peer QA confirmed that partner staff see only connected participants and no unrestricted messages, earnings, housing details, or unrelated teen records. Poster/public profile tests found no school, shelter, organization, family, or housing disclosure.

## Document vault

- Bucket: `mort-document-vault`
- Public: false
- Size limit: 10 MiB
- MIME types: JPEG, PNG, PDF
- Objects: 0
- Client Storage policies referencing the bucket: 0
- Real-person document cases: 0
- Readiness gates: 0/18 passed
- Real collection: false

`request_document_vault_access` is authenticated but requires a specialized assigned reviewer, conflict clearance, case/object binding, action, and reason. `consume_document_vault_access_grant` is not anonymous or authenticated executable. The prepared Edge Function caps signed delivery at 60 seconds and is intentionally undeployed.

## Migration and backup

All 60 local migration versions match the remote history. Pre-change backup: `backups/remote-feature-schema-rakjydmgwwgtdislanbt-2026-07-19T01-20-16-385Z.json` (public/storage schema, migrations, bucket state, and aggregate counts; no user rows). Post-change backup: `backups/remote-feature-schema-rakjydmgwwgtdislanbt-2026-07-19T03-14-30-758Z.json` (public/private/storage schema, migrations, bucket state, and aggregate counts; no user rows). Backups are excluded from delivery archives.
